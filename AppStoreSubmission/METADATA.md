# Métadonnées App Store Connect — ChessLab

**Version courante : 1.5.0** (build 7). Voir `RELEASE_NOTES-1.5.0.md` pour le
détail complet des changements depuis la 1.2.

Tout ce qui suit est à copier-coller directement dans les champs
correspondants d'App Store Connect. Les limites de caractères d'Apple sont
respectées (vérifiées).

> **Pour cette mise à jour**, quatre champs demandent une action : **Nouveautés
> de cette version** (ci-dessous, obligatoire), le numéro de build, et la
> **description**, qui a été complétée deux fois depuis la 1.2 : la 1.4 y a
> ajouté les répertoires personnels (importer et partager les siens), la 1.5
> doit y ajouter le module Finales — 77 cours prouvés par table de finales et
> l'entraînement libre, l'argument le plus différenciant de l'app ; vérifier
> le bloc « LE COIN DES FINALES » de la description ci-dessous avant de
> coller. Le **texte promotionnel** reste valable ; nom, sous-titre,
> mots-clés et catégories aussi.

---

## Nouveautés de cette version — 1.5 (4000 car. max)

C'est le champ « What's New in This Version ». Rédigé pour l'utilisateur
final : ce qu'il va sentir, pas ce qui a été refactorisé.

> **Ce texte couvre 1.2 → 1.5, pas seulement 1.5.** Ni la 1.3 ni la 1.4 n'ont
> été soumises : le dernier build envoyé à Apple est le build 3 de la 1.2
> (commit `a211763`). Les utilisateurs passent donc directement de la 1.2 à la
> 1.5, et les nouveautés des 1.3 et 1.4 doivent leur être annoncées ici.

### Français (2500 car. — limite 4 000)

```
NOUVEAU : LE MODULE FINALES — 77 COURS PROUVÉS
De l'opposition à la Lucena, des forteresses aux études célèbres (Lasker,
Troitsky, Kubbel…), 77 cours groupés en neuf familles pour enfin convertir
vos finales. Chaque ligne est vérifiée par table de finales — le verdict
mathématique exact : aucun coup enseigné ne lâche le gain, aucune défense
proposée ne perd la nulle. Révision espacée et synchro iCloud, comme les
ouvertures.

ENTRAÎNEMENT LIBRE DES FINALES
Concluez la position contre la meilleure défense : tout coup qui préserve le
verdict est accepté — pas seulement celui de la leçon. Un coup qui lâche le
gain est repris, meilleur coup à l'appui, et « conversion propre » se mérite.

VOS PROPRES RÉPERTOIRES D'OUVERTURES
Importez un répertoire au format PGN — variantes comprises — entraînez-le en
répétition espacée, modifiez-le dans l'app et partagez-le d'un simple
fichier, sans compte ni serveur.

LES 58 OUVERTURES COMPLÉTÉES ET RELUES
Près de 900 positions ajoutées : les réponses que les joueurs de club jouent
vraiment (la London contre les défenses au 1.d4, la Philidor, la Petroff…).
Et chaque coup du catalogue est rejoué sous Stockfish avant publication.

LES MODES SE PARLENT
« Changer de mode » bascule vers le Laboratoire, l'ordinateur ou une partie à
deux en emportant la position affichée — depuis un puzzle, un cours ou une
partie. Le menu d'export envoie aussi la position vers l'analyse ; votre
partie vous attend au retour.

ANALYSE PLUS SÛRE ET PLUS JUSTE
Les verdicts limites sont réexaminés avec dix fois plus d'effort avant
d'être étiquetés : 85 % d'erreurs d'étiquette en moins. Le score de précision
ne se laisse plus gonfler par les positions déjà gagnées, et l'app explique
POURQUOI un coup est une erreur. « Analyser PGN / FEN » reconnaît tout seul
ce que contient votre presse-papiers.

PUZZLES
Un seul essai par défaut, comme un vrai exercice de calcul (trois essais
disponibles dans les Réglages). Bilan par thème, et sets ciblés sur vos
faiblesses depuis l'écran Progrès — désormais filtrable sur 7 ou 30 jours.

L'ÉCHIQUIER RÉPOND ENFIN AU DOIGT
Correctif majeur pour iOS 18, où aucune pièce ne répondait au toucher. Et
partout : relâcher une pièce un peu à côté joue quand même le coup, la case
visée s'allume pendant le glissement.

ET AUSSI
Stockfish 17.1. Bibliothèque sans doublons, suppression de parties. Lecteur
d'ouvertures à plateau ancré. Aide accessible depuis l'accueil. iPhone en
portrait, iPad en pleine page, plus aucun débordement de texte.
```

