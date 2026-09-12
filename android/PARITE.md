# Parité avec l'app iOS

Relevé du 12/09/2026, fonction par fonction, en lisant les deux codes. La
synchronisation iCloud est HORS PÉRIMÈTRE (décision du 12/09 : le transfert
Android passe par un fichier).

Ce document est une liste de travail : chaque ligne cochée l'a été après
vérification sur appareil, pas après compilation.

## Ce qui est déjà à parité

| | |
| --- | --- |
| Jouer contre l'ordinateur | 9 personnages Maia + Stockfish, niveau, couleur, pendule, indice, barre d'éval, abandon du moteur |
| Analyse des parties | classification, précision, coach, courbe, candidats, menace, rétrospective, bilan, export PGN, puzzles depuis les erreurs |
| Ouvertures | 58 cours, lecteur qui descend l'arbre, flèches colorées, commentaires, statistiques des maîtres, éval |
| Finales | 78 cours, même lecteur |
| Entraînement | FSRS-5, séance du jour, positions difficiles, une ligne |
| Puzzles | 106 094 puzzles Lichess, essais réglables, indice |
| Deux joueurs | plateau qui se retourne |
| Laboratoire | série de parties, Maia ou Stockfish de chaque côté |
| Scanner | détection du plateau, coins ajustables, recadrage |
| Éditeur de position | composer une position |
| Progression | statistiques d'entraînement |
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
- [ ] **Statistiques** par thème et par niveau — les données sont désormais
      enregistrées, l'écran reste à faire.

### 5. Finales
- [ ] **Entraînement libre** : conclure la position contre la meilleure défense,
      tout coup qui préserve le verdict étant accepté.

### 6. Laboratoire
- [ ] **Estimation Elo** de l'écart entre les deux camps, avec intervalle de
      confiance.
- [ ] **Position de départ** imposée à la série.
- [ ] **Export** du bilan.

### 7. Ouvertures
- [ ] **Index des lignes** : la table de toutes les variantes d'un cours, pour
      sauter directement à l'une d'elles.

### 8. Scanner
- [ ] **Écran de confirmation** : corriger les pièces mal lues AVANT d'utiliser
      la position. Android donne la FEN et la propose telle quelle.

### 9. Répertoires personnels
- [ ] **Import PGN** de ses propres ouvertures, variantes comprises, et
      entraînement dessus avec le même FSRS.

### 10. Variantes — cinq manquantes sur douze
iOS : Chess960, Roi de la colline, Trois échecs, Horde, Course des rois,
Atomique, Antiéchecs, **Crazyhouse**, **Barricades**, **Barricades
aléatoires**, **Coup Volé**, **Duck Chess**.
Android : les sept premières.
- [ ] **Crazyhouse** — demande une réserve de pièces et un geste de parachutage.
- [ ] **Barricades** et **Barricades aléatoires** — murs sur le plateau, et qui
      se déplacent à chaque coup pour la seconde.
- [ ] **Coup Volé** — variante maison.
- [ ] **Duck Chess** — un canard bloque une case, tour en deux temps.
- [ ] **Chess960** : iOS a le choix par NUMÉRO de position et un mode deux
      joueurs ; Android tire au hasard et ne joue que contre l'ordinateur.

### 11. Le reste
- [ ] **Visite guidée** au premier lancement (onze étapes, rejouables depuis
      l'aide).
- [ ] **Écran Licences** : Android n'a qu'une phrase dans les réglages. La
      GPLv3 demande davantage — voir `PUBLIER.md` §0.
- [ ] **Cache des évaluations d'analyse** : iOS garde sur disque ce que le
      moteur a déjà calculé ; Android recalcule à chaque ouverture.
