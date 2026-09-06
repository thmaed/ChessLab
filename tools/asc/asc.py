#!/usr/bin/env python3
"""ChessLab → App Store Connect, jusqu'au seuil de la soumission.

    tools/asc/.venv/bin/python tools/asc/asc.py <commande> [--version 1.8.0] [--build 11]

Commandes :
    apps         vérifie la clé et affiche l'app
    version      crée (ou retrouve) la version App Store et l'affiche
    metadata     nom, sous-titre, mots-clés, promo, description, nouveautés,
                 URLs, en FR et EN — lus dans AppStoreSubmission/METADATA.md
    screenshots  remplace les captures des deux formats (iPhone 6,7", iPad 13")
    previews     remplace les aperçus vidéo des deux formats
    build        attend que le build soit traité par Apple, l'affiche
    attach       rattache le build à la version
    review       notes pour la révision (et « pas de compte de démonstration »)
    status       ce qu'App Store Connect a pour cette version
    all          tout ce qui précède, dans l'ordre, puis s'arrête AVANT la soumission

Authentification : clé d'API d'équipe (rôle App Manager) dans ~/.private_keys/
AuthKey_<KEY_ID>.p8, avec ASC_ISSUER_ID dans l'environnement (et ASC_KEY_ID
si plusieurs clés sont présentes). Rien de tout cela n'entre dans le dépôt.
"""
import argparse, glob, hashlib, json, os, re, sys, time
from pathlib import Path

import jwt, requests

ROOT = Path(__file__).resolve().parents[2]
SUBMISSION = ROOT / "AppStoreSubmission"
BUNDLE_ID = "com.chesslab.ChessLab"
API = "https://api.appstoreconnect.apple.com/v1"

# Formats App Store Connect ↔ dossiers du dépôt.
# - Les captures iPhone font 1284 × 2778 : c'est le format « 6,5 pouces » de
#   l'API (le « 6,7 pouces » exige 1290 × 2796 et REFUSE 1284 × 2778 —
#   IMAGE_INCORRECT_DIMENSIONS, constaté le 06/09/2026). Le dossier garde
#   son nom historique.
# - Le « iPad 13 pouces » de l'interface est, dans l'API, le jeu « iPad Pro
#   12,9 pouces 3e génération » ; il accepte 2064 × 2752.
SCREENSHOT_SETS = {
    "APP_IPHONE_65": SUBMISSION / "screenshots" / "iphone-6.7",
    "APP_IPAD_PRO_3GEN_129": SUBMISSION / "screenshots" / "ipad-13",
}
PREVIEW_SETS = {
    "IPHONE_65": ["iphone-classic-puzzle.mov", "iphone-variants.mov"],
    "IPAD_PRO_3GEN_129": ["ipad-classic-puzzle.mov", "ipad-variants.mov"],
}
# Les langues de la fiche : le français, et l'anglais du ROYAUME-UNI — c'est
# celui que la fiche a depuis l'origine ; un « en-US » neuf est refusé parce
# que le nom « ChessLab » y est déjà pris par une autre app.
LOCALES = {"fr-FR": "Français", "en-GB": "English"}


# ---------------------------------------------------------------- client

