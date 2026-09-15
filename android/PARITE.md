# Parité avec l'app iOS

Relevé du 12/09/2026, fonction par fonction, en lisant les deux codes. La
synchronisation iCloud est HORS PÉRIMÈTRE (décision du 12/09 : le transfert
Android passe par un fichier).

Ce document est une liste de travail : chaque ligne cochée l'a été après
vérification sur appareil, pas après compilation.

## 🔁 Nouvelle passe — 14/09/2026, écran par écran sur appareil

La passe de septembre déclarait la parité atteinte. En testant l'app sur le
Galaxy, elle ne l'était pas : ce qui avait été VÉRIFIÉ, c'était la présence
des écrans, pas leur comportement. Quatre agents relisant les deux codes
côte à côte ont relevé une centaine d'écarts, dont plusieurs muets — le
curseur de force ne bridait pas le moteur, trois interrupteurs de réglage
n'avaient aucun effet, le filet de sécurité était porté mais jamais appelé.

Cette passe reprend module par module. Un module n'est refermé qu'après
vérification SUR APPAREIL, suite instrumentée passée.

**Les dix modules sont passés** (15/09, 09 h → 14 h). Vingt-trois lots. Ce
qu'elle a trouvé de plus coûteux n'était visible d'aucune capture d'écran :
les noms des joueurs jetés à l'enregistrement, un coup sur 22 mal étiqueté
faute d'affinage, la barre du haut figée sur l'état d'ouverture de l'écran,
et un plateau d'analyse qu'on ne pouvait pas jouer.

### Module « Jouer contre l'ordinateur » — FAIT le 14/09
Voir le commit « Jouer : le curseur bride enfin le moteur, et le filet se
referme ».

### Module « Deux joueurs » — FAIT le 14/09
- [x] **Les noms des joueurs étaient perdus.** La bibliothèque rangeait
      toutes les parties à deux sous « Blancs — Noirs » : l'écran de réglages
      demandait deux noms et personne ne les lisait. Ils sont désormais
      enregistrés, mémorisés d'une partie sur l'autre (`TwoPlayerSettingsStore`,
      comme `PlaySettingsStore`), et portés par le résultat lui-même
      (« Camille a gagné (échec et mat) », formulation d'iOS).
- [x] **Abandon et nulle par accord.** Ils n'existaient pas. « Qui
      abandonne ? » nomme les deux joueurs, comme iOS ; la nulle demande
      confirmation. La chute de drapeau, elle, n'enregistrait RIEN.
- [x] **Panneau de fin** : résultat, notation enfin révélée, Accueil /
      Analyser / Revanche (couleurs échangées, position standard). Confettis
      sur une victoire — `CelebrationOverlay`, mêmes bornes qu'iOS, et rien
      du tout quand « réduire les animations » est actif.
- [x] **Barre de consultation** : début / précédent / curseur / suivant /
      direct, « Reprendre ici » hors pendule, et huit secondes pour annuler.
- [x] **Reprise fidèle** : l'autosauvegarde porte les réglages, la position
      de départ, la cadence et les DEUX temps restants (base v8).
- [x] **Pendule** : suspendue quand l'écran s'en va ou que l'app passe
      derrière — le drapeau tombait derrière l'analyse.
- [x] **Cadences** : les six familles et la cadence personnalisée, comme
      « Nouvelle partie ». Le bouton « Commencer » passe dans une barre fixe.
- [x] **Mode « autour d'une table »** : ligne du haut ET commandes retournées
      à 180°, pièces retournées quand c'est au joueur d'en face, sélecteur de
      promotion retourné avec lui.
- [x] **Notation MASQUÉE pendant la partie**, révélée sur l'écran de
      résultat : parti pris d'iOS, deux joueurs n'arbitrent pas leur partie.
- [x] **Menu d'export** (FEN, PGN, partage) — il manquait aussi au mode Jouer.
- [x] **Glisser-déposer** sur le plateau, pour TOUS les modes : on ne traîne
      que les pièces du camp au trait.
- [x] **Annonces pour lecteur d'écran** : le coup joué (« Blancs : cavalier
      en f 3, échec »), le résultat, et la troncature d'une reprise.
      `MoveNarration` est LOCALISÉ des deux côtés — il était en français dur
      sur iOS.
- [x] **Arriver avec une position** passe par l'écran de réglages, titré
      « Continuer la partie », au lieu de sauter directement au plateau.

### Module « Analyse » — FAIT le 15/09
- [x] **Le plateau était INERTE.** `enabled = false` : la seule façon
      d'explorer une idée était de toucher une pastille de candidat, donc on
      ne pouvait essayer que ce que le moteur proposait déjà. Il se joue
      maintenant au doigt comme au glissé, toucher la case d'arrivée d'une
      flèche joue ce candidat, et la promotion demande en quoi promouvoir.
- [x] **Retour au début, lecture automatique** (un coup par seconde) et
      **« jouer le meilleur coup »** : trois commandes d'iOS qui manquaient.
- [x] **Bannière « l'ordinateur n'a pas démarré »** + Réessayer.
- [x] **Affinage des verdicts limites** — le plus important : un coup sur 22
      recevait une étiquette FAUSSE. Bande de ±2 points autour des trois
      frontières, 3 M nœuds, arrêt anticipé (`RefinementStopRule`), re-test
      entre les deux affinages, jamais sur la théorie ni en surchauffe.
