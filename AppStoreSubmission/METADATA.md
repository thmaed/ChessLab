# Métadonnées App Store Connect — ChessLab

**Version courante : 2.1, build 21** (fixés dans `project.pbxproj`). La 2.0 (build 19) est EN VENTE. Voir `RELEASE_NOTES-2.1.md` pour le détail des changements depuis la 2.0. **Préparée le 03/11/2026 : fiche, nouveautés et notes de révision posées dans App Store Connect (version 2.1, PREPARE_FOR_SUBMISSION) ; le build n'est PAS archivé ni téléversé, la version n'est PAS soumise (attendre l'accord de Thierry).**

Tout ce qui suit est à copier-coller directement dans les champs correspondants d'App Store Connect. Les limites de caractères d'Apple sont respectées (vérifiées).

> **Convention d'édition** : dans les blocs à coller, JAMAIS de retour à la ligne à l'intérieur d'un paragraphe — App Store Connect rend chaque saut de ligne tel quel, une césure à 78 colonnes hacherait le texte sur la fiche. Une ligne par paragraphe ; les titres EN CAPITALES gardent leur propre ligne.

> **Révisé le 29/09/2026** — la description annonçait « sept variantes de plus » dans les deux langues, alors que le hub en compte douze depuis la 1.8 : Crazyhouse, Duck Chess, Barricades et Barricades aléatoires y sont entrées sans que la description permanente suive (la fiche Google Play, elle, avait été corrigée le 19/09). Corrigé ici, les deux descriptions vérifiées sous la limite. Captures et aperçus vidéo de la 1.8 conservés — rien du contenu n'a changé.

---

## Nouveautés de cette version — 2.1 (4000 car. max)

C'est le champ « What's New in This Version ». Rédigé pour l'utilisateur final : ce qu'il va sentir, pas ce qui a été refactorisé.

> Version 2.1, build 20. Contenu : collections de puzzles importées d'un fichier PGN (demande d'un utilisateur, format validé sur son fichier réel), écran Puzzles repensé, réussite partielle, 130 935 puzzles, « S'entraîner » sur la variante affichée, découvrabilité. Détail dans `RELEASE_NOTES-2.1.md`.

### Français

```
CHESSLAB 2.1

VOS PROPRES PUZZLES
Importez vos fichiers PGN : chaque fichier devient une collection, rangée à part de la bibliothèque, et chaque partie du fichier un puzzle. Le premier coup est joué d'avance et surligné — à vous de voir ce qui a changé —, puis de trouver la suite. Travaillez une collection en série, refaites ses ratés, ou lancez un programme Woodpecker sur toute la collection.

UN ÉCRAN PUZZLES PLUS CLAIR
Quatre séries démarrent au toucher : À mon niveau, Ratés, À revoir, Mes parties. « Série sur mesure » règle le niveau, la phase, le type et la provenance, et le thème à travailler vous est proposé en tête d'écran.

RÉUSSITE PARTIELLE
Un puzzle dont vous trouvez le début sans la fin n'est plus compté comme raté : il rejoint « À revoir » et revient bientôt.

SÉANCE DU JOUR
Un cycle Woodpecker en cours s'affiche désormais parmi les tâches du jour, avec le nombre de puzzles qu'il reste à faire : un toucher et vous reprenez là où vous en étiez.

PLUS DE 24 000 PUZZLES
La bibliothèque passe à 130 935 problèmes, surtout aux niveaux extrêmes et pour les solutions de quatre coups ou plus. Une barre de progression suit son préchargement au premier lancement.

OUVERTURES ET FINALES
« S'entraîner » travaille la variante que vous êtes en train de lire, et non plus seulement la ligne principale. Les noms d'ouvertures s'affichent dans la langue de l'app.

MIEUX S'Y RETROUVER
Un bouton « Modes » pour changer de mode, les sources d'Analyse dépliées, des « Questions fréquentes » dans l'Aide, la version en bas des Réglages. Et dans une partie chronométrée relue après coup, « Analyser ici » ouvre l'analyse sur la position affichée.
```

