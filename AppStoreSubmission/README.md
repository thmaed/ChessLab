# Préparation de la soumission App Store

Tout ce qu'il faut pour soumettre ChessLab sur l'App Store, en dehors des
étapes qui ne se font que dans App Store Connect ou Xcode.

- **`CHECKLIST.md`** — commence par là : ce qui est fait, ce qui reste.
- **`METADATA.md`** — nom, sous-titre, mots-clés, description (FR + EN),
  catégories, réponses aux questionnaires App Privacy / âge / chiffrement,
  et une note aux reviewers Apple (caméra, réseau, licence GPLv3). À
  copier-coller dans App Store Connect.
- **`screenshots/`** — captures d'écran réelles (pas des maquettes), prises
  sur simulateur, en français ET en anglais, aux deux résolutions
  actuellement obligatoires :
  - `iphone-6.9/<fr|en>/` : 1320×2868 (iPhone 17 Pro Max / 16 Pro Max)
  - `ipad-13/<fr|en>/` : 2064×2752 (iPad Pro 13" M5 / 12.9")

La politique de confidentialité et la page de support ne sont **pas** dans
ce dossier : elles vivent dans `../docs/` (`privacy-policy.html` et
`support.html`), déjà poussées sur le dépôt GitHub public, prêtes pour
GitHub Pages — voir ci-dessous.

## Activer GitHub Pages pour `docs/`

Le dépôt (`github.com/thmaed/ChessLab`) est déjà public et les deux pages
sont déjà poussées dans `docs/` ; il ne reste qu'à activer Pages :

1. Repo GitHub ▸ Settings ▸ Pages ▸ Source : « Deploy from a branch » ▸
   branche `main`, dossier `/docs`.
2. GitHub publie les URL après quelques minutes :
   - `https://thmaed.github.io/ChessLab/privacy-policy.html` → App Store
     Connect ▸ App Information ▸ Privacy Policy URL.
   - `https://thmaed.github.io/ChessLab/support.html` → App Store Connect
     ▸ App Information ▸ Support URL.

## Régénérer les captures d'écran

Le test `ChessLabUITests/AppStoreScreenshotUITests.swift` s'exécute à la
demande, pas dans la suite verte du projet ; il contient deux méthodes
(`testCaptureAppStoreScreenshotsFrench` / `…English`) qui forcent la
langue via `-AppleLanguages` sans toucher aux réglages in-app. Pour
relancer :

```bash
xcodebuild test -project ChessLab.xcodeproj -scheme ChessLab \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:ChessLabUITests/AppStoreScreenshotUITests
```

(remplacer le nom de l'appareil par un iPad pour la seconde taille). Les
fichiers atterrissent dans `/tmp/cl-appstore-screenshots/<iphone|ipad>/<fr|en>/`
— à recopier ici après coup.