- [x] **Budgets moteur par PALIER d'appareil** (`DevicePerformance`), comme
      iOS : 180 000 à 300 000 nœuds, plafonds et profondeur assortis.
- [x] **Une vraie BIBLIOTHÈQUE** : recherche, filtres (mode, résultat,
      étiquette), étiquettes libres, suppression unitaire et en lot, import
      d'un fichier PGN, précision par partie. C'était huit lignes sous
      l'écran d'analyse.
- [x] **Le bilan chiffré rejoint la partie enregistrée** (base v9) : clé
      d'empreinte, version du barème, précision, perte moyenne, coups classés
      et coups de théorie par camp.
- [x] **Écran d'entrée** : « Autres sources » replié, feuille de saisie avec
      « Ajouter aussi à la bibliothèque », ouverture d'un fichier .pgn/.fen.
- [x] **L'écran qui s'en va arrête ce qui tourne pour lui** : la lecture
      automatique déroulait la partie derrière l'écran disparu, et l'analyse
      en continu gardait le moteur à plein régime.
- [x] **Bilan** : l'ouverture en tête, et la mention « analyse en cours »
      quand le décompte est partiel.
- [x] **La barre du haut était FIGÉE** (défaut trouvé ici, valable pour TOUS
      les écrans) : ses actions gardaient l'état de l'ouverture de l'écran.

### Module « Puzzles » — FAIT le 15/09
- [x] **On choisit sa séance AVANT de résoudre** : niveau, phase, type, le
      bilan de ce qu'on rate d'habitude, puis « Commencer ». Les filtres
      vivaient dans un tiroir au-dessus du plateau, et le puzzle courant
      changeait sous les doigts.
- [x] **« Voir dans la partie d'origine »** pour un puzzle maison.
- [x] **Toucher à côté annule la promotion** — elle promouvait en dame sans
      rien demander, ce qui pouvait faire rater le puzzle.

### Module « Laboratoire » — FAIT le 15/09
- [x] **Une série a une LONGUEUR** (1 à 500) et s'arrête d'elle-même. Sans
      borne, deux bilans ne se comparaient pas.
- [x] Le **niveau de chaque camp** (on ne pouvait choisir que le personnage),
      le temps par coup, l'alternance des couleurs, le mode rapide.
- [x] **Abandon et nulle par accord** sur évaluation soutenue : sur cent
      parties, les finales jouées jusqu'au mat coûtent plus que tout le reste.
- [x] **Écran gardé allumé** pendant une longue série.

### Le plateau, pour TOUS les modes — 15/09
- [x] **Glisser-déposer**, explicitement déclaré écran par écran : sur un
      plateau qui COMPOSE (éditeur de position), un glissé aurait posé deux
      pièces d'un coup.
- [x] **Glissement du dernier coup** et **anneau de prise**.

### Modules « Réglages », « Scanner », « Variantes » — FAIT le 15/09
- [x] **Sources des données** (à quoi les ouvertures doivent leurs chiffres) et
      **Aide** dans les réglages : iOS les offre aux deux endroits.
- [x] **Photographier un vrai plateau** : le scanner n'ouvrait que la galerie,
      alors que la carte d'entrée promet « photo ou plateau réel ». Aucune
      permission demandée — on passe par l'app photo du système.
- [x] **Revoir une partie de VARIANTE aux règles de la variante**
      (`VariantAnalysisViewModel` + son écran) : l'analyse ordinaire jugeait
      une Horde ou un Roi de la colline aux règles orthodoxes, et son chiffre
      était donc faux. Panneau de fin de partie avec « Analyser », comme sur
      iOS.
- [x] **La promotion s'annule** dans les deux écrans d'entraînement.
- [x] **Mémorisation** : la carte manquait à iOS, pas à Android — c'est iOS
      qui a été relevé (`TrainingStats.swift`, neuf tests).

### Module « Variantes » — les RÉGLAGES d'une partie — FAIT le 15/09
Signalé à l'essai : « dans toutes les variantes je ne peux pas choisir le
niveau ELO, le camp, la cadence et les aides ». C'était exact, et pour les
HUIT : on tombait sur un adversaire à pleine puissance, avec les Blancs, sans
pendule et sans aucune aide, alors que le mode « Contre l'ordinateur » laisse
tout régler depuis toujours.
- [x] **Un écran de réglage pour les huit** (`VariantSetupScreen`, pendant de
      `FairyVariantSetupView` + `Chess960SetupView` réunis) : camp, force du
      moteur, cadence, aides — plus ce qui n'appartient qu'à un jeu (le numéro
      de Scharnagl du Chess960, l'intervalle des jetons du Coup Volé, le mode à
      deux du Duck Chess). Les réglages se retiennent PAR VARIANTE : le Roi de
      la colline et la Horde n'ont aucune raison de partager une cadence.
- [x] **Le bridage arrive VRAIMENT au moteur** : `fairySetupCommands` avant le
      `go`, et `go depth` sous la borne d'`UCI_Elo`. Sans cela le curseur ne
      changeait rien du tout — Fairy-Stockfish rejette une valeur hors bornes
      en silence.
- [x] **Pendule** des deux côtés du plateau, incrément Fischer, drapeau, et le
      budget de réflexion du moteur calculé sur le temps qui reste
      (`VariantClock`, partagée par les trois écrans de jeu).
