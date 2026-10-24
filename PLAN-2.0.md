# ChessLab 2.0 — « ChessLab apprend de vos parties »

Cadrage du 24/10/2026. Il porte sur les volets **A** (la boucle d'entraînement)
et **B** (le coach humain, Maia). Rien n'est commencé : ce document sert à
décider.

**La promesse en une phrase** : *chaque partie que vous jouez nourrit
automatiquement votre entraînement, et ChessLab vous dit où vous perdez des
points — comme un humain de votre niveau les perdrait.*

**Contraintes tenues** : aucun compte, aucun réseau, rien qui sorte de
l'appareil (le manifeste Android ne gagne pas la permission `INTERNET`) ; iOS
fait foi, Android suit dans le même chantier (`CLAUDE.md`) ; la 1.10 (ce qui
est déjà dans `main`) sort **avant** et séparément.

---

## 1. Ce qui existe déjà (relevé du code, 24/10)

| Brique | État |
|---|---|
| Analyse Stockfish d'une partie (classification, précision, explication) | Complète, **mais attachée à l'écran** : elle s'arrête quand on quitte `AnalysisView` |
| Cache d'analyse par coup (`AnalysisEvalStore`) | Fichiers JSON **locaux**, 300 max, clé = départ + coups |
| Métriques d'une partie (`GameRecord` : précision, perte moyenne, coups classés) | Écrites **seulement** quand on ouvre l'analyse ; **lues par personne** (ni Progression, ni bibliothèque) |
| Puzzles tirés des fautes, mats manqués | Livrés (1.10), déclenchés **à la main** |
| Répertoires personnels + FSRS par position | Complets, **sans** « cette position / ce coup est-il dans mon répertoire ? » |
| Maia : distribution **complète** des coups par niveau | Existe (`MaiaPolicy.candidates`), ~3 ms/position sur Mac ; sert aujourd'hui à **jouer**, pas à **expliquer** |
| Cote du joueur (puzzles ou niveau) | **Aucune** |
| Tâche de fond (`BGTaskScheduler`) | **Aucune** |
| Agrégat « à faire aujourd'hui » sur l'accueil | **Aucun** (des compteurs existent, dispersés) |
| Parties réelles avec cotes connues | **Aucune** dans le dépôt |

La conséquence principale : **le moteur de la 2.0 existe en pièces
détachées**. L'essentiel du travail est de les relier, et deux choses sont
vraiment neuves : l'analyse sans écran, et l'estimation du niveau.

---

## 2. Volet A — La boucle : jouer → comprendre → s'entraîner

### A1. Analyse automatique, sans écran *(fondation, bloque A2 à A5)*
Extraire de `AnalysisViewModel` un **service d'analyse** indépendant de l'écran
(file de parties à analyser, une à la fois, interruptible, reprise après
coupure), qui écrit le cache par coup et les métriques de la partie.
- Déclenchée à la fin d'une partie contre l'ordinateur, et pour les parties
  importées (à la demande, jamais en masse sans accord).
- **Le coût est réel** : environ 1 à 3 minutes pour une partie de 40 coups
  (estimation à confirmer), plus de chaleur et de batterie. Garde-fous déjà
  présents à réutiliser : facteur thermique, mode économie d'énergie, pas
  d'affinage à chaud.
- iOS : tâche en avant-plan d'abord ; `BGProcessingTask` ensuite, si l'essai
  montre que ça vaut la complexité. Android : même service, via un travail de
  fond (WorkManager) avec les mêmes garde-fous.
- **Réglage « Analyser mes parties automatiquement »** dans Réglages (à
  décider : activé par défaut ou non, voir §5).

### A2. Puzzles personnels automatiques
Quand une partie est analysée, ses erreurs et ses mats manqués deviennent des
puzzles « Mes parties », **sans que l'utilisateur ait à y penser**. Tout est
déjà écrit (génération 900 000 nœuds, mats manqués, dédoublonnage).
- Plafond par partie (par exemple 3) pour ne pas noyer : les plus coûteuses
  d'abord.
- Une pastille « 2 nouveaux puzzles de votre dernière partie » sur l'accueil.

### A3. Sorties de répertoire
Pendant l'analyse, comparer chaque coup du joueur aux **répertoires qu'il suit**
(`RepertoireMembership` + cours personnels) : « Coup 6 : vous avez quitté votre
répertoire (Cf6 au lieu de Fe7) ».
- Nouveau : une API `expectedMove(inRepertoire:, position:)` (clé de position
  normalisée, transpositions comprises — `OpeningFENKey` fait déjà le travail).
- Effet : la position fautive rejoint les **révisions FSRS** du répertoire. Ce
  qu'on a raté en partie est revu demain.
- Cas à trancher : on quitte la théorie *volontairement* (l'adversaire a dévié
  le premier) — ne pas le compter comme une faute.

### A4. Profil de faiblesses (Progression)
Aujourd'hui, Progression mesure vos **puzzles** par thème et vos résultats par
niveau d'adversaire. Elle ne dit rien de vos **parties**. La 2.0 ajoute :
- phase où vous perdez le plus de points (ouverture, milieu, finale) ;
- thèmes tactiques que vous manquez **en partie** (fourchettes, clouages…) ;
- précision par partie et tendance sur 10 parties ;
- ouvertures qui vous coûtent des points.
- **Décision de données** : stocker des agrégats **par partie** dans
  `GameRecord` (ajout additif, synchronisé par iCloud) plutôt que de relire les
  fichiers du cache local, qui ne voyagent pas et sont limités à 300.

### A5. « Séance du jour »
Un bouton sur l'accueil qui enchaîne : ouvertures dues → puzzles ratés →
puzzles tirés de vos parties → une finale. Avec une **série de jours
consécutifs**. Rien de neuf côté contenu : c'est un agrégateur, et c'est lui
qui rend la boucle **visible**.
- Durée visée : 10 à 15 minutes, réglable.
- Pas de notification en 2.0 (promesse « aucun réseau », et un rappel demande
  une permission de plus). À discuter.

---

## 3. Volet B — Le coach humain (Maia)

Idée directrice : le moteur dit ce qui est *parfait* ; Maia dit ce qu'un
joueur *de votre niveau* ferait. C'est l'avantage que n'a aucune app grand
public, et il tourne sur l'appareil.

### B1. Analyse « humaine »
Pour chaque coup d'une partie analysée, interroger Maia **au niveau du
joueur** :
- probabilité du coup joué parmi les coups possibles (« 4 % des joueurs de
  votre niveau jouent ce coup ») ;
- le coup qu'un humain de ce niveau trouverait le plus souvent, à côté du coup
  parfait du moteur ;
- **qualification de l'erreur** : *erreur typique* (beaucoup de joueurs de ce
  niveau la font — leçon à retenir) ou *accident* (rare — fatigue).