### English (2335 char. — 4,000 limit)

```
NEW: THE ENDGAMES MODULE — 77 PROVEN COURSES
From the opposition to the Lucena, from fortresses to famous studies
(Lasker, Troitsky, Kubbel…), 77 courses in nine families to finally convert
your endings. Every line is verified against endgame tablebases — the exact
mathematical verdict: no taught move gives up a win, no recommended defence
loses a draw. Spaced repetition and iCloud sync, like the openings.

FREE ENDGAME TRAINING
Finish the position against best defence: any move that preserves the
verdict is accepted — not just the lesson's move. A move that lets the win
slip is taken back, best move shown, and "clean conversion" has to be earned.

YOUR OWN OPENING REPERTOIRES
Import a repertoire as PGN — variations included — drill it with spaced
repetition, edit it in the app and share it as a single file, no account
and no server.

ALL 58 OPENINGS EXPANDED AND REVIEWED
Nearly 900 positions added: the replies club players actually play (the
London against 1.d4 defences, the Philidor, the Petroff…). And every move in
the catalogue is replayed under Stockfish before release.

THE MODES TALK TO EACH OTHER
"Switch mode" jumps to the Laboratory, the computer or a two-player game,
carrying the displayed position along — from a puzzle, a course or a game.
The export menu also sends the position to analysis; your game is waiting
when you come back.

SAFER, FAIRER ANALYSIS
Borderline verdicts are re-examined with ten times the effort before being
labelled: 85% fewer mislabels. The accuracy score is no longer inflated by
already-won positions, and the app explains WHY a move is a mistake.
"Analyse PGN / FEN" recognises what's in your clipboard by itself.

PUZZLES
One attempt by default, the way a calculation exercise should work (three
attempts available in Settings). Reports by theme, and targeted sets on your
weaknesses from the Progress screen — now filterable to 7 or 30 days.

THE BOARD FINALLY ANSWERS YOUR FINGER
Major fix for iOS 18, where no piece responded to touch. And everywhere:
releasing a piece slightly off-square still plays the move, and the target
square lights up while you drag.

ALSO
Stockfish 17.1. Duplicate-free library with game deletion. Opening reader
with an anchored board. Help reachable from the home screen. iPhone in
portrait, iPad full-page sheets, no text overflow anywhere.
```

---

## Français (langue principale)

**Nom de l'app** (30 car. max) :
```
ChessLab
```

**Sous-titre** (30 car. max — 28 utilisés) :
```
Jouez, analysez, progressez.
```

**Mots-clés** (100 car. max — 94 utilisés, séparés par des virgules, sans espace) :
```
stockfish,tactique,ouverture,puzzle,gambit,fen,pgn,elo,entrainement,scanner,analyse,ia,plateau
```

**Texte promotionnel** (170 car. max — modifiable sans nouvelle revue) :
```
Analysez vos parties, scannez un échiquier : 58 ouvertures, 77 finales
prouvées, 100 000+ puzzles, l'ordinateur en face — 100% local.
```