- [x] **Aides** : barre d'évaluation, flèches d'indice (MultiPV 3), alerte de
      coup risqué au même barème qu'en mode ordinaire.
- [x] **Abandon et nulle proposée**, à la même règle d'acceptation (±50 cp sur
      le dernier avis du moteur).
- [x] **Analyse d'après-partie pour les HUIT** : le Duck Chess et le Coup Volé
      n'en avaient aucune. Leur partie ne se rejoue pas à partir de ses coups —
      le canard n'est dans aucun coup, et un tour double ferait jouer deux fois
      le même camp — donc l'analyse accepte désormais un JOURNAL DE POSITIONS.
- [x] **La pendule s'arrête en quittant l'écran et repart au retour** : le
      modèle de vue survit à la navigation, et aller voir l'analyse faisait
      tomber le drapeau sans que personne n'ait joué.

### Module « Laboratoire » — les réglages AVANCÉS — FAIT le 15/09
iOS règle une série sur un écran dédié (`LabSetupView`) en quatre sections ;
Android les tient sous le plateau, ce qui reste un écart de FORME assumé — mais
trois choses manquaient vraiment.
- [x] **Livre d'ouvertures**, camp par camp, plus son ampleur (lignes
      principales / avec variantes). Sans lui, deux Stockfish rejouaient
      indéfiniment la même ouverture : la série mesurait une position, pas une
      force. Un personnage garde TOUJOURS son propre répertoire — c'est son
      caractère, pas un réglage.
- [x] **Réflexion par coup en CURSEUR**, 50 ms à 5 s (c'était un incrémenteur
      plafonné à 3 s : on ne parcourt pas cette plage en tapant cinquante fois
      sur « + »), avec la note de calibration — les Elo de Stockfish sont calés
      sur 2-3 s par coup — et l'avertissement quand un camp proche du maximum
      tourne à moins d'une demi-seconde.
- [x] **Reprendre une série interrompue** : la série s'écrit sur le disque
      après CHAQUE partie, et une bannière la propose à l'ouverture. Un quart
      d'heure de calcul se perdait sans que rien ne le dise.
- [x] **La veille se DÉDUIT de la longueur** tant qu'on n'y a pas touché
      (au-delà de vingt parties), et un choix explicite tient ensuite — le
      réglage était écrasé à chaque changement de longueur.

## ✅ La passe de septembre — 13/09/2026

(Relevé de l'époque, conservé tel quel.) Les onze sections sont faites :
plus une seule case à cocher. Les deux apps
offrent les mêmes fonctions, les mêmes écrans, les mêmes barèmes et les mêmes
libellés dans les deux langues, aux écarts ASSUMÉS près — iCloud hors
périmètre, aucun échange iOS ↔ Android, et les deux points signalés en
commentaire à l'endroit exact du code (l'entraînement, et le commentaire
unique par arête de répertoire côté Android).

Vingt-six écarts relevés le 12/09, tous refermés. En chemin, la passe a
trouvé une dizaine de DÉFAUTS que personne n'avait vus — les 78 finales
ouvertes sur la position de départ, une réponse du moteur atterrissant sur
une partie relancée, la progression qui comptait les victoires par le nom
« Vous » et rendait donc zéro en anglais, la clé FEN non canonique, le
détecteur du scanner absent des licences DES DEUX CÔTÉS. Ils sont corrigés,
chacun avec son test.

À partir d'ici, la règle de `CLAUDE.md` prend le relais : toute évolution
demandée sur l'app iPhone se porte sur Android dans le même chantier. Ce
document redevient ce qu'il doit être — la liste des écarts, vide.

## Ce qui est déjà à parité

| | |
| --- | --- |
| Jouer contre l'ordinateur | 9 personnages Maia + Stockfish, niveau, couleur, pendule, indice, barre d'éval, abandon du moteur |
| Analyse des parties | plateau JOUABLE, lecture automatique, meilleur coup, affinage des verdicts limites, classification, précision, coach, courbe, candidats, menace, rétrospective, bilan, export PGN, puzzles depuis les erreurs (15/09) ; flèches alignées le 12/09 — VERTES et lues dans le cache en revue, GRISES depuis le moteur en analyse d'une position, rouge translucide pour la menace, et la rétrospective reste SEULE quand elle sort |
| Ouvertures | 58 cours, lecteur qui descend l'arbre, flèches colorées, commentaires, index des lignes, coups des maîtres et lignes de Stockfish pré-calculées (sidecar Labs, 13/09), répertoires personnels importés d'un PGN (13/09) |
| Finales | 78 cours, même lecteur |
| Entraînement | FSRS-5, séance du jour, positions difficiles, une ligne |
| Puzzles | 106 094 puzzles Lichess, choix de la séance, essais réglables, indice, retour à la partie d'origine (15/09) |
| Deux joueurs | noms des joueurs, trois présentations, cadences, abandon, nulle, consultation, revanche, export (14/09) |
| Laboratoire | série BORNÉE, niveau par camp, abandon et nulle, mode rapide, écran gardé allumé (15/09) |
| Scanner | détection du plateau, coins ajustables, recadrage, confirmation dans l'éditeur avec cases douteuses et sens de lecture (13/09) |
| Éditeur de position | composer une position |
| Progression | statistiques d'entraînement ; bilan complet le 13/09 — par niveau d'adversaire, par personnage, meilleure victoire, réussite des puzzles par palier, niveau atteint, thèmes à travailler |
| Changer de mode | sur huit écrans |
| Thèmes, jeux de pièces, sons | mêmes valeurs qu'iOS |
| Deux langues | décor ET contenu des cours |
| Transfert entre appareils | fichier `.clab`, fusion par rejeu du journal |

