#!/usr/bin/env python3
"""Les captures de la fiche Play (2.3), dans TOUTES les langues : sept captures — accueil, séance du jour,
nouvelle partie, analyse (une partie collée, avec le Coach), ouvertures (filtre Classiques), puzzle, finales —
prises avec l'APK de DEBUG (com.maeder.chesslab.debug : un build de release consommerait un versionCode).

    tools/captures-play.py device     es-ES phone-screenshots          # le téléphone branché (ANDROID_SERIAL)
    tools/captures-play.py chesslab-tab7  de-DE tablet-screenshots     # un émulateur
    tools/captures-play.py chesslab-tab10 it-IT large-tablet-screenshots

Les libellés à toucher sont LUS dans les ressources de la langue (values-<langue>/strings_app.xml) : le même
script sert donc fr, en, es, de et it. La notation « Automatique » donne à chaque langue ses lettres.
"""
import re, subprocess, sys, time, os, xml.etree.ElementTree as ET

AVD, LANGUE, DOSSIER = sys.argv[1:4]
RACINE = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SDK = "/opt/homebrew/share/android-commandlinetools"
ADB = f"{SDK}/platform-tools/adb"
PORT = 5560
SERIE = f"emulator-{PORT}"
PAQUET = "com.maeder.chesslab.debug"
APK = f"{RACINE}/android/app/build/outputs/apk/debug/app-debug.apk"
SORTIE = f"{RACINE}/android/app/src/main/play/listings/{LANGUE}/graphics/{DOSSIER}"
FR = LANGUE.startswith("fr")
DEVICE = AVD == "device"
if DEVICE:
    SERIE = os.environ.get("ANDROID_SERIAL") or sys.exit("ANDROID_SERIAL requis en mode device")
RES = f"{RACINE}/android/app/src/main/res"
FOLDER = {"fr": "values-fr", "en": "values", "es": "values-es", "de": "values-de", "it": "values-it"}[LANGUE[:2]]

def L(name):
    """Un libellé de l'app dans la langue cible, lu dans ses ressources."""
    x = ET.parse(f"{RES}/{FOLDER}/strings_app.xml").getroot()
    for e in x.iter("string"):
        if e.get("name") == name:
            return (e.text or "").replace("\\'", "'").replace("\\n", "\n")
    sys.exit(f"ressource introuvable : {name}")
os.makedirs(SORTIE, exist_ok=True)

def adb(*a, **k): return subprocess.run([ADB, "-s", SERIE, *a], capture_output=True, text=True, **k)
def sh(*a): return adb("shell", *a).stdout
def dump():
    sh("uiautomator", "dump", "/sdcard/e.xml")
    x = adb("exec-out", "cat", "/sdcard/e.xml").stdout
    return ET.fromstring(x[x.index("<"):])
def nodes():
    for n in dump().iter("node"):
        b = list(map(int, re.findall(r"\d+", n.get("bounds"))))
        yield (n.get("text") or n.get("content-desc") or ""), b
def tap(text, wait=2.0, last=False, exact=False):
    for _ in range(3):   # l'écran peut encore s'animer : trois essais avant d'abandonner
        hits = [(t, b) for t, b in nodes() if (text.lower() == t.strip().lower() if exact else text.lower() in t.lower())]
        if hits: break
        time.sleep(1.5)
    if not hits: print("  ✗ introuvable :", text); return False
    t, b = hits[-1] if last else hits[0]
    sh("input", "tap", str((b[0] + b[2]) // 2), str((b[1] + b[3]) // 2)); time.sleep(wait); return True
def back(w=1.5): sh("input", "keyevent", "KEYCODE_BACK"); time.sleep(w)
def shot(nom):
    p = f"{SORTIE}/{nom}.png"
    open(p, "wb").write(subprocess.run([ADB, "-s", SERIE, "exec-out", "screencap", "-p"], capture_output=True).stdout)
    print("  ✓", nom)
def relancer():
    sh("am", "force-stop", PAQUET)
    sh("am", "start", "-n", f"{PAQUET}/com.chesslab.MainActivity"); time.sleep(6)

if DEVICE:
    emu = None
else:
    print("▸ démarrage de", AVD)
    emu = subprocess.Popen([f"{SDK}/emulator/emulator", "-avd", AVD, "-port", str(PORT), "-no-boot-anim", "-no-snapshot",
                            "-gpu", "host", "-netdelay", "none", "-netspeed", "full"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
try:
    if not DEVICE:
        subprocess.run([ADB, "-s", SERIE, "wait-for-device"])
        for _ in range(120):
            if adb("shell", "getprop", "sys.boot_completed").stdout.strip() == "1": break
            time.sleep(2)
        time.sleep(6)
        print("▸ installation")
        if adb("install", "-r", APK).returncode != 0: sys.exit("installation refusée")
    sh("input", "keyevent", "KEYCODE_WAKEUP")
    sh("settings", "put", "secure", "show_ime_with_hard_keyboard", "0")
    sh("pm", "clear", PAQUET)   # installation neuve : la visite guidée, aucune donnée de test
    sh("cmd", "locale", "set-app-locales", PAQUET, "--locales", "fr-FR" if FR else LANGUE.split("-")[0])
    relancer(); time.sleep(8)
    for _ in range(3):
        if not tap(L("discovery_skip"), 1.5): break
    # Un jour d'entraînement : la finale du jour, pour que la séance affiche sa série.
    tap(L("daily_title"), 2.5)
    tap(L("daily_step_endgame"), 3.5)
    back(); back()
    print("▸ captures")
    relancer(); shot("1-accueil")
    tap(L("daily_title"), 2.5); shot("2-seance"); back()
    tap(L("home_play_short"), 3); shot("3-jouer"); back()
    tap(L("route_analysis"), 3.5, exact=True)   # exact : le slogan de l'accueil contient « analyser » en de/it
    tap(L("entry_paste"), 3)
    tap(L("analysis_input_label"), 1.5)
    sh("input", "text", "1.e4%se5%s2.Nf3%sNc6%s3.Bc4%sNf6%s4.Ng5%sd5%s5.exd5%sNxd5%s6.Nxf7%sKxf7%s7.Qf3+%sKe6%s8.Nc3%sNcb4%s9.O-O%sc6%s10.d4%sNxc2")
    time.sleep(1)
    tap(L("analysis_load"), 40)
    shot("4-analyse")
    relancer()
    tap(L("route_openings"), 3)
    tap(L("filter_all_levels"), 1.5)
    tap(L("filter_classics"), 2.5)
    shot("5-ouvertures"); back()
    tap(L("route_puzzles"), 2.5)
    tap(L("puzzle_at_my_level"), 5)   # « À mon niveau » lance un puzzle (l'écran Puzzles de la 2.1)
    shot("6-puzzles"); back(); back()
    tap(L("route_endgames"), 3.5); shot("7-finales")
    print("▸ terminé —", SORTIE)
finally:
    if emu is not None:
        adb("emu", "kill"); emu.terminate()