### English

```
CHESSLAB 2.1

YOUR OWN PUZZLES
Import your PGN files: each file becomes a collection, kept apart from the library, and each game in it a puzzle. The first move is played for you and highlighted — spot what changed — and then you find the rest. Work through a collection as a series, redo its misses, or start a Woodpecker programme on the whole collection.

A CLEARER PUZZLES SCREEN
Four series start with a tap: At my level, Missed, Review, My games. “Custom series” sets the level, phase, type and source, and the theme to work on is suggested at the top of the screen.

PARTIAL SUCCESS
A puzzle where you find the start but not the end no longer counts as missed: it joins “Review” and comes back soon.

DAILY SESSION
A Woodpecker cycle under way now appears among the day's tasks, with the number of puzzles still to do: one tap and you pick up where you left off.

OVER 24,000 MORE PUZZLES
The library grows to 130,935 problems, especially at the extreme levels and for solutions of four moves or more. A progress bar follows its loading on first launch.

OPENINGS AND ENDGAMES
“Practice” works on the variation you are reading, not only the main line. Opening names now appear in the app's language.

EASIER TO FIND YOUR WAY
A “Modes” button to switch mode, Analyse sources open by default, “Frequently asked questions” in Help, the version at the bottom of Settings. And in a timed game reviewed afterwards, “Analyse here” opens the analysis on the position shown.
```

---

## Français (langue principale)

**Nom de l'app** (30 car. max) :
```
ChessLab
```

**Sous-titre** (30 car. max — 30 utilisés) :
```
Jeu d'échecs, analyse, puzzles
```
_29/10/2026 (ASO) : les mots que l'on CHERCHE (« jeu d'échecs », « analyse », « puzzles ») plutôt
qu'une formule ; ils comptent comme mots-clés, qui n'ont donc plus à les répéter. Pas de « gratuit »
ici : Apple refuse les informations tarifaires dans le sous-titre et les mots-clés (règle 2.3.7)._

**Mots-clés** (100 car. max — 95 utilisés, séparés par des virgules, sans espace) :
```
stockfish,maia,tactique,ouverture,finale,entrainement,chess960,coach,elo,pgn,adversaire,scanner
```

**Texte promotionnel** (170 car. max — modifiable sans nouvelle revue) :
_En ligne sur la 2.0 depuis le 29/10/2026 avec « plus de 100 000 puzzles » (la 2.0 en a 106 094) ;
le texte ci-dessous, à 130 000, part avec la version suivante._
```
Sans publicité, sans compte, sans réseau. Neuf adversaires qui jouent comme des humains, l'analyse Stockfish et plus de 130 000 puzzles — tout sur votre appareil.
```