class Client:
    def __init__(self):
        # ~/.private_keys/asc.env : ASC_KEY_ID et ASC_ISSUER_ID, hors dépôt.
        env_file = Path.home() / ".private_keys" / "asc.env"
        if env_file.exists():
            for line in env_file.read_text().splitlines():
                if "=" in line and not line.startswith("#"):
                    k, v = line.split("=", 1)
                    os.environ.setdefault(k.strip(), v.strip())
        keys = sorted(Path.home().glob(".private_keys/AuthKey_*.p8"))
        key_id = os.environ.get("ASC_KEY_ID")
        if not key_id:
            if len(keys) != 1:
                sys.exit(f"ASC_KEY_ID requis : {len(keys)} clé(s) dans ~/.private_keys")
            key_id = keys[0].stem.split("_", 1)[1]
        self.issuer = os.environ.get("ASC_ISSUER_ID") or sys.exit("ASC_ISSUER_ID manquant dans l'environnement")
        self.key_id = key_id
        self.private_key = (Path.home() / ".private_keys" / f"AuthKey_{key_id}.p8").read_text()
        self._token = None
        self._token_time = 0

    def token(self):
        if time.time() - self._token_time > 600:
            now = int(time.time())
            self._token = jwt.encode(
                {"iss": self.issuer, "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"},
                self.private_key, algorithm="ES256", headers={"kid": self.key_id},
            )
            self._token_time = now
        return self._token

    def call(self, method, path, **kw):
        url = path if path.startswith("http") else API + path
        headers = {"Authorization": f"Bearer {self.token()}"}
        r = requests.request(method, url, headers=headers, timeout=120, **kw)
        if r.status_code >= 400:
            try:
                errors = r.json().get("errors", [])
                detail = "; ".join(f"{e.get('title')}: {e.get('detail')}" for e in errors)
            except ValueError:
                detail = r.text[:400]
            sys.exit(f"{method} {path} → {r.status_code} {detail}")
        return r.json() if r.content else {}

    def get(self, path, **params):
        return self.call("GET", path, params=params)

    def get_all(self, path, **params):
        out = []
        page = self.call("GET", path, params=params)
        out += page.get("data", [])
        while page.get("links", {}).get("next"):
            page = self.call("GET", page["links"]["next"])
            out += page.get("data", [])
        return out

    def post(self, path, data):
        return self.call("POST", path, json={"data": data})

    def try_post(self, path, data):
        """Comme `post`, mais rend None (et explique) sur un refus 409."""
        r = requests.request("POST", API + path, headers={"Authorization": f"Bearer {self.token()}"},
                             json={"data": data}, timeout=120)
        if r.status_code == 409:
            detail = "; ".join(e.get("detail", "") for e in r.json().get("errors", []))
            print(f"  ⚠️ refusé : {detail}")
            return None
        if r.status_code >= 400:
            sys.exit(f"POST {path} → {r.status_code} {r.text[:400]}")
        return r.json()

    def patch(self, path, data):
        return self.call("PATCH", path, json={"data": data})

    def delete(self, path):
        return self.call("DELETE", path)


def rel(type_, id_):
    return {"data": {"type": type_, "id": id_}}


# ---------------------------------------------------------------- METADATA.md

def read_metadata():
    """Les champs à coller, lus dans METADATA.md : chaque champ est un bloc
    ``` sous son étiquette en gras, dans la section de sa langue."""
    text = (SUBMISSION / "METADATA.md").read_text(encoding="utf-8")

    def section(title_re):
        m = re.search(r"^## " + title_re + r".*?$(.*?)(?=^## |\Z)", text, re.M | re.S)
        if not m:
            sys.exit(f"section introuvable dans METADATA.md : {title_re}")
        return m.group(1)

    def field(block, label):
        m = re.search(r"\*\*" + re.escape(label) + r"\*\*.*?```\n(.*?)```", block, re.S)
        if not m:
            sys.exit(f"champ introuvable dans METADATA.md : {label}")
        return m.group(1).strip("\n")

    def subsection(block, title):
        m = re.search(r"^### " + re.escape(title) + r".*?```\n(.*?)```", block, re.M | re.S)
        if not m:
            sys.exit(f"sous-section introuvable dans METADATA.md : {title}")
        return m.group(1).strip("\n")

    fr = section(r"Français \(langue principale\)")
    en = section(r"English")
    news = section(r"Nouveautés de cette version")
    common = section(r"Champs communs")
    notes = section(r"App Review Notes")

    def url(label):
        m = re.search(r"\*\*" + re.escape(label) + r"\*\*[^`]*`([^`]+)`", common)
        return m.group(1) if m else None

    meta = {
        "fr-FR": {
            "name": field(fr, "Nom de l'app"), "subtitle": field(fr, "Sous-titre"),
            "keywords": field(fr, "Mots-clés"), "promotionalText": field(fr, "Texte promotionnel"),
            "description": field(fr, "Description"), "whatsNew": subsection(news, "Français"),
        },
        "en-GB": {
            "name": field(en, "Name"), "subtitle": field(en, "Subtitle"),
            "keywords": field(en, "Keywords"), "promotionalText": field(en, "Promotional text"),
            "description": field(en, "Description"), "whatsNew": subsection(news, "English"),
        },
        "supportUrl": url("URL du support"),
        "marketingUrl": url("URL marketing"),
        "privacyPolicyUrl": url("URL de la politique de confidentialité"),
        "reviewNotes": re.search(r"```\n(.*?)```", notes, re.S).group(1).strip("\n"),
    }
    limits = {"name": 30, "subtitle": 30, "keywords": 100, "promotionalText": 170, "description": 4000, "whatsNew": 4000}
    for locale in LOCALES:
        for key, limit in limits.items():
            n = len(meta[locale][key])
            if n > limit:
                sys.exit(f"{locale} {key} : {n} caractères, limite {limit}")
    return meta