- Coût : ~3 ms par position sur Mac, donc une partie entière en moins d'une
  seconde ; sur téléphone Android mesuré 28 à 216 ms (facteur 7 entre deux
  lancements), donc quelques secondes — acceptable.
- Affichage : une ligne de plus dans l'explication d'un coup (« Coach »), pas
  un nouvel écran.
- **Attention** : Maia ne calcule pas (elle ne trouve jamais certains sacrifices
  profonds, mesuré). Ses probabilités disent *ce que les humains jouent*, pas
  *ce qui est bon*. L'écran doit le dire en une phrase.

### B2. Niveau estimé *(le volet risqué — voir §4)*
Estimer votre niveau sur l'échelle Lichess à partir de vos parties :
- **Méthode** : la *vraisemblance sous Maia* — pour un niveau N donné, quelle
  probabilité Maia donnait-elle aux coups que vous avez réellement joués ?
  Le niveau qui rend vos coups les plus probables est votre estimation. C'est
  la façon dont on mesure la « force de jeu humaine », et elle gagne en
  précision avec le nombre de coups.
- **Toujours une fourchette** (« environ 1500, entre 1400 et 1620 »), jamais un
  chiffre exact, avec le nombre de parties qui la fondent.
- Courbe de progression sur la durée (c'est le « effet 2.0 » : voir sa
  progression se dessiner).

### B3. Cote de puzzle personnelle et puzzles à votre niveau
- Une cote (Glicko simplifié) mise à jour à chaque puzzle, sur l'échelle des
  puzzles Lichess (déjà portée par `Puzzle.rating`).
- « Puzzles adaptés » : servis autour de votre cote, plutôt que tirés au hasard
  dans un palier large.
- Distincte de B2 (cote de **tactique** vs niveau de **partie**) — les deux se
  lisent côte à côte dans Progression.

### B4. Où ça vit dans l'interface
Pas de nouveau mode : B1 dans l'explication des coups, B2 et B3 dans
Progression, B3 dans le choix de séance des puzzles (un chip « À mon niveau »).

---

## 4. Risques — dits franchement

