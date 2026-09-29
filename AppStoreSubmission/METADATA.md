# Métadonnées App Store Connect — ChessLab

**Version courante : 1.8.1, build 14** (fixés dans `project.pbxproj` le 29/09/2026). Voir `RELEASE_NOTES-1.8.1.md` pour le détail des changements depuis la 1.8.

Tout ce qui suit est à copier-coller directement dans les champs correspondants d'App Store Connect. Les limites de caractères d'Apple sont respectées (vérifiées).

> **Convention d'édition** : dans les blocs à coller, JAMAIS de retour à la ligne à l'intérieur d'un paragraphe — App Store Connect rend chaque saut de ligne tel quel, une césure à 78 colonnes hacherait le texte sur la fiche. Une ligne par paragraphe ; les titres EN CAPITALES gardent leur propre ligne.

> **Révisé le 29/09/2026** — la description annonçait « sept variantes de plus » dans les deux langues, alors que le hub en compte douze depuis la 1.8 : Crazyhouse, Duck Chess, Barricades et Barricades aléatoires y sont entrées sans que la description permanente suive (la fiche Google Play, elle, avait été corrigée le 19/09). Corrigé ici, les deux descriptions vérifiées sous la limite. Captures et aperçus vidéo de la 1.8 conservés — rien du contenu n'a changé.

---

## Nouveautés de cette version — 1.8.1 (4000 car. max)

C'est le champ « What's New in This Version ». Rédigé pour l'utilisateur final : ce qu'il va sentir, pas ce qui a été refactorisé.

> ⏳ **Prête, pas soumise.** Version 1.8.1, build 14. Couvre le 13/09 → 29/09/2026, depuis la 1.8 (build 13, READY_FOR_SALE depuis sa révision). Détail dans `RELEASE_NOTES-1.8.1.md`.

### Français

```
VOTRE NOM, ENFIN
Réglages → Votre nom : le nom sous lequel vous jouez s'affiche sur votre plaque, dans la bibliothèque et dans les parties que vous exportez. Laissez le champ vide et il vaut « Vous ». Au passage, ce nom suit désormais la langue de l'interface — en anglais il dit « You », y compris dans les parties déjà enregistrées, alors qu'il restait français.

LE PGN EXPORTÉ EST UN VRAI PGN
Une partie partagée ou copiée ne portait que la suite des coups : ni en-têtes, ni résultat. Elle porte maintenant les sept balises du standard — événement, site, date, ronde, Blancs, Noirs, résultat — et le résultat clôt aussi les coups. Les en-têtes d'un PGN importé ne sont jamais écrasées : on ne comble que les manques. Les douze variantes en profitent, et vos parties déjà rangées sont complétées quand vous les rouvrez.

IPAD : LES FENÊTRES PARTAGÉES, ET LA PLACE DE L'ÉCHIQUIER
Dans une fenêtre réduite pour partager l'écran avec une autre app, ChessLab gardait ses deux colonnes : la barre latérale prenait sa place entière, et il restait à l'échiquier moins de largeur que sur un iPhone. Sous la largeur du plus étroit des iPad, l'app prend désormais la disposition iPhone — une colonne, échiquier pleine largeur. Là où les deux colonnes restent, l'échiquier se sert le premier : il gagne jusqu'à 15 % en paysage, et toute la largeur en portrait quand la barre latérale est repliée.

MÉMORISATION
Une carte de plus dans Progrès : positions vues, acquises, à raffermir, dues aujourd'hui, révisions de la semaine et taux de réussite. La répétition espacée montre enfin ce qu'elle fait de vos révisions.

DÉTAILS
Barre d'évaluation activée par défaut dans tous les modes qui l'offrent. Au Duck Chess, prendre le roi n'est plus annoncé « échec et mat » mais « roi capturé » — le canard masque le coup qui vient, et la partie se gagne en prenant le roi. Annonces VoiceOver des coups revues. Le détecteur du scanner est déclaré dans l'écran Licences.
```

### English