# ---------------------------------------------------------------- app, version

def find_app(c):
    apps = c.get("/apps", **{"filter[bundleId]": BUNDLE_ID})["data"]
    if not apps:
        sys.exit(f"aucune app {BUNDLE_ID} visible avec cette clé")
    return apps[0]


def same_version(a, b):
    """« 1.8 » et « 1.8.0 » désignent la même version pour App Store Connect."""
    norm = lambda s: tuple(int(x) for x in s.split(".")) + (0, 0, 0)
    return norm(a)[:3] == norm(b)[:3]


def find_version(c, app_id, version_string, create=False):
    versions = c.get_all(f"/apps/{app_id}/appStoreVersions", **{"filter[platform]": "IOS"})
    for v in versions:
        if same_version(v["attributes"]["versionString"], version_string):
            return v
    if not create:
        sys.exit(f"version {version_string} absente d'App Store Connect (commande `version` pour la créer)")
    return c.post("/appStoreVersions", {
        "type": "appStoreVersions",
        "attributes": {"platform": "IOS", "versionString": version_string},
        "relationships": {"app": rel("apps", app_id)},
    })["data"]


def version_localizations(c, version_id):
    return {l["attributes"]["locale"]: l for l in c.get_all(f"/appStoreVersions/{version_id}/appStoreVersionLocalizations")}


# ---------------------------------------------------------------- commandes

def cmd_apps(c, args):
    app = find_app(c)
    print(f"{app['attributes']['name']}  ({app['attributes']['bundleId']})  id {app['id']}")
    for v in c.get_all(f"/apps/{app['id']}/appStoreVersions", **{"filter[platform]": "IOS"})[:5]:
        a = v["attributes"]
        print(f"  {a['versionString']:8} {a['appStoreState']}")


def cmd_version(c, args):
    app = find_app(c)
    v = find_version(c, app["id"], args.version, create=True)
    print(f"version {v['attributes']['versionString']} : {v['attributes']['appStoreState']}  id {v['id']}")


def cmd_metadata(c, args):
    meta = read_metadata()
    app = find_app(c)
    v = find_version(c, app["id"], args.version)
    existing = version_localizations(c, v["id"])
    for locale in LOCALES:
        m = meta[locale]
        attrs = {
            "description": m["description"], "keywords": m["keywords"],
            "promotionalText": m["promotionalText"], "whatsNew": m["whatsNew"],
            "supportUrl": meta["supportUrl"], "marketingUrl": meta["marketingUrl"],
        }
        if locale in existing:
            c.patch(f"/appStoreVersionLocalizations/{existing[locale]['id']}",
                    {"type": "appStoreVersionLocalizations", "id": existing[locale]["id"], "attributes": attrs})
        else:
            created = c.try_post("/appStoreVersionLocalizations", {
                "type": "appStoreVersionLocalizations",
                "attributes": {"locale": locale, **attrs},
                "relationships": {"appStoreVersion": rel("appStoreVersions", v["id"])},
            })
            if not created:
                print(f"  {locale}: langue absente de la fiche et refusée — voir ci-dessus")
                continue
        print(f"  {locale}: description, mots-clés, promo, nouveautés, URLs")

    # Nom, sous-titre, URL de confidentialité : au niveau de l'app (appInfo
    # modifiable, celui de la version en préparation).
    infos = c.get_all(f"/apps/{app['id']}/appInfos")
    editable = [i for i in infos if i["attributes"].get("appStoreState") not in ("READY_FOR_SALE", "READY_FOR_DISTRIBUTION")]
    info = (editable or infos)[0]
    locs = {l["attributes"]["locale"]: l for l in c.get_all(f"/appInfos/{info['id']}/appInfoLocalizations")}
    for locale in LOCALES:
        attrs = {"name": meta[locale]["name"], "subtitle": meta[locale]["subtitle"], "privacyPolicyUrl": meta["privacyPolicyUrl"]}
        if locale in locs:
            c.patch(f"/appInfoLocalizations/{locs[locale]['id']}",
                    {"type": "appInfoLocalizations", "id": locs[locale]["id"], "attributes": attrs})
        elif not c.try_post("/appInfoLocalizations", {
                "type": "appInfoLocalizations", "attributes": {"locale": locale, **attrs},
                "relationships": {"appInfo": rel("appInfos", info["id"])},
            }):
            continue
        print(f"  {locale}: nom, sous-titre, URL de confidentialité")