1. **L'estimation du niveau (B2) peut ne pas être fiable.** L'étude de
   calibration de l'été (`tools/elo-calibration/`) a **abandonné** une
   estimation de niveau à partir de parties : ±677 points sur une partie, ±214
   sur dix. La méthode du §B2 est meilleure (elle exploite chaque coup), mais
   **rien ne le prouve encore** : le dépôt ne contient **aucune partie avec une
   cote connue**. Il faut un jeu de parties réelles cotées (la base ouverte
   Lichess est sous CC0) pour **mesurer** la précision avant de promettre quoi
   que ce soit. → **essai technique S2, avant tout engagement**.
2. **L'analyse en arrière-plan (A1) peut décevoir sur batterie, chaleur ou
   temps.** Mesurer sur l'iPhone XS (le plus ancien) et le Galaxy A16 (entrée
   de gamme). → **essai S1**.
3. **L'analyse automatique peut ne pas aboutir si l'app est quittée.** iOS
   suspend les tâches de fond ; il faut accepter de la reprendre plus tard, et
   le dire (« analyse en attente »).
4. **Taille Android** : l'APK frôle déjà ~165 Mo, le plafond Google Play est à
   ~200 Mo sans livraison par fichiers de ressources. B n'ajoute **pas** de
   modèle (Maia est déjà embarquée), A non plus — à re-mesurer.
5. **iCloud** : les agrégats par partie (A4) et la cote (B3) sont de nouveaux
   champs synchronisés. Le **schéma CloudKit doit être déployé en production**
   avant la sortie, sinon rien ne voyage.
6. **Le volume de travail Android** : A1 et B1 doivent exister des **deux**
   côtés. Le service d'analyse Android passe par un travail de fond Android
   (autre mécanisme que BGTask) : à prévoir comme un lot à part entière.
7. **Le message** : « ChessLab apprend de vos parties » promet de la
   *personnalisation*. Si A2 déverse dix puzzles médiocres après chaque
   partie, c'est pire que rien. La qualité du filtrage (A2) décide de la
   perception.

---

## 4 bis. Résultat de l'essai S2 (24/10/2026) — niveau estimé par vraisemblance Maia

**Protocole.** 60 joueurs de la base ouverte Lichess (janvier 2013, parties
classées non bullet de 40 demi-coups et plus, cotes de 1271 à 2139), au moins
5 parties chacun ; pour chaque coup joué (hors 8 premiers coups de chaque camp),
probabilité sous Maia-3 23M à 14 niveaux de 700 à 2700 ; l'estimation est le
niveau qui rend les coups du joueur les plus probables. Erreur mesurée contre la
cote Lichess moyenne du joueur, sur 100 tirages de N parties par joueur.
Script : `tools/maia3-spike/s2_elo_estimate.py` (+ `s2_analyze.py`, résultats
bruts `s2_results.json`).

| Parties | Erreur moyenne | Écart-type | Dans ±100 | Dans ±200 |
|---:|---:|---:|---:|---:|
| 1 | 239 | 324 | 28 % | 53 % |
| 3 | 146 | 181 | 39 % | 73 % |
| **5** | **127** | **157** | **46 %** | **77 %** |
| 8 | 123 | 151 | 47 % | 77 % |

**Lecture.**
- **Bien meilleur que la méthode abandonnée** (±677 sur une partie, ±214 sur
  dix) : ici ±324 sur une partie, ±157 sur cinq.