## Ce qui manque — par ordre de traitement

### 1. Réglages — FAIT le 12/09
- [x] **Retour haptique.** Le vocabulaire d'iOS — coup, prise, échec, fin de
      partie, coup refusé — porté aux effets prédéfinis d'Android, qui sont
      calibrés par le constructeur. Vérifié sur le Galaxy A16 :
      `com.chesslab … played: Prebaked=TICK(MEDIUM)`, 39 ms, sur le coup joué.
- [x] **Notation des coups.** Le réglage n'est PAS « figurines ou lettres »
      comme je l'avais d'abord noté, mais **française ou anglaise** (Cf3 contre
      Nf3) : iOS garde les figurines pour le seul lecteur d'ouvertures, et
      applique la langue partout ailleurs. Android fait maintenant pareil.
      Le piège est la conversion en UNE passe — « R → T » puis « K → R »
      retraduirait les tours fraîchement écrites ; six tests le verrouillent.
- [x] **Mode de flèches mémorisé.**

### 2. Jouer — en partie, le 12/09
- [x] **Annuler un coup.** Le dernier coup ET la riposte du moteur, car
      reprendre un seul demi-coup rendrait la main à l'adversaire — ce n'est
      pas ce qu'on demande en disant « annuler ». Pas avec une pendule : on ne
      reprend pas du temps déjà écoulé, et iOS a tranché pareil. Le bouton
      disparaît alors au lieu de rester grisé sans qu'on sache pourquoi.
- [x] **Alerte après un coup risqué.** Rétroactive, comme iOS : prévenir AVANT
      obligerait à faire attendre à chaque coup. Le barème est le même, en deux
      couches — ce que le coup coûte en PROBABILITÉ DE GAIN (et non en
      centipions bruts : perdre deux pions à +8 ne change rien), et si la
      partie se joue encore (ni déjà perdue, ni encore gagnée). Trois messages
      distincts : mat concédé, mat laissé filer, perte en pions.

      **Le piège, trouvé sur l'appareil** : la vérification doit passer AVANT
      la réponse du moteur. Lancées en parallèle, la réponse gagnait la course,
      « le moteur réfléchit » interdisait de reprendre, et l'alerte ne sortait
      jamais. iOS les met dans la même file pour cette raison-là.
- [x] **Répertoire d'ouvertures des personnages.** Le fichier était embarqué
      depuis septembre et personne ne le lisait. Les huit répertoires sont
      maintenant consultés, avec tirage PONDÉRÉ — ce qui distingue les
      personnages n'est pas la liste des premiers coups (tous proposent e4, d4,
      c4, Cf3) mais leurs poids. Le livre général est branché aussi, avec son
      réglage.

### 3. Deux joueurs — FAIT le 12/09
- [x] **Écran de réglages** : les NOMS des deux joueurs, la présentation du
      plateau (face à face, fixe, table) et la cadence. Les noms ne sont pas
      un ornement : une partie rangée sous « Blancs — Noirs » se confond avec
      toutes les autres, sous « Thierry — Camille » on la retrouve.
- [x] **Mode table** : plateau fixe, mais la ligne du joueur d'en face
      retournée à 180°, pour qu'il lise son nom et sa pendule à l'endroit
      depuis son côté.
- [x] **Pendule** : le mode n'en avait aucune. Elle part avec la partie, comme
      une vraie qu'on enclenche en s'asseyant.
- [x] **Reprise d'une partie interrompue**, et l'accueil propose la plus
      RÉCENTE des deux modes plutôt que toujours celle contre l'ordinateur.

### 4. Puzzles — FAIT le 12/09
- [x] **Filtres** : difficulté (quatre paliers de cote), phase de partie,
      thème (huit). Sans eux on tirait au hasard dans 106 094 positions ; avec,
      on travaille une faiblesse précise, et c'est tout l'intérêt d'une base de
      cette taille. Une seule ligne repliable, pas trois rangées permanentes —
      c'est le plateau qu'on vient voir.
- [x] **Progression et répétition espacée** (SM-2, comme iOS — et non FSRS, qui
      sert aux ouvertures : une position d'ouverture se révise des dizaines de
      fois, un puzzle se résout une fois). Ce qu'on rate revient demain.