def upload_asset(c, create_path, set_rel_name, set_type, set_id, path, type_):
    """Réserve, téléverse par morceaux, puis confirme avec la somme MD5 —
    le protocole commun aux captures et aux aperçus."""
    data = path.read_bytes()
    reservation = c.post(create_path, {
        "type": type_,
        "attributes": {"fileName": path.name, "fileSize": len(data)},
        "relationships": {set_rel_name: rel(set_type, set_id)},
    })["data"]
    for op in reservation["attributes"]["uploadOperations"]:
        headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        chunk = data[op["offset"]: op["offset"] + op["length"]]
        r = requests.request(op["method"], op["url"], headers=headers, data=chunk, timeout=600)
        if r.status_code >= 400:
            sys.exit(f"téléversement de {path.name} : {r.status_code} {r.text[:200]}")
    c.patch(f"{create_path}/{reservation['id']}", {
        "type": type_, "id": reservation["id"],
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()},
    })
    return reservation["id"]


def wait_asset_state(c, path, ids, label):
    """Apple traite les fichiers après le téléversement : on attend COMPLETE,
    et on s'arrête net sur FAILED."""
    pending = set(ids)
    deadline = time.time() + 900
    while pending and time.time() < deadline:
        for id_ in list(pending):
            state = c.get(f"{path}/{id_}")["data"]["attributes"]["assetDeliveryState"]
            if state["state"] == "COMPLETE":
                pending.discard(id_)
            elif state["state"] == "FAILED":
                sys.exit(f"{label} {id_} refusé par Apple : {state.get('errors')}")
        if pending:
            time.sleep(5)
    if pending:
        sys.exit(f"{label} : {len(pending)} fichier(s) toujours en traitement après 15 min")


def cmd_screenshots(c, args):
    app = find_app(c)
    v = find_version(c, app["id"], args.version)
    locs = version_localizations(c, v["id"])
    if not locs:
        sys.exit("aucune localisation sur la version : lancer `metadata` d'abord")
    for locale in locs:
        sets = {s["attributes"]["screenshotDisplayType"]: s
                for s in c.get_all(f"/appStoreVersionLocalizations/{locs[locale]['id']}/appScreenshotSets")}
        for display_type, folder in SCREENSHOT_SETS.items():
            files = sorted((folder / "en").glob("*.png"))
            if not files:
                sys.exit(f"aucune capture dans {folder}/en")
            if len(files) > 10:
                # App Store Connect n'accepte que dix captures par format ;
                # les suivantes vont dans hors-fiche/, pas sur la fiche.
                print(f"  ⚠️ {folder.name} : {len(files)} captures, seules les dix premières partent — "
                      + ", ".join(f.name for f in files[10:]) + " ignorées")
                files = files[:10]
            if display_type in sets:
                set_id = sets[display_type]["id"]
                for shot in c.get_all(f"/appScreenshotSets/{set_id}/appScreenshots"):
                    c.delete(f"/appScreenshots/{shot['id']}")
            else:
                set_id = c.post("/appScreenshotSets", {
                    "type": "appScreenshotSets",
                    "attributes": {"screenshotDisplayType": display_type},
                    "relationships": {"appStoreVersionLocalization": rel("appStoreVersionLocalizations", locs[locale]["id"])},
                })["data"]["id"]
            ids = [upload_asset(c, "/appScreenshots", "appScreenshotSet", "appScreenshotSets", set_id, f, "appScreenshots") for f in files]
            c.call("PATCH", f"/appScreenshotSets/{set_id}/relationships/appScreenshots",
                   json={"data": [{"type": "appScreenshots", "id": i} for i in ids]})
            wait_asset_state(c, "/appScreenshots", ids, "capture")
            print(f"  {locale} {display_type}: {len(files)} captures")