**Description** (4000 car. max) :
```
Entièrement gratuite, sans publicité, sans compte : rien ne quitte votre appareil.

ChessLab est un compagnon d'échecs complet pour iPhone et iPad : jouer, analyser, s'entraîner et expérimenter, avec Stockfish intégré, sans jamais quitter l'app.

DES ADVERSAIRES QUI JOUENT COMME DES HUMAINS
Neuf personnages joués par Maia-3, un réseau entraîné sur des millions de parties humaines : il ne cherche pas le meilleur coup, il joue celui qu'un humain de ce niveau jouerait, gaffes comprises. Chacun a son style, son répertoire et son tempérament, et un niveau réglable sur l'échelle humaine. Ou affrontez Stockfish, du débutant (~900 Elo) au maximum (~3190). Pendule en option, indice, alerte avant un coup risqué et barre d'évaluation à volonté.

ANALYSER ET COMPRENDRE
Chaque coup est classé (imprécision, erreur, gaffe, coup brillant…), chaque joueur reçoit sa précision, et l'app dit pourquoi un coup était mauvais. Le Coach ajoute la part des joueurs de votre niveau qui le jouent. À la fin, elle propose de transformer vos erreurs et vos mats manqués en puzzles. Entrée par PGN, FEN, éditeur de position ou scanner photo.

SÉANCE DU JOUR
Chaque jour, ce qu'il faut revoir : positions d'ouverture dues, puzzles ratés, une finale. Une série de jours et des médailles pour tenir la durée.

OUVERTURES
58 ouvertures rédigées à la main (bilingues) et relues au moteur : chaque coup est expliqué, des flèches colorées relient le plateau à la liste, et la répétition espacée les ancre. Importez aussi vos propres répertoires en PGN.

FINALES
78 cours prouvés par table de finales : aucun coup enseigné ne lâche le gain, aucune défense proposée ne perd la nulle. Et l'entraînement libre, où tout coup qui préserve le verdict est accepté.

PUZZLES
Plus de 130 000 problèmes de la base Lichess, filtrables par niveau et par thème, plus les vôtres : tirés de vos erreurs, ou importés de vos propres fichiers PGN. Cote personnelle et « À mon niveau ».

VARIANTES ET PLUS
Chess960 et onze variantes contre l'ordinateur (Roi de la colline, Trois échecs, Horde, Atomique, Crazyhouse, Duck Chess, Barricades…), chacune avec sa propre analyse. Mode deux joueurs, et Laboratoire pour comparer deux réglages de Stockfish.

IPHONE ET IPAD
Grand échiquier et panneaux côte à côte sur iPad, clavier et trackpad, portrait et paysage. Bilingue français/anglais. Synchronisation iCloud optionnelle, désactivée par défaut.

VIE PRIVÉE
Hors ligne par défaut : aucun serveur ChessLab, aucune mesure d'audience, aucune publicité. Vos parties restent sur votre appareil.

ChessLab intègre le moteur Stockfish (licence GPLv3), le réseau Maia-3 de l'Université de Toronto (licence AGPLv3) et des jeux de pièces vectorielles libres — cburnett (GPLv2+/CC BY-SA), chessnut (Apache 2.0) et merida (GPLv2+). Code source complet et mentions de licence disponibles depuis l'app (Réglages → Licences).
```

---

## English (secondary localization — App Store Connect: "English (U.K.)", en-GB — la fiche a toujours été en anglais britannique ; un « English (U.S.) » neuf est refusé, le nom « ChessLab » y étant pris par une autre app)

**Name** (30 char. max):
```
ChessLab
```

**Subtitle** (30 char. max — 29 used):
```
Chess game, analysis, puzzles
```

**Keywords** (100 char. max — 97 used):
```
stockfish,maia,tactics,openings,endgame,training,chess960,coach,elo,pgn,opponent,scanner,variants
```

**Promotional text** (170 char. max):
```
No ads, no account, no network. Nine opponents who play like humans, Stockfish analysis and over 130,000 puzzles — all on your device.
```

