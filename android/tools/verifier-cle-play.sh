#!/usr/bin/env bash
#
# Vérifie, étape par étape, que la clé du compte de service Google Play est
# utilisable — et dit LAQUELLE des étapes manque.
#
# « Ça ne marche pas » peut vouloir dire six choses différentes : fichier au
# mauvais endroit, clé invalide, API non activée, compte de service non invité,
# droits insuffisants, application inexistante. Chacune a son propre message
# ici, et sa propre réparation.
#
#   ./tools/verifier-cle-play.sh              vérifie
#   ./tools/verifier-cle-play.sh --installer  pose la clé de ~/Downloads, puis vérifie
#
# Rien n'est publié : la sonde crée un brouillon de version (« edit »), qui est
# une transaction locale à Google, et le supprime aussitôt.

set -uo pipefail

# Surchargeable pour pouvoir ÉPROUVER le vérificateur lui-même.
CLE="${CLE_PLAY:-${HOME}/.private_keys/play-service-account.json}"
PAQUET="com.maeder.chesslab"
PORTEE="https://www.googleapis.com/auth/androidpublisher"

rouge() { printf '\033[31m✗\033[0m %s\n' "$1"; }
vert()  { printf '\033[32m✓\033[0m %s\n' "$1"; }
info()  { printf '  %s\n' "$1"; }

