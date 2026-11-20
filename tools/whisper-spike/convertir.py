"""Whisper base → deux modèles Core ML pour le CHOIX parmi les coups légaux (étude du 19/11/2026).

  WhisperAudio.mlpackage   son 16 kHz (30 s, complété de silence) → clés et valeurs de l'attention croisée, pour
                           les six couches du décodeur (le spectrogramme log-mel de Whisper est calculé DEDANS)
  WhisperScorer.mlpackage  lot de 32 suites de jetons (16 au plus) + clés/valeurs → log P de chaque jeton sachant
                           les précédents et le son ; la somme sur une formulation = sa note

Plus `whisper-pretokens.json` : les jetons de chaque morceau de phrase dont on a besoin (pièces, cases, « en »,
« prend »…), pour que l'iPhone n'ait pas à embarquer le tokeniseur complet.

Usage : HF_HUB_OFFLINE=1 .venv/bin/python convertir.py <dossier de sortie> [--verifier trials.jsonl dossier_sons]
"""
import json
import math
import re
import sys
from pathlib import Path

import numpy as np
import torch
import torch.nn.functional as F
from transformers import WhisperFeatureExtractor, WhisperForConditionalGeneration, WhisperTokenizer

NAME = "openai/whisper-base"
SAMPLES = 480_000
BATCH, LENGTH = 32, 16


class LogMel(torch.nn.Module):
    """Le spectrogramme de Whisper (stft 400/160, fenêtre de Hann, 80 bandes mel, log10, plancher -8, (x+4)/4) en
    convolutions : convertible tel quel."""

    def __init__(self, filters):
        super().__init__()
        n = torch.arange(400, dtype=torch.float64)
        window = 0.5 - 0.5 * torch.cos(2 * math.pi * n / 400)
        k = torch.arange(201, dtype=torch.float64).unsqueeze(1)
        angle = 2 * math.pi * k * n / 400
        self.register_buffer("cos", (torch.cos(angle) * window).float().unsqueeze(1))
        self.register_buffer("sin", (-torch.sin(angle) * window).float().unsqueeze(1))
        self.register_buffer("mel", torch.tensor(filters, dtype=torch.float32).T)  # [80, 201]

    def forward(self, audio):                                   # [1, 480000]
        x = F.pad(audio.unsqueeze(1), (200, 200), mode="reflect")  # [1, 1, 480400]
        re_ = F.conv1d(x, self.cos, stride=160)                 # [1, 201, 3001]
        im = F.conv1d(x, self.sin, stride=160)
        power = (re_ * re_ + im * im)[:, :, :-1]                 # [1, 201, 3000]
        mel = torch.matmul(self.mel, power)                     # [1, 80, 3000]
        log = torch.log10(torch.clamp(mel, min=1e-10))
        log = torch.maximum(log, log.max() - 8.0)
        return (log + 4.0) / 4.0


class Audio(torch.nn.Module):
    def __init__(self, model, filters):
        super().__init__()
        self.logmel = LogMel(filters)
        self.encoder = model.model.encoder
        layers = model.model.decoder.layers
        self.k = torch.nn.ModuleList([l.encoder_attn.k_proj for l in layers])
        self.v = torch.nn.ModuleList([l.encoder_attn.v_proj for l in layers])

    def forward(self, audio):
        h = self.encoder(self.logmel(audio)).last_hidden_state  # [1, 1500, 512]
        keys = torch.stack([k(h)[0] for k in self.k])           # [6, 1500, 512]
        values = torch.stack([v(h)[0] for v in self.v])
        return keys, values


class Scorer(torch.nn.Module):
    """Le décodeur de Whisper, réécrit pour noter un LOT de suites d'un coup contre UN son (clés/valeurs croisées
    calculées une fois par `Audio`, partagées par tout le lot)."""

    def __init__(self, model):
        super().__init__()
        d = model.model.decoder
        self.embed = d.embed_tokens
        self.positions = d.embed_positions.weight
        self.layers = d.layers
        self.norm = d.layer_norm
        self.heads, self.dim = 8, 64
        mask = torch.full((LENGTH, LENGTH), float("-inf")).triu(1)
        self.register_buffer("causal", mask)

    # Dimensions FIXES (BATCH, LENGTH) : lues sur le tenseur, elles deviennent des opérations que Core ML refuse.
    def split(self, x):                                         # [B, L, 512] → [B, 8, L, 64]
        return x.reshape(BATCH, LENGTH, 8, 64).transpose(1, 2)

    def merge(self, x):
        return x.transpose(1, 2).reshape(BATCH, LENGTH, 512)

    def forward(self, tokens, keys, values):                    # [B, L] int32, [6, 1500, 512] ×2
        tokens = tokens.long()
        x = self.decode(self.embed(tokens) + self.positions[:LENGTH], keys, values)
        logits = x @ self.embed.weight.T                        # [B, L, 51865]
        norm = torch.logsumexp(logits, dim=-1)                  # [B, L]
        # Le jeton SUIVANT de chaque position, sans « gather » sur le tenseur géant : un produit scalaire.
        nxt = torch.cat([tokens[:, 1:], tokens[:, -1:]], dim=1)
        target = (x * self.embed(nxt)).sum(-1)
        return target - norm                                    # [B, L] ; la dernière colonne ne sert pas

    def decode(self, x, keys, values):
        for i, layer in enumerate(self.layers):
            a = layer.self_attn
            h = layer.self_attn_layer_norm(x)
            q, k, v = self.split(a.q_proj(h) * a.scaling), self.split(a.k_proj(h)), self.split(a.v_proj(h))
            w = torch.softmax(q @ k.transpose(-1, -2) + self.causal, dim=-1)
            x = x + a.out_proj(self.merge(w @ v))
            c = layer.encoder_attn
            h = layer.encoder_attn_layer_norm(x)
            q = self.split(c.q_proj(h) * c.scaling)
            ck = keys[i].reshape(1500, 8, 64).transpose(0, 1).unsqueeze(0)    # [1, 8, 1500, 64]
            cv = values[i].reshape(1500, 8, 64).transpose(0, 1).unsqueeze(0)
            w = torch.softmax(q @ ck.transpose(-1, -2), dim=-1)
            x = x + c.out_proj(self.merge(w @ cv))
            h = layer.final_layer_norm(x)
            x = x + layer.fc2(F.gelu(layer.fc1(h)))
        return self.norm(x)                                     # [B, L, 512]