```
YOUR NAME, AT LAST
Settings → Your name: the name you play under shows on your plate, in the library and in the games you export. Leave the field empty and it reads "You". Along the way, that name now follows the interface language — in English it says "You", including in games already recorded, where it used to stay French.

AN EXPORTED PGN IS A REAL PGN
A game shared or copied carried only the moves: no headers, no result. It now carries the seven tags of the standard — event, site, date, round, White, Black, result — and the result closes the moves too. The headers of an imported PGN are never overwritten: only the gaps are filled. The twelve variants benefit as well, and games already stored are completed when you reopen them.

IPAD: SHARED WINDOWS, AND ROOM FOR THE BOARD
In a window shrunk to share the screen with another app, ChessLab kept its two columns: the sidebar took its full place, and the board was left with less width than on an iPhone. Below the width of the narrowest iPad, the app now takes the iPhone layout — one column, board at full width. Where the two columns remain, the board serves itself first: it gains up to 15 % in landscape, and the whole width in portrait when the sidebar is folded.

MEMORISATION
One more card in Progress: positions seen, acquired, to firm up, due today, reviews this week and success rate. Spaced repetition finally shows what it does with your reviews.

DETAILS
Evaluation bar on by default in every mode that offers it. In Duck Chess, taking the king is no longer announced as "checkmate" but as "king captured" — the duck hides the move to come, and the game is won by taking the king. VoiceOver move announcements revised. The scanner's detector is declared on the Licences screen.
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
ChessLab est un compagnon d'échecs complet pour iPhone et iPad : jouer, analyser, s'entraîner et expérimenter, avec le moteur Stockfish intégré, sans jamais quitter l'app.

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
Chess960 (les échecs Fischer Random) : position de départ aléatoire, choisie par numéro, ou composée soi-même, avec la même analyse de fin de partie qu'en mode « Jouer ». Onze variantes de plus contre l'ordinateur, chacune avec sa propre analyse : Roi de la colline, Trois échecs, Horde, Course des rois, Atomique, Antéchecs, Crazyhouse, Coup Volé, Duck Chess, Barricades et Barricades aléatoires.

VOS PROPRES RÉPERTOIRES
Importez vos ouvertures au format PGN, variantes comprises, et entraînez-les avec le même système. Partagez un répertoire par simple fichier — aucun compte, aucun serveur. Ce que vous avez déjà mémorisé sur une position vaut aussitôt dans le répertoire importé.

PUZZLES
Plus de 100 000 problèmes tactiques issus de la base Lichess, filtrables par niveau et par thème, plus des puzzles générés depuis vos propres erreurs en analyse. Répétition espacée et suivi de vos points forts.

LABORATOIRE
Faites s'affronter deux réglages de Stockfish sur une série de parties pour comparer leur force, avec estimation de l'écart Elo et intervalle de confiance.

ÉDITEUR ET SCANNER
Composez une position à la main, ou scannez-la depuis une capture d'écran ou une photo d'écran — la reconnaissance se corrige avant de jouer ou d'analyser.

CONÇU POUR IPAD
Échiquier grand format et panneaux côte à côte (coups, courbe, MultiPV), clavier et trackpad, portrait, paysage et fenêtre partagée.

SYNCHRONISATION iCLOUD (optionnelle)
Activez-la dans les Réglages pour que vos parties suivent vos appareils, via votre iCloud privé. Aucun compte, aucun serveur. Désactivée par défaut.

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
Chess960 (Fischer Random Chess): a randomly drawn starting position, one chosen by number, or one you compose yourself, with a full post-game analysis just like "Play" mode. Eleven more variants against the computer, each with its own analysis: King of the Hill, Three-Check, Horde, Racing Kings, Atomic, Antichess, Crazyhouse, Stolen Move (a token every 7 moves lets you play twice in a row), Duck Chess, Barricades and Random Barricades.

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

**1.8.1, build 14** — fixés le 29/09/2026 (`MARKETING_VERSION = 1.8.1`, `CURRENT_PROJECT_VERSION = 14`), aux deux configurations de la cible applicative. La 1.8 (build 13) est **READY_FOR_SALE** : le 14 est le premier numéro libre. Nouveautés détaillées dans `RELEASE_NOTES-1.8.1.md`, texte prêt à coller ci-dessus.

Pourquoi 1.8.1 et non 1.9.0 : la version est faite de corrections — le nom du joueur, les balises PGN, la mise en page en fenêtre partagée — avec deux ajouts modestes (le réglage « Votre nom », la carte Mémorisation). Aucun mode ni module nouveau. Si le choix doit changer, c'est une constante dans `project.pbxproj` et un titre ici.

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

English, for the Apple reviewer. Opens with the nature of the update (1.8.1 : correction de défauts), puis la proposition de valeur (sept modes, entièrement gratuits), la permission caméra, le seul appel réseau, la situation de licence (moteur GPLv3, sources publiques), et qu'aucun compte de test n'est nécessaire.

```
WHAT'S IN THIS UPDATE (1.8.1): a bug-fix release. No new mode, no change to permissions, privacy or licensing. It fixes three defects reported by a tester on 27 September 2026: the player's name stayed in French ("Vous") in an otherwise fully English interface; an exported PGN carried only the moves, with no tag pairs and no result, which some chess programs reject; and on iPad, a window narrowed to share the screen kept the two-column layout, leaving the board less room than on an iPhone. Two small additions: an optional "Your name" setting, and a memorisation card in the Progress screen.

ChessLab is a free chess app — no paywall, no ads, no in-app purchases, no account, no login, no server. Nothing to set up before reviewing. It bundles seven modes: play against the embedded Stockfish engine (Elo ~900 to ~3190) or against one of nine "characters" played by the Maia-3 neural network (University of Toronto, AGPLv3), which predicts human moves at a given level and runs entirely on-device via Core ML; two players on one device; full game analysis with Stockfish; 58 hand-written opening courses with spaced-repetition training; over 100,000 Lichess puzzles; an engine-vs-engine laboratory; and twelve variants (Chess960, King of the Hill, Three-Check, Horde, Racing Kings, Atomic, Antichess, Crazyhouse, Duck Chess, two Barricades, and a house variant, Stolen Move).

CAMERA: the Scanner uses the camera only to photograph a chess diagram — a screenshot or a physical board seen from above — and reconstruct the position with on-device recognition. Photos never leave the device. On Simulator (no camera), use the "Paste" entry in the Scanner screen with any chess diagram in the clipboard: it skips the camera and exercises the same recognition.

NETWORK: there is no ChessLab server, no API, no analytics, no ads. The only network activity is an optional iCloud sync, OFF by default. Turned on (Settings → Sync), CloudKit syncs the user's own saved games and progress through their OWN private iCloud database; the bundled puzzles and courses stay local. No data reaches the developer, hence "Data Not Collected". With sync off — the default — the app makes no network call at all.

ENGINE LICENSE (GPLv3): ChessLab embeds the Stockfish engine, compiled from its own sources, so the binary as a whole is a GPLv3 derivative work. The complete source code matching this build is published at https://github.com/thmaed/ChessLab. Notices for every third-party component (Stockfish/GPLv3, Maia-3/AGPLv3 — compatible per its section 13, the app provides no network service —, ChessKit/MIT, the piece sets cburnett/GPLv2+ & CC BY-SA 3.0, chessnut/Apache 2.0, merida/GPLv2+, the Lichess puzzles/CC0) are shown in-app under Settings → Licences.
```