**Description** (4000 car. max) :
```
ChessLab est un compagnon d'échecs complet pour iPhone et iPad : jouer,
analyser, s'entraîner et expérimenter, avec le moteur Stockfish intégré et
sans jamais quitter l'application.

CONTRE STOCKFISH
Affrontez Stockfish à la force de votre choix, du débutant (~900 Elo) au
niveau maximal (~3190 Elo), avec ou sans pendule. Indice, alerte avant un
coup risqué et barre d'évaluation sont activables à tout moment.

DEUX JOUEURS
Jouez à deux sur le même appareil, avec un mode « table » qui retourne les
pièces pour rester lisible face à face.

ANALYSER
Passez une partie ou une position au crible de Stockfish : classification de
chaque coup (imprécision, erreur, gaffe, coup brillant…), courbe
d'évaluation, flèches du meilleur coup et de la menace adverse, lecture
automatique. Entrée par PGN, FEN, éditeur de position ou scanner photo.

OUVERTURES
Choisissez une ouverture et avancez coup par coup : chaque coup est
expliqué, les variantes sont proposées, et des flèches colorées relient le
plateau à la liste des coups. 58 ouvertures rédigées à la main (bilingues),
toutes relues au moteur, avec un entraînement en répétition espacée
simplifié pour les mémoriser.

LE COIN DES FINALES
77 cours prouvés par table de finales — le verdict mathématique exact :
aucun coup enseigné ne lâche le gain, aucune défense proposée ne perd la
nulle. Neuf familles, de l'opposition aux études célèbres. Et l'entraînement
libre : concluez la position contre la meilleure défense, tout coup qui
préserve le verdict est accepté — pas seulement celui de la leçon.

VOS PROPRES RÉPERTOIRES
Importez vos ouvertures au format PGN, variantes comprises, et entraînez-les
avec le même système. Partagez un répertoire par simple fichier — aucun
compte, aucun serveur. Ce que vous avez déjà mémorisé sur une position vaut
aussitôt dans le répertoire importé.

PUZZLES
Plus de 100 000 problèmes tactiques issus de la base Lichess, filtrables
par niveau et par thème, plus des puzzles générés automatiquement depuis
vos propres erreurs en analyse. Répétition espacée et suivi de vos points
forts.

LABORATOIRE
Faites s'affronter deux réglages de Stockfish sur une série de parties pour
comparer leur force, avec estimation de l'écart Elo et intervalle de
confiance.

ÉDITEUR ET SCANNER
Composez une position à la main, ou scannez-la depuis une capture d'écran ou
une photo d'écran — la reconnaissance se corrige avant de jouer ou
d'analyser.

CONÇU POUR IPAD
Échiquier grand format et panneaux visibles simultanément (coups, courbe,
MultiPV), clavier et trackpad pris en charge, portrait et paysage soignés.

SYNCHRONISATION iCLOUD (optionnelle)
Activez la synchronisation iCloud dans les Réglages pour que vos parties
suivent tous vos appareils, via votre iCloud privé. Aucun compte à créer,
aucun serveur ChessLab. Désactivée par défaut : l'app fonctionne
entièrement hors ligne.

VIE PRIVÉE
Hors ligne par défaut : aucun serveur ChessLab, aucune mesure d'audience,
aucune publicité. Vos parties et réglages restent sur votre appareil. La
synchronisation iCloud, si vous l'activez, utilise votre propre iCloud
privé — vos données ne sont jamais partagées avec le développeur. Bilingue
français/anglais.

ChessLab intègre le moteur Stockfish (licence GPLv3) et des jeux de pièces
vectorielles libres — cburnett (GPLv2+/CC BY-SA), chessnut (Apache 2.0) et
merida (GPLv2+). Code source complet et mentions de licence disponibles
depuis l'app (Réglages → Licences).
```

---

## English (secondary localization — App Store Connect: "English (U.S.)")

**Name** (30 char. max):
```
ChessLab
```

**Subtitle** (30 char. max — 23 used):
```
Play, analyze, improve.
```

**Keywords** (100 char. max — 92 used):
```
stockfish,tactics,openings,puzzle,gambit,fen,pgn,elo,training,scanner,analysis,offline,board
```

**Promotional text** (170 char. max):
```
Analyze your games, scan a chessboard: 58 openings, 77 proven endgames,
100,000+ puzzles, the computer to beat — fully offline, no ads.
```