def cmd_previews(c, args):
    app = find_app(c)
    v = find_version(c, app["id"], args.version)
    locs = version_localizations(c, v["id"])
    if not locs:
        sys.exit("aucune localisation sur la version : lancer `metadata` d'abord")
    for locale in locs:
        sets = {s["attributes"]["previewType"]: s
                for s in c.get_all(f"/appStoreVersionLocalizations/{locs[locale]['id']}/appPreviewSets")}
        for preview_type, names in PREVIEW_SETS.items():
            files = [SUBMISSION / "videos" / n for n in names if (SUBMISSION / "videos" / n).exists()]
            if not files:
                sys.exit(f"aucun aperçu pour {preview_type}")
            if preview_type in sets:
                set_id = sets[preview_type]["id"]
                for p in c.get_all(f"/appPreviewSets/{set_id}/appPreviews"):
                    c.delete(f"/appPreviews/{p['id']}")
            else:
                set_id = c.post("/appPreviewSets", {
                    "type": "appPreviewSets",
                    "attributes": {"previewType": preview_type},
                    "relationships": {"appStoreVersionLocalization": rel("appStoreVersionLocalizations", locs[locale]["id"])},
                })["data"]["id"]
            ids = [upload_asset(c, "/appPreviews", "appPreviewSet", "appPreviewSets", set_id, f, "appPreviews") for f in files]
            wait_asset_state(c, "/appPreviews", ids, "aperçu")
            print(f"  {locale} {preview_type}: {len(files)} aperçu(s)")


def find_build(c, app_id, version, build):
    builds = c.get_all("/builds", **{
        "filter[app]": app_id, "filter[version]": build,
        "filter[preReleaseVersion.version]": version, "sort": "-uploadedDate",
    })
    return builds[0] if builds else None


def cmd_build(c, args):
    app = find_app(c)
    deadline = time.time() + (3600 if args.wait else 0)
    while True:
        b = find_build(c, app["id"], args.version, args.build)
        state = b["attributes"]["processingState"] if b else "ABSENT"
        if state == "VALID":
            print(f"build {args.version} ({args.build}) traité, id {b['id']}")
            return b
        if state in ("FAILED", "INVALID"):
            sys.exit(f"build {args.build} : {state}")
        if time.time() >= deadline:
            sys.exit(f"build {args.version} ({args.build}) : {state} — relancer avec --wait après le téléversement")
        print(f"  build {args.build} : {state}, nouvelle vérification dans 60 s")
        time.sleep(60)


def cmd_attach(c, args):
    app = find_app(c)
    v = find_version(c, app["id"], args.version)
    b = cmd_build(c, args)
    if b["attributes"].get("usesNonExemptEncryption") is None:
        # Le projet règle ITSAppUsesNonExemptEncryption = NO ; si la clé
        # n'était pas dans le binaire, on répond ici, comme documenté.
        c.patch(f"/builds/{b['id']}", {"type": "builds", "id": b["id"], "attributes": {"usesNonExemptEncryption": False}})
    c.call("PATCH", f"/appStoreVersions/{v['id']}/relationships/build", json={"data": {"type": "builds", "id": b["id"]}})
    print(f"build {args.build} rattaché à la version {args.version}")


