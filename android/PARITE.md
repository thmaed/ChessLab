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
| Analyse des parties | classification, précision, coach, courbe, candidats, menace, rétrospective, bilan, export PGN, puzzles depuis les erreurs ; flèches alignées le 12/09 — VERTES et lues dans le cache en revue, GRISES depuis le moteur en analyse d'une position, rouge translucide pour la menace, et la rétrospective reste SEULE quand elle sort |
| Ouvertures | 58 cours, lecteur qui descend l'arbre, flèches colorées, commentaires, index des lignes, coups des maîtres et lignes de Stockfish pré-calculées (sidecar Labs, 13/09), répertoires personnels importés d'un PGN (13/09) |
| Finales | 78 cours, même lecteur |
| Entraînement | FSRS-5, séance du jour, positions difficiles, une ligne |
| Puzzles | 106 094 puzzles Lichess, essais réglables, indice |
| Deux joueurs | plateau qui se retourne |
| Laboratoire | série de parties, Maia ou Stockfish de chaque côté |
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
- [ ] **L'éditeur de répertoire** d'iOS (`OpeningEditorView`, 628 lignes) :
      renommer, ajouter des coups en jouant sur le plateau, commenter ou
      supprimer une arête. L'import couvre l'usage principal ; l'édition sur
      place vient après les gros blocs.
- [ ] **Le transfert `.clab`** n'emporte pas encore les répertoires
      personnels — iOS les fait suivre par iCloud, Android n'a que le fichier.

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