**Description** (4000 char. max):
```
ChessLab is a complete chess companion for iPhone and iPad: play, analyze,
train and experiment, with the Stockfish engine built in and without ever
leaving the app.

PLAY VS STOCKFISH
Take on Stockfish at any strength you like, from beginner (~900 Elo) to
maximum (~3190 Elo), with or without a clock. Hints, a warning before risky
moves, and an evaluation bar can all be toggled on demand.

TWO PLAYERS
Play locally on the same device, with a "pass-and-play" mode that flips the
pieces so both players read the board comfortably.

ANALYZE
Run a game or a position through Stockfish: move-by-move classification
(inaccuracy, mistake, blunder, brilliant move…), an evaluation graph, best-
move and opponent-threat arrows, and auto-play through the moves. Import by
PGN, FEN, position editor, or photo scanner.

OPENINGS
Pick an opening and step through it move by move: every move is explained,
the alternatives are offered, and colored arrows link the board to the move
list. 58 hand-written openings (bilingual), all reviewed by the engine, with
simplified spaced-repetition training to memorize them.

THE ENDGAME CORNER
77 courses proven by endgame tablebases — the exact mathematical verdict:
no taught move gives up a win, no recommended defence loses a draw. Nine
families, from the opposition to famous studies. And free training: finish
the position against best defence, where any move that preserves the
verdict is accepted — not just the lesson's move.

YOUR OWN REPERTOIRES
Import your openings as PGN, variations included, and drill them with the same
system. Share a repertoire as a single file — no account, no server. What you
already know about a position counts right away in the imported repertoire.

PUZZLES
Over 100,000 tactics puzzles from the Lichess database, filterable by
rating and theme, plus puzzles generated automatically from your own
mistakes in analysis. Spaced repetition and progress tracking included.

LABORATORY
Pit two Stockfish configurations against each other over a series of games
to compare their strength, with an estimated Elo gap and confidence
interval.

EDITOR AND SCANNER
Set up a position by hand, or scan it from a screenshot or a photo — review
and correct the recognized position before playing or analyzing it.

BUILT FOR IPAD
Full-size board with move list, graph and MultiPV visible at once, keyboard
and trackpad support, polished portrait and landscape layouts.

iCLOUD SYNC (optional)
Turn on iCloud sync in Settings so your games follow you across all your
devices, via your private iCloud. No account to create, no ChessLab server.
Off by default: the app works fully offline.

PRIVACY
Offline by default: no ChessLab server, no analytics, no ads. Your games
and settings stay on your device. iCloud sync, if you enable it, uses your
own private iCloud — your data is never shared with the developer. Fully
bilingual, French and English.

ChessLab embeds the Stockfish engine (GPLv3 license) and free vector piece
sets — cburnett (GPLv2+/CC BY-SA), chessnut (Apache 2.0) and merida
(GPLv2+). Full source code and license notices are available from within
the app (Settings → Licenses).
```

---

## Champs communs (indépendants de la langue)

- **Catégorie principale** : Jeux (Games)
- **Sous-catégorie** : Plateau (Board)
- **Catégorie secondaire** (optionnel) : Éducation
- **Copyright** : `© 2026 Thierry Maeder`
  — déduit du certificat de signature local (« Apple Development: Thierry
  Maeder (N982QZWW97) »), qui indique un compte individuel. À vérifier
  contre developer.apple.com/account ▸ Membership pour l'orthographe
  exacte avant de coller.
