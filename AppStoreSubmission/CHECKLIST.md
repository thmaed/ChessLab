# Checklist de soumission App Store — ChessLab

État au 21/07/2026. Coché = fait par ce lot de préparation ou déjà en
place. Non coché = reste une action utilisateur (compte, App Store Connect,
ou décision qui n'appartient qu'à toi).

## Fait dans ce lot

- [x] **Icône App Store** (`ChessLab/Assets.xcassets/AppIcon.appiconset/etna.png`)
      aplatie : le canal alpha (uniformément opaque, donc invisible) a été
      retiré. Apple rejette les icônes avec canal alpha au moment de
      valider l'archive.
- [x] **Manifeste de confidentialité** `ChessLab/Resources/PrivacyInfo.xcprivacy`
      ajouté : déclare l'usage d'`UserDefaults` (raison `CA92.1`), aucune
      donnée collectée, pas de tracking. Obligatoire depuis 2024 pour
      toute app utilisant une API à « raison requise ».
- [x] **Conformité chiffrement** : `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`
      réglé dans les build settings (Debug + Release). L'app n'utilise que
      HTTPS standard (import Lichess), aucune cryptographie propriétaire.
- [x] **Écran Licences** (`ChessLab/LicensesView.swift`, accessible depuis
      Réglages → « Licences ») : mentions Stockfish (GPLv3), ChessKit /
      ChessKitEngine (MIT), pièces cburnett (CC BY-SA 3.0), base de
      puzzles Lichess (CC0), réseaux NNUE, et lien vers le code source de
      l'app. Traduit FR/EN dans `Localizable.xcstrings`.
- [x] **Signature de Release nettoyée** : un `CODE_SIGN_IDENTITY = "Apple
      Development"` orphelin sur la configuration Release de la cible
      ChessLab (seule cette config l'avait, ni le Debug ni les autres
      cibles) a été retiré — avec la signature automatique déjà active,
      il pouvait forcer un certificat de développement sur une archive
      censée partir en distribution App Store. À vérifier malgré tout
      lors du premier `Product ▸ Archive`.
- [x] **Correction de traduction découverte au passage** : le libellé du
      joueur dans « Jouer » (`PlayView.swift`) affichait « Vous » même en
      anglais — chaîne littérale au lieu de passer par
      `LocalizationController.string(_:)` comme le reste de l'app (la
      traduction anglaise « You » existait déjà dans le catalogue, elle
      n'était juste jamais utilisée). Repéré en relisant les captures EN.
- [x] **Captures d'écran réelles**, FR ET EN, générées par un test UI dédié
      (`ChessLabUITests/AppStoreScreenshotUITests.swift`, à lancer à la
      demande — pas dans la suite verte habituelle) : accueil + partie en
      cours, sur iPhone 17 Pro Max (1320×2868 — format « 6,9 pouces ») et
      iPad Pro 13" M5 (2064×2752 — format « iPad 13 pouces »). Dans
      `AppStoreSubmission/screenshots/<iphone-6.9|ipad-13>/<fr|en>/`.
- [x] **Politique de confidentialité** rédigée EN d'abord puis FR
      (`docs/privacy-policy.html`), **déposée et poussée sur le dépôt GitHub
      public**. Reste à activer GitHub Pages pour obtenir une URL servie
      (voir plus bas).
- [x] **Page de support** rédigée en anglais (`docs/support.html`),
      **déposée et poussée** avec le disclaimer fourni (projet indépendant,
      pas de SLA) et le contact `variospeed67@gmail.com`.
- [x] **Métadonnées App Store Connect** rédigées FR/EN
      (`AppStoreSubmission/METADATA.md`) : nom, sous-titre, mots-clés,
      texte promotionnel, description, catégories, export compliance,
      App Privacy, classification d'âge, **note aux reviewers Apple**
      (caméra, réseau, licence GPLv3).
