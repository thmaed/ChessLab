# Revue de code du 18 août — propositions à arbitrer

*Revue approfondie menée en deux passes dans la nuit du 17 au 18/08. Passe 1
(23 h 15) : constructions à crash, concurrence, cycles de vie, intégration
Finales, textes périmés, clés UserDefaults, erreurs avalées. Passe 2 (minuit) :
pendule, puzzles, lecteur d'ouvertures, scanner, et une passe statique —
ZÉRO avertissement compilateur dans le code de l'app. La porte de régression
(suite complète, unitaires + 64 UI) est verte.*

*Ce fichier ne contient QUE ce qui mérite ton arbitrage : tout ce qui était
sûr a été corrigé directement (voir les commits de la nuit). Trié par
importance.*

---

## 1. Le flux « Explorateur » d'ouvertures est mort — le supprimer ?

**Constat.** Personne ne pousse la route `openingExplorerPicker` : tout le
sous-flux Explorateur → Explorer → Apprendre (3 routes, 3 hôtes,
`OpeningCoursePickerView`, `OpeningExplorerView`, `OpeningLearnView`,
~1 500 lignes avec leurs view models) est inatteignable depuis l'interface.
Le commentaire de `HomeView` le dit d'ailleurs : « l'ancien Explorer/Apprendre
reste défini mais n'est plus atteint depuis le flux principal ».

**Déjà corrigé (sûr)** : le texte des Réglages qui envoyait l'utilisateur vers
le bouton « Explorateur (🧭) » — un bouton qui n'existe plus ; et le filtre
des finales dans le sélecteur, au cas où le flux serait ranimé.

**Proposition (à arbitrer)** : supprimer le sous-flux entier, OU le rebrancher
quelque part. « Continuer contre Stockfish » depuis `OpeningLearnView` est une
fonctionnalité que le lecteur actuel n'offre pas — si tu y tiens, elle
mériterait d'être portée dans le lecteur plutôt que de garder trois écrans
morts. Je n'ai pas tranché seul : c'est 1 500 lignes et un choix de produit.

## 2. ✅ FAIT (arbitré le 18/08 au matin) — File de révision

**Constat.** Le compteur « Réviser aujourd'hui » (Ouvertures ET Finales)
compte TOUTES les positions dues. Mais la séance quotidienne, elle, se limite
aux cours marqués au répertoire dès qu'il y en a un seul. Un utilisateur qui a
mis 3 ouvertures au répertoire et entraîné la Lucena verra « 12 à revoir »,
lancera la séance… et les positions de finales dues n'y seront jamais servies.
Préexistant, mais AMPLIFIÉ par le module Finales (on entraîne une finale sans
penser à l'« étoiler »).

**Arbitré et implémenté** (commit `a0e869d`) : la progression prime sur
l'étoile — `reviewableCourses(in:)`, deux tests. Résidu marginal noté au
commit : une position d'un répertoire personnel SUPPRIMÉ reste comptée.

## 3. ✅ FAIT (arbitré le 18/08 au matin) — Corruption du store

**Constat** (`ChessLabApp.makeContainer`). Si le store local ne s'ouvre pas au
lancement (migration interrompue, corruption… ou simple DISQUE PLEIN), l'app
le DÉTRUIT et repart de zéro : parties, répertoires personnels et progression
locale perdus sans un mot. Le choix est documenté (« plutôt qu'une boucle de
crash ») et la synchro iCloud atténue — mais un disque plein est un état
TRANSITOIRE : détruire pour ça est disproportionné.

**Arbitré et implémenté** : premier échec → on ne touche à RIEN, session en
mémoire (bannière l'avoue) ; deuxième échec consécutif → QUARANTAINE horodatée
dans Application Support/StoreQuarantine (jamais de suppression, rotation à
deux), puis store neuf. Compteur `container.openFailures` remis à zéro au
premier succès.

## 4. ✅ FAIT (arbitré le 18/08 au matin) — Sauvegardes silencieuses

**Constat.** Les sauvegardes SwiftData avalent leurs erreurs partout (21
sites). Un disque plein ou un conflit CloudKit passe inaperçu : l'utilisateur
croit sa partie enregistrée. Aucun bug constaté — c'est le silence qui est le
défaut.

**Arbitré et implémenté** : `PersistenceLog.save(_:origin:)` (os_log, compteur
d'échecs consécutifs) remplace les 21 sites ; variante de fond pour le seeder
(le succès de fond ne blanchit pas l'ardoise) ; bannière d'accueil à partir du
2e échec — la même qui avoue la session en mémoire du §3. Trois tests.

## 5. ✅ RÉGLÉ (18/08) — Le PDF de Nils est supprimé

Tu as tranché : plus utile. `AppStoreSubmission/ChessLab-analyse-moteur.pdf`
est retiré du dépôt (l'historique git le garde si besoin). Les chiffres
honnêtes (1,92 %) restent documentés dans le code et dans
`docs/ETUDE-AFFINAGE-TROIS-NIVEAUX.md`.

## 6. L'arrêt anticipé mérite une mesure SUR APPAREIL

**Constat.** La garde anti-double-paiement et l'arrêt anticipé sont en place
(commit `d5801e5`), avec leurs tests. Les gains (×2,73 → ≈ ×2,2, moitié moins
d'arrêts longs) sont PROJETÉS depuis les données du banc — la règle réelle
(2 transitions stables) est plus conservatrice que le proxy mesuré (47 %
d'arrêts). À vérifier sur ton iPhone à l'usage ; si les arrêts longs restent
gênants, le levier suivant est `stableTransitionsRequired: 2 → 1` (je ne l'ai
pas fait : conservateur d'abord).

## 7. Import d'un très gros PGN : tout se fait sur le fil principal

**Constat.** « Coller un PGN » et « Importer des parties » parsent et
dédupliquent sur le MainActor. Neuf parties : imperceptible. Une base de
5 000 parties collée ou importée : interface figée plusieurs secondes
(découpage + signature anti-doublons par partie). Aucun crash — juste un gel.

**Proposition** : passer `importPGNCollection` en tâche de fond avec un
indicateur de progression (la bannière « Préparation de la bibliothèque… » de
l'accueil existe déjà pour les puzzles, même patron). Non fait : toucher au
threading d'un import qui marche mérite ton accord et une passe de tests
dédiée.

## Corrigé directement cette nuit (pour mémoire)

- Analyse depuis la bibliothèque : plateau vide (« Aucun coup joué ») —
  `Game(pgn:)` brut contourné le blindage de `PGNLoader` sur CINQ points
  d'entrée ; invariant verrouillé par test de source.
- Persistance des analyses sur l'appareil (ta demande du soir).
- Pastilles des moments critiques sur la courbe d'évaluation (idem).
- Garde anti-double-affinage + arrêt anticipé (étude validée par toi).
- Réglages : texte pointant vers le bouton « Explorateur » disparu.
- Sélecteur de l'Explorateur : les finales n'y fuient plus.