- [x] **Statistiques** par thème et par niveau — FAIT le 13/09. Sur l'écran
      des puzzles, la carte « Réussite » d'iOS : taux, « N réussis sur M
      tentatives », et les thèmes À TRAVAILLER (au moins quatre essais et plus
      d'un tiers d'échecs, sinon on désignerait comme faiblesse un thème
      réussi à 90 %). Sur l'écran Progression, tout ce qu'iOS y met et
      qu'Android n'avait pas : la réussite par palier de difficulté en barres,
      le « niveau atteint » (le palier le plus dur tenu à 60 % sur cinq essais
      au moins), les thèmes faibles qui LANCENT une série ciblée d'un tap,
      et côté parties : fenêtre 7 jours / 30 jours / tout, victoires-nulles-
      défaites, MEILLEURE VICTOIRE en Elo, bilan par niveau d'adversaire et
      par personnage avec « battu jusqu'à ». Il fallait pour cela que les
      parties portent l'adversaire, son niveau et la couleur du moteur, et
      les puzzles leur note : schéma v7, trois colonnes, rien à convertir.
      Le transfert `.clab` les emporte. Neuf cas JVM.

      Trouvé en chemin : la progression comptait les victoires en cherchant
      le nom « Vous » — traduit « You » en anglais, donc zéro victoire dans
      cette langue. Le bilan lit désormais la couleur du moteur, champ
      sémantique, le nom ne servant que de repli pour les parties anciennes.

### 5. Finales — FAIT le 12/09
- [x] **Entraînement libre** : conclure la position contre la meilleure défense,
      tout coup qui préserve le verdict étant accepté. Le seuil est celui de
      l'audit iOS (250 centipions), et un verdict qui S'AMÉLIORE passe sans
      commentaire — sous jeu optimal c'est impossible, donc c'est l'arbitre qui
      se corrige, et on n'accuse pas l'utilisateur d'un artefact.

      **Trois pièges, tous trouvés sur l'appareil.**

      1. Les 78 cours de finales s'ouvraient sur la POSITION DE DÉPART. Les
         fichiers portent des FEN à quatre champs — c'est la clé du graphe —
         et `FenParser` en exige six ; le repli `?: Position.standard` rendait
         donc un échiquier complet. Comme les 59 ouvertures partent justement
         du début, le défaut était invisible depuis toujours, et il touchait
         AUSSI l'entraînement guidé. `CourseRepository.position()` complète les
         compteurs, comme `OpeningFENKey.position(from:)` chez iOS.
      2. Le coup était joué sur le VRAI plateau avant d'être arbitré : un coup
         repris laissait quand même la pièce sur sa nouvelle case, et la flèche
         de correction montrait le meilleur coup de l'ADVERSAIRE. iOS arbitre
         sur une copie — `Board` y est une `struct`, ici c'est une classe, et
         l'affectation ne copie rien.
      3. Le verdict à tenir était figé sur la position de départ. iOS le
         RECALCULE après chaque riposte : sans quoi une nulle améliorée en gain
         pouvait ensuite être regâchée sans que rien ne le dise.

      Cinq cas instrumentés verrouillent le tout, avec un arbitre postiche.

### 6. Laboratoire — FAIT le 12/09
- [x] **Estimation Elo** avec intervalle de confiance à 95 %, LOS, score,
      V·N·D, longueur moyenne, répartition et courbe de progression — chaque
      tuile s'ouvrant sur son explication, comme iOS. Les formules sont portées
      à l'identique, y compris les deux correctifs qui changent les chiffres :
      **Bessel** (`n − 1`) et le **terme de continuité de Wilson**, sans lequel
      deux nulles d'affilée donnent une variance nulle — donc une fausse
      certitude à 95 % après deux parties. `erf` n'existe pas en Kotlin : c'est
      l'approximation d'Abramowitz & Stegun, vérifiée à 1,5·10⁻⁷.
      Quatorze cas repris un à un de `LabStatsTests.swift`.
- [x] **Position de départ** imposée : un FEN **ou un PGN**, dont on prend la
      position finale — pour lancer une série depuis la fin d'une ouverture
      qu'on vient de coller.
- [x] **Export** : PGN de toutes les parties (en-têtes synthétiques, résultat
      en clôture, tags `SetUp`/`FEN` conservés) et CSV des résultats.
      Presse-papiers EN PLUS du partage, comme l'analyse.
- [x] Trois libellés du bandeau étaient écrits EN DUR, donc en français au
      milieu d'un écran anglais — les ressources existaient déjà. Un test JVM
      compare désormais les deux catalogues clé par clé, argument par argument.

### 7. Ouvertures — FAIT le 13/09
- [x] **Index des lignes** : l'arbre de toutes les variantes, chaque coup écrit
      UNE fois, les débranchements imbriqués avec leurs rails, et chaque coup
      est un bouton — taper le 7ᵉ coup du Fried Liver amène directement à
      cette position, fil des coups rempli. Titres de chapitre posés au point
      de divergence, repères « transposition » qui renvoient à la rangée qui
      déplie vraiment la position, verdicts du moteur (`??`, `?!`, `!!`…) sur
      les coups qui le méritent. Quinze cas repris d'`OpeningLineTreeTests`,
      bornes mesurées sur les 58 ouvertures comprises (≤ 200 rangées, profondeur
      3 à 12) ; les titres de l'Italienne tombent au bon endroit (Evans → 4.b4,
      Fried Liver → 6.Cxd5, Traxler → 4…Fc5).
- [x] **Le sidecar Labs**, qu'Android n'embarquait pas : pour chaque position,
      les coups des MAÎTRES avec leur part et leur bilan, et les trois lignes
      de STOCKFISH calculées d'avance, avec la profondeur. Le lecteur les montre
      en deux colonnes sous le répertoire, comme iOS, et l'évaluation de la
      position vient désormais du moteur pré-calculé (« +0,25 p20 »), le coup
      du cours ne servant que de repli. 2,6 Mo d'assets en plus.