- [x] **Purge du code mort « répertoire personnel »** (21/07/2026) : en
      vérifiant la mention Lichess ci-dessus, découverte que l'écran
      « Mes répertoires » avait été retiré de Ouvertures le 18/07/2026
      (`RepertoireListView.swift`), mais que `RepertoireDetailView.swift`
      (import PGN + import Lichess), `LichessStudyImportService.swift`,
      `RepertoireBuilderView.swift`/`RepertoireBuilderViewModel.swift` et
      leurs routes dans `HomeView.swift` restaient dans le binaire sans
      plus AUCUN chemin d'accès (`Route.repertoireDetail` n'était plus
      jamais poussée). Cinq fichiers supprimés, deux cas de route et un
      hôte privé retirés. **Conséquence directe : l'app ne fait plus
      AUCUN appel réseau** (c'était le seul `URLSession` du projet) — les
      mentions réseau/Lichess ont donc été retirées des notes reviewers,
      de la politique de confidentialité et de la description marketing
      (« Ouvertures » decrit désormais uniquement la bibliothèque ECO,
      seule partie du module encore accessible). 330 tests / 53 suites
      verts après coup (348/54 moins les 18 tests du service supprimé).
- [x] **Licence GPLv3 de Stockfish** : le dépôt source est déjà public
      (`github.com/thmaed/ChessLab`), ce qui satisfait l'obligation de
      mise à disposition du code source. Assure-toi juste que l'état
      poussé sur GitHub correspond au binaire soumis avant de cliquer sur
      « Submit for Review ».

## Mac Catalyst — recommandation : ne pas l'inclure dans cette soumission

Le projet a `SUPPORTS_MACCATALYST = YES` et compile réellement pour Mac
(vérifié : `xcodebuild ... -destination 'platform=macOS,variant=Mac
Catalyst' build` → succès, signé avec un certificat « Apple Development »
déjà présent sur cette machine). Ce n'est pas un réglage accidentel : il y a
du vrai code défensif spécifique à Catalyst (`MenuCommands.swift` élague la
barre de menus, `IdleTimerGuard.swift` contourne une limite Catalyst,
`ScannerView.swift` remplace la capture par un import de fichier sur Mac).

Mais rien n'a jamais été **testé ni pensé pour une soumission** sur cette
plateforme : aucune mention dans `PROGRESS.md`, aucune passe QA dédiée (les
348 tests + tests UI tournent tous sur simulateur iOS), aucune capture
d'écran Mac, et l'icône (`AppIcon.appiconset/Contents.json`) ne déclare
qu'une image `platform: ios` — pas d'icône dédiée au style macOS. Le
`PROMPT-ChessLab.md` d'origine ne mentionne d'ailleurs jamais Mac : la
cible annoncée est « universelle iPhone + iPad ».

**Recommandation retenue** : pour cette première soumission, ne PAS cocher
« Mac » comme plateforme disponible dans la fiche App Store Connect —
seuls iPhone et iPad seront proposés, même si le binaire contient aussi une
tranche Catalyst. C'est le choix le plus sûr : zéro risque de rejet pour un
comportement Mac non testé, zéro capture d'écran Mac à produire. Rien à
changer côté build settings pour ça (`SUPPORTS_MACCATALYST` peut rester à
`YES`, ça ne force pas la distribution Mac).

Si le Mac App Store devient un objectif plus tard, prévoir alors : icône au
format macOS, captures d'écran Mac (1280×800 minimum), et une vraie passe
de test manuel sur la destination Catalyst (permissions caméra, menus,
redimensionnement de fenêtre).

## Reste à faire (actions utilisateur, hors de portée du code)

- [ ] **Activer GitHub Pages** sur le dépôt (déjà public, fichiers déjà
      poussés dans `docs/`) : Settings ▸ Pages ▸ Source ▸ « Deploy from a
      branch » ▸ branche `main`, dossier `/docs`. Donne
      `https://thmaed.github.io/ChessLab/privacy-policy.html` et
      `.../support.html` — à coller dans App Store Connect (App
      Information ▸ Privacy Policy URL, et Support URL).
- [ ] **Compte Apple Developer Program** actif (99 $/an) associé à l'équipe
      `3N3BN259H6` déjà réglée dans le projet. Un certificat *Apple
      Development* (Thierry Maeder, N982QZWW97) est déjà présent sur cette
      machine, ce qui confirme un compte développeur Apple connecté à
      Xcode — mais ne prouve pas l'inscription payante au Program : seule
      elle débloque le certificat *Apple Distribution* nécessaire à
      l'archive App Store. À vérifier dans developer.apple.com/account.
- [ ] **Créer la fiche app dans App Store Connect** (bundle ID
      `com.chesslab.ChessLab`, déjà cohérent dans le projet) : nom,
      métadonnées (voir `METADATA.md`), catégories, coordonnées de
      contact, informations bancaires/fiscales si l'app devient payante.
- [ ] **Remplir le copyright** dans `METADATA.md` avec le nom légal exact
      du compte Apple Developer (je ne le connais pas).
- [ ] **Product ▸ Archive** depuis Xcode (PAS depuis la copie `/tmp` —
      archive la vraie copie sous `~/Desktop/Devl/ChessLab`, en acceptant
      la lenteur due à iCloud, ou déplace le dépôt hors du Bureau comme
      déjà suggéré) puis Distribute App ▸ App Store Connect. C'est à ce
      moment que Xcode crée/choisit le certificat de distribution et le
      profil de provisionnement.
- [ ] **Uploader les captures d'écran** : celles générées ici couvrent le
      minimum obligatoire (1 par taille requise). Envisage d'en ajouter
      2-4 de plus par taille (Analyse, Puzzles, Ouvertures…) pour une
      fiche plus vendeuse — facile à faire main dans le Simulateur
      (Cmd+S) une fois le build lancé.
- [ ] **Remplir le questionnaire App Privacy** dans App Store Connect en
      suivant les réponses documentées dans `METADATA.md` (aucune donnée
      collectée).
- [ ] **Remplir le questionnaire de classification d'âge** (voir
      `METADATA.md` — tout à « aucun » → 4+).