- **URL du support** : `https://thmaed.github.io/ChessLab/support.html`
  (page déposée dans `docs/support.html`, publique — reste à activer GitHub
  Pages pour qu'elle soit servie, voir `README.md`). En repli immédiat, le
  temps d'activer Pages : `https://github.com/thmaed/ChessLab/issues`.
- **URL marketing** (optionnel) : `https://github.com/thmaed/ChessLab`
- **URL de la politique de confidentialité** : `https://thmaed.github.io/ChessLab/privacy-policy.html`
  (page déposée dans `docs/privacy-policy.html`, publique — même remarque
  sur l'activation de GitHub Pages).
- **Coordonnées de contact** (non publiques, pour Apple uniquement) : nom,
  adresse, téléphone, email valides — à renseigner dans App Store Connect.

### Export compliance (chiffrement)
`INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` est déjà réglé dans le
projet. L'app n'implémente aucune cryptographie propre. La seule activité
réseau possible, la synchronisation iCloud (optionnelle, désactivée par
défaut), passe par CloudKit — chiffrement standard fourni par le système
Apple, donc **exempté** au sens de l'export compliance. Si App Store Connect
pose la question : aucune cryptographie propriétaire, exempté.

### App Privacy (étiquette de confidentialité)
Réponse à la question « Collectez-vous des données ? » : **Non**.
Aucun SDK tiers d'analytics, de publicité ou de suivi n'est intégré (les
seules dépendances tierces sont ChessKit et le moteur Stockfish vendorisé,
qui tournent entièrement localement). Le champ « scan de l'appareil
photo » sert uniquement à la reconnaissance locale d'une position, jamais à
un envoi réseau. La synchronisation iCloud (optionnelle) stocke les données
dans l'iCloud **privé** de l'utilisateur (base CloudKit privée), à laquelle
le développeur n'a aucun accès : Apple ne considère pas cela comme une
collecte de données par le développeur. Résultat attendu dans le
questionnaire App Store Connect : « Data Not Collected » pour toutes les
catégories.

### Classification par âge
Le nouveau questionnaire d'âge (contenu, pas de violence, pas de contenu
généré par les utilisateurs partagé publiquement, pas de jeu d'argent, pas
d'accès web non restreint) doit répondre « aucun » partout → note **4+**.

### App Accessibility (App Information ▸ Accessibility)
Réponses déduites du code (vérifié, pas deviné) :
- **VoiceOver** : Oui — `accessibilityLabel`/`Value`/`Hint` sur 17 fichiers,
  coups annoncés en SAN.
- **Larger Text** (Dynamic Type) : Oui — quasi tous les textes utilisent
  des styles sémantiques (`.body`, `.headline`…), réactifs par défaut.
- **Reduced Motion** : Oui — `accessibilityReduceMotion` géré dans
  `Theme.swift` et `ChessBoardView.swift`.
- **Dark Interface** : Oui — l'app est en sombre forcé partout
  (`.preferredColorScheme(.dark)`).
- **Sufficient Contrast** : probablement oui (texte blanc sur fond très
  sombre), mais pas d'audit WCAG automatisé fait — à confirmer visuellement
  avant de cocher.
- **Voice Control** : aucune adaptation spécifique trouvée dans le code —
  ne cocher que si testé manuellement sur appareil.
- **Captions** : non applicable, pas de contenu audio/vidéo narratif.

### Version et build

**1.5.0, build 7** — nouveautés détaillées dans `RELEASE_NOTES-1.5.0.md`, et
le texte prêt à coller est la section « Nouveautés de cette version » en haut
de ce fichier.

Vérifié dans `ChessLab.xcodeproj/project.pbxproj` (19/08/2026) : la cible
applicative (`com.chesslab.ChessLab`) porte bien `MARKETING_VERSION = 1.5.0`
et `CURRENT_PROJECT_VERSION = 7` **aux deux configurations**, Debug et
Release.

⚠️ **Ni la 1.3 ni la 1.4 n'ont été soumises.** Le dernier build envoyé à
Apple reste le build 3 de la 1.2 (commit `a211763`). Le build 5 / 1.3.0 puis
le build 6 / 1.4.0 ont été préparés puis dépassés par le rythme du
développement ; on saute directement à la 1.5. Les nouveautés des 1.3 ET 1.4
sont donc annoncées dans le texte « Nouveautés » de la 1.5 — sans quoi
personne ne les verrait jamais.

Les cibles de TEST (`ChessLabTests`, `ChessLabUITests`) sont restées en
`1.2.0` / build 3. **Sans effet sur la soumission** : leurs bundles ne sont pas
livrés. À aligner un jour par propreté, pas avant d'expédier.

Incrémenter `CURRENT_PROJECT_VERSION` à chaque nouveau build renvoyé à Apple,
même version marketing.

### ⚠️ À FAIRE AVANT DE SOUMETTRE — pousser le code source

Les notes réviseurs (plus bas) affirment que « the complete source code of the
app — **matching this submitted build** — is published publicly at
github.com/thmaed/ChessLab ». Ce n'est pas une formule de style : Stockfish
étant GPLv3, le binaire ChessLab est une œuvre dérivée GPLv3, et la
publication du code correspondant est une **obligation de licence**, pas un
argument commercial.

Vérifier donc, juste avant d'archiver :

```
git status -sb        # doit indiquer 'main...origin/main' sans 'ahead'
git push origin main
```

Au 19/08/2026, `main` est poussé au fil de l'eau (la nuit de travail du
18-19/08 a été poussée commit par commit). Vérifier malgré tout au moment de
soumettre (`git log --oneline origin/main..HEAD | wc -l` doit rendre 0) :
soumettre sans pousser publierait un binaire dont les sources annoncées ne
correspondent pas.

### Historique des versions
- **1.5.0** — module Finales (77 cours prouvés par tablebase, 9 familles),
  entraînement libre arbitré au verdict, correctif majeur iOS 18, ~900
  positions ajoutées aux ouvertures, verdicts d'analyse affinés, sélecteur
  « Changer de mode » avec reprise de position, Stockfish 17.1
  (`RELEASE_NOTES-1.5.0.md` — couvre 1.2 → 1.5).
- **1.4.0** — préparée, **jamais soumise** : répertoires d'ouvertures
  personnels (import PGN + partage par fichier), les 58 ouvertures relues au
  moteur, un seul essai par puzzle, lecteur d'ouvertures à plateau ancré
  (`RELEASE_NOTES-1.4.0.md`, conservé comme document historique). Son contenu
  est livré avec la 1.5.
- **1.3.0** — préparée, **jamais soumise** : échiquier tolérant au doigt, score
  de précision recalibré, revue d'analyse fiabilisée, iPhone en portrait. Son
  contenu est livré avec la 1.4 ; aucune note de version distincte n'a été
  rédigée.
- **1.2.0** — Ouvertures repensées, interface iPad/Mac, synchro iCloud
  (`RELEASE_NOTES-1.2.0.md`, regroupe 1.0.2 et 1.1.0).

---

## App Review Notes (paste into App Store Connect → App Review Information → Notes)

English, for the Apple reviewer. Frames the app's value proposition (six
advanced modes, entirely free), then explains the camera permission, the
network call, the licensing situation (GPLv3 engine, public source), and
that no login/test account is needed.