- [x] Nom de la variante atteinte sous le plateau, et sur chaque suite du
      répertoire le nom de la ligne qu'elle ouvre.
- [x] **La clé canonique** (`OpeningFENKey.key(for:)`) : Android n'avait que la
      troncature à quatre champs. Suffisant pour une FEN venue d'un fichier,
      faux pour une position qu'on vient de JOUER — ChessKit garde une case
      « en passant » sans preneur et un droit de roque dont la tour est prise ;
      deux chemins vers la même position donnaient deux clés. Sans effet sur
      le lecteur (ses clés viennent du fichier), indispensable à l'import de
      répertoires (§9). Six cas repris d'`OpeningFENKeyTests`.
- [x] Le statut des commentaires est honoré : seul un commentaire `validated`
      s'affiche. Les 1 834 du catalogue le sont tous — le verrou est pour
      demain.

### 8. Scanner — FAIT le 13/09
- [x] **Écran de confirmation**, OBLIGATOIRE : rien de ce qui sort du scanner
      ne part vers le moteur sans passer sous les yeux de l'utilisateur. Comme
      iOS, c'est l'éditeur de position pré-rempli avec la lecture : les cases
      douteuses (confiance < 0,55) sont surlignées, une bannière en donne le
      compte, le sens de lecture s'inverse d'un tap (deux orientations
      plausibles pour un diagramme, l'orientation proposée étant celle qui
      donne une position légale — ou, à égalité, la mieux placée pour ses
      pions), les roques sont DÉDUITS de la position et jamais inventés, et
      « Recadrer » ramène aux coins. Avant : la FEN lue partait telle quelle,
      avec « KQkq » inventé.
- [x] **Le validateur de FEN** d'iOS, porté avec ses sept règles (deux rois,
      pas de pion sur les rangées extrêmes, camp sans le trait pas en échec,
      camp au trait avec un coup légal, roques et case « en passant »
      cohérents) : l'éditeur les met en mots et refuse d'analyser une
      position injouable. Huit cas JVM ; sept pour la lecture (rotation, FEN,
      cases douteuses, orientation devinée) ; sur l'appareil, la capture de
      référence traverse tout l'écran jusqu'à l'analyse.

### 9. Répertoires personnels — FAIT le 13/09
- [x] **Import PGN** : les variantes entre parenthèses deviennent des
      branches, les transpositions fusionnent en un seul nœud (deux ordres de
      coups, une position, une seule progression), les annotations de
      l'auteur (`?`, `?!`) deviennent des rôles, les commentaires suivent, et
      chaque partie d'une étude devient un chapitre. Le nom se devine dans le
      PGN (`[Opening]`, puis `[Event]` tronqué avant le « : » d'une étude
      Lichess). Douze cas repris d'`OpeningPGNImporterTests`.
- [x] **Le magasin** : des fichiers JSON au format EXACT des cours embarqués,
      relus par le même décodeur — ce qui rend le partage gratuit (un fichier
      exporté par Android est un cours pour iOS, et réciproquement) — et
      validés à l'entrée par le validateur d'intégrité porté (`rootMissing`,
      arêtes orphelines, coups illégaux, cibles fausses, clés non canoniques,
      chapitres orphelins). Les 137 cours livrés le passent sans remarque.