- [ ] **TestFlight** (recommandé avant soumission) : envoyer le premier
      build à un groupe de test interne pour vérifier qu'il s'installe et
      tourne sur un vrai appareil, pas seulement en simulateur.

## Point d'attention indépendant (pas bloquant)

L'accueil sur iPad (voir `screenshots/ipad-13/01-accueil.png`) laisse
beaucoup d'espace vide sous les tuiles de mode : la grille ne remplit pas
la largeur disponible sur un écran 13". Pas un problème de conformité,
mais si tu veux une capture d'accueil plus impressionnante pour la fiche
App Store, vaut mieux soit retravailler cette mise en page, soit choisir
une autre capture (Analyse ou Jouer, qui remplissent mieux l'écran) comme
image de tête.

## Découverte en marge, non traitée : le modèle `Repertoire` n'a plus AUCUN créateur

En retirant le code mort ci-dessus, remarqué que même les écrans encore
BRANCHÉS (`RepertoireQueueView`, `RepertoireTrainingHost`,
`RepertoireItemGenerator`) reposent sur l'existence d'un objet
`Repertoire` en base — et que plus rien, nulle part dans le code actuel,
n'en crée un (`grep` ne trouve aucun site d'instanciation, seulement des
lectures via `FetchDescriptor<Repertoire>`). Sur une installation
fraîche, la table `Repertoire` reste donc vide indéfiniment, et tout le
pipeline de révision espacée des répertoires personnels — pas juste
l'écran que je viens de retirer — est en pratique inatteignable. Non
traité ici : c'est plus large que la demande initiale (une mention à
enlever), et j'ai pu manquer un mécanisme de création que je n'ai pas vu.
À vérifier de ton côté avant de décrire cette fonctionnalité dans une
future mise à jour de la fiche App Store.
