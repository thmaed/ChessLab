# ChessLab — Roadmap 1.2 → 2.0 (révisée 22/07/2026)

## Principe directeur, non négociable

ChessLab reste **100 % autonome, sans compte ni serveur** : aucune
fonctionnalité de cette roadmap ne doit rendre une connexion Internet
nécessaire au fonctionnement normal de l'app. C'est déjà l'état actuel —
l'import Lichess a été retiré en juillet 2026 précisément pour ça, et l'app
ne fait plus aucun appel réseau. Toute idée qui romprait ce principe (compte
utilisateur, backend, tracking) est explicitement hors périmètre.

## Fil conducteur de cette révision

Trois constats guident le découpage :

1. **Le manque nº 1 n'est pas un module de plus, c'est le retour sur
   progression.** Tout est déjà mesuré et persisté (résultats contre
   Stockfish avec Elo par partie dans `GameRecord`, réussite par thème dans
   `PuzzleStats`, précision d'analyse) mais rien n'est restitué à
   l'utilisateur dans la durée. C'est aussi ce qui manque à l'accueil iPad,
   à moitié vide (constaté par capture le 22/07/2026) : les deux problèmes
   ont la même solution.
2. **Le scanner est LE différenciateur** face aux apps concurrentes — un
   nouveau modèle YOLO (71 jeux de pièces, 16 thèmes de plateau, 17 000
   images) est en cours d'entraînement ; il faut le livrer, le MESURER
   honnêtement, puis viser le plateau physique photographié en angle.
3. **Les finales sont le grand absent pédagogique** — et contrairement à
   l'idée reçue, un entraîneur de finales EXACT ne demande pas 1 Go de
   tables Syzygy : une bitbase Roi+Pion contre Roi tient en quelques
   dizaines de Ko.

Effort indicatif par item : **[S]** quelques heures, **[M]** quelques
jours, **[L]** semaine(s).

---

## 1.1 — livré (juillet 2026)

- Crash à la sortie de l'Analyse corrigé (libération du moteur).
- Écran « Diagnostic moteur » retiré ; section « Contactez le développeur »
  dans l'Aide.
- Accueil iPad, 1re passe : grille 3 colonnes, tuiles agrandies, fond
  d'ambiance recalibré à la taille d'écran.
- Code mort du répertoire personnel supprimé (décision : ne sera jamais
  réactivé — la bibliothèque ECO et l'entraînement par ligne, eux, restent).

## 1.2 — scanner v2 + consolidation

Livrer le fruit de l'entraînement en cours, et fermer ce qui traîne.

- **[S] Intégrer le nouveau modèle YOLO** (entraînement 40 epochs en cours) :
  remplacer `ChessPiecesYOLO.mlpackage`, passer les fixtures, comparer à
  l'ancien sur les mêmes captures.
- **[M] Mesure de généralisation honnête** : ré-entraîner en EXCLUANT
  quelques jeux de pièces, générer un set de validation avec eux seuls, et
  publier la mAP sur ces jeux jamais vus. C'est le seul chiffre qui dit si
  le modèle a appris des formes ou mémorisé des rendus (déjà identifié dans
  `scripts/yolo/README.md` comme la seule mesure fiable).
- **[S] Fixtures réelles** : déposer de vraies captures variées dans
  `ChessLabTests/ScannerFixtures/` (autres jeux que cburnett, milieu de
  partie dense, les deux orientations) — action utilisateur, bloquante pour
  valider sérieusement le point précédent.
- **[S] Stabiliser `ScannerFlowUITests`** (tap sur un bouton de promotion
  introuvable par intermittence).
- **[M] Passe Instruments** sur appareil physique (fuites, pics CPU) — seul
  reste non automatisé du plan final-1407.

## 1.3 — progression & accueil (le cœur de cette révision)

Un seul chantier à deux visages : restituer la progression, et s'en servir
pour finir l'accueil iPad.

- **[M] Tableau de bord « Progression »** : évolution du niveau aux puzzles
  dans le temps, réussite par thème tactique (déjà dans `PuzzleStats`),
  bilan contre Stockfish par palier d'Elo (déjà dans `GameRecord` :
  `engineEloApprox`, résultat, date), précision moyenne en analyse,
  lignes d'ouverture parcourues. AUCUNE nouvelle collecte : uniquement de
  l'agrégation de ce qui est déjà en base SwiftData.
- **[M] Accueil iPad à deux zones (option C, suite logique de la passe
  1.1)** : en classe régulière, colonne gauche = les 6 modes ; colonne
  droite = reprise de partie, parties récentes, et les tuiles du tableau de
  bord ci-dessus. C'est LE contenu qui manquait à la moitié basse de
  l'écran — pas du remplissage décoratif.
- **[S] Suggestion de travail** : depuis le tableau de bord, un bouton
  « Travailler ce thème » sur le thème tactique le plus faible lance
  directement une session de puzzles filtrée (le filtre existe déjà).
- **[S] Bilan hebdomadaire local** : une carte « Votre semaine » (parties
  jouées, puzzles résolus, tendance) calculée à l'ouverture — aucune
  notification, aucun réseau, juste une synthèse quand on revient.

## 1.4 — entraînement : trois modes nouveaux, tous sur l'existant

- **[M] Puzzle Rush** : série chronométrée (3 min / 5 min / survie à
  3 erreurs), filtrable par thème (`PuzzleTheme`, déjà taggé sur toute la
  bibliothèque). Meilleur score dans le tableau de bord de 1.3.
- **[M] Visualisation** : exercices de coach classiques — couleur d'une
  case nommée, retrouver une case, trajet du cavalier entre deux cases,
  chronométrés. Aucune dépendance de données ; excellent pour les
  débutants, public que le reste de l'app sert moins.
- **[S] Reconnaissance d'ouvertures** : flashcards « voici une position /
  une séquence — quelle famille ECO ? » sur les 149 familles déjà chargées
  (`EcoOpeningLoader`), à choix multiple.

## 1.5 — finales

Le grand absent pédagogique, en deux paliers dont le premier est bien plus
accessible qu'il n'y paraît :

- **[L] Entraîneur de finales exact, SANS Syzygy** : curriculum des
  fondamentaux — opposition, règle du carré, Roi+Pion contre Roi, mats de
  base (Dame, Tour, deux Fous). Le verdict EXACT sur R+P/R tient dans une
  bitbase de quelques dizaines de Ko (l'approche historique des moteurs,
  calculable une fois par script et embarquée comme n'importe quelle
  ressource) ; les mats de base se vérifient par la recherche de mat de
  Stockfish déjà embarqué. Chaque exercice peut donc dire « ce coup
  gâche la victoire » avec certitude, pas une éval approximative.
- **[M] Packs 4 pièces** (R+D/R+T contre défenses diverses) : à 4 pièces,
  les tables exactes ne pèsent que quelques Mo — embarquables sans débat.
  Le palier 5 pièces (~1 Go) reste HORS bundle : soit on y renonce, soit
  un pack optionnel téléchargé UNE fois à la demande explicite — à
  trancher le moment venu, le principe hors-ligne restant la règle (l'app
  ne doit jamais l'EXIGER).

## Transversal — petits gestes natifs, gros rendement [chacun S/M]

- **Widget « Puzzle du jour »** : WidgetKit fonctionne entièrement hors
  ligne (timeline précalculée depuis la base locale). Un mini-diagramme sur
  l'écran d'accueil qui s'ouvre sur le puzzle — le meilleur rappel d'usage
  possible sans la moindre notification ni réseau.
- **Raccourcis / App Intents** : « Analyser le presse-papiers » (PGN/FEN),
  « Puzzle rapide », « Reprendre la partie » — exposés à Spotlight et à
  l'app Raccourcis. Peu de code, grosse valeur pour les utilisateurs
  avancés.
- **Sauvegarde/restauration locale** : exporter TOUT (parties, progression
  puzzles, réglages) dans un fichier unique via la feuille de partage, et
  le réimporter — la migration d'appareil sans iCloud, cohérente avec le
  positionnement vie privée.

---

## 2.0 — les paris

- **[L] Scanner de plateau PHYSIQUE en angle** : aujourd'hui le scanner
  suppose une vue quasi zénithale. Le chemin : détection des 4 coins du
  plateau (un dataset public adapté existe, `surawut/chessboard-dataset-yolo`,
  CC-BY-4.0, ~3 700 images réelles annotées en keypoints — analysé le
  22/07/2026) → homographie → le pipeline existant prend le relais sur
  l'image redressée. C'est LE déblocage qui rend le scanner utile au club
  ou devant un livre + plateau réel.
- **[L] Scan vidéo continu** : une fois l'angle maîtrisé, passer de la
  photo unique au flux caméra (le pipeline reste 100 % embarqué). Vision à
  terme : suivre une partie réelle coup par coup en posant l'iPhone sur un
  trépied — ChessLab comme greffier de partie.
- **[M] Synchronisation iCloud optionnelle** (désactivée par défaut) : le
  point d'ancrage existe (`CloudSyncSettingsStore`, jamais branché).
  Continuité entre les appareils du même utilisateur via CloudKit — pas un
  compte applicatif, et jamais exigé pour fonctionner.
- **[L, exploratoire] Adversaire au style humain** : Stockfish bridé joue
  « mal comme une machine », pas comme un humain de 1400. Les modèles type
  Maia (issus de la recherche, entraînés sur des parties humaines par
  niveau) donnent des adversaires crédibles — mais exigent un moteur
  d'inférence de plus dans le bundle et une vérification de licence
  sérieuse. À prototyper avant de promettre.
- **Parcours pédagogiques thématiques** : leçons + puzzles séquencés (mats
  classiques, sacrifices types, finales de tours) au-dessus du contenu déjà
  embarqué — surtout un travail ÉDITORIAL, à ne lancer que si l'usage des
  modes d'entraînement de 1.4 le justifie.

---

## Écarté délibérément (avec date de décision)

- **Répertoire personnel** (22/07/2026) — supprimé du code après plusieurs
  semaines sans usage réel ; la bibliothèque ECO couvre le besoin.
- **Modèles YOLO tiers pré-entraînés** (22/07/2026) — cinq candidats
  analysés (Hugging Face/Roboflow) : datasets opaques ou minuscules,
  licences GPL contaminantes ou restrictives, aucune métrique publiée.
  Notre pipeline synthétique maison reste supérieur et maîtrisé.
- **Game Center** — classements/succès passeraient par l'identité Apple en
  ligne : en tension avec le positionnement « aucun compte, aucun
  classement, vos données restent chez vous », pour un gain faible sur une
  app solo.
- **Apple Watch** — pas de cas d'usage crédible pour un échiquier.
- **Compte utilisateur, multijoueur en ligne, publicité, télémétrie,
  import réseau (Lichess ou autre)** — contredisent le principe directeur.