def cmd_review(c, args):
    meta = read_metadata()
    app = find_app(c)
    v = find_version(c, app["id"], args.version)
    detail = c.get(f"/appStoreVersions/{v['id']}/appStoreReviewDetail").get("data")
    attrs = {"notes": meta["reviewNotes"], "demoAccountRequired": False}
    if detail:
        c.patch(f"/appStoreReviewDetails/{detail['id']}", {"type": "appStoreReviewDetails", "id": detail["id"], "attributes": attrs})
        a = detail["attributes"]
        if not a.get("contactEmail"):
            print("  ⚠️ contact de révision vide (nom, téléphone, e-mail) : à remplir dans App Store Connect")
    else:
        c.post("/appStoreReviewDetails", {
            "type": "appStoreReviewDetails", "attributes": attrs,
            "relationships": {"appStoreVersion": rel("appStoreVersions", v["id"])},
        })
        print("  ⚠️ fiche de révision créée sans contact : nom, téléphone, e-mail à remplir dans App Store Connect")
    print("  notes pour la révision posées")


def cmd_status(c, args):
    app = find_app(c)
    v = find_version(c, app["id"], args.version)
    a = v["attributes"]
    print(f"{a['versionString']} — {a['appStoreState']} — sortie {a.get('releaseType')}")
    build = c.get(f"/appStoreVersions/{v['id']}/build").get("data")
    print("  build :", f"{build['attributes']['version']} ({build['attributes']['processingState']})" if build else "aucun")
    for locale, loc in version_localizations(c, v["id"]).items():
        shots = sum(len(c.get_all(f"/appScreenshotSets/{s['id']}/appScreenshots"))
                    for s in c.get_all(f"/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets"))
        previews = sum(len(c.get_all(f"/appPreviewSets/{s['id']}/appPreviews"))
                       for s in c.get_all(f"/appStoreVersionLocalizations/{loc['id']}/appPreviewSets"))
        la = loc["attributes"]
        print(f"  {locale}: {shots} captures, {previews} aperçus, nouveautés {len(la.get('whatsNew') or '')} car., description {len(la.get('description') or '')} car.")
    detail = c.get(f"/appStoreVersions/{v['id']}/appStoreReviewDetail").get("data")
    print("  révision :", "notes posées" if detail and detail["attributes"].get("notes") else "sans notes",
          "· contact", detail["attributes"].get("contactEmail") if detail else "absent")


def cmd_all(c, args):
    args.wait = True
    print("version"); cmd_version(c, args)
    print("métadonnées"); cmd_metadata(c, args)
    print("captures"); cmd_screenshots(c, args)
    print("aperçus"); cmd_previews(c, args)
    print("build"); cmd_attach(c, args)
    print("révision"); cmd_review(c, args)
    print("\nTout est en place. Il reste à ouvrir App Store Connect, relire, et cliquer « Soumettre pour révision ».")
    cmd_status(c, args)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("command", choices=["apps", "version", "metadata", "screenshots", "previews", "build", "attach", "review", "status", "all"])
    p.add_argument("--version", default=None, help="version marketing (défaut : MARKETING_VERSION du projet)")
    p.add_argument("--build", default=None, help="numéro de build (défaut : CURRENT_PROJECT_VERSION du projet)")
    p.add_argument("--wait", action="store_true", help="build : attendre le traitement par Apple (1 h max)")
    args = p.parse_args()
    # Version et build de la CIBLE APPLICATIVE : les cibles de test portent
    # leurs propres numéros (1.2.0 / 3), sans rapport avec la soumission.
    pbx = (ROOT / "ChessLab.xcodeproj" / "project.pbxproj").read_text()
    app_settings = [b for b in re.findall(r"buildSettings = \{(.*?)\};", pbx, re.S)
                    if f"PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};" in b]
    versions = {re.search(r"MARKETING_VERSION = ([\d.]+);", b).group(1) for b in app_settings}
    builds = {re.search(r"CURRENT_PROJECT_VERSION = ([\d.]+);", b).group(1) for b in app_settings}
    if len(versions) != 1 or len(builds) != 1:
        sys.exit(f"version/build incohérents entre Debug et Release : {versions} / {builds}")
    args.version = args.version or versions.pop()
    args.build = args.build or builds.pop()
    c = Client()
    globals()["cmd_" + args.command](c, args)


if __name__ == "__main__":
    main()