class SmallScorer(Scorer):
    """Le noteur à VOCABULAIRE RÉDUIT (19/11/2026) : les jetons d'entrée sont des numéros LOCAUX (les 4 du préfixe,
    puis ceux des phrases d'échecs et la fin), et chaque jeton est normalisé sur ces seuls jetons d'échecs — même
    choix sur le Mac (48/51), ~400 fois moins de calcul en sortie, plus de débordement en demi-précision, et plus de
    table de 51 865 jetons dans le modèle."""

    def __init__(self, model, local, allowed_count):
        super().__init__(model)
        table = model.model.decoder.embed_tokens.weight.detach()[torch.tensor(local)]
        del self.embed
        self.table = torch.nn.Parameter(table, requires_grad=False)      # [V, 512], V = 4 + allowed
        self.first_allowed = len(local) - allowed_count

    def forward(self, tokens, keys, values):
        tokens = tokens.long()
        x = self.table[tokens] + self.positions[:LENGTH]
        x = self.decode(x, keys, values)
        logits = x @ self.table[self.first_allowed:].T                   # [B, L, ~101]
        norm = torch.logsumexp(logits, dim=-1)
        nxt = torch.cat([tokens[:, 1:], tokens[:, -1:]], dim=1)
        target = (x * self.table[nxt]).sum(-1)
        return target - norm


PRETOKEN = re.compile(r" ?[^\W\d_]+| ?\d+| ?[^\s\w]+|\s+")


def pretokens(text):
    return PRETOKEN.findall(text)


def vocabulary_pieces():
    """Tous les morceaux de phrase que l'iPhone peut avoir à écrire (cf. spoken_forms + surface de mesure.py)."""
    words = ["roi", "dame", "tour", "fou", "cavalier", "pion", "en", "prend", "petit", "grand", "roque", "promotion"]
    pieces = set()
    for w in words:
        for v in (w, w.capitalize()):
            pieces |= {v, " " + v}
    for f in "abcdefgh":
        for v in (f, f.upper()):
            pieces |= {v, " " + v}
    for r in "12345678":
        pieces |= {r, " " + r}
    pieces |= {".", " ."}
    return sorted(pieces)


