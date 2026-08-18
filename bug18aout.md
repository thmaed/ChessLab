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

## 1. Flux « Explorateur » mort — le brief pour décider (détaillé le 18/08)

**L'inventaire exact, mesuré.** Il y a en réalité DEUX sous-flux morts, pas
un :

| Sous-flux | Écrans | Lignes | Atteignable ? |
|---|---|---|---|
| Explorateur → Explorer → Apprendre | `OpeningCoursePickerView` (181), `OpeningExplorerView` (278), `OpeningLearnView` (259) | ~720 + hôtes/routes | Non — personne ne pousse `openingExplorerPicker` |
| Ancienne bibliothèque de lignes | `OpeningLibraryView`, `OpeningLineTrainingView` | ~400 + hôtes/routes | Non — personne ne pousse `activeOpeningLine` |

**Ce qui doit RESTER quoi qu'on décide** (partagé avec le flux vivant) :
`OpeningExplorerViewModel.apply(uci:to:)` sert au lecteur ET à l'entraîneur ;
`OpeningLearnViewModel.mainLine(of:)` sert à la file d'entraînement. Le reste
de ces deux view models (~350 lignes) ne sert qu'aux écrans morts.

**Ce que les écrans morts ont d'unique** : « Continuer contre Stockfish »
depuis une position de cours — jouer la suite de la ligne contre le moteur,
à SA force réglée. Le lecteur vivant ne l'offre pas, et c'est objectivement
une bonne idée pédagogique (surtout pour les FINALES : lire la Lucena puis la
GAGNER contre Stockfish, c'est le vrai test).

### Option A — Supprimer, en sauvant l'idée (ma recommandation)

1. Porter « Continuer contre Stockfish » dans le LECTEUR (bouton de barre :
   la position courante part vers `Route.continueVsStockfish`, l'écran de
   réglages existe déjà) — ~30 lignes, gros gain pour les finales.
2. Extraire `mainLine(of:)` vers `OpeningTrainingQueue`, garder
   `OpeningExplorerViewModel` (partagé).
3. Supprimer les 4 écrans morts, leurs hôtes et leurs 5 routes.

Bilan : **≈ −1 300 lignes**, une fonctionnalité sauvée et mise là où les
utilisateurs passent, plus aucun écran fantôme à maintenir (ils ont déjà
coûté deux correctifs « au cas où » cette semaine).

### Option B — Réanimer l'Explorateur

Rebrancher le sélecteur depuis Ouvertures (bouton boussole) et assumer DEUX
façons d'apprendre le même cours (lecteur guidé + explorateur libre).
Coût : 1-2 jours de réconciliation UX, et le risque de confusion que la
simplification de l'app (ta demande d'hier) cherchait justement à éviter.

### Option C — Statu quo

Garder le code mort. Coût récurrent démontré : chaque évolution du modèle
doit maintenir des écrans invisibles (le champ `kind` d'hier, le filtre
d'avant-hier).

**Ma recommandation : A.** Un mot de toi (« A », « B » ou « C ») et je
l'exécute.

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

## 7. ✅ FAIT (arbitré le 18/08) — Import de gros PGN en tâche de fond

**Constat.** « Coller un PGN » et « Importer des parties » parsent et
dédupliquent sur le MainActor. Neuf parties : imperceptible. Une base de
5 000 parties collée ou importée : interface figée plusieurs secondes
(découpage + signature anti-doublons par partie). Aucun crash — juste un gel.

**Arbitré et implémenté** : `importPGNCollection(text:container:onProgress:)`
travaille détaché sur un contexte propre (même conteneur) ; les fichiers sont
lus AVANT le détachement (portée sécurité). Les trois points d'appel sont
asynchrones — la bibliothèque affiche « Import : X/Y parties… » en capsule
bas d'écran, et « coller + ajouter » ouvre l'analyse sans attendre le
rangement. 18 tests d'import verts.

## Corrigé directement cette nuit (pour mémoire)

- Analyse depuis la bibliothèque : plateau vide (« Aucun coup joué ») —
  `Game(pgn:)` brut contourné le blindage de `PGNLoader` sur CINQ points
  d'entrée ; invariant verrouillé par test de source.
- Persistance des analyses sur l'appareil (ta demande du soir).
- Pastilles des moments critiques sur la courbe d'évaluation (idem).
- Garde anti-double-affinage + arrêt anticipé (étude validée par toi).
- Réglages : texte pointant vers le bouton « Explorateur » disparu.
- Sélecteur de l'Explorateur : les finales n'y fuient plus.
