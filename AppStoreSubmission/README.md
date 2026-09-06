# Préparation de la soumission App Store

Tout ce qu'il faut pour soumettre ChessLab sur l'App Store, en dehors des étapes qui ne se font que dans App Store Connect ou Xcode.

- **`CHECKLIST.md`** — commence par là : ce qui est fait, ce qui reste.
- **`METADATA.md`** — nom, sous-titre, mots-clés, description (FR + EN), catégories, réponses aux questionnaires App Privacy / âge / chiffrement, et une note aux reviewers Apple (caméra, réseau, licence GPLv3). À copier-coller dans App Store Connect.
- **`screenshots/`** — captures d'écran réelles (pas des maquettes), prises sur simulateur, EN ANGLAIS uniquement (décision du 19/08 : un seul jeu de visuels pour la fiche). Douze par idiome depuis le 06/09 (`04-adversaires` : la galerie des personnages) :
  - `iphone-6.7/en/` : 1284×2778 — capturées en 1320×2868 (iPhone 17 Pro Max) puis converties par étirement (écart de ratio 0,4 %, invisible), format « 6,7 pouces » accepté par App Store Connect ;
  - `ipad-13/en/` : 2064×2752 (iPad Pro 13" M5 / 12.9").

La politique de confidentialité et la page de support ne sont **pas** dans ce dossier : elles vivent dans `../docs/` (`privacy-policy.html` et `support.html`), déjà poussées sur le dépôt GitHub public, prêtes pour GitHub Pages — voir ci-dessous.

## Activer GitHub Pages pour `docs/`

Le dépôt (`github.com/thmaed/ChessLab`) est déjà public et les deux pages sont déjà poussées dans `docs/` ; il ne reste qu'à activer Pages :

1. Repo GitHub ▸ Settings ▸ Pages ▸ Source : « Deploy from a branch » ▸ branche `main`, dossier `/docs`.
2. GitHub publie les URL après quelques minutes :
   - `https://thmaed.github.io/ChessLab/privacy-policy.html` → App Store Connect ▸ App Information ▸ Privacy Policy URL.
   - `https://thmaed.github.io/ChessLab/support.html` → App Store Connect ▸ App Information ▸ Support URL.

## Régénérer les captures d'écran

Le test `ChessLabUITests/AppStoreScreenshotUITests.swift` s'exécute à la demande, pas dans la suite verte du projet ; il contient deux méthodes (`testCaptureAppStoreScreenshotsFrench` / `…English`) qui forcent la langue via `-AppleLanguages` sans toucher aux réglages in-app. Pour relancer :

```bash
xcodebuild test -project ChessLab.xcodeproj -scheme ChessLab \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:ChessLabUITests/AppStoreScreenshotUITests
```

(remplacer le nom de l'appareil par un iPad pour la seconde taille). Les fichiers atterrissent dans `/tmp/cl-appstore-screenshots/<iphone|ipad>/<fr|en>/` — à recopier ici après coup.

## App previews (vidéos)

REPORTÉS À LA PROCHAINE VERSION (décision du 20/08/2026) : la 1.5 est soumise sans aperçu vidéo — c'est optionnel sur App Store Connect. L'outillage complet est prêt (parcours scénarisés `AppStorePreviewTourUITests`, tirage de puzzle déterministe, découpe multi-segments) ; les deux aperçus prévus restent :

- `previews/iphone-6.7/en/preview-play-puzzle.mov` — 886×1920 : accueil → contre l'ordinateur (deux coups) → un puzzle résolu (tirage déterministe `-uiTestDeterministicPuzzles`, puzzle 00008).
- `previews/ipad-13/en/preview-endgame-lab.mov` — 1200×1600 : Finales (deux coups dans « L'opposition ») → Laboratoire, série lancée.

### Régénérer

1. Démarrer le simulateur cible (`xcrun simctl boot <UDID>`).
2. Lancer l'enregistrement : `xcrun simctl io <UDID> recordVideo --codec=h264 --force /tmp/raw.mov &` puis le parcours scénarisé : `xcodebuild test … -only-testing:ChessLabUITests/AppStorePreviewTourUITests/testTourPlayThenPuzzleEnglish` (iPhone) ou `…/testTourEndgameThenLabEnglish` (iPad). Arrêter l'enregistrement (`kill -INT` du processus recordVideo).
3. Repérer la fenêtre utile (l'enregistrement contient le build et le springboard) : `swift tools/appstore-preview/probe_at.swift /tmp/raw.mov /tmp/probe 30 40 50 …` puis regarder les PNG.
4. Découper/formater : `swift tools/appstore-preview/make_preview.swift /tmp/raw.mov sortie.mov <largeur> <hauteur> <début_s> <durée_s> [<début2_s> <durée2_s> …] [vitesse]` (886 1920 pour iPhone 6,9", 1200 1600 pour iPad 13"). Plusieurs paires début/durée mettent bout à bout des segments de la prise — pour couper un temps mort, choisir les deux bornes sur le même écran statique, le raccord est invisible ; `vitesse` (≤ 1,4) compresse un parcours trop long sans amputer le scénario. Le script plafonne à 30 i/s, ajoute la piste audio silencieuse et vérifie ses propres dimensions/durée en sortie.
