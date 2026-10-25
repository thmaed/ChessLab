#!/usr/bin/env python3
"""Les captures de TABLETTE de la fiche Play 2.0, prises sur émulateur avec l'APK de DEBUG
(com.maeder.chesslab.debug) : un build de release consommerait un versionCode.

    tools/captures-tablette-2.0.py chesslab-tab10 fr-FR large-tablet-screenshots
    tools/captures-tablette-2.0.py chesslab-tab7  en-US tablet-screenshots

Sept captures, comme sur téléphone : accueil, séance du jour, nouvelle partie, analyse (une partie
collée, avec le Coach), ouvertures (filtre Classiques), puzzle, finales.
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
def tap(text, wait=2.0, last=False):
    hits = [(t, b) for t, b in nodes() if text.lower() in t.lower()]
    if not hits: print("  ✗ introuvable :", text); return False
    t, b = hits[-1] if last else hits[0]
    sh("input", "tap", str((b[0] + b[2]) // 2), str((b[1] + b[3]) // 2)); time.sleep(wait); return True
def back(w=1.5): sh("input", "keyevent", "KEYCODE_BACK"); time.sleep(w)
def shot(nom):
    p = f"{SORTIE}/{nom}.png"
    open(p, "wb").write(subprocess.run([ADB, "-s", SERIE, "exec-out", "screencap", "-p"], capture_output=True).stdout)
    print("  ✓", nom)
def notation_anglaise():
    """Réglages → notation « English » : sans cela, une fiche anglaise montrerait « Cxc2 » (lettres françaises)."""
    top = [(b, t) for t, b in ((t, b) for t, b in nodes()) if b[1] < 400 and b[3] - b[1] > 40]
    n = dump()
    cand = []
    for e in n.iter("node"):
        if e.get("clickable") == "true":
            b = list(map(int, re.findall(r"\d+", e.get("bounds"))))
            if b[1] < 400: cand.append(b)
    if not cand: print("  ✗ engrenage introuvable"); return
    b = max(cand, key=lambda b: b[2])
    sh("input", "tap", str((b[0] + b[2]) // 2), str((b[1] + b[3]) // 2)); time.sleep(2.5)
    # Défile jusqu'à la rangée « French / English » de la notation (« French » n'existe que là).
    w, h = map(int, sh("wm", "size").split()[-1].split("x"))
    for _ in range(8):
        fr = [b for t, b in nodes() if t.strip().startswith("French")]
        if fr:
            fb = fr[0]
            row = [b for t, b in nodes() if t.strip().startswith("English") and abs(b[1] - fb[1]) < 80 and b[0] > fb[0]]
            if row:
                b = row[0]
                sh("input", "tap", str((b[0] + b[2]) // 2), str((b[1] + b[3]) // 2)); time.sleep(1.5)
                print("  ✓ notation anglaise"); break
        sh("input", "swipe", str(w // 2), str(int(h * 0.75)), str(w // 2), str(int(h * 0.3)), "400"); time.sleep(0.8)
    else:
        print("  ✗ rangée de notation introuvable")
    back()

def relancer():
    sh("am", "force-stop", PAQUET)
    sh("am", "start", "-n", f"{PAQUET}/com.chesslab.MainActivity"); time.sleep(6)

print("▸ démarrage de", AVD)
emu = subprocess.Popen([f"{SDK}/emulator/emulator", "-avd", AVD, "-port", str(PORT), "-no-boot-anim", "-no-snapshot",
                        "-gpu", "host", "-netdelay", "none", "-netspeed", "full"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
try:
    subprocess.run([ADB, "-s", SERIE, "wait-for-device"])
    for _ in range(120):
        if adb("shell", "getprop", "sys.boot_completed").stdout.strip() == "1": break
        time.sleep(2)
    time.sleep(6)
    print("▸ installation")
    if adb("install", "-r", APK).returncode != 0: sys.exit("installation refusée")
    sh("settings", "put", "secure", "show_ime_with_hard_keyboard", "0")
    sh("cmd", "locale", "set-app-locales", PAQUET, "--locales", LANGUE.split("-")[0] if not FR else "fr-FR")
    relancer(); time.sleep(8)
    # La visite guidée couvre l'écran d'une installation neuve : « Passer ».
    for _ in range(3):
        if not tap("Passer" if FR else "Skip", 1.5): break
    if not FR: notation_anglaise()
    # Un jour d'entraînement : la finale du jour, pour que la séance affiche sa série.
    tap("Séance du jour" if FR else "Daily session", 2.5)
    tap("Une finale" if FR else "An endgame", 3.5)
    back(); back()
    print("▸ captures")
    relancer(); shot("1-accueil" if FR else "1-home")
    tap("Séance du jour" if FR else "Daily session", 2.5); shot("2-seance" if FR else "2-daily-session"); back()
    tap("Ordinateur" if FR else "Computer", 3); shot("3-jouer" if FR else "3-play"); back()
    # Analyse : une partie collée, qui montre le Coach.
    if not FR:
        pass
    tap("Analyser" if FR else "Analyse", 2.5)
    tap("Coller, ouvrir" if FR else "Paste, open", 2.5)
    tap("Analyser PGN / FEN" if FR else "Analyse PGN / FEN", 2.5)
    tap("PGN ou FEN" if FR else "PGN or FEN", 1.5)
    sh("input", "text", "1.e4%se5%s2.Nf3%sNc6%s3.Bc4%sNf6%s4.Ng5%sd5%s5.exd5%sNxd5%s6.Nxf7%sKxf7%s7.Qf3+%sKe6%s8.Nc3%sNcb4%s9.O-O%sc6%s10.d4%sNxc2")
    time.sleep(1)
    tap("Charger" if FR else "Load", 40)
    shot("4-analyse" if FR else "4-analysis")
    relancer()
    tap("Ouvertures" if FR else "Openings", 3)
    tap("Tous niveaux" if FR else "All levels", 1.5)
    tap("Classiques" if FR else "Classics", 2.5)
    shot("5-ouvertures" if FR else "5-openings"); back()
    tap("Puzzles", 2.5)
    tap("Commencer la séance" if FR else "Start the session", 4)
    shot("6-puzzles"); back(); back()
    tap("Finales" if FR else "Endgames", 3.5); shot("7-finales" if FR else "7-endgames")
    print("▸ terminé —", SORTIE)
finally:
    adb("emu", "kill"); emu.terminate()
