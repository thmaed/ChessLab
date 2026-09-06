# Métadonnées App Store Connect — ChessLab

**Version courante : 1.7.0** (build à fixer — voir « Version et build » plus bas). Voir `RELEASE_NOTES-1.7.0.md` pour le détail complet des changements depuis la 1.6.

Tout ce qui suit est à copier-coller directement dans les champs correspondants d'App Store Connect. Les limites de caractères d'Apple sont respectées (vérifiées).

> **Convention d'édition** : dans les blocs à coller, JAMAIS de retour à la ligne à l'intérieur d'un paragraphe — App Store Connect rend chaque saut de ligne tel quel, une césure à 78 colonnes hacherait le texte sur la fiche. Une ligne par paragraphe ; les titres EN CAPITALES gardent leur propre ligne.

> **Révisé le 26/08/2026** — le module Variantes, esquissé à 4 formes de jeu (Chess960 + 3) le 25/08, est allé jusqu'à 8 en une nuit : Roi de la colline, Trois échecs, Horde, Course des rois, Antéchecs, Atomique, et Coup Volé (variante maison). Tous les champs qui mentionnaient « 3 variantes » sont corrigés en conséquence. Trois champs demandent encore une action avant de soumettre : **Nouveautés de cette version** (ci-dessous, obligatoire), le numéro de build (voir « Version et build » — `CURRENT_PROJECT_VERSION` a dérivé à `8.2` tout seul au fil des builds locaux, à fixer délibérément juste avant d'archiver), et le **compte de cours de finales**, passé de 77 à 78 (« Pions électriques »).

---

## Nouveautés de cette version — 1.8.0 (4000 car. max)

C'est le champ « What's New in This Version ». Rédigé pour l'utilisateur final : ce qu'il va sentir, pas ce qui a été refactorisé.

> ✅ **Soumise le 06/09/2026 (build 13).** Ce texte couvre 1.6 → 1.8.0 (28/08 → 06/09/2026) — la 1.7.0 et la 1.7.1 ne sont jamais parties, tout est regroupé ici. Point de départ : la 1.6, soumise le 28/08/2026. Détail dans `RELEASE_NOTES-1.8.0.md` (et `RELEASE_NOTES-1.7.1.md` pour la part 1.7).

### Français

```
NEUF PERSONNAGES À AFFRONTER
À côté du niveau Elo de Stockfish, choisissez un adversaire qui a un caractère : Lena l'attaquante, Nils le mur, Milo le gambiteur, Nadia la technicienne, Sacha le piégeur, Ana la contre-attaquante, Yuri le matérialiste, Pablo l'impulsif, et Maia l'étalon. Ils sont joués par Maia-3, un réseau entraîné sur des millions de parties humaines : il ne cherche pas le meilleur coup, il joue celui qu'un humain de ce niveau jouerait — gaffes comprises quand le niveau est bas. Chacun a son style, son répertoire d'ouvertures, son tempérament et son illustration ; le niveau se règle et se mémorise par personnage, sur l'échelle humaine (proche de Lichess). Tout tourne sur l'appareil, sans réseau.

STOCKFISH ANALYSE, ET ASSURE
Indice, alerte gaffe, barre d'évaluation et analyse restent ceux de Stockfish. Derrière un personnage, il n'intervient que pour un mat court, une finale à peu de pièces ou une répétition en position gagnée — et l'écran de fin le dit.

PROGRÈS ET LABORATOIRE
Votre bilan par personnage, avec le plus haut niveau battu. Au Laboratoire, un camp peut être joué par Maia.

QUATRE VARIANTES DE PLUS — LE HUB PASSE À 12
Crazyhouse (les prises changent de camp et se reposent), Duck Chess (un canard bloque une case, tour en deux temps), Barricades (d4 et e5 murées) et Barricades aléatoires (les murs changent de case à chaque coup). Toutes contre l'ordinateur, analyse de fin de partie comprise.

UNE VISITE GUIDÉE, ET LES ANALYSES DE VARIANTES AU COMPLET
Onze étapes courtes au premier lancement, rejouables depuis l'Aide. Les douze variantes ont la même analyse que le mode classique : courbe, précision par couleur, coups en ligne colorés. « Proposer nulle » fonctionne partout.

FIABILITÉ ET MISE EN PAGE
Six mécanismes de panne du moteur corrigés en profondeur ; au-delà de 2850, la force des variantes n'est plus bridée au lieu de retomber en silence à 1350 ; grille des modes sur l'accueil iPad et Mac ; mise en page revue sur les grandes fenêtres et les petits iPhone.
```