def main():
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    model = WhisperForConditionalGeneration.from_pretrained(NAME).eval()
    extractor = WhisperFeatureExtractor.from_pretrained(NAME)
    tok = WhisperTokenizer.from_pretrained(NAME)
    audio_model, scorer = Audio(model, extractor.mel_filters).eval(), Scorer(model).eval()

    # 1. Les jetons des morceaux, et la preuve que les recoller redonne le tokeniseur.
    table = {p: tok.encode(p, add_special_tokens=False) for p in vocabulary_pieces()}
    sys.path.insert(0, str(Path(__file__).parent))
    import mesure
    for sample in [" Pion e4.", " Cavalier F3", " cavalier b1 en d2.", " Petit roque.", " E8 dame", " Roi prend H7."]:
        glued = [t for p in pretokens(sample) for t in table[p]]
        assert glued == tok.encode(sample, add_special_tokens=False), sample
    prefix = tok.convert_tokens_to_ids(["<|startoftranscript|>", "<|fr|>", "<|transcribe|>", "<|notimestamps|>"])
    # Numéros LOCAUX du noteur réduit : les 4 du préfixe, puis les jetons d'échecs et la fin.
    allowed = sorted({t for ids_ in table.values() for t in ids_} | {tok.eos_token_id})
    local = prefix + allowed
    lid = {t: i for i, t in enumerate(local)}
    small = SmallScorer(model, local, len(allowed)).eval()
    (out / "whisper-pretokens.json").write_text(json.dumps(
        {"prefix": [lid[t] for t in prefix], "endoftext": lid[tok.eos_token_id],
         "pieces": {p: [lid[t] for t in ids_] for p, ids_ in table.items()}}, ensure_ascii=False))
    print(f"{len(table)} morceaux, {len(local)} jetons locaux ; préfixe {prefix}")

    # 2. La réécriture rend-elle les mêmes notes que Whisper d'origine ?
    with torch.no_grad():
        rng = np.random.default_rng(1)
        audio = np.zeros(SAMPLES, dtype=np.float32)
        audio[:32000] = rng.normal(0, 0.05, 32000).astype(np.float32)
        ref_mel = extractor(audio[:32000], sampling_rate=16000, return_tensors="pt").input_features
        mel = audio_model.logmel(torch.tensor(audio).unsqueeze(0))
        print("écart du spectrogramme :", float((mel - ref_mel).abs().max()))
        keys, values = audio_model(torch.tensor(audio).unsqueeze(0))
        texts = [" Pion e4.", " Cavalier f3", " Petit roque."]
        ids = torch.full((BATCH, LENGTH), tok.eos_token_id, dtype=torch.int32)
        for i, t in enumerate(texts):
            s = prefix + tok.encode(t, add_special_tokens=False) + [tok.eos_token_id]
            ids[i, :len(s)] = torch.tensor(s)
        mine = scorer(ids, keys, values)
        enc = model.model.encoder(ref_mel).last_hidden_state
        for i, t in enumerate(texts):
            s = prefix + tok.encode(t, add_special_tokens=False) + [tok.eos_token_id]
            logits = model(encoder_outputs=(enc,), decoder_input_ids=torch.tensor([s[:-1]])).logits
            ref = torch.log_softmax(logits, -1)[0].gather(1, torch.tensor(s[1:]).unsqueeze(1)).squeeze(1)
            print(f"  {t!r} : origine {ref[len(prefix)-1:].sum():.4f}, réécrit {mine[i, len(prefix)-1:len(s)-1].sum():.4f}")
        # Le noteur réduit face au calcul de référence restreint aux mêmes jetons (variantes.py).
        local_ids = torch.full((BATCH, LENGTH), lid[tok.eos_token_id], dtype=torch.int32)
        for i, t in enumerate(texts):
            s = prefix + tok.encode(t, add_special_tokens=False) + [tok.eos_token_id]
            local_ids[i, :len(s)] = torch.tensor([lid[x] for x in s])
        reduced = small(local_ids, keys, values)
        for i, t in enumerate(texts):
            s = prefix + tok.encode(t, add_special_tokens=False) + [tok.eos_token_id]
            logits = model(encoder_outputs=(enc,), decoder_input_ids=torch.tensor([s[:-1]])).logits[0][:, allowed]
            pos = torch.tensor([allowed.index(x) if x in allowed else 0 for x in s[1:]])
            ref = torch.log_softmax(logits, -1).gather(1, pos.unsqueeze(1)).squeeze(1)
            print(f"  réduit {t!r} : référence {ref[len(prefix)-1:].sum():.4f}, "
                  f"noteur {reduced[i, len(prefix)-1:len(s)-1].sum():.4f}")

    # 3. Core ML.
    import coremltools as ct
    example = torch.zeros(1, SAMPLES)
    traced = torch.jit.trace(audio_model, example)
    # Le SPECTROGRAMME en pleine précision : en demi-précision, la puissance d'un son faible (iPhone XS, deux fois
    # moins fort qu'iPhone3) tombe sous le plus petit nombre représentable — 12/21 au lieu de 16/21 (19/11/2026).
    # Tout ce qui porte une dimension du spectrogramme (480 000 / 480 400 échantillons, 201 fréquences, [1, 80, 3000])
    # ou un maximum global reste en float32 ; l'encodeur, lui, passe en float16.
    def half(op):
        if op.op_type == "reduce_max":
            return False
        for v in op.outputs:
            shape = tuple(v.shape) if v.shape is not None else ()
            if any(d in (480_000, 480_400, 201) for d in shape if isinstance(d, int)) or shape == (1, 80, 3000):
                return False
        return True

    ml = ct.convert(traced, inputs=[ct.TensorType("audio", shape=(1, SAMPLES))],
                    outputs=[ct.TensorType("keys"), ct.TensorType("values")],
                    minimum_deployment_target=ct.target.iOS17,
                    compute_precision=ct.transform.FP16ComputePrecision(op_selector=half))
    ml.save(str(out / "WhisperAudio.mlpackage"))
    traced = torch.jit.trace(small, (local_ids, keys, values))
    ml = ct.convert(traced, inputs=[ct.TensorType("tokens", shape=(BATCH, LENGTH), dtype=np.int32),
                                    ct.TensorType("keys", shape=(6, 1500, 512)),
                                    ct.TensorType("values", shape=(6, 1500, 512))],
                    outputs=[ct.TensorType("logprobs")],
                    minimum_deployment_target=ct.target.iOS17, compute_precision=ct.precision.FLOAT16)
    ml.save(str(out / "WhisperScorer.mlpackage"))
    print("Core ML écrit dans", out)


if __name__ == "__main__":
    main()