# --installer : poser la clé au bon endroit, sous le bon nom.
#
# C'est l'étape qui rate le plus souvent, et pour une raison bête : le fichier
# que Google fait télécharger porte un nom à lui (`projet-a1b2c3.json`), et le
# greffon ne lit QUE `~/.private_keys/play-service-account.json`. Un fichier
# parfaitement valide laissé dans Téléchargements ne sert à rien.
if [ "${1:-}" = "--installer" ]; then
    SOURCE="${2:-}"
    if [ -z "$SOURCE" ]; then
        # La plus RÉCENTE des clés de compte de service de Téléchargements.
        SOURCE=$(
            for f in "$HOME"/Downloads/*.json; do
                [ -f "$f" ] || continue
                if python3 -c "
import json,sys
try: d=json.load(open(sys.argv[1]))
except Exception: raise SystemExit(1)
raise SystemExit(0 if d.get('type')=='service_account' else 1)
" "$f" 2>/dev/null; then
                    printf '%s\t%s\n' "$(stat -f %m "$f")" "$f"
                fi
            done | sort -rn | head -1 | cut -f2-
        )
    fi
    if [ -z "$SOURCE" ] || [ ! -f "$SOURCE" ]; then
        rouge "Aucune clé de compte de service trouvée dans ~/Downloads"
        info "Si elle est ailleurs, donnez son chemin :"
        info "  ./tools/verifier-cle-play.sh --installer /chemin/vers/la-cle.json"
        exit 1
    fi
    mkdir -p "$HOME/.private_keys"
    cp "$SOURCE" "$CLE"
    chmod 600 "$CLE"
    vert "Clé installée depuis $(basename "$SOURCE")"
    info "→ $CLE"
    echo
fi

echo "── 1. Le fichier de clé ──────────────────────────────────────"

if [ ! -f "$CLE" ]; then
    rouge "Aucun fichier en $CLE"
    info ""
    info "Le fichier téléchargé depuis Google Cloud porte un nom du genre"
    info "  chesslab-472210-a1b2c3d4e5f6.json"
    info "Il doit être RENOMMÉ et déplacé — le greffon ne cherche que ce"
    info "chemin-là, exactement :"
    info ""
    info "  mkdir -p ~/.private_keys"
    info "  mv ~/Downloads/<le-fichier>.json ~/.private_keys/play-service-account.json"
    info "  chmod 600 ~/.private_keys/play-service-account.json"
    exit 1
fi
vert "Fichier présent"

if ! python3 -c "import json,sys; json.load(open('$CLE'))" 2>/dev/null; then
    rouge "Le fichier n'est pas du JSON valide"
    info "Téléchargement interrompu, ou fichier renommé depuis autre chose."
    info "Recréez une clé : Cloud → Comptes de service → Clés → Ajouter une clé."
    exit 1
fi

lire() { python3 -c "import json;print(json.load(open('$CLE')).get('$1',''))"; }
TYPE=$(lire type); PROJET=$(lire project_id); COMPTE=$(lire client_email)

if [ "$TYPE" != "service_account" ]; then
    rouge "Ce n'est pas une clé de COMPTE DE SERVICE (type = « ${TYPE:-vide} »)"
    info "C'est sans doute un identifiant OAuth client, qui ne convient pas."
    info "Cloud → IAM et administration → Comptes de service → Clés."
    exit 1
fi
vert "Clé de compte de service"
info "projet : $PROJET"
info "compte : $COMPTE"

echo
echo "── 2. Le jeton d'accès (la clé est-elle acceptée ?) ──────────"

# Le JWT se fabrique en Python (base64url + `openssl` pour la signature),
# mais l'appel réseau passe par `curl` : `urllib` s'appuie sur le magasin de
# certificats de Python, qui n'est pas installé par défaut sur macOS — le
# vérificateur annonçait alors une panne de réseau qui n'en était pas une.
JWT=$(python3 - "$CLE" "$PORTEE" <<'FINPY'
import base64, json, os, subprocess, sys, tempfile, time

chemin, portee = sys.argv[1], sys.argv[2]
d = json.load(open(chemin))

def b64(o):
    brut = o if isinstance(o, bytes) else json.dumps(o, separators=(",", ":")).encode()
    return base64.urlsafe_b64encode(brut).rstrip(b"=")

maintenant = int(time.time())
a_signer = b64({"alg": "RS256", "typ": "JWT"}) + b"." + b64({
    "iss": d["client_email"], "scope": portee,
    "aud": "https://oauth2.googleapis.com/token",
    "iat": maintenant, "exp": maintenant + 3600,
})

# `openssl` plutôt qu'une bibliothèque Python : il est là sur toute machine,
# et une dépendance de plus pour signer trois cents octets n'a pas de sens.
# La clé privée passe par un fichier temporaire à droits restreints.
with tempfile.NamedTemporaryFile("w", suffix=".pem", delete=False) as f:
    os.chmod(f.name, 0o600)
    f.write(d["private_key"])
    pem = f.name
try:
    r = subprocess.run(["openssl", "dgst", "-sha256", "-sign", pem],
                       input=a_signer, capture_output=True)
    if r.returncode != 0:
        print("ERREUR_SIGNATURE " + r.stderr.decode().strip()[:200])
    else:
        print((a_signer + b"." + b64(r.stdout)).decode())
finally:
    os.unlink(pem)
FINPY
)

case "$JWT" in
    ERREUR_SIGNATURE*)
        rouge "La clé privée du fichier est inutilisable"
        info "${JWT#ERREUR_SIGNATURE }"
        info "Recréez une clé JSON depuis la console Cloud."
        exit 1 ;;
esac

REP_JETON=$(curl -s -w '\n%{http_code}' -X POST https://oauth2.googleapis.com/token \
    --data-urlencode "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer" \
    --data-urlencode "assertion=${JWT}")
CODE_JETON=$(printf '%s' "$REP_JETON" | tail -1)
CORPS_JETON=$(printf '%s' "$REP_JETON" | sed '$d')

if [ "$CODE_JETON" != "200" ]; then
    rouge "Google refuse la clé (HTTP ${CODE_JETON:-aucun code})"
    info "$(printf '%s' "$CORPS_JETON" | head -c 300)"
    info ""
    info "« invalid_grant » : clé révoquée, ou compte de service supprimé."
    info "« invalid_client » : le compte de service n'existe plus."
    info "Dans les deux cas : recréez une clé depuis la console Cloud."
    exit 1
fi
JETON=$(printf '%s' "$CORPS_JETON" | python3 -c "import json,sys;print(json.load(sys.stdin).get('access_token',''))")
if [ -z "$JETON" ]; then
    rouge "Réponse inattendue du service de jetons"
    info "$(printf '%s' "$CORPS_JETON" | head -c 300)"
    exit 1
fi

vert "Jeton obtenu — la clé est bonne"

echo
echo "── 3. L'API Play (activée ? compte invité ? app existante ?) ─"

REPONSE=$(curl -s -w '\n%{http_code}' -X POST \
    -H "Authorization: Bearer $JETON" -H "Content-Length: 0" \
    "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PAQUET}/edits")
CODE=$(printf '%s' "$REPONSE" | tail -1)
CORPS=$(printf '%s' "$REPONSE" | sed '$d')

case "$CODE" in
    200)
        vert "L'API répond : tout est en place"
        ID=$(printf '%s' "$CORPS" | python3 -c "import json,sys;print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
        [ -n "$ID" ] && curl -s -o /dev/null -X DELETE -H "Authorization: Bearer $JETON" \
            "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PAQUET}/edits/${ID}"
        info "(le brouillon de sonde a été supprimé)"
        echo
        vert "PRÊT — lancez :  cd android && ./gradlew publishBundle"
        exit 0 ;;
    403)
        rouge "Refus (403)"
        if printf '%s' "$CORPS" | grep -q "SERVICE_DISABLED\|has not been used"; then
            info "L'API « Google Play Android Developer » n'est pas ACTIVÉE"
            info "dans le projet $PROJET."
            info "→ console.cloud.google.com → API et services → Bibliothèque"
            info "  → « Google Play Android Developer API » → Activer."
        else
            info "La clé est valide, mais le compte de service n'a pas le droit"
            info "d'agir sur cette application."
            info "→ Play Console → Utilisateurs et autorisations → Inviter :"
            info "  $COMPTE"
            info "  droits : informations sur l'application, présence sur le"
            info "  Store, versions de test."
        fi
        info ""
        info "Réponse brute : $(printf '%s' "$CORPS" | head -c 300)"
        exit 1 ;;
    404)
        rouge "Application introuvable (404)"
        info "Le compte de service fonctionne, mais « $PAQUET » n'existe pas"
        info "encore dans la Play Console."
        info "→ Play Console → Créer une application. L'API sait envoyer des"
        info "  binaires, elle ne sait pas créer une fiche."
        exit 1 ;;
    401)
        rouge "Non authentifié (401)"
        info "Le jeton a été obtenu mais refusé : l'invitation du compte de"
        info "service vient peut-être d'être faite — attendez quelques minutes."
        info "Réponse brute : $(printf '%s' "$CORPS" | head -c 300)"
        exit 1 ;;
    *)
        rouge "Réponse inattendue ($CODE)"
        info "$(printf '%s' "$CORPS" | head -c 400)"
        exit 1 ;;
esac