### English

```
NINE CHARACTERS TO FACE
Next to Stockfish's Elo level, pick an opponent with a personality: Lena the attacker, Nils the wall, Milo the gambiteer, Nadia the technician, Sacha the trapper, Ana the counter-attacker, Yuri the materialist, Pablo the impulsive one, and Maia the reference. They are played by Maia-3, a network trained on millions of human games: it does not look for the best move, it plays the one a human of that level would play — blunders included when the level is low. Each has a style, an opening repertoire, a temperament and an illustration; the level is set and remembered per character, on the human scale (close to Lichess). Everything runs on the device, offline.

STOCKFISH ANALYZES, AND COVERS
Hints, blunder alert, evaluation bar and analysis are still Stockfish's. Behind a character it only steps in for a short mate, an endgame with few pieces or a repetition in a won position — and the end-of-game screen says so.

PROGRESS AND LAB
Your record against each character, with the highest level beaten. In the Lab, one side can be played by Maia.

FOUR MORE VARIANTS — THE HUB GROWS TO 12
Crazyhouse (captures switch sides and get dropped back), Duck Chess (a duck blocks a square, two-part turns), Barricades (d4 and e5 walled) and Random Barricades (the walls move after every move). All against the computer, post-game analysis included.

A GUIDED TOUR, AND VARIANT ANALYSIS COMPLETE
Eleven short steps on first launch, replayable from Help. All twelve variants get the same analysis as the classic mode: curve, per-color accuracy, colored inline moves. "Offer a draw" works everywhere.

RELIABILITY AND LAYOUT
Six engine failure mechanisms fixed in depth; above 2850, variant strength is no longer limited instead of silently dropping to 1350; mode grid on the iPad and Mac home; layout revisited on large windows and small iPhones.
```

## Français (langue principale)

**Nom de l'app** (30 car. max) :
```
ChessLab
```

**Sous-titre** (30 car. max — 28 utilisés) :
```
Adversaires humains, analyse
```

**Mots-clés** (100 car. max — 94 utilisés, séparés par des virgules, sans espace) :
```
stockfish,maia,tactique,ouverture,puzzle,gambit,fen,pgn,elo,entrainement,scanner,analyse,ia,plateau
```

**Texte promotionnel** (170 car. max — modifiable sans nouvelle revue) :
```
Neuf adversaires qui jouent comme des humains (Maia-3), analyse Stockfish, 58 ouvertures, 78 finales prouvées, 100 000+ puzzles — 100 % local.
```

