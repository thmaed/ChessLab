# Revue de code du 18 août — propositions à arbitrer

*Revue approfondie démarrée le 17/08 à 23 h 15 comme demandé. Ce fichier ne
contient QUE ce qui mérite ton arbitrage : tout ce qui était sûr a été corrigé
directement (voir les commits de la nuit). Trié par importance.*

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

## 2. File de révision : le compte promet ce que la séance ne sert pas

**Constat.** Le compteur « Réviser aujourd'hui » (Ouvertures ET Finales)
compte TOUTES les positions dues. Mais la séance quotidienne, elle, se limite
aux cours marqués au répertoire dès qu'il y en a un seul. Un utilisateur qui a
mis 3 ouvertures au répertoire et entraîné la Lucena verra « 12 à revoir »,
lancera la séance… et les positions de finales dues n'y seront jamais servies.
Préexistant, mais AMPLIFIÉ par le module Finales (on entraîne une finale sans
penser à l'« étoiler »).

**Proposition** : soit compter uniquement les positions servables (cohérent
mais le chiffre baisse « mystérieusement »), soit inclure TOUJOURS les cours
où l'utilisateur a de la progression, répertoire ou pas (mon préféré : on
révise ce qu'on a appris, l'étoile ne devrait filtrer que les cours jamais
travaillés). Changement de comportement → ta décision.

## 3. Corruption du store SwiftData : destruction silencieuse

**Constat** (`ChessLabApp.makeContainer`). Si le store local ne s'ouvre pas au
lancement (migration interrompue, corruption… ou simple DISQUE PLEIN), l'app
le DÉTRUIT et repart de zéro : parties, répertoires personnels et progression
locale perdus sans un mot. Le choix est documenté (« plutôt qu'une boucle de
crash ») et la synchro iCloud atténue — mais un disque plein est un état
TRANSITOIRE : détruire pour ça est disproportionné.

**Proposition** : renommer le store en `Games.corrupt-2026…` au lieu de le
supprimer (récupérable au support), et ne détruire qu'après échec sur un
DEUXIÈME lancement. Touche au démarrage → pas fait sans ton feu vert.

## 4. Vingt-et-un `try? context.save()` silencieux

**Constat.** Les sauvegardes SwiftData avalent leurs erreurs partout (21
sites). Un disque plein ou un conflit CloudKit passe inaperçu : l'utilisateur
croit sa partie enregistrée. Aucun bug constaté — c'est le silence qui est le
défaut.

**Proposition** : un petit `PersistenceLog.save(context, origin:)` central qui
tente, journalise l'échec (os_log) et lève une bannière discrète à partir du
2e échec consécutif. Mécanique, mais 21 sites → je préfère ton accord sur le
principe avant de toucher à toutes les écritures.

## 5. Le PDF de Nils porte encore les chiffres optimistes

**Constat.** L'étude du 18/08 a corrigé le résidu d'affinage (1,92 % réel
contre 0,68 % annoncé — l'ancien calcul supposait qu'un coup recalculé était
corrigé). Le code est corrigé, `AppStoreSubmission/ChessLab-analyse-moteur.pdf`
non.

**Proposition** : régénérer le PDF avec la section corrigée AVANT de
l'envoyer à Nils (10 min, scripts prêts). Pas fait cette nuit : tu as
peut-être déjà envoyé la version actuelle, auquel cas mieux vaut un erratum
qu'une substitution silencieuse — dis-moi.

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