- [x] **L'écran** : « + » sur la liste des ouvertures, PGN collé ou fichier
      (un `.json` reçu d'un ami entre tel quel, ré-identifié), nom deviné,
      camp étudié ; section « Mes répertoires » en tête de liste, hors filtre
      de niveau ; partage et suppression (la progression reste — elle est
      indexée par position). Un test instrumenté fait le tour complet.
- [x] **L'entraînement** en hérite sans une ligne : le catalogue sert les
      répertoires personnels en premier, et FSRS est indexé par FEN.

      Trouvé en chemin : le nettoyage d'un PGN multi-parties se faisait AVANT
      le découpage, et ne gardait qu'une ligne vide — la seconde partie perdait
      la sienne et devenait illisible. iOS découpe d'abord. L'analyse ne l'a
      jamais vu : elle ne lit que la première partie.

      Restent, hors de ce lot :
- [x] **L'éditeur de répertoire** — fait le 13/09. Le geste central est
      l'ajout, et il n'a PAS de bouton : on joue le coup sur l'échiquier, il
      entre dans le répertoire et l'éditeur y entre avec nous. La consigne
      reste affichée en permanence (côté iOS, elle disparaissait dès qu'un
      coup existait, et l'écran passait pour une liste en lecture seule).
      Renommer, commenter une arête, supprimer une variante ; le fil des coups
      ramène à n'importe quel demi-coup ; « Suivant » nomme le coup à venir.
      Enregistrement IMMÉDIAT, et le résultat n'est gardé que si le fichier a
      bien été écrit. La couche de graphe est pure et porte les deux
      invariants d'iOS : aucune arête que le validateur rejetterait (le coup
      est rejoué, TRAIT compris — `canMove` ne le consulte pas), et aucun nœud
      inatteignable (purge par accessibilité depuis la racine, jamais en
      descendant le sous-arbre : une transposition maintient une position
      jointe). Seize tests JVM, quatre instrumentés.
      Écart ASSUMÉ : le modèle Android ne garde qu'un commentaire par arête,
      donc le réenregistrement l'écrit dans les deux langues au lieu de
      préserver la traduction de l'autre. Rien n'est perdu, mais une version
      anglaise distincte ne survivrait pas à une modification française.
- [x] **Le transfert `.clab` emporte les répertoires personnels** — fait le
      13/09. Le fichier de cours voyage tel quel : c'est LUI le répertoire, et
      il se relit par l'analyseur de l'import. L'identité vient du fichier
      (`user-<uuid>`, posée à la création), donc elle traverse les appareils —
      réimporter ne duplique pas, et un répertoire déjà présent n'est JAMAIS
      écrasé : il a pu être modifié ici depuis l'export, et l'import fusionne.
      Un cours illisible ou refusé par le validateur est ignoré sans emporter
      le reste de l'import. Trois tests JVM, un instrumenté qui fait l'aller-
      retour complet.

### 10. Variantes — les DOUZE, des deux côtés (13/09)
iOS comme Android : Chess960, Roi de la colline, Trois échecs, Horde, Course
des rois, Atomique, Antiéchecs, Crazyhouse, Barricades, Barricades
aléatoires, Coup Volé, Duck Chess.
- [x] **Crazyhouse** — fait le 13/09. La seule variante du hub où l'on POSE
      des pièces. La réserve se lit entre crochets dans la FEN du moteur
      (`CrazyhouseFen`), s'affiche au-dessus du plateau pour l'adversaire et
      en dessous pour soi, et ne s'affiche PAS quand elle est vide — une bande
      vide vole de la place à l'échiquier sans rien dire. On touche une pièce
      de sa main, les cases de pose s'allument, on la pose ; la réserve d'en
      face est un relevé, elle ne se touche pas. Le `~` des pièces promues est
      retiré avant de rendre la position à `chesskit`, qui refuserait tout le
      reste à cause de lui. La lettre d'une pose est la lettre FEN, pas la
      lettre SAN — vide pour le pion, elle donnait « @e4 » côté iOS et aucune
      case trouvée. Cinq tests JVM, un test de plomberie qui interroge le VRAI
      moteur (la FEN porte la réserve, les poses sont listées « P@xx » et
      visent des cases vides) et un test d'écran.
- [x] **Barricades** et **Barricades aléatoires** — faites le 13/09. Le moteur
      n'a AUCUNE notion de case-mur : la définition écrite par l'app la lui
      fabrique, avec le type `immobile` (notation Betza vide : aucun coup
      possible), `mobilityRegion` pour que les Noirs ne puissent pas s'y
      poser, et une valeur nulle pour qu'un mur ne pèse rien. Elle est
      enseignée par `VariantPath`, AVANT tout `UCI_Variant` — dans l'autre
      ordre le moteur refuse un nom qu'il ne connaît pas encore et reste aux
      échecs ordinaires sans rien dire. Le blocage des lignes ne vient pas de
      la région de mobilité mais de l'OCCUPATION : un mur est une pièce, donc
      il arrête une tour et un cavalier lui saute par-dessus.
      La variante aléatoire ne peut pas se protéger ainsi — une région figée
      ne suit pas des murs qui bougent —, donc le moteur y propose de prendre
      les murs et c'est l'app qui retire ces coups-là, rien d'autre. Sa
      position se RÉÉCRIT entre les demi-coups (deux murs sur trois changent
      de case, jamais le même épargné), ce qu'aucun journal de coups ne
      saurait reproduire : le modèle rebase la position et compte les
      demi-coups à part.
      Le « W » du mur ne parvient jamais à `chesskit`, qui refuserait toute la
      position à cause de lui ; le plateau le dessine comme une ardoise, plus
      sombre que n'importe quelle case. Neuf tests JVM, quatre sur le VRAI
      moteur (il apprend la variante ; un mur fixe ne se prend pas ; un mur
      mobile se prendrait sans le filtre de l'app ; un mur arrête une tour) et
      deux d'écran.
- [x] **Coup Volé** — fait le 13/09. Variante MAISON : le tour double
      n'existe dans aucun moteur et aucune option UCI ne saurait le décrire.
      `chesskit` reste l'unique arbitre de chaque coup, Stockfish n'est que
      l'adversaire, et le TOUR est tenu par l'app. Les cinq règles y sont :
      un jeton tous les N coups joués par un camp (réglable de 4 à 8), un
      seul en stock — un nouveau efface l'ancien —, pas de dépense en échec,
      deux coups d'affilée sauf si le premier donne échec, et la prise en
      passant ouverte par le dernier coup adverse qui SURVIT au coup
      intercalé (le trait et la case en passant sont rendus au second coup :
      sans cela `chesskit` ferait jouer l'adversaire et effacerait une prise
      pourtant légale). L'ordinateur dépense toujours un jeton disponible —
      non dépensé, il serait perdu au suivant. Sept tests JVM sur les règles,
      un instrumenté qui gagne un jeton en quatre coups, le dépense, et joue
      bien deux coups sans que l'adversaire s'intercale.
- [x] **Duck Chess** — fait le 13/09. La seule variante dont les règles sont
      calculées DANS L'APP : aucun moteur ne la connaît, et un coup y est DEUX
      actions — déplacer une pièce, puis poser le canard —, ce que le
      protocole UCI ne sait pas exprimer. `DuckChessRules` engendre donc les
      coups lui-même (pseudo-légaux au sens classique : ni échec, ni mat, ni
      pat — on gagne en CAPTURANT le roi), `DuckChessFen` les applique en
      écrivant le plateau résultant, et Stockfish n'est qu'un CONSEILLER,
      borné par `searchmoves` aux coups que le canard autorise. Trois cas le
      mettraient en défaut, tous traités avant lui : un roi prenable (position
      illégale à ses yeux, et pourtant le coup gagnant), une position illégale
      qui ne l'est pas ici, et une liste vide.
      Le canard bloque totalement une case — rien ne s'y pose, rien ne la
      traverse, il ne se capture pas — et il DOIT changer de case à chaque
      tour. L'ordinateur le pose là où il gêne : sur la case d'arrivée du
      meilleur coup adverse, sinon sur son trajet. Il ne figure ni dans la
      position ni dans la FEN, ce qui permet de rendre celle-ci à `chesskit`
      et de réutiliser tout l'affichage ; il se dessine à part. Vingt-quatre
      tests JVM (quinze portés un à un de la suite iOS) et un d'écran.
- [x] **Chess960 par numéro, et à deux** — fait le 13/09. La tuile ouvre un
      écran de réglage : la position se choisit par son NUMÉRO de Scharnagl,
      celui de Lichess et des moteurs — champ de saisie pour viser, curseur
      pour explorer, « Au hasard » et « Classique (518) » —, et le plateau la
      MONTRE avant qu'on commence, parce qu'un numéro seul ne dit rien. La
      numérotation est portée de python-chess comme sur iOS, et le test JVM
      compare les 960 FEN au MÊME fichier de référence que la suite iOS : si
      la 518 n'était pas la partie classique, tout le reste serait faux sans
      que rien ne le dise. Un interrupteur « à deux sur cet appareil » : le
      moteur ne joue plus, il arbitre seulement, le statut nomme la couleur au
      trait, et le plateau se retourne si le réglage du mode Deux joueurs le
      demande. Cinq tests JVM, trois instrumentés.

### 11. Le reste
- [x] **Visite guidée** — faite le 13/09. Les onze étapes d'iOS, en trois
      sections (Jouer, Comprendre, Explorer) : voile percé d'un trou qui
      GLISSE d'un contrôle au suivant, anneau qui respire, flèche courbe à
      tête calculée, carte émeraude avec barre de progression, chips des
      gestes de partie / des variantes (lues dans le catalogue, et le titre
      les COMPTE plutôt que d'écrire « Douze » tant qu'Android n'en a pas
      douze) / des salles d'entraînement. La visite PILOTE la navigation
      (accueil, réglages de partie, entrée d'Analyser, Ouvertures). Se
      propose une seconde après l'accueil d'une NOUVELLE installation
      (empreinte `firstInstallTime`, pas un booléen — même raison qu'iOS),
      jamais par-dessus une reprise ; « Passer » compte comme vue ; se
      rejoue depuis l'Aide (carte en tête). Géométrie portée avec ses
      chiffres et ses six tests ; un instrumenté traverse quatre étapes.
      Trouvé en chemin : l'accueil Android n'avait pas la section « Parties
      récentes » qu'une étape désigne — ajoutée (quatre parties, pastille de
      résultat ivoire/ardoise d'iOS, un tap ouvre l'analyse, « Voir tout »
      vers la bibliothèque).
- [x] **Écran Licences** — fait le 13/09. Réglages → À propos → « Licences »
      ouvre le même écran qu'iOS : une carte par composant, nom, licence,
      texte, lien (confié au navigateur d'un tap — l'app ne déclare toujours
      pas la permission réseau). Les dix entrées d'iOS, plus deux que seul le
      binaire Android embarque : ONNX Runtime (MIT) et le détecteur du
      scanner (YOLO11, AGPLv3). Ce détecteur manquait AUSSI côté iOS ; il y a
      été ajouté dans le même commit (`LicensesView.swift`). Trois tests JVM
      sur la liste, un instrumenté sur l'écran.
- [x] **Cache des évaluations d'analyse** — fait le 13/09. `AnalysisEvalStore`
      comme sur iOS : un fichier JSON par partie, clé SHA-256 de la position
      de départ et de la ligne principale en LAN (deux PGN cosmétiquement
      différents de la même partie partagent leur analyse), profil moteur +
      budget qui invalide tout s'il change, 300 parties gardées (LRU).
      Seules les évaluations sont rangées : verdicts, courbe et précision se
      recalculent par la fonction pure. Une revue interrompue est persistée
      telle quelle et reprend où elle en était. Quatre tests JVM, un
      instrumenté qui rouvre la partie et trouve le bilan en moins de 3 s.
- [x] **Revue automatique à l'ouverture d'un PGN** — fait le 13/09. Le modèle
      distingue désormais à la source la REVUE d'une partie de l'analyse
      d'une POSITION : en revue, la classification part toute seule au
      chargement (progression visible), puis le moteur se TAIT — naviguer lit
      le cache (éval, flèches vertes, candidats), rien n'est recalculé ; une
      position pas encore évaluée (variante explorée depuis un candidat) est
      classée une seule fois. Sur une position (FEN, scan, éditeur),
      l'analyse en continu reste la seule source. Le bouton « Revue » ne
      subsiste qu'en repli, quand une revue n'a pas abouti.