**Description** (4000 car. max) :
```
ChessLab est un compagnon d'échecs complet pour iPhone et iPad : jouer, analyser, s'entraîner et expérimenter, avec le moteur Stockfish intégré et sans jamais quitter l'application.

DES ADVERSAIRES HUMAINS
Neuf personnages joués par Maia-3, un réseau entraîné sur des millions de parties humaines : il ne cherche pas le meilleur coup, il joue celui qu'un humain de ce niveau jouerait, gaffes comprises. Chacun a son style, son répertoire, son tempérament, son portrait, et un niveau réglable sur l'échelle humaine. Ou affrontez Stockfish lui-même, du débutant (~900 Elo) au niveau maximal (~3190 Elo). Avec ou sans pendule. Indice, alerte avant un coup risqué et barre d'évaluation sont activables à tout moment.

DEUX JOUEURS
Jouez à deux sur le même appareil, avec un mode « table » qui retourne les pièces pour rester lisible face à face.

ANALYSER
Passez une partie ou une position au crible de Stockfish : classification de chaque coup (imprécision, erreur, gaffe, coup brillant…), courbe d'évaluation, flèches du meilleur coup et de la menace adverse, lecture automatique. Entrée par PGN, FEN, éditeur de position ou scanner photo.

OUVERTURES
Choisissez une ouverture et avancez coup par coup : chaque coup est expliqué, les variantes sont proposées, et des flèches colorées relient le plateau à la liste des coups. 58 ouvertures rédigées à la main (bilingues), toutes relues au moteur, avec un entraînement en répétition espacée simplifié pour les mémoriser.

LE COIN DES FINALES
78 cours prouvés par table de finales — le verdict mathématique exact : aucun coup enseigné ne lâche le gain, aucune défense proposée ne perd la nulle. Neuf familles, de l'opposition aux études célèbres. Et l'entraînement libre : concluez la position contre la meilleure défense, tout coup qui préserve le verdict est accepté — pas seulement celui de la leçon.

VARIANTES
Chess960 (les échecs Fischer Random) : position de départ aléatoire, choisie par numéro, ou composée soi-même, avec la même analyse de fin de partie qu'en mode « Jouer ». Sept variantes de plus contre l'ordinateur, chacune avec sa propre analyse : Roi de la colline, Trois échecs, Horde, Course des rois, Antéchecs, Atomique, et Coup Volé.

VOS PROPRES RÉPERTOIRES
Importez vos ouvertures au format PGN, variantes comprises, et entraînez-les avec le même système. Partagez un répertoire par simple fichier — aucun compte, aucun serveur. Ce que vous avez déjà mémorisé sur une position vaut aussitôt dans le répertoire importé.

PUZZLES
Plus de 100 000 problèmes tactiques issus de la base Lichess, filtrables par niveau et par thème, plus des puzzles générés automatiquement depuis vos propres erreurs en analyse. Répétition espacée et suivi de vos points forts.

LABORATOIRE
Faites s'affronter deux réglages de Stockfish sur une série de parties pour comparer leur force, avec estimation de l'écart Elo et intervalle de confiance.

ÉDITEUR ET SCANNER
Composez une position à la main, ou scannez-la depuis une capture d'écran ou une photo d'écran — la reconnaissance se corrige avant de jouer ou d'analyser.

CONÇU POUR IPAD
Échiquier grand format et panneaux visibles simultanément (coups, courbe, MultiPV), clavier et trackpad pris en charge, portrait et paysage soignés.

SYNCHRONISATION iCLOUD (optionnelle)
Activez-la dans les Réglages pour que vos parties suivent tous vos appareils, via votre iCloud privé. Aucun compte, aucun serveur ChessLab. Désactivée par défaut.

VIE PRIVÉE
Hors ligne par défaut : aucun serveur ChessLab, aucune mesure d'audience, aucune publicité. Vos parties et réglages restent sur votre appareil, et ne sont jamais partagés avec le développeur. Bilingue français/anglais.

ChessLab intègre le moteur Stockfish (licence GPLv3), le réseau Maia-3 de l'Université de Toronto (licence AGPLv3) et des jeux de pièces vectorielles libres — cburnett (GPLv2+/CC BY-SA), chessnut (Apache 2.0) et merida (GPLv2+). Code source complet et mentions de licence disponibles depuis l'app (Réglages → Licences).
```

---

## English (secondary localization — App Store Connect: "English (U.K.)", en-GB — la fiche a toujours été en anglais britannique ; un « English (U.S.) » neuf est refusé, le nom « ChessLab » y étant pris par une autre app)

**Name** (30 char. max):
```
ChessLab
```

**Subtitle** (30 char. max — 25 used):
```
Human opponents, analysis
```

**Keywords** (100 char. max — 92 used):
```
stockfish,maia,tactics,openings,puzzle,gambit,fen,pgn,elo,training,scanner,analysis,offline
```

**Promotional text** (170 char. max):
```
Nine opponents that play like humans (Maia-3), Stockfish analysis, 58 openings, 78 proven endgames, 100,000+ puzzles — fully offline, no ads.
```