**Description** (4000 char. max):
```
Completely free, no ads, no account: nothing leaves your device.

ChessLab is a complete chess companion for iPhone and iPad: play, analyse, train and experiment, with Stockfish built in, without ever leaving the app.

OPPONENTS THAT PLAY LIKE HUMANS
Nine characters played by Maia-3, a network trained on millions of human games: it does not look for the best move, it plays the one a human of that level would play, blunders included. Each has a style, a repertoire and a temperament, and a level set on the human scale. Or take on Stockfish, from beginner (~900 Elo) to maximum (~3190). Optional clock, hints, a warning before risky moves and an evaluation bar, all on demand.

ANALYSE AND UNDERSTAND
Every move is graded (inaccuracy, mistake, blunder, brilliant…), each player gets an accuracy score, and the app tells you why a move was bad. The Coach adds the share of players at your level who play it. At the end, it offers to turn your mistakes and missed mates into puzzles. Load a game by PGN, FEN, position editor or photo scanner.

DAILY SESSION
Every day, what to review: opening positions that are due, missed puzzles, an endgame. A streak of days and medals to keep you going.

OPENINGS
58 hand-written openings (bilingual), checked against the engine: every move is explained, coloured arrows tie the board to the move list, and spaced repetition makes them stick. Import your own repertoires as PGN too.

ENDGAMES
78 courses proven by endgame tablebases: no move taught gives up a win, no defence offered loses a draw. Plus free training, where any move that keeps the verdict is accepted.

PUZZLES
Over 130,000 problems from the Lichess database, filtered by level and theme, plus your own: drawn from your mistakes, or imported from your own PGN files. Personal rating and “At my level”.

VARIANTS AND MORE
Chess960 and eleven variants against the computer (King of the Hill, Three-Check, Horde, Atomic, Crazyhouse, Duck Chess, Barricades…), each with its own analysis. Two-player mode, and a Laboratory to compare two Stockfish settings.

IPHONE AND IPAD
A large board with side-by-side panels on iPad, keyboard and trackpad, portrait and landscape. Fully bilingual, French and English. Optional iCloud sync, off by default.

PRIVACY
Offline by default: no ChessLab server, no analytics, no ads. Your games stay on your device.

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

**2.1, build 21** — `MARKETING_VERSION = 2.1`, `CURRENT_PROJECT_VERSION = 21` (la 2.0, build 19, est en vente ; le build 20, téléversé le 04/11 sans la tâche Woodpecker de la séance, est écarté). Nouveautés détaillées dans `RELEASE_NOTES-2.1.md`.

**2.0, build 19** — `MARKETING_VERSION = 2.0`, `CURRENT_PROJECT_VERSION = 19` (la 1.9.2, build 17, est la dernière soumise : le 18 est le premier numéro libre, à revérifier par `asc.py build` avant l'archive). Nouveautés détaillées dans `RELEASE_NOTES-2.0.md`.

**1.9.1, build 16** — fixés le 23/10/2026, aux deux configurations de la cible applicative. La 1.9.0 (build 15) est **READY_FOR_SALE** : le 16 est le premier numéro libre (vérifié par l'API le 23/10). Version de correction : la case d'origine de l'échiquier et un coin du recadrage ne répondaient plus en iOS 18.

**1.9.0, build 15** — fixés le 13/10/2026 (`MARKETING_VERSION = 1.9.0`, `CURRENT_PROJECT_VERSION = 15`), aux deux configurations de la cible applicative. La 1.8.1 (build 14) est **READY_FOR_SALE** : le 15 est le premier numéro libre (vérifié par l'API le 13/10). Nouveautés détaillées dans `RELEASE_NOTES-1.9.0.md`, texte prêt à coller ci-dessus.

Pourquoi 1.9.0 : un appareil nouveau pris en charge de bout en bout (iPhone Duo, SDK iOS 27.1), avec des dispositions nouvelles pour les écrans plus larges que hauts et une politique d'orientation qui change. Plus qu'une correction.

**1.8.1, build 14** — 29/09/2026, version de corrections (nom du joueur, balises PGN, fenêtres partagées sur iPad).

**Historique du 06/09/2026** — 1.8.0, build 13 : App Store Connect avait déjà reçu des builds 11 et 12 le matin même, depuis Xcode, et exige un numéro strictement supérieur. Le build 13 est celui téléversé par `tools/asc/release.sh`.

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
- **2.0** — build 18 : séance du jour, analyse → puzzles avec récapitulatif, Coach (Maia-3), cote de puzzle, ouvertures illustrées, reprise de partie, limite de temps en option ; correctifs (reprise après capture d'une tour, coup de mat noté) (`RELEASE_NOTES-2.0.md`).
- **1.9.2** — build 17, soumise : correctif de la prise au tap-tap sous iOS 18.
- **1.9.1** — build 16 : la pièce du coin haut gauche de l'échiquier (h1 aux Noirs, a8 aux Blancs) et un coin du recadrage du scanner ne répondaient plus au toucher en iOS 18 (`RELEASE_NOTES-1.9.1.md`).
- **1.9.0** — build 15, en ligne : iPhone Duo, dispositions pour écrans plus larges que hauts (`RELEASE_NOTES-1.9.0.md`).
- **1.8.1** — build 14, en ligne : nom du joueur traduit et réglable, PGN exporté avec ses sept balises, disposition iPhone dans une fenêtre d'iPad plus étroite que 744 pt, échiquier servi en premier (`RELEASE_NOTES-1.8.1.md`).
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

English, for the Apple reviewer. Opens with the nature of the update (2.0 : major content update), puis la proposition de valeur (sept modes, entièrement gratuits), la permission caméra, le seul appel réseau, la situation de licence (moteur GPLv3, sources publiques), et qu'aucun compte de test n'est nécessaire.

```
WHAT'S IN THIS UPDATE (2.1): a feature update. New: the user can import their own chess puzzles from PGN files (Puzzles → My collections → Import puzzles). The files are chosen with the standard system document picker, or the text can be pasted; they are read on the device and never uploaded. Each file becomes a collection kept apart from the bundled library. To try it without a file: tap "Import puzzles", paste the two lines below in the text area, give any name and tap "Import the text" — each game is one puzzle, the first move being played for you:
[FEN "6k1/p4ppp/8/8/8/8/5PPP/4R1K1 b - - 0 1"]
1...a6 2.Re8#
Also new: a redesigned Puzzles screen (four ready-made series and a custom-series sheet), partial credit for a puzzle solved only in part, 24,841 more bundled puzzles (130,935 in all, from the Lichess database, CC0), "Practice" in the opening and endgame courses now follows the variation being read, a "Modes" button on the mode screens, and a frequently-asked-questions section in Help. A standard system rating request (StoreKit) may appear at most once per version, after the user has played and trained for a few days. No change to permissions, privacy or licensing; still no network call, no account, no data collected.