- **Mais un plancher d'environ ±125** : au-delà de 5 parties, ajouter des
  parties n'améliore plus. Une partie de ce plancher vient de la mesure elle-même
  (la cote Lichess d'un joueur bouge d'une partie à l'autre), pas seulement de la
  méthode.
- **Un défaut de forme** : l'estimation s'écarte de la moyenne (biais de −66 pour
  les joueurs de 1300-1600, +75 pour 1600-1900). Échantillon trop petit (60
  joueurs, très peu aux extrémités) pour conclure à une correction.

**Verdict : GO conditionnel pour B2, en FOURCHETTE et non en chiffre.**
- Affichée seulement à partir de **5 parties analysées**, sous la forme
  « environ 1 500, entre 1 350 et 1 650 » (±150) ; avant : « pas assez de
  parties » avec un compteur.
- Jamais comme une cote de classement ; titre « Niveau estimé », phrase
  d'explication.
- **Limite non levée** : l'essai suppose connu le niveau de l'adversaire (sa
  cote Lichess). Contre un **personnage Maia**, c'est le cas (niveau consigné sur
  l'échelle Lichess) ; contre **Stockfish bridé**, l'échelle n'est pas
  comparable (étude du 05/09) : ces parties devront être exclues du calcul, ou
  comptées avec un niveau d'adversaire par défaut. À trancher.
- **Reste à faire pour fiabiliser** : relancer sur davantage de joueurs et un
  autre mois (2023, cotes actuelles) ; tester l'effet du retrait de l'ouverture
  (`--skip`) ; décider d'un éventuel étalonnage du biais.

---

## 4 ter. Résultat de l'essai S1 (24/10/2026) — analyse complète d'une partie

**Protocole.** Trois vraies parties de tournoi (`Fixtures_nils.pgn`), analysées
de bout en bout (classification de tous les coups, affinage des verdicts
limites, bilan) par le mode normal de l'app, sur le **Galaxy A16** (téléphone
d'entrée de gamme, branché en USB). Test :
`HeadlessAnalysisMeasureTest` (Android) et `HeadlessAnalysisMeasureTests`
(iOS, mesuré le même jour sur l'**iPhone XS**, le plus ancien appareil de la flotte).

| Partie | Demi-coups | Durée | Par demi-coup |
|---|---:|---:|---:|
| 28 coups | 55 | 63 s | 1,1 s |
| 52 coups | 104 | 158 s | 1,5 s |
| 66 coups | 131 | 252 s | 1,9 s |

**iPhone XS (iOS 18.7.9)** : 36 s (55 demi-coups, 0,66 s/demi-coup), 70 s (104,
0,67 s) et 126 s (131, 0,96 s), état thermique resté à « normal » — **deux fois
plus vite que le Galaxy A16**. iOS tient largement la barre ; c'est Android qui
dimensionne la fonction.

- **Une partie de 40 coups se classe en 1 à 3 minutes** sur un téléphone d'entrée
  de gamme (mon estimation de 1 à 3 minutes était juste). Les parties longues et
  tendues vont jusqu'à 4 minutes.
- **Chaleur** : +1,2 °C de la batterie sur la partie la plus longue, état
  thermique du système resté à « normal » : aucune bride sur ce volume.
- **Batterie** : NON mesurée (le téléphone était alimenté en USB). À mesurer sur
  batterie avant de rendre l'analyse automatique par défaut.

**Verdict : GO pour A1**, avec ces règles :
- analyse **proposée au premier lancement** (décision 24/10) et **arrêtable** ;
- une partie à la fois, avec une barre de progression honnête (« partie en cours
  d'analyse, environ 2 minutes ») ;
- **interrompue si l'app passe en arrière-plan sur iOS** (l'arrière-plan
  `BGProcessingTask` est un second temps, pas un prérequis) ;
- Android : un service de premier plan avec notification, mêmes garde-fous
  (thermique, économie d'énergie) ;
- plafond : ne pas analyser en masse l'historique à l'installation de la 2.0.

---

## 5. Décisions

**Tranchées le 24/10/2026** (« tout OK pour ta proposition ») :
1. Analyse automatique **proposée au premier lancement de la 2.0**, avec une
   phrase claire sur la batterie — pas de défaut silencieux.
2. B1 utilise le niveau saisi à la création d'une partie (`PlayerLevel`) tant
   que le niveau estimé n'existe pas.
3. **B2 ne sort que si l'essai S2 le valide.**
4. Pas de notification de rappel.
5. Noms : « Coach » (B1) et « Séance du jour » (A5).
6. Démarrage immédiat de **S1, S2 et B3**.
7. **Ajout du volet C** (revue de l'interface) — voir §8.

**Volet C, tranché le 24/10/2026 après l'audit** :
- premier lot **C1 + C2 + C3** lancé (tuiles d'accueil teintées, un seul style
  de titre, en-têtes de section colorés partout), maquette d'abord ;
- **identité sombre assumée** : pas de thème clair (C9 abandonné) ;
- **C4 : bouton d'action plein, teinté du mode, collé en bas** de chaque écran
  de réglage (Nouvelle partie, Deux joueurs, Laboratoire, Variantes).

Les points d'origine, pour mémoire :

1. **Analyse automatique : activée par défaut, ou à activer ?** Je recommande
   *à activer au premier lancement de la 2.0*, avec une phrase claire sur la
   batterie, plutôt qu'un défaut silencieux.
2. **Quelle source pour le niveau du joueur en B1 avant que B2 existe ?**
   `PlayerLevel` (le niveau saisi à la création d'une partie) existe déjà : je
   propose de l'utiliser, puis de passer au niveau estimé quand il sera fiable.
3. **B2 conditionnel** : acceptez-vous que le niveau estimé ne sorte **que si
   l'essai S2 le valide** ? Sinon la 2.0 sort avec B1 + B3 (cote de puzzle),
   qui valent seuls.
4. **Notification de rappel** pour la séance du jour : oui / non (non par
   défaut).
5. **Nom** : « Coach » pour B1 ? « Séance du jour » pour A5 ?

---

## 6. Découpage en lots et ordre

Essais techniques d'abord, parce qu'ils peuvent changer le périmètre :

| Lot | Contenu | Dépend de | Plateformes |
|---|---|---|---|
| **S1** | Essai : analyse sans écran, durée / chaleur / batterie | — | iPhone XS, Galaxy A16 |
| **S2** | Essai : estimer le niveau par vraisemblance Maia, sur parties cotées (Lichess CC0) ; mesurer l'erreur selon le nombre de parties | — | Mac (Python), puis les deux |
| **A1** | Service d'analyse sans écran + réglage — **FAIT 24/10** (avant-plan seulement) | S1 | iOS, Android |
| **A2** | Puzzles automatiques depuis les parties analysées | A1 | iOS, Android |
| **B1** | Analyse « humaine » (probabilité du coup, coup typique, erreur typique ou accident) | A1 | iOS, Android |
| **A3** | Sorties de répertoire → révisions FSRS | A1 | iOS, Android |
| **A4** | Profil de faiblesses (Progression) | A1 | iOS, Android |
| **B3** | Cote de puzzle personnelle + puzzles « à mon niveau » | — (indépendant) | iOS, Android |
| **B2** | Niveau estimé + courbe | S2, B1 | iOS, Android |
| **A5** | Séance du jour + série | A2, A3 | iOS, Android |
| **V** | Aide, nouveautés, captures, schéma CloudKit, soumissions | tout | iOS, Android |

| **C** | Revue de l'interface : menus modernisés, plus colorés et attractifs | audit, puis lots | iOS, Android |

**Chemin critique** : S1 → A1 → (A2 ‖ B1 ‖ A3 ‖ A4) → A5 → V. B3 peut avancer
dès maintenant, indépendamment, et c'est le meilleur premier lot : il est
**petit, sans risque, et déjà utile à la 1.10**.

**Ordre de livraison proposé** :
1. **S1 et S2 en parallèle** (quelques jours chacun) — ils décident du reste.
2. **B3** (cote de puzzle) pendant que S1/S2 mesurent.
3. **A1**, puis **A2 + B1** : c'est le premier moment où l'on *voit* la boucle.
4. **A3, A4, A5**, puis **B2** si S2 est concluant.
5. Vérification sur les deux téléphones, puis la 2.0.

**Ce qui ferait renoncer à une partie du plan** : si S1 montre qu'analyser une
partie ruine la batterie, A1 devient « à la demande » (un bouton « Analyser
mes dernières parties »), et le plan tient encore, en moins automatique. Si S2
échoue, B2 sort de la 2.0.

---

## 7. Ce que la 2.0 dirait aux joueurs

> **ChessLab apprend de vos parties.** Chaque partie est analysée sur votre
> appareil, vos erreurs deviennent des puzzles, vos sorties de répertoire des
> révisions, et ChessLab vous dit où vous perdez des points — et si c'est une
> erreur que votre niveau fait souvent. Séance du jour en un bouton. Toujours
> sans compte, sans réseau, sans pub.

---

## 8. Volet C — Revue de l'interface

**Demande (24/10)** : voir s'il est possible de **moderniser les menus et les
rendre plus attractifs et colorés**.

Méthode, en trois temps, pour ne rien redessiner à l'aveugle :
1. **Audit** : une capture de chaque écran principal, sur iPhone et Android,
   puis un relevé de ce qui est déjà cohérent (le thème sombre, les teintes par
   mode, les pastilles colorées des puzzles) et de ce qui est terne ou daté.
   Livrable : un document d'audit illustré, avec des propositions classées par
   effet / coût.
2. **Maquettes** des deux ou trois changements les plus rentables, à valider
   avant de les coder.
3. **Réalisation** par lots, iOS d'abord, Android dans le même chantier.

Garde-fous : conserver le sens des couleurs (vert de la revue, gris de
l'analyse en direct, rouge translucide de la menace) ; respecter les Human
Interface Guidelines (contrastes, Dynamic Type, cibles de 44 pt) ; ne rien
casser pour les 21 tests d'interface qui dépendent des identifiants
d'accessibilité.