**Description** (4000 char. max):
```
ChessLab is a complete chess companion for iPhone and iPad: play, analyze, train and experiment, with the Stockfish engine built in and without ever leaving the app.

HUMAN OPPONENTS
Nine characters played by Maia-3, a network trained on millions of human games: it does not look for the best move, it plays the one a human of that level would play, blunders included. Each has a style, a repertoire, a temperament, a portrait, and an adjustable level on the human scale. Or take on Stockfish itself, from beginner (~900 Elo) to maximum (~3190 Elo). With or without a clock. Hints, a warning before risky moves, and an evaluation bar can all be toggled on demand.

TWO PLAYERS
Play locally on the same device, with a "pass-and-play" mode that flips the pieces so both players read the board comfortably.

ANALYZE
Run a game or a position through Stockfish: move-by-move classification (inaccuracy, mistake, blunder, brilliant move…), an evaluation graph, best-move and opponent-threat arrows, and auto-play through the moves. Import by PGN, FEN, position editor, or photo scanner.

OPENINGS
Pick an opening and step through it move by move: every move is explained, the alternatives are offered, and colored arrows link the board to the move list. 58 hand-written openings (bilingual), all reviewed by the engine, with simplified spaced-repetition training to memorize them.

THE ENDGAME CORNER
78 courses proven by endgame tablebases — the exact mathematical verdict: no taught move gives up a win, no recommended defence loses a draw. Nine families, from the opposition to famous studies. And free training: finish the position against best defence, where any move that preserves the verdict is accepted — not just the lesson's move.

VARIANTS
Chess960 (Fischer Random Chess): a randomly drawn starting position, one chosen by number, or one you compose yourself, with a full post-game analysis just like "Play" mode. Seven more variants against the computer, each with its own analysis: King of the Hill, Three-Check, Horde, Racing Kings, Antichess, Atomic, and Stolen Move (a token earned every 7 moves lets you play two moves in a row).

YOUR OWN REPERTOIRES
Import your openings as PGN, variations included, and drill them with the same system. Share a repertoire as a single file — no account, no server. What you already know about a position counts right away in the imported repertoire.

PUZZLES
Over 100,000 tactics puzzles from the Lichess database, filterable by rating and theme, plus puzzles generated automatically from your own mistakes in analysis. Spaced repetition and progress tracking included.

LABORATORY
Pit two Stockfish configurations against each other over a series of games to compare their strength, with an estimated Elo gap and confidence interval.

EDITOR AND SCANNER
Set up a position by hand, or scan it from a screenshot or a photo — review and correct the recognized position before playing or analyzing it.

BUILT FOR IPAD
Full-size board with move list, graph and MultiPV visible at once, keyboard and trackpad support, polished portrait and landscape layouts.

iCLOUD SYNC (optional)
Turn on iCloud sync in Settings so your games follow you across all your devices, via your private iCloud. No account to create, no ChessLab server. Off by default: the app works fully offline.

PRIVACY
Offline by default: no ChessLab server, no analytics, no ads. Your games and settings stay on your device. iCloud sync, if you enable it, uses your own private iCloud — your data is never shared with the developer. Fully bilingual, French and English.

ChessLab embeds the Stockfish engine (GPLv3 license), the University of Toronto's Maia-3 network (AGPLv3 license) and free vector piece sets — cburnett (GPLv2+/CC BY-SA), chessnut (Apache 2.0) and merida (GPLv2+). Full source code and license notices are available from within the app (Settings → Licenses).
```

---

## Champs communs (indépendants de la langue)