```
ChessLab's purpose is to offer an extensive set of advanced chess features
— entirely free, with no paywall, no ads, and no in-app purchases. That is
the app's core value: depth and quality normally found in paid or
subscription chess apps, given away for free as a passion project. It
bundles six modes:

1. Play vs the computer (powered by the embedded Stockfish engine) —
   adjustable strength (Elo ~900 to ~3190), clocks, hints, risky-move
   warnings, opening book.
2. Two Players — local pass-and-play on a single device.
3. Analyze — full game/position analysis with Stockfish: move-by-move
   classification, evaluation graph, best-move/threat arrows.
4. Openings — 58 hand-written, annotated openings; step through each one
   move by move, with variations and simplified spaced-repetition training.
5. Puzzles — over 100,000 tactics puzzles from the Lichess database, plus
   puzzles auto-generated from the user's own mistakes in Analyze.
6. Laboratory — engine-vs-engine testing to compare Stockfish
   configurations over a series of games.

There is no account, no server, no login — nothing to set up before
reviewing.

CAMERA: the Scanner feature uses the camera only to photograph a chess
diagram (a screenshot or a physical board from above) and reconstruct the
position with on-device image recognition. Photos are processed entirely
on-device and are never uploaded anywhere. If testing on Simulator (no
camera), use the "Paste" entry in the Scanner screen with any chess
diagram image copied to the clipboard, or the "Import a file" entry
(visible on Mac Catalyst) — both skip the camera and exercise the same
recognition pipeline.

NETWORK: ChessLab has no first-party or third-party backend — no ChessLab
server, no API, no analytics, no ads. The ONLY network activity is an
optional iCloud sync, which is OFF by default. When a user turns it on
(Settings → Sync), SwiftData/CloudKit syncs their own data — saved games,
puzzle progress, and opening-training progress — through the user's OWN
private iCloud database (CloudKit private database). The bundled content
(the 100,000+ puzzle library and the 58 opening courses) stays local and is
never synced. No data is shared with the developer, so the App Privacy answer
remains "Data Not Collected". With sync disabled — the default — the app
makes no network calls at all.

ENGINE LICENSE (GPLv3): ChessLab embeds the Stockfish chess engine,
compiled from its own sources and bundled directly into the app (with ARM
NEON optimizations). Because Stockfish is GPLv3, the ChessLab binary as a
whole is a GPLv3 derivative work. To comply, the complete source code of the
app — matching this submitted build — is published publicly at
https://github.com/thmaed/ChessLab. Copyright and license notices for all
third-party components (Stockfish/GPLv3, ChessKit/MIT, the chess piece sets
cburnett/GPLv2+ & CC BY-SA 3.0,
chessnut/Apache 2.0 and merida/GPLv2+, the Lichess puzzle database/CC0) are
also shown in-app under Settings → Licenses. All embedded piece sets are
free/open-source and license-compatible with the app's GPLv3.

No in-app purchases, no ads, no user-generated content shared publicly,
no multiplayer/online play.
```