ChessLab is a free chess app — no paywall, no ads, no in-app purchases, no account, no login, no server. Nothing to set up before reviewing. It bundles seven modes: play against the embedded Stockfish engine (Elo ~900 to ~3190) or against one of nine "characters" played by the Maia-3 neural network (University of Toronto, AGPLv3), which predicts human moves at a given level and runs entirely on-device via Core ML; two players on one device; full game analysis with Stockfish; 58 hand-written opening courses with spaced-repetition training; over 130,000 Lichess puzzles; an engine-vs-engine laboratory; and twelve variants (Chess960, King of the Hill, Three-Check, Horde, Racing Kings, Atomic, Antichess, Crazyhouse, Duck Chess, two Barricades, and a house variant, Stolen Move).

CAMERA: the Scanner uses the camera only to photograph a chess diagram — a screenshot or a physical board seen from above — and reconstruct the position with on-device recognition. Photos never leave the device. On Simulator (no camera), use the "Paste" entry in the Scanner screen with any chess diagram in the clipboard: it skips the camera and exercises the same recognition.

NETWORK: there is no ChessLab server, no API, no analytics, no ads. The only network activity is an optional iCloud sync, OFF by default. Turned on (Settings → Sync), CloudKit syncs the user's own saved games and progress through their OWN private iCloud database; the bundled puzzles and courses stay local. No data reaches the developer, hence "Data Not Collected". With sync off — the default — the app makes no network call at all.

ENGINE LICENSE (GPLv3): ChessLab embeds the Stockfish engine, compiled from its own sources, so the binary as a whole is a GPLv3 derivative work. The complete source code matching this build is published at https://github.com/thmaed/ChessLab. Notices for every third-party component (Stockfish/GPLv3, Maia-3/AGPLv3 — compatible per its section 13, the app provides no network service —, ChessKit/MIT, the piece sets cburnett/GPLv2+ & CC BY-SA 3.0, chessnut/Apache 2.0, merida/GPLv2+, the Lichess puzzles/CC0) are shown in-app under Settings → Licences.
```