- **Catégorie principale** : Jeux (Games)
- **Sous-catégorie** : Plateau (Board)
- **Catégorie secondaire** (optionnel) : Éducation
- **Copyright** : `© 2026 Thierry Maeder` — déduit du certificat de signature local (« Apple Development: Thierry Maeder (N982QZWW97) »), qui indique un compte individuel. À vérifier contre developer.apple.com/account ▸ Membership pour l'orthographe exacte avant de coller.
- **URL du support** : `https://thmaed.github.io/ChessLab/support.html` (page déposée dans `docs/support.html`, publique — reste à activer GitHub Pages pour qu'elle soit servie, voir `README.md`). En repli immédiat, le temps d'activer Pages : `https://github.com/thmaed/ChessLab/issues`.
- **URL marketing** (optionnel) : `https://github.com/thmaed/ChessLab`
- **URL de la politique de confidentialité** : `https://thmaed.github.io/ChessLab/privacy-policy.html` (page déposée dans `docs/privacy-policy.html`, publique — même remarque sur l'activation de GitHub Pages).
- **Coordonnées de contact** (non publiques, pour Apple uniquement) : nom, adresse, téléphone, email valides — à renseigner dans App Store Connect.

### Export compliance (chiffrement)
`INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` est déjà réglé dans le projet. L'app n'implémente aucune cryptographie propre. La seule activité réseau possible, la synchronisation iCloud (optionnelle, désactivée par défaut), passe par CloudKit — chiffrement standard fourni par le système Apple, donc **exempté** au sens de l'export compliance. Si App Store Connect pose la question : aucune cryptographie propriétaire, exempté.

### App Privacy (étiquette de confidentialité)
Réponse à la question « Collectez-vous des données ? » : **Non**. Aucun SDK tiers d'analytics, de publicité ou de suivi n'est intégré (les seules dépendances tierces sont ChessKit et le moteur Stockfish vendorisé, qui tournent entièrement localement). Le champ « scan de l'appareil photo » sert uniquement à la reconnaissance locale d'une position, jamais à un envoi réseau. La synchronisation iCloud (optionnelle) stocke les données dans l'iCloud **privé** de l'utilisateur (base CloudKit privée), à laquelle le développeur n'a aucun accès : Apple ne considère pas cela comme une collecte de données par le développeur. Résultat attendu dans le questionnaire App Store Connect : « Data Not Collected » pour toutes les catégories.

### Classification par âge
Le nouveau questionnaire d'âge (contenu, pas de violence, pas de contenu généré par les utilisateurs partagé publiquement, pas de jeu d'argent, pas d'accès web non restreint) doit répondre « aucun » partout → note **4+**.

### App Accessibility (App Information ▸ Accessibility)
Réponses déduites du code (vérifié, pas deviné) :
- **VoiceOver** : Oui — `accessibilityLabel`/`Value`/`Hint` sur 17 fichiers, coups annoncés en SAN.
- **Larger Text** (Dynamic Type) : Oui — quasi tous les textes utilisent des styles sémantiques (`.body`, `.headline`…), réactifs par défaut.
- **Reduced Motion** : Oui — `accessibilityReduceMotion` géré dans `Theme.swift` et `ChessBoardView.swift`.
- **Dark Interface** : Oui — l'app est en sombre forcé partout (`.preferredColorScheme(.dark)`).
- **Sufficient Contrast** : probablement oui (texte blanc sur fond très sombre), mais pas d'audit WCAG automatisé fait — à confirmer visuellement avant de cocher.
- **Voice Control** : aucune adaptation spécifique trouvée dans le code — ne cocher que si testé manuellement sur appareil.
- **Captions** : non applicable, pas de contenu audio/vidéo narratif.

### Version et build

**1.8.0, build 13** — fixés le 06/09/2026 (`MARKETING_VERSION = 1.8.0`, `CURRENT_PROJECT_VERSION = 13`) : App Store Connect avait déjà reçu des builds 11 et 12 le matin même, depuis Xcode, et exige un numéro strictement supérieur. Le build 13 est celui téléversé par `tools/asc/release.sh`. Vérifier dans App Store Connect que le build réellement soumis pour la 1.6 est bien inférieur à 11 avant d'archiver. Nouveautés détaillées dans `RELEASE_NOTES-1.8.0.md`, texte prêt à coller ci-dessus.

Historique : la 1.7.1 (build 10.1) avait été fixée le 05/09 et n'est jamais partie ; la 1.8.0 l'absorbe.

Vérifié dans `ChessLab.xcodeproj/project.pbxproj` (26/08/2026) : la cible applicative (`com.chesslab.ChessLab`) porte `MARKETING_VERSION = 1.6` aux deux configurations, Debug et Release — correct. Mais `CURRENT_PROJECT_VERSION` **dérive tout seul** au fil des builds locaux (`8.1` le 25/08, `8.2` observé le 26/08, sans action délibérée) — le dernier build réellement soumis était le 7 (1.5.0). App Store Connect exige un entier (ou une liste d'entiers séparés par des points) strictement supérieur au dernier build soumis, donc n'importe laquelle de ces valeurs conviendrait numériquement (`8` > `7`), mais la dérive elle-même est le problème : ne PAS archiver avec la valeur trouvée « par hasard » au dernier build local — la fixer consciemment (`8` tout rond est le plus simple) au moment de l'archive, pas avant, sinon elle continuera de bouger.

⏳ **1.6.0 : pas encore soumise.** Succède au build 7 de la 1.5.0, en ligne depuis le 20/08/2026.

Les cibles de TEST (`ChessLabTests`, `ChessLabUITests`) sont restées en `1.2.0` / build 3. **Sans effet sur la soumission** : leurs bundles ne sont pas livrés. À aligner un jour par propreté, pas avant d'expédier.

Incrémenter `CURRENT_PROJECT_VERSION` à chaque nouveau build renvoyé à Apple, même version marketing.

### ⚠️ À FAIRE AVANT DE SOUMETTRE — pousser le code source

Les notes réviseurs (plus bas) affirment que « the complete source code of the app — **matching this submitted build** — is published publicly at github.com/thmaed/ChessLab ». Ce n'est pas une formule de style : Stockfish étant GPLv3, le binaire ChessLab est une œuvre dérivée GPLv3, et la publication du code correspondant est une **obligation de licence**, pas un argument commercial.

Vérifier donc, juste avant d'archiver :

```
git status -sb        # doit indiquer 'main...origin/main' sans 'ahead'
git push origin main
```

Au 19/08/2026, `main` est poussé au fil de l'eau (la nuit de travail du 18-19/08 a été poussée commit par commit). Vérifier malgré tout au moment de soumettre (`git log --oneline origin/main..HEAD | wc -l` doit rendre 0) : soumettre sans pousser publierait un binaire dont les sources annoncées ne correspondent pas.

### Historique des versions
- **1.8.0** — soumise le 06/09/2026, build 13, fiche remplie par `tools/asc/` : neuf personnages joués par Maia-3 (style, répertoire, tempérament, illustration, niveau mémorisé par personnage sur l'échelle humaine), filet Stockfish à quatre cas, Progrès par personnage, camp Maia au Laboratoire, licence AGPLv3, borne Fairy-Stockfish à 2850 (`RELEASE_NOTES-1.8.0.md` — absorbe la 1.7.1).
- **1.7.1** — jamais soumise, absorbée par la 1.8.0 : visite guidée bilingue (11 étapes, rejouable depuis l'Aide), coups en ligne colorés dans TOUTES les analyses de variantes, grille des modes sur l'accueil iPad/Mac, stabilité du moteur des variantes en profondeur (6 mécanismes corrigés, suite de torture), Aide remise à jour (version lue du bundle, module Variantes à douze tuiles), zéro warning de compilation (`RELEASE_NOTES-1.7.1.md` — couvre 1.6 → 1.7.1).
- **1.7.0** — jamais soumise, absorbée par la 1.7.1 : quatre variantes de plus au hub, qui passe à douze — **Crazyhouse** (les prises changent de camp et se reposent), **Duck Chess** (un canard bloque une case, tour en deux temps), **Barricades** (d4 et e5 murées dès le départ) et **Barricades aléatoires** (deux murs qui changent de case à chaque coup), toutes contre l'ordinateur. Plus le correctif d'un défaut moteur récurrent des Variantes (« le moteur n'a pas pu être démarré » après une analyse ou un retour en arrière), et une passe de mise en page menée sur les deux extrêmes du parc — grandes fenêtres en classe *regular* (iPad plein écran, Split View, Stage Manager) et petits iPhone (`RELEASE_NOTES-1.7.0.md` — couvre 1.6 → 1.7).
- **1.6.0** — soumise le 28/08/2026 : module Variantes porté à 8 façons de jouer (Chess960 complet, six variantes Fairy-Stockfish, et Coup Volé — variante maison sur Stockfish standard), analyse de fin de partie commune aux 7 non-Chess960, nouveau lecteur d'Ouvertures en arbre, Finales à 78 cours avec recherche, « Changer de mode » uniformisé, correctifs de fiabilité moteur, stockage allégé (175 → 60 Mo) (notes supprimées après soumission ; détail dans l'historique Git).
- **1.5.0** — module Finales (77 cours prouvés par tablebase, 9 familles), entraînement libre arbitré au verdict, correctif majeur iOS 18, ~900 positions ajoutées aux ouvertures, verdicts d'analyse affinés, sélecteur « Changer de mode » avec reprise de position, Stockfish 17.1 (notes supprimées après soumission ; détail dans l'historique Git).
- **1.4.0** — préparée, **jamais soumise** : répertoires d'ouvertures personnels (import PGN + partage par fichier), les 58 ouvertures relues au moteur, un seul essai par puzzle, lecteur d'ouvertures à plateau ancré (`RELEASE_NOTES-1.4.0.md`, conservé comme document historique). Son contenu est livré avec la 1.5.
- **1.3.0** — préparée, **jamais soumise** : échiquier tolérant au doigt, score de précision recalibré, revue d'analyse fiabilisée, iPhone en portrait. Son contenu est livré avec la 1.4 ; aucune note de version distincte n'a été rédigée.
- **1.2.0** — Ouvertures repensées, interface iPad/Mac, synchro iCloud (`RELEASE_NOTES-1.2.0.md`, regroupe 1.0.2 et 1.1.0).

---

## App Review Notes (paste into App Store Connect → App Review Information → Notes)

English, for the Apple reviewer. Frames the app's value proposition (six advanced modes, entirely free), then explains the camera permission, the network call, the licensing situation (GPLv3 engine, public source), and that no login/test account is needed.

```
ChessLab's purpose is to offer an extensive set of advanced chess features — entirely free, with no paywall, no ads, and no in-app purchases. That is the app's core value: depth and quality normally found in paid or subscription chess apps, given away for free as a passion project. It bundles seven modes:

1. Play vs the computer (powered by the embedded Stockfish engine) — adjustable strength (Elo ~900 to ~3190), clocks, hints, risky-move warnings, opening book; or against one of nine "characters" played by the Maia-3 neural network (University of Toronto, AGPLv3), which predicts human moves at a given level and runs fully on-device via Core ML — Stockfish only steps in for short mates, small endgames and repetitions. 2. Two Players — local pass-and-play on a single device. 3. Analyze — full game/position analysis with Stockfish: move-by-move classification, evaluation graph, best-move/threat arrows. 4. Openings — 58 hand-written, annotated openings; step through each one move by move, with variations and simplified spaced-repetition training. 5. Puzzles — over 100,000 tactics puzzles from the Lichess database, plus puzzles auto-generated from the user's own mistakes in Analyze. 6. Laboratory — engine-vs-engine testing to compare Stockfish configurations over a series of games. 7. Variants — Chess960 plus seven more ways to play against the computer (King of the Hill, Three-Check, Horde, Racing Kings, Antichess, Atomic, and a house variant, Stolen Move), each with the same strength/clock settings and its own post-game analysis as the main Play mode.

There is no account, no server, no login — nothing to set up before reviewing.

CAMERA: the Scanner feature uses the camera only to photograph a chess diagram (a screenshot or a physical board from above) and reconstruct the position with on-device image recognition. Photos are processed entirely on-device and are never uploaded anywhere. If testing on Simulator (no camera), use the "Paste" entry in the Scanner screen with any chess diagram image copied to the clipboard, or the "Import a file" entry (visible on Mac Catalyst) — both skip the camera and exercise the same recognition pipeline.

NETWORK: ChessLab has no first-party or third-party backend — no ChessLab server, no API, no analytics, no ads. The ONLY network activity is an optional iCloud sync, which is OFF by default. When a user turns it on (Settings → Sync), SwiftData/CloudKit syncs their own data — saved games, puzzle progress, and opening-training progress — through the user's OWN private iCloud database (CloudKit private database). The bundled content (the 100,000+ puzzle library and the 58 opening courses) stays local and is never synced. No data is shared with the developer, so the App Privacy answer remains "Data Not Collected". With sync disabled — the default — the app makes no network calls at all.

ENGINE LICENSE (GPLv3): ChessLab embeds the Stockfish chess engine, compiled from its own sources and bundled directly into the app (with ARM NEON optimizations). Because Stockfish is GPLv3, the ChessLab binary as a whole is a GPLv3 derivative work. To comply, the complete source code of the app — matching this submitted build — is published publicly at https://github.com/thmaed/ChessLab. Copyright and license notices for all third-party components (Stockfish/GPLv3, Maia-3/AGPLv3 — compatible with GPLv3 per its section 13, the app provides no network service, ChessKit/MIT, the chess piece sets cburnett/GPLv2+ & CC BY-SA 3.0, chessnut/Apache 2.0 and merida/GPLv2+, the Lichess puzzle database/CC0) are also shown in-app under Settings → Licenses. All embedded piece sets are free/open-source and license-compatible with the app's GPLv3.

No in-app purchases, no ads, no user-generated content shared publicly, no multiplayer/online play.
```
