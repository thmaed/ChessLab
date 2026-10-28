# Parité avec l'app iOS

Relevé du 12/09/2026, fonction par fonction, en lisant les deux codes. La
synchronisation iCloud est HORS PÉRIMÈTRE (décision du 12/09 : le transfert
Android passe par un fichier).

Ce document est une liste de travail : chaque ligne cochée l'a été après
vérification sur appareil, pas après compilation.

### Barre de progression du préchargement — 28/10/2026

- Écart ASSUMÉ, sans objet côté Android : iOS précharge les puzzles dans sa base au premier
  lancement (bandeau « Préparation… » avec barre) ; Android lit le JSON à la demande, rien
  à attendre au démarrage.

### Bibliothèque de puzzles : +24 841 — 28/10/2026

- [ ] Même fichier des deux côtés (`ChessLab/Resources/lichess_puzzles.json`, copié au
      build) : 130 935 puzzles. Rien à porter ; **à vérifier sur le Galaxy** : la durée
      d'un tirage (le JSON de 23 Mo est lu en flux à chaque série) et la taille de l'APK.

### Réussite partielle des puzzles et « Analyser ici » — 28/10/2026

Portés dans le même chantier que iOS. **Rien n'est coché sur appareil** : à
vérifier sur le Galaxy avant de cocher.

- [ ] **Trois issues** (maîtrisé / partiel / raté) au lieu du binaire. Partiel =
      séquence où au moins un coup est juste puis échec, OU résolu après une
      fausse tentative (réglage 3 essais). L'indice ne rend PAS partiel (décision
      du 23/10 : réussi avec indice = réussi). iOS `PuzzleOutcome`, Android
      `PuzzleResult` (l'autre nom y désigne l'état de l'écran).
- [ ] SM-2 : qualité 3, retour à 2 jours, `repetitions` inchangé. Compteurs
      succès/échec inchangés (stats stables) ; cote Glicko inchangée.
- [ ] Puce **« À revoir »** (EN « Review ») à côté de « Ratés », grisée à zéro,
      exclusive avec elle. « Ratés » = issue `missed`, ou ancienne ligne sans issue
      lue comme avant.
- [ ] Base v11 → v12 (`lastOutcome`), fichier `.clab` : champ `outcome` optionnel,
      pas de changement de `version` (un fichier ancien se lit, un nouveau lu par
      une ancienne version est ignoré). Tests JVM + `MigrationTest` verts.
- [ ] **« Analyser ici »** : en consultation AVEC pendule, pastille à la place de
      « Reprendre ici » (qui n'existe pas), vers l'Analyse sur la position
      affichée. Retour d'un utilisateur : le bouton disparaissait sans un mot.
- [ ] Phrase de fin de partie : « … essayer d'autres lignes … ».
- Écart connu : la séance du jour (`DailySession`) ne compte que les « Ratés » ;
  les partiels n'y sont pas encore proposés (iOS et Android pareil).
- Écart de synchro iOS : le miroir CloudKit adopte l'issue avec l'état de
  révision « le plus avancé » (`repetitions`) ; un partiel, qui ne change pas ce
  compteur, ne se propage pas d'un appareil à l'autre avant la prochaine réussite.

### Puzzles Android : l'en-tête qui repoussait le plateau — 24/10/2026

- [x] **Signalé par l'utilisateur sur le Galaxy** : un puzzle « Attaque à la
      découverte · Débutant · Milieu de partie » s'affichait avec l'en-tête sur
      la moitié de l'écran, le plateau en bas, essais et indice hors champ. La
      ligne de contexte (une `Row`) débordait. Elle passe désormais à la ligne
      (`FlowRow`). `PuzzleDeviceFlowTest.unThemeLongNeRepoussePasLePlateau`,
      vert sur Galaxy A16. iOS n'a pas ce défaut (une ligne, texte réductible).
- [x] **La version de test s'appelle « ChessLab test »** sur l'appareil : sous
      le même nom que celle du Play Store, deux icônes identiques — on
      vérifiait les nouveautés dans la mauvaise.

### Variantes contre l'ordinateur : PAS DE CONSULTATION sur Android — relevé le 24/10/2026

- [x] **Écart (préexistant, jamais inscrit)** : sur iOS, les cinq écrans de
      variantes contre l'ordinateur (Chess960, variantes Fairy, Barricades &
      co., Coup Volé, Duck Chess) ont la barre de consultation — précédent /
      suivant, « Reprendre ici » hors pendule, annulation huit secondes. Sur
      Android, AUCUN : `VariantScreens`, `StolenMoveScreen` et
      `DuckChessScreen` n'ont ni historique des positions, ni position
      consultée, ni reprise. Relevé en étendant aux variantes la navigation
      par coup complet (iOS, 24/10 — `ReviewStepper`, par la FEN, ou par la
      couleur de qui joue pour le tour double du Coup Volé). À porter EN BLOC :
      la barre, puis la même règle de pas.
      **Porté le 24/10/2026, en bloc** : les trois ViewModels de variantes
      (`VariantPlayViewModel` — Chess960 et les neuf variantes du moteur —,
      `DuckChessViewModel`, `StolenMoveViewModel`) ont la consultation, la
      reprise hors pendule et ses huit secondes d'annulation, et le pas d'un
      coup complet contre l'ordinateur (demi-coup à deux). Reprises fidèles à
      iOS : départ + coups gardés pour une variante ordinaire, position
      consultée pour les Barricades aléatoires, rejeu des coups (jetons
      compris) pour le Coup Volé, journaux tronqués pour le Duck Chess.
      `VariantReviewTest` (cinq cas) vert sur Galaxy A16.

### Volet C de la 2.0 — premier lot visuel — 24/10/2026

- [x] **C1 — tuiles d'accueil teintées** : voile de la teinte du mode sur toute
      la carte (30 % → 5 %), filigrane plus présent. Mêmes valeurs des deux
      côtés. Vu sur Galaxy A16.
- [x] **C3 — en-têtes de section avec pastille teintée** : les cinq groupes
      de l'écran de choix des puzzles (`SectionHeader(icon, tint)`).
- [x] **C4 — bouton d'action plein en bas, teinté du mode** (Nouvelle partie vert,
      Deux joueurs bleu, Laboratoire rose, variantes) : iOS `PrimaryActionBar`,
      Android `tintedActionGradient`. Reste à voir sur le Galaxy.
- [ ] **C2 — un seul style de titre : fait sur iOS seulement.** Les écrans de
      menu iOS (Puzzles, Nouvelle partie, Deux joueurs, Analyser,
      Bibliothèque, Laboratoire, Variantes, Progression) passent en GRAND titre
      à gauche, comme Ouvertures et Finales. Android garde sa barre d'app
      unique, déjà cohérente d'un écran à l'autre : le grand titre y demande une
      `LargeTopAppBar` qui se réduit au défilement, à décider avec C4.

### A1 de la 2.0 — analyse automatique des parties — 24/10/2026

- [x] **Service sans écran** (`AutoAnalysisService` des deux côtés) : file de
      parties, UNE à la fois, par le même `AnalysisViewModel` que l'écran
      d'analyse (mêmes verdicts) ; le bilan est recopié dans la partie
      enregistrée. Déclenché à la fin d'une partie contre l'ordinateur
      (standard seulement) si l'utilisateur l'a accepté.
- [x] **Garde-fous identiques** : rien sans accord ; rien en économie d'énergie
      ni appareil bridé ; interrompu en arrière-plan, repris au retour ;
      arrêtable (bandeau « Analyse de votre partie en cours », « Arrêter »).
- [x] **Proposition à l'accueil**, une fois, après la visite guidée (« Activer »
      / « Plus tard » / « Non merci ») ; réglage « Analyser mes parties
      automatiquement » dans Réglages. Local à l'appareil, hors iCloud.
- [x] Tests : `AutoAnalysisServiceTests` (iOS, moteur réel) et
      `AutoAnalysisServiceTest` (Android, Galaxy A16), verts.
- [ ] **Écart assumé pour l'instant** : ni `BGProcessingTask` (iOS) ni service
      de premier plan (Android) — l'analyse s'arrête quand l'app quitte
      l'avant-plan, des DEUX côtés (donc pas de divergence). À décider après
      mesure de batterie réelle (S1 : non mesurée, USB).
- [ ] **À vérifier sur appareil** : la proposition (Android : extra d'intent
      `autoAnalysisPrompt` en build débogable ; iOS : réinitialiser le choix)
      et le bandeau pendant une vraie partie.

### A1 — correctif du conflit avec l'analyse de l'utilisateur — 24/10/2026

Retour de l'iPhone 17 Pro : l'analyse de fond « se bloque à l'avant-dernier coup »
et gêne l'analyse que l'utilisateur ouvre en fin de partie. Cause : le process
moteur est UNIQUE (iOS) / le verrou du moteur est tenu pendant toute la revue
(Android) — deux analyses ne peuvent pas coexister.
- [x] **L'écran de l'utilisateur passe toujours avant.** iOS : tout
      `EngineController` / `FairyEngineController` « réserve » le moteur à son
      démarrage (`acquireUserEngine`) ; le service s'arrête, rend le moteur,
      puis l'écran démarre. Android : `EngineService.use` prévient le service
      (`userWillUse`) avant de prendre le verrou ; le travail de fond passe
      `background = true`. Reprise 3 s après la libération du moteur.
- [x] **Le travail déjà fait n'est pas perdu** (cache disque par coup) : l'écran
      de l'utilisateur le relit, le service reprend ensuite sur le cache.
- [x] **Garde-fou contre le blocage** : 2 minutes sans progrès = échec ; moteur
      indisponible = échec ; trois échecs d'une partie = on y renonce.
- [x] Tests : `yieldsEngineToUserAnalysisThenResumes` (iOS),
      `yieldsEngineToUserThenResumes` (Android, Galaxy A16).
- [ ] À revérifier sur appareil en conditions réelles (fin de partie, tap sur
      « Analyser » pendant que le fond travaille).

### A2 de la 2.0 — puzzles automatiques depuis les parties analysées — 24/10/2026

- [x] Quand une partie est analysée, **ses** erreurs (jamais celles de
      l'ordinateur) et ses mats manqués deviennent des puzzles « Mes parties » :
      les mats d'abord, puis les fautes les plus coûteuses ; **trois au plus**
      par partie ; une position déjà présente est sautée. iOS
      `AutoAnalysisService.createPuzzles`, Android `createOwnPuzzles`.
- [x] Pastille d'accueil « N nouveaux puzzles de votre dernière partie » (tap =
      ouvre les puzzles, efface la pastille). Compteur local à l'appareil.
- [x] Tests : `createsOwnPuzzlesFromUserMistakes` (iOS), `createsOwnPuzzleFromMissedMate`
      (Android, Galaxy A16), verts.

### B1 de la 2.0 — le Coach : ce que jouent les humains de votre niveau — 24/10/2026

- [x] Sous l'explication d'un coup, une ligne « Coach · 13 % des joueurs de
      niveau 1200 jouent ce coup : erreur typique. Le plus courant : g6
      (55 %). » et, en dessous, la mise en garde « D'après Maia : ce que jouent
      les humains, pas ce qui est bon ». Pour une faute : *erreur typique*
      (≥ 8 % des joueurs), *accident* (< 3 %), ou le chiffre seul entre les
      deux ; pour un bon coup : seulement s'il est *rare* (< 4 %). Seuils
      identiques des deux côtés (`HumanMoveCoach`).
- [x] Niveau interrogé = celui choisi à la création de la dernière partie
      (1200 par défaut), borné à 600–2600. `PlayerLevel` n'existe plus (retiré
      avec l'adaptatif le 06/09) : le niveau estimé (B2) le remplacera s'il
      est validé.
- [x] Calculé à la demande, mis en cache, jamais pour l'analyse de fond.
- [x] Tests : `HumanMoveCoachTests` + `CoachExplanationUITests` (iOS),
      `HumanMoveCoachTest` + `AnalysisReviewTest.leCoachDitCeQueJouentLesHumains`
      (Android, Galaxy A16).
- [ ] Écart : le texte d'aide « Analyser » mentionne le Coach côté iOS ; Android
      n'a pas d'écran d'aide équivalent (écart antérieur, voir plus haut).

### A3 de la 2.0 — sorties de répertoire → révisions FSRS — 24/10/2026

- [x] À la fin de l'analyse automatique d'une partie, le premier coup où
      l'utilisateur QUITTE son répertoire met la position AVANT ce coup dans
      les révisions (note « encore »). Si l'adversaire a quitté la théorie le
      premier, ou si la ligne s'arrête, rien n'est signalé. Un coup que le cours
      note `inaccuracy` ou `refutation` compte comme une sortie. Une sortie par
      partie au plus. iOS `RepertoireExitDetector`, Android
      `courses/RepertoireExitDetector.kt`.
- [x] « Répertoire suivi » = les répertoires **personnels** (tout compte) et les
      cours livrés **étudiés** (seules comptent les positions réellement
      révisées : jouer 1.d4 une fois ne « quitte » pas l'Italienne). iOS y ajoute
      les cours marqués (`RepertoireMembership`).
- [x] Pastille d'accueil « N positions de votre répertoire à revoir » (tap =
      ouvre les ouvertures, efface la pastille). Compteur local à l'appareil.
- [x] Tests : `RepertoireExitDetectorTests` + `RepertoireExitServiceTests` (iOS) ;
      `RepertoireExitDetectorTest` (JVM, 8) + `RepertoireExitTest` (Galaxy A16).
- **Constat** : `RepertoireStore.toggle` (l'étoile « mon répertoire ») n'a plus
  aucun appelant côté iOS — le marquage n'est offert nulle part, donc
  `RepertoireMembership` reste vide hors données d'un ancien iCloud. Android n'a
  jamais eu ce marquage. Pas un écart : les deux apps se comportent pareil.
- [ ] Non affiché dans l'analyse du coup (« Coup 6 : vous avez quitté votre
      répertoire… ») : seule la pastille et la révision existent. À décider.
- [ ] À vérifier sur appareil en conditions réelles : un répertoire personnel,
      une partie qui en sort, la pastille puis la séance du lendemain.

### A4 de la 2.0 — profil de faiblesses dans Progression — 24/10/2026

- [x] Carte « Vos parties » (dès trois parties analysées contre l'ordinateur) :
      précision sur les dix dernières parties et écart avec les dix d'avant ;
      **point faible** = la phase (ouverture / milieu de partie / finale, même
      classifieur que les puzzles) où l'on perd le plus de points de probabilité
      de gain par coup hors théorie (une phase demande 8 coups pour être jugée) ;
      **tactiques manquées** (mat, pièce en prise, fourchette, découverte,
      clouage, autres) ; **ouvertures coûteuses** (deux parties et six coups hors
      théorie au moins). Mêmes seuils et mêmes libellés des deux côtés.
- [x] Données par partie, additives : iOS `GameRecord` (+5 champs optionnels,
      synchronisés), Android Room v11 (`MIGRATION_10_11`, +5 colonnes).
      Écrites avec les métriques, relues sans recalcul. `nil` = analysée avant
      A4 : la partie compte pour la précision, pas pour le reste.
- [x] Tests : `PlayerProfileTests` (iOS, 8) + `AutoAnalysisServiceTests` (avec
      moteur) ; `PlayerProfileTest` (JVM, 8) + `AutoAnalysisServiceTest` +
      `MigrationTest` (Galaxy A16).
- [ ] Les parties déjà analysées avant A4 ne portent pas de profil : elles
      seront comptées quand elles seront réanalysées. À décider : proposer
      « Réanalyser mes parties » ?
- [ ] À vérifier sur appareil : l'aspect de la carte avec de vraies données
      (aucune capture n'a été faite — pas de jeu de données semé).

### A5 de la 2.0 — Séance du jour + série de jours (et accueil C7) — 24/10/2026

- [x] Carte « Séance du jour » en tête de l'accueil (flamme + série) ; un tap
      ouvre l'écran des étapes : **ouvertures dues** → **puzzles ratés** →
      **puzzles de vos parties** → **une finale**, chaque étape ouvrant l'écran
      existant. Une étape est « faite » quand il n'y a plus rien à y revoir
      (comptes relus au retour) ; la finale l'est une fois ouverte. La finale
      tourne : une par jour, jours depuis l'epoch modulo le nombre de finales
      (même règle des deux côtés). iOS `DailySession/`, Android `dailysession/`.
- [x] Série de jours, locale à l'appareil : un jour compte quand une position
      d'ouverture est révisée, un puzzle tenté (Woodpecker compris) ou la finale
      de la séance ouverte. Les révisions auto de A3 n'y comptent pas. Elle vit
      jusqu'à la fin d'un jour manqué (aujourd'hui vide → on compte jusqu'à hier).
- [x] Tests : `DailySessionTests` (7) + `DailySessionUITests` (iOS) ;
      `DailySessionTest` JVM (6) + instrumenté (Galaxy A16).
- [x] **Séance courte** (retour utilisateur, 24/10) : au plus 10 positions
      d'ouverture et 5 puzzles par étape, plafond réellement appliqué aux écrans
      (`PuzzleSessionFilter.limit`, `reviewLimit` / `TrainMode.Session`) ; le reste
      attend demain. Durée réglable par l'utilisateur : non faite.
- [ ] Pas de notification (décision du 24/10). La série n'est pas synchronisée.
- [ ] À vérifier sur appareil : aspect de la carte Android (iOS vérifié au
      simulateur), enchaînement réel des étapes.

### C5 de la 2.0 — Ouvertures et Finales vivantes — 24/10/2026

- [x] Chaque carte de cours porte une **vignette de plateau** (ouverture : la
      position après dix demi-coups de la ligne principale ; finale : la position
      de départ), une **pastille de niveau** (Club ambre, Avancé rose) et une
      **barre de maîtrise** « N / M travaillées » (positions révisées / positions
      à réviser du cours). iOS `MiniBoardView` + `CourseCardInfo`, Android
      `ui/MiniBoard.kt` + `courses/CourseCardInfo.kt`. Vérifié sur simulateur et
      Galaxy A16.
- [x] Tests : `CourseCardsTest` (Galaxy A16) ; suites `AppTest`, `TrainingTest`,
      `RepertoireImportTest` toujours vertes.
- [ ] Pas de pastille « Débutant » : le catalogue ne porte que Club et Avancé.

### C6 de la 2.0 — l'écran Analyser repensé — 24/10/2026

- [x] La **dernière partie** passe en tête, dans une carte : joueurs, résultat,
      date, ouverture reconnue et précision du joueur quand elle est analysée,
      puis deux gestes — « Analyser » et « Mats manqués » (ouvre l'analyse déjà
      réglée sur la recherche des mats). Scanner et Bibliothèque deviennent deux
      grandes tuiles côte à côte. « Autres sources » inchangé.
- [x] Tests : `AnalysisEntryUITests` (iOS), `AnalysisEntryTest` (Galaxy A16) ;
      `LibraryScreenTest`, `AnalysisReviewTest`, `ScannerFlowUITests` verts.
- [ ] Aspect Android non vu à l'écran (seul le comportement est testé).

### C8 de la 2.0 — médailles de série et comparaison Woodpecker — 25/10/2026

- [x] **Médailles de série** (3 bronze, 7 argent, 30 or, 100 platine, 365
      diamant) : sous la série dans la Séance du jour, en pastille colorée sur
      la carte d'accueil, confettis le jour où un palier est franchi et la
      séance terminée. `StreakMedal` des deux côtés, mêmes paliers et teintes.
- [x] **Bilan de cycle Woodpecker** : barres « Trouvés » et « Temps » (ancien
      cycle pâle contre le nouveau) et mention « Plus rapide de … » quand le
      cycle est à la fois plus rapide et au moins aussi juste. `CycleComparison`.
- [x] Tests : `StreakMedalTests` / `StreakMedalTest` (JVM), `DailySessionTest`
      et `PuzzleDeviceFlowTest` (Galaxy A16), `WoodpeckerUITests` et
      `DailySessionUITests` (iOS) verts.
- [x] **Fin de partie** : mini-courbe du **matériel** au fil de la partie sous
      le résultat (dès 3 demi-coups), sans moteur — celui-ci reste tenu par
      l'écran de jeu. Précision et coups clés restent dans Analyser.
      `GameOverMaterialCurveUITests` (iOS), `PlaySetupTest` (Galaxy A16).
- [ ] Aspect Android non vu à l'écran.

### Écrans de réglage de partie — Limite de temps et options colorées — 25/10/2026

- [x] Interrupteur **« Limite de temps »**, éteint par défaut, dans les quatre
      écrans (ordinateur, deux joueurs, Chess960, variantes) : les familles de
      cadence (chacune sa couleur) et leurs préréglages n'apparaissent qu'une
      fois allumé. `TimeLimitSelection` / `TimeLimitSection` (iOS),
      `TimeLimitState` / `TimeLimitSection` (Android).
- [x] La **dernière cadence** est mémorisée par écran, même interrupteur éteint
      (clé `timeLimit.<écran>` côté iOS, préférences `time_limit` côté Android).
- [x] Options **colorisées** par groupe (couleur ambre, livre or, départ violet,
      aides rose, orientation violette…) : puces et interrupteurs prennent la
      teinte de leur section.
- [x] Plafond d'ouvertures de la séance du jour **réglable** (2 / 5 / 8,
      5 par défaut) dans les Réglages.
- [x] Correctifs trouvés par les suites complètes : relecture des métriques de
      partie (phases vides), cache des cours Android (accès concurrent).

### Filtre « Classiques » des Ouvertures — 25/10/2026

- [x] Une puce **« Classiques »** à côté de Club et Avancé : les 19 ouvertures
      les plus jouées (Italienne, Espagnole, Écossaise, Gambit du Roi, London,
      Gambit-Dame accepté et refusé, Anglaise, Réti, Catalane, Najdorf, Dragon,
      Française, Caro-Kann, Scandinave, Petrov, Est-Indienne, Nimzo-Indienne,
      Slave). Liste identique : `OpeningCatalogFeature.classicIDs` (iOS) et
      `CourseRepository.CLASSIC_IDS` (Android). Se range dans le sélecteur **Niveau** (Tous / Classiques / Club / Avancé, un seul
      choix), à côté du sélecteur **Camp** (Tous / Blancs / Noirs, pastilles blanche
      et noire) ; les répertoires importés y échappent. Absente pour les finales.
- [x] Tests : `ClassicOpeningsTests`, `OpeningsModuleUITests` (iOS),
      `CourseCardsTest` (Galaxy A16).

### Cote de puzzle : l'indice coûte des points — 25/10/2026

- [x] Un puzzle **réussi avec l'indice** ne fait plus monter la cote : son score vaut
      le score attendu moins 0,15 (`hintPenalty` / `HINT_PENALTY`), soit environ −3
      points sur un puzzle de son niveau (un échec franc : environ −10). Le puzzle
      reste « réussi » pour la répétition espacée. Même règle des deux côtés.
- [x] Tests : `PuzzleRatingTests` (iOS), `PuzzleRatingTest` (JVM).

### Aide, visite guidée et nouveautés 2.0 — 25/10/2026

- [x] **Aide** mise à jour : nouveautés 2.0, Séance du jour, cote de puzzle et indice,
      analyse/Coach/profil, limite de temps, filtres des Ouvertures ; cartes
      « Revoir la visite guidée » et « Revoir les nouveautés ».
- [x] **Visite guidée** complète : treize étapes (séance du jour et limite de temps
      s'ajoutent) ; `DiscoveryTourController` a deux parcours (`full`, `whatsNew`).
- [x] **Parcours des nouveautés 2.0** (six étapes, mêmes cibles) proposé une seule fois
      à qui met à jour depuis la 1.x : visite complète déjà vue sur cette installation et
      `whatsNewSeenVersion` ≠ « 2.0 ». Une installation neuve voit la visite complète
      seulement. L'identifiant `whatsNewID` / `WHATS_NEW_ID` se change à la version
      majeure suivante.
- [x] **Analyse automatique : plus de question au démarrage.** L'offre vit sur l'écran
      de fin de partie (« Voir vos erreurs sans rien faire ? », [Oui, automatiquement] /
      [Non merci]), au plus deux fois, tant que le choix n'est pas fait ; la partie qui
      vient de finir rejoint la file si on accepte. Texte du réglage reformulé.
- [x] Tests : `DiscoveryTourStepsTests`, `DiscoveryTourUITests`,
      `GameOverMaterialCurveUITests` (iOS) ; `DiscoveryTourTest` (JVM et Galaxy A16).
- [x] **Version 2.0** posée le 25/10/2026 : iOS `MARKETING_VERSION` 2.0, build 18 (la 1.9.2 build 17 est
      soumise) ; Android `versionName` « 2.0 » (le `versionCode` s'incrémente seul, prochain : voir
      `version.properties`). Le correctif tactile iOS 18 de la 1.9.2 est déjà dans `main` (commit c093460).

### Reprise de partie depuis l'écran de réglages — 27/10/2026

- [x] Retour d'un joueur : la flèche de retour le menait à « Nouvelle partie », où « Commencer »
      effaçait sa partie sans prévenir. L'écran de réglages montre désormais une carte
      **« Reprendre la partie en cours »** (nombre de coups), et « Commencer » **demande** :
      Reprendre / Remplacer / Annuler. iOS : `NewGameSetupView` (`setupResumeGame`,
      alerte « Une partie est en cours ») ; Android : `NewGameScreen` (`reprendre-depuis-reglages`).
- [x] Test iOS `ResumeGameUITests` vert. **Test Android `PlaySetupTest` écrit mais NON exécuté** :
      le Galaxy n'était pas branché au moment de l'écrire. À lancer.

### Plantage à la reprise d'une partie : droit de roque périmé — 27/10/2026

- [x] Retour d'un joueur : l'app plantait **à chaque reprise** de sa partie, dans Stockfish (`Position::set`).
      Cause : la FEN de la bibliothèque d'échecs (ChessKit, et son pendant Kotlin) **garde le droit de roque
      d'un camp quand sa tour est prise dans son coin** (ici la tour a8, prise par Fxa8). Stockfish balaie alors la
      rangée à la recherche de la tour, sans borne, et lit hors de l'échiquier. Corrigé des deux côtés par un
      garde-fou avant le moteur : `UCIPositionSanitizer` (iOS, Stockfish et Fairy) / `UciPositionSanitizer`
      (Android, Stockfish et Fairy) — un droit n'est gardé que si un roi et une tour du camp, du bon côté,
      sont sur la rangée de fond.
- [x] Tests : `CastlingRightsTests`, `UCIPositionSanitizerTests`, `ResumeFromDiskUITests` (la partie réelle du
      joueur, rejouée sur simulateur) ; `UciPositionSanitizerTest` (JVM).
- [ ] La cause racine (la bibliothèque qui garde le droit) n'est PAS corrigée : le garde-fou la masque pour le moteur.
      D'autres usages de la FEN (export, partage) la gardent telle quelle.

### B3 de la 2.0 — cote de puzzle personnelle et « À mon niveau » — 24/10/2026

- [x] Cote Glicko (`PuzzleRating`, mêmes formules des deux côtés, 1500 ±350 au
      départ, plancher d'incertitude 60), mise à jour à chaque puzzle COTÉ de
      la bibliothèque — indice = réussi, puzzles maison et Woodpecker exclus.
- [x] Chip « À mon niveau » (fenêtre ±100 à ±250 selon l'incertitude), cote
      affichée sur l'écran de choix (« ≈ » tant que moins de 10 puzzles).
- [x] Elle voyage : clé iCloud `puzzleRating.v1` (iOS), `.clab` (Android, la
      cote la mieux informée l'emporte).
- Tests : `PuzzleRatingTests` / `PuzzleRatingTest`, convergence vérifiée sur
  600 puzzles simulés ; `PuzzleDeviceFlowTest.laSerieAMonNiveau…` et
  `TransferTest` sur Galaxy A16.

### Consultation contre l'ordinateur : par coup complet — 23/10/2026

Demande de l'utilisateur, faite des deux côtés : les flèches « coup
précédent / suivant » avancent et reculent d'un COUP COMPLET, vers les
positions où c'est au joueur de jouer — « Reprendre ici » y reprend donc
toujours SA partie. Même règle pure (`ReviewStepper`), parité inversée pour une
partie commencée avec les Noirs au trait. La liste des coups mène toujours au
demi-coup choisi. Les variantes ne sont pas concernées.

- [x] Android : `ReviewStepperTest` (JVM) ;
      `PlaySetupTest.reprendreIciTronqueLaPartieEtSAnnule` réécrit — UN recul,
      puis « Reprendre ici » rend la main au joueur — vert sur Galaxy A16.

### Méthode Woodpecker — 23/10/2026

Troisième suggestion du testeur, faite des deux côtés. Décisions de
l'utilisateur : le programme ne touche PAS la répétition espacée ; lots de 25,
50 ou 100 (50 par défaut) — ramenés à 10, 25 ou 50 (25 par défaut) le même jour ; ordre MÉLANGÉ à chaque cycle ; nombre d'essais du
réglage habituel ; réussi avec l'indice = réussi.

- [x] **Carte « Méthode Woodpecker »** sur l'écran de choix : créer un programme
      avec les critères choisis (taille 10/25/50), ou reprendre / arrêter celui
      en cours. Vérifié sur Galaxy A16
      (`AppTest.aWoodpeckerProgrammeCanBeCreatedResumedAndStopped`).
- [x] **Écran de résolution en mode programme** : « Cycle n · k/N » et le chrono
      du cycle (temps ACTIF, en pause hors du premier plan) sur leur propre
      ligne, pas de « Passer », pas de score de séance. Vu sur Galaxy A16.
- [x] **Bilan de fin de cycle** (score et temps, cycle précédent, objectif =
      moitié du temps) et « Commencer le cycle n+1 » : vérifié en JVM
      (`WoodpeckerPlanTest`), puis joué jusqu'au bout sur le Galaxy le 23/10 au
      soir : `PuzzleDeviceFlowTest` résout dix VRAIS puzzles de la
      bibliothèque coup par coup (ripostes comprises), voit le bilan, lance le
      cycle 2, et vérifie que la répétition espacée n'a rien reçu.
- [x] **Même plan des deux côtés** (`WoodpeckerPlan`), copie des puzzles dans le
      plan, plan stocké en un bloc JSON ; Room v10 (`woodpecker_programs`),
      migration vérifiée sur appareil (`MigrationTest`).
- [x] **Écart restant — le `.clab` ne transporte pas les programmes Woodpecker**,
      pas plus que la progression puzzle par puzzle (voir plus bas) ; iOS les
      fait voyager par iCloud. À traiter avec elle.
- [x] **Corrigé au passage (Android, lot B)** : la demande « Mats manqués »
      tenait dans un drapeau du view model, qui vit autant que l'activité — une
      deuxième partie terminée n'aurait plus déclenché la recherche. Clé par
      partie, oubliée à la sortie de l'écran.

### Mats manqués en fin de partie — 23/10/2026

Deuxième suggestion du testeur, faite des deux côtés. Vérifié par tests (iOS :
`MissedMateDetectorTests`, `MissedMateScanIntegrationTests` avec le vrai
moteur ; Android : `MissedMateDetectorTest` en JVM,
`AnalysisReviewTest.lesMatsManquesSontProposesPuisAjoutes` et
`PlaySetupTest.laFinDePartieProposeLesMatsManques` sur émulateur). **Galaxy
A16, 23/10** : ces trois tests, et toute la classe `AnalysisReviewTest`, verts.

- [x] **Bouton « Mats manqués »** en fin de partie contre l'ordinateur, à côté
      d'« Analyser » : ouvre l'analyse, qui cherche d'elle-même après la revue.
- [x] **« Chercher les mats manqués »** dans le menu de l'analyse, pour toute
      partie.
- [x] **Mêmes règles des deux côtés** (`MissedMateDetector`) : les deux camps,
      mat en 5 au plus, présélection à 97 % de gain, recherche dédiée au budget
      des puzzles, autre chemin vers le mat non compté, ligne COMPLÈTE jusqu'au
      mat (pas de `PuzzleSolutionTrimmer`), position déjà présente sautée.
- [x] **Proposition avant enregistrement** : « Coup 23, Blancs : mat en 2 —
      L'ajouter à vos puzzles ? », mêmes phrases FR/EN. Puzzles thème « Mat »,
      provenance « Mes parties ».
- [x] **Corrigé au passage (Android seul)** : une partie abandonnée dans les
      premières secondes se ROUVRAIT quand le modèle Maia finissait de charger
      (`refresh` relisait « partie finie » sur l'échiquier seul). iOS n'a pas ce
      défaut.

### Puzzles : provenance, « Ratés », mats alternatifs — 23/10/2026

Suggestions d'un testeur, faites des deux côtés dans le même chantier.
Vérifié par tests (iOS : `PuzzleSessionDrawerTests` ; Android :
`PuzzleAnswerTest` en JVM, `AppTest.ownGamesHideTheLevelFilter` sur
émulateur). **Galaxy A16, 23/10** : `AppTest.ownGamesHideTheLevelFilter` et
`puzzlesLoadFromTheLibrary` verts — la provenance est cochée. « Ratés » et le
mat alternatif : cochés le 23/10 au soir — `PuzzleDeviceFlowTest` les joue
À TRAVERS L'ÉCRAN sur le Galaxy (puzzle raté → revient dans « Ratés » →
réussi par l'autre mat → quitte la série). Ce test a révélé que l'écran de
résolution n'affichait JAMAIS son message d'état : une série vide montrait
l'ancien plateau sous « Trouvez le meilleur coup ». Corrigé (`EmptySeries`).

- [x] **Groupe « Provenance »** (Toutes · Mes parties · Bibliothèque) sur
      l'écran de choix. C'est iOS qui rattrapait Android ici : Android avait
      un sélecteur Lichess / Mes parties AU-DESSUS DU PLATEAU, iOS rien — ses
      puzzles maison se noyaient dans les ~100 000 de la bibliothèque. Le
      sélecteur Android a rejoint l'écran de choix, comme les autres critères ;
      « Lichess » s'appelle désormais « Bibliothèque », comme sur iOS.
      « Mes parties » masque le groupe « Niveau » (aucune cote).
- [x] **Groupe « Historique » : Tous · Ratés.** Ratés = dernière tentative
      échouée (`failureCount > 0 && repetitions == 0`), échéance IGNORÉE.
      Réussi avec l'indice = réussi (décision du 23/10). Android retire de la
      file un puzzle réussi en série « Ratés ».
- [x] **Un coup qui mate est toujours juste**, même hors solution enregistrée,
      et clôt le puzzle. Android juge une promotion hors solution une fois la
      pièce choisie.
- [x] **Doublons** : iOS ne recrée plus un puzzle maison pour une position
      déjà présente (Android le faisait déjà, `OwnPuzzleDao.countFor`).
- [x] **Écart restant — le `.clab` ne transporte pas la progression puzzle
      par puzzle**, seulement deux compteurs. Après un transfert, la série
      « Ratés » est vide sur le nouvel appareil, et la répétition espacée
      repart de zéro. iOS fait voyager cette progression par iCloud
      (`PuzzleProgress`). À ajouter au `TransferFile` (table `puzzle_progress`).
- [x] **Écart restant — un puzzle maison Android n'a pas de PHASE**
      (`OwnPuzzle.toPuzzle()` la met à `null`) : un filtre de phase l'exclut,
      alors qu'iOS la calcule à la création (`GamePhaseClassifier`).
      **Fait le 24/10/2026** : `GamePhase.classify`, pendant exact de
      `GamePhaseClassifier` (iOS, mêmes seuils, mêmes positions de test),
      calcule la phase dans `OwnPuzzle.toPuzzle()`. Et le `.clab` transporte
      désormais la progression puzzle par puzzle ET les programmes Woodpecker
      (la mise à jour la plus récente l'emporte, comme la synchro iCloud
      d'iOS) — `TransferTest.lesRatesEtLesProgrammesWoodpeckerVoyagent`, vert
      sur Galaxy A16 : un téléphone vidé retrouve ses ratés et son programme.

### iPhone Duo (iOS, 13/10/2026) — rien à porter

Le chantier iPhone Duo d'iOS (voir `PROGRESS.md`, 13/10) donne aux écrans
d'échiquier un panneau à DROITE dès que la place est nettement plus large que
haute, replie la barre latérale sur un échiquier trop serré, et laisse tourner
l'app sur un écran assez grand. Android faisait déjà l'équivalent : rotation
libre, et `BoardScaffold` met plateau et panneau côte à côte dès que la
fenêtre est plus large que haute, sur TOUS les écrans d'échiquier. Pas de barre
latérale côté Android, donc pas de repli. Aucun écart créé.

### Module « Variantes » — l'INTERFACE alignée sur iOS — FAIT le 20/09
Relevé en comparant les deux catalogues ligne à ligne. Rien ne fonctionnait
mal : les douze variantes se jouaient. C'est le VOCABULAIRE et la PRÉSENTATION
qui divergeaient, et cela ne se voit qu'en posant les deux téléphones côte à
côte.

- [x] **Les descriptions des règles étaient des textes DIFFÉRENTS.** Android
      avait des résumés de deux lignes écrits pour lui ; iOS des explications
      complètes. Exemple : Android disait « Toute capture fait exploser la case
      d'arrivée et ses voisines, pions exceptés » quand iOS précise lesquelles,
      et ce qu'il advient du roi. Les douze textes viennent désormais d'iOS,
      dans les deux langues.
- [x] **Antichecs → Antéchecs.** Une faute d'orthographe dans le nom d'une
      variante, présente depuis l'origine.
- [x] **Quatre sous-titres** reformulés : « Le roi au centre » → « Roi au
      centre », « Échec trois fois gagne » → « Échec trois fois », « Un canard
      bloque » → « Le canard bloque », « Les murs se déplacent » → « Ils bougent
      chaque coup ».
- [x] **Six tuiles sur douze étaient à la mauvaise place.** L'ordre du hub va
      du plus familier au plus dépaysant — il n'est ni alphabétique ni
      technique. Le Crazyhouse passait avant les Antéchecs, le Duck Chess avant
      le Coup Volé, et les Barricades siégeaient au milieu alors qu'elles
      ferment la marche. Un test JVM le verrouille désormais.
- [x] **Trois teintes divergeaient** : les Barricades étaient grises au lieu
      d'ambrées, et le Duck Chess et le Coup Volé avaient leurs couleurs
      ÉCHANGÉES. C'est à la couleur qu'on reconnaît une tuile d'un coup d'œil.
- [x] **Le Duck Chess portait une PATTE** en guise d'icône. La variante doit
      son nom à un canard, qu'on voit ensuite sur le plateau.
- [x] **Les noms COURTS** — « Roi colline », « 3 échecs », « Course rois »,
      « Canard », « Murs mobiles » — n'existaient pas. iOS les affiche sur
      iPhone ; Android laissait le nom long passer à la ligne. La tuile choisit
      maintenant selon la place, comme iOS selon sa classe de taille.
- [x] **Le titre de l'écran** disait « Variantes », comme la tuile d'accueil.
      iOS distingue les deux : la tuile dit « Variantes », l'écran « Variantes
      d'échecs ».

**Un écart ASSUMÉ**, et il est volontaire : le texte du Coup Volé garde son
paramètre. iOS écrit « tous les 7 coups (réglable de 4 à 8) » en dur ; Android
affiche l'intervalle RÉEL, et sa plage va de 2 à 12. Recopier iOS aurait
introduit un texte faux.

### Module « Variantes » — la REVUE de partie et la place des règles — 20/09

- [x] **L'analyse d'une partie de variante n'avait pas de COURBE
      d'évaluation.** iOS en pose une sous la barre de navigation, dans les
      trois écrans de revue de variante (`VariantAnalysisView`,
      `Chess960AnalysisView`, `DuckChessAnalysisView`) ; Android n'en avait que
      dans l'analyse orthodoxe. Elle dit d'un coup d'œil OÙ la partie a basculé,
      et un appui y saute. Le composant existait déjà (`EvalCurve.kt`) : il ne
      manquait que les points, et donc le cache des évaluations en pions que la
      passe de classification ne gardait pas.
- [x] **Ni carte de PRÉCISION.** Elle vient juste dessous sur iOS, dans les
      mêmes trois écrans. Le calcul est celui du mode « Contre l'ordinateur »,
      et vit désormais dans `VariantAccuracy.kt` — pendant exact de
      `VariantAccuracy.swift`, huit tests JVM à l'appui.
- [x] **Les deux se COMPLÈTENT au fil de la passe** au lieu d'apparaître d'un
      coup à la fin, comme sur iOS où ce sont des propriétés calculées lues au
      cache. La courbe s'allonge, les pastilles se posent, le pourcentage
      s'affine.
      *Prouvé le 01/10 sur l'émulateur téléphone : `VariantAnalysisTest.
      laRevueSeCompleteAuFilDeLaPasse` relève la courbe PENDANT la passe et
      exige de l'y voir partielle avant qu'elle soit entière.*
- [x] **L'écran de JEU affichait les règles de la variante** au-dessus du
      plateau, sur deux à quatre lignes prises au plateau. Aucun écran de jeu
      iOS ne le fait : les règles se lisent sur l'écran de réglages, avant de
      lancer la partie. Elles y sont désormais dans une section « Règle », avec
      l'icône et la teinte de la variante — la présentation d'iOS
      (`FairyVariantSetupView.ruleSummary`).

### La passe de vérification SUR APPAREIL — 20/09

Tout ce que la revue avait produit et que personne n'avait encore vu à l'écran,
repris un par un sur le Galaxy A16.

- [x] **La revue d'une partie de Crazyhouse** : 1.e4 Cf6 2.d4 Cxe4, abandon,
      revue. Trente et une pièces sur l'échiquier, la réserve n'y est pas — le
      cavalier fantôme a disparu. Avec, au passage, le titre « Analyse —
      Crazyhouse », la barre d'évaluation, la pastille de qualité sur e4, le
      compteur « 4 / 4 », la courbe, les précisions et les capsules « 1. e4 ·
      Cf6 ?! · 2. d4 ?? · Cxe4 ».
- [x] **Le menu d'export** de la revue : copier la position, copier la partie,
      partager l'une ou l'autre — les quatre entrées d'iOS.
- [x] **L'alerte de coup risqué** répond « Ignorer » / « Reprendre le coup ».
- [x] **« Analyser la dernière partie »** du Laboratoire ouvre bien la dernière
      partie de la série (Défense Nimzo-indienne, 37 demi-coups, `Dh2#`).
- [x] **La bande de reprise** : « Reprendre la partie en cours », « 2 coups
      joués ».
- [x] **Les libellés de puzzles** : la puce « Découverte », et « Tous les
      puzzles, mélangés ».

### Les DOUZE fins de partie, jugées sur le vrai moteur — 20/09

- [x] **Onze variantes sur douze vérifiées SUR APPAREIL** contre les FEN que
      Fairy-Stockfish rend vraiment (`VariantEndingsTest`) : chaque variante
      reçoit une position à un coup de la fin, le coup est joué PAR LE MOTEUR,
      et c'est sa réponse qui est jugée. Les onze verdicts sont exacts —
      vainqueur et raison.

      Les tests JVM de `VariantOutcome` travaillent sur des FEN écrites à la
      main : ils vérifient le raisonnement, pas le CONTRAT avec le moteur. Or
      c'est là qu'on s'était déjà trompé — le septième champ des Trois Échecs
      ne se voyait dans aucun journal.
- [x] La douzième, le **Duck Chess**, est arbitrée dans l'app sans moteur :
      elle se vérifie autrement, et ne l'est pas encore.

### La phrase de victoire, et un écart ASSUMÉ au Duck Chess — 20/09

- [x] **La phrase de fin s'affiche vraiment** (`VariantVictoryTest`) : une
      partie de Roi de la colline jouée coup par coup PAR OÙ LES DOIGTS
      PASSENT, sur l'appareil, avec le vrai moteur pour arbitre, jusqu'à
      « Blancs a gagné (roi au centre) ». `VariantEndingsTest` prouvait le
      verdict ; celui-ci prouve qu'il arrive jusqu'aux yeux.

**~~Un écart ASSUMÉ~~ — TRANCHÉ le 21/09, et c'était bien iOS qui était en
tort** : au Duck Chess, iOS annonçait la fin comme un « échec et mat »
(`GameOutcome(reason: .checkmate)`), alors que son propre générateur de
notation écrit, commentaire à l'appui, qu'il n'y a « ni échec ni mat » dans
cette variante — on y gagne en CAPTURANT le roi. iOS a reçu la raison qui
manquait (`.kingCaptured`, « roi capturé ») ; les deux apps disent maintenant
la même chose. Voir la section du 21/09 en fin de document.

### La barre d'évaluation, activée PAR DÉFAUT — 20/09

Demandé le 20/09 : « par défaut je veux que la barre d'évaluation soit activée
dans les paramètres, dans tous les modes ».

En le faisant, on a trouvé qu'**iOS n'était pas cohérent avec lui-même** : les
variantes Fairy l'avaient à `true`, Chess960 et le mode « Contre l'ordinateur »
à `false`. Android l'avait à `false` partout. Les deux apps la mettent
maintenant à `true` dans les quatre endroits — c'est la seule fois de la revue
où iOS a été touché, et c'est une décision produit, pas une correction de
parité.

- [x] Vérifié à l'écran sur une variante JAMAIS ouverte (Atomique) : les trois
      aides sont actives d'emblée.
- [x] Les réglages DÉJÀ enregistrés gardent leur valeur — c'est le
      comportement voulu d'un changement de défaut, mais il faudra basculer
      l'interrupteur une fois dans les modes déjà configurés.
      **Clos le 01/10 : ce n'est pas un écart.** iOS se comporte de même — un défaut qui change ne réécrit pas un choix déjà fait.

### Ce que la suite sur appareil a rattrapé — 20/09

Les 118 tests instrumentés ont tourné sur le Galaxy A16 après la revue : trois
échecs, tous dus à la revue elle-même, et l'un d'eux n'était pas qu'un test.

- [x] **La capsule d'état du moteur était MUETTE.** Son étiquette était posée
      sur la rangée et non sur le texte, et Compose ne fusionne pas les
      descendants d'une `Row` ordinaire : ni le lecteur d'écran ni les tests
      n'y lisaient rien. `semantics(mergeDescendants = true)`.
- [x] Deux tests attendaient l'ancienne mise en page : les réglages réordonnés
      mettent le temps de réflexion hors de l'écran (un clic sur un nœud non
      affiché échoue), et le hub affiche « King Hill » et non « King of the
      Hill » sur une tuile étroite — ce qui EST le comportement d'iOS.

**Ce que le troisième a appris** : la capsule retombe sur « Moteur en attente »
dès que l'évaluation affichée sort du CACHE de la revue plutôt que de l'analyse
en direct — `depth` y est remis à zéro. iOS fait exactement pareil
(`isLiveAnalyzing` faux → « Moteur en attente »), donc le portage est fidèle ;
c'est le test qui présumait le contraire. Il attend désormais que le moteur
PROPOSE un coup, seul signal franc depuis que le chiffre vit dans la barre.

**118 tests sur 118 verts** après correction.

### Modules « Réglages », « Puzzles », « Éditeur » — 20/09

- [x] **Les Réglages n'étaient pas dans l'ordre d'iOS** (vérifié à l'écran) :
      la langue vient d'abord — c'est le réglage qu'on vient changer —, puis ce
      qui se voit sur le plateau, puis ce qui change la façon de travailler, et
      enfin l'aide et les licences.
- [x] **Sons et vibrations faisaient DEUX sections** ; iOS n'en fait qu'une,
      « Sons et vibrations ». Ce sont les deux façons dont l'app répond au
      doigt.
- [x] **Deux notes d'iOS manquaient** : « Le PGN exporté reste en notation
      anglaise — c'est le standard… » et « Avec un seul essai, on calcule la
      variante jusqu'au bout avant de jouer… ». Android en avait écrit une
      troisième, jumelle de la seconde : retirée, deux phrases qui disent la
      même chose l'une sous l'autre se lisent moins bien qu'une.
- [x] **L'éditeur de position ne savait pas COPIER la FEN** (vérifié à
      l'écran). iOS a le bouton depuis toujours ; ici il fallait la recopier au
      clavier.
- [x] **Deux libellés de puzzles** : « Tous les puzzles » → « Tous les puzzles,
      mélangés », et la puce « Attaque à la découverte » raccourcie en
      « Découverte » — sur cet écran seulement, comme iOS, le libellé entier
      restant à la résolution.

**RETIRÉS le 20/09, sur décision** : la section « Temps de réflexion du
moteur » — le temps est figé à 900 ms, la valeur d'iOS — et le grand aperçu du
plateau, remplacé par une vignette dans CHAQUE ligne de thème, avec ses vraies
pièces, comme iOS.

**Conformes, vérifiés en lisant les deux codes** : la Progression (bilan,
par niveau, par personnage, par difficulté, à travailler, mémorisation), le
Scanner (photo, galerie, recadrage, confirmation, témoin d'activité), le mode
Deux joueurs, la bibliothèque de parties.

### Modules « Laboratoire », « Ouvertures » et « Finales » — 20/09

- [x] **On ne pouvait pas revoir la dernière partie d'une série.** iOS propose
      « Analyser la dernière partie » sous les statistiques ; côté Android il
      fallait exporter le PGN de TOUTE la série et le recoller dans l'analyse
      pour en regarder une seule.
- [x] **Le lecteur de cours ne disait rien au bout d'une ligne.** « Suivant »
      devenait gris, et c'était tout. iOS écrit « Fin de la ligne. Reviens en
      arrière pour explorer une variante » — le mot manquait, et avec lui
      l'invitation à aller voir les variantes.
- [x] **L'engagement de la maison manquait au pied de la liste des finales**
      (vérifié à l'écran le 20/09) : « Chaque ligne de ces cours est vérifiée
      par table de finales (Syzygy)… ». C'est lui qui dit ce que ces cours
      valent.
- [x] Deux libellés recalés : « Parties dans la série » → « Nombre de
      parties », et « Ni un FEN légal, ni un PGN lisible. » → « Ni un FEN ni un
      PGN reconnaissable. »

**Un écart de FORME toujours ouvert** : iOS règle une série sur un écran dédié
(`LabSetupView`) puis la fait tourner sur un autre (`LabRunView`) ; Android
tient les réglages sous le plateau, sur un seul écran. C'était noté « assumé »
le 15/09 ; la demande du 20/09 (« identique à iOS ») le remet en question. Le
refaire en deux écrans est un chantier à part, à décider.

### Modules « Analyser » et « Accueil » — 20/09

- [x] **La ligne d'état du moteur disait « profondeur 18 ».** iOS a renoncé à
      ce mot, commentaire à l'appui : il ne dit rien à qui ne connaît pas les
      moteurs. Devient « L'ordinateur calcule — 18 coups d'avance », dans une
      capsule au-dessus du plateau, avec le point qui s'allume.
- [x] **L'écran avait SA barre d'évaluation** : un ruban vert et bleu de 8 dp,
      doublé d'une carte répétant le chiffre, la profondeur et le début de la
      variante. iOS n'a ni la carte ni la variante — le score est DANS la barre,
      et les coups du moteur sont dans la barre des candidats juste dessous.
      Remplacée par la barre partagée.
- [x] **La bande des coups était coincée dans la rangée de navigation**, à
      côté de cinq boutons : deux capsules y tenaient. Elle passe en pleine
      largeur, en fin de panneau, sous un titre « Coups joués » — la place
      qu'elle a sur iOS.
- [x] **Trois formats de nombres divergeaient.** L'éval d'un candidat
      s'écrivait « +0,44 » (deux décimales, virgule de la locale) contre
      « +0.4 » sur iOS, et « +M5 » là où iOS écrit « M5 ». La précision
      s'écrivait « 97,1 % » contre « 97% ». L'écart de gain affichait « −0 % »
      quand le coup n'avait rien coûté ; iOS écrit « ≈ 0 % », en gris.
- [x] **Les puzzles créés depuis les gaffes** se disaient « ajoutés à vos
      puzzles maison » ; iOS renvoie vers le mode Puzzles, et nomme la raison
      quand il n'y en a aucun.
      **Fait (constaté le 01/10)** : `analysis_puzzles_created` et `analysis_no_puzzles` reprennent mot pour mot les deux phrases d'iOS, et `AnalysisScreen` les emploie.
- [x] **La bande de reprise de l'accueil** disait « Reprendre » puis le nom de
      l'adversaire. iOS annonce ce qu'on reprend et où en est la partie :
      « Reprendre la partie en cours », « 14 coups joués ».

**RETIRÉE le 20/09, sur décision** : la bande « Réviser » de l'accueil, qu'iOS
n'a pas. On révise désormais en passant par la tuile Ouvertures, comme sur
iPhone.

**Les tuiles de l'accueil sont conformes** : les huit titres, sous-titres longs
et courts sont ceux d'iOS, et le choix long/court suit la largeur comme sa
classe de taille.

### Module « Variantes » — la REVUE DE FOND du 20/09

Revue demandée : « Android doit être identique à iOS ». Faite en lisant les
deux codes écran par écran, puis en comparant les textes affichés des deux
côtés. Ce qui suit a été trouvé, et corrigé.

**Deux DÉFAUTS, pas des écarts d'apparence :**

- [x] **La revue d'une partie de Crazyhouse posait la RÉSERVE sur
      l'échiquier.** L'écran de jeu assainissait la FEN du moteur, l'écran de
      revue la donnait brute à `chesskit` — qui ne lève jamais d'exception et
      rend une position plausible. Un cavalier capturé apparaissait en h1.
      Toutes les lectures passent désormais par `VariantFen.forChessKit`,
      pendant de `VariantFEN.swift`, et cinq tests le verrouillent.
- [x] **La FEN des Trois Échecs était ILLISIBLE.** Fairy-Stockfish y glisse un
      septième champ (« 3+3 », les échecs restants) ; `chesskit` en attend six
      exactement et rendait `null`. Tout ce qui en dépendait retombait
      silencieusement sur rien. Le champ est retiré au même endroit.

**Ce qu'Android ne disait pas :**

- [x] **Aucune partie de variante ne disait QUI avait gagné.** Le moteur
      annonçait « plus aucun coup légal » et l'écran affichait « Partie
      terminée ». iOS dit « Vous avez gagné (roi au centre) ». Porté :
      `VariantOutcome.kt` (pendant d'`EngineLegalityVariant.outcome` et de
      `FairyVariant.specialOutcome`) et `VariantDrawRules.kt` — dont la règle
      du matériel insuffisant, qui ne vaut QUE dans les variantes où l'on
      gagne par mat. Douze tests JVM.
- [x] **Le compteur des Trois Échecs n'existait pas.** C'est la ressource qui
      décide la partie ; iOS l'affiche en permanence sur chaque bandeau
      joueur. Lu dans la FEN du moteur (`ThreeCheckFen`).
- [x] **Les coups s'affichaient en UCI** — « b5b6 a7b6 » — là où iOS écrit
      « b6 axb6 ». Portés : `VariantSan.kt` (d'`EngineLegalitySAN.swift`) et
      `DuckChessSan.kt` (de `DuckChessSAN.swift`, avec son « ++ » et sans
      échec ni mat). Le Coup Volé fournissait déjà sa notation. Douze tests.
- [x] **L'écran de jeu n'avait pas de BANDE DES COUPS** : un « 12 demi-coups »
      disait seulement qu'il s'était passé quelque chose.
- [x] **Les bandeaux joueurs n'existaient pas.** Une ligne de pendule nue, et
      seulement s'il y avait une cadence : sans horloge, rien ne disait qui
      jouait quoi. iOS montre « Ordinateur » / « Vous », l'icône, le témoin de
      réflexion, le compteur d'échecs et la pendule.
- [x] **La revue n'avait ni titre propre, ni menu d'export.** « Analyse —
      Horde » désormais, et copier/partager la FEN et le PGN comme iOS.

**Ce qui était là mais pas pareil :**

- [x] **La barre d'évaluation** : 8 dp sans rien écrit, contre 20 pt avec le
      score DEDANS, un repère d'égalité au milieu, dégradés et liseré côté
      iOS. Refaite à l'identique, et elle sert une dizaine d'écrans. Son score
      s'écrit « +1.5 », avec un point, dans les deux langues — comme iOS, dont
      le `String(format:)` travaille en locale POSIX.
- [x] **Le ruban de coups** était du texte posé sur le fond ; iOS en fait des
      CAPSULES bordées de la couleur de la catégorie, le coup courant en
      dégradé d'accent. Refait, et partagé par les deux écrans d'analyse comme
      chez iOS. Il se CENTRE maintenant sur le coup affiché au lieu de rester
      collé à la fin.
- [x] **La pastille de qualité** (« !! », « ?? ») se pose désormais SUR la case
      d'arrivée, dans les deux écrans d'analyse, au lieu d'une ligne de texte
      à côté du plateau.
- [x] **La barre de navigation de la revue** est une carte portant le compteur
      « 4 / 10 » au milieu, la progression de la passe à côté — la forme
      d'iOS —, au lieu de quatre flèches alignées à gauche et d'une barre de
      progression sur sa propre ligne.
- [x] **L'alerte de coup risqué** répondait « Le garder » / « Annuler » ;
      iOS répond « Ignorer » / « Reprendre le coup ». « Annuler » disait à la
      fois « annuler le coup » et « annuler la boîte ».

**Vérifié sur appareil** (Galaxy A16, 20/09) : le hub, la section « Règle », la
revue d'une partie de Horde (titre, barre, pastille, courbe, précision,
capsules en notation), une partie de Trois Échecs (bandeaux, compteur, bande
des coups). **Pas encore vérifié sur appareil** : les fins de partie des douze
variantes, une par une.

Au passage, `EvalCurve` rend maintenant le DEMI-COUP touché, comme
`EvalCurveView.swift`, au lieu de l'index du coup : c'est l'appelant qui
traduit dans sa propre numérotation. L'analyse orthodoxe compte les coups
(−1 = départ), les variantes comptent les demi-coups ; le composant partagé
n'avait pas à connaître l'une des deux.

### Les décisions prises le 20/09

Quatre points laissés au choix, tranchés :

- [x] **La bande « Réviser » de l'accueil** : RETIRÉE. iOS ne l'a pas.
- [x] **Le réglage « Temps de réflexion du moteur »** : RETIRÉ. Le temps sans
      pendule est figé à 900 ms — la valeur d'iOS (`PlayViewModel.baseMovetime`).
      Deux apps qui ne réfléchissent pas aussi longtemps ne jouent pas au même
      niveau.
- [x] **Le grand aperçu du plateau** des réglages : RETIRÉ, remplacé par une
      vignette dans chaque ligne de thème — six cases, six vraies pièces, comme
      `piecePreview` d'iOS. Android montrait des pastilles de deux couleurs
      PUIS un grand échiquier à part : deux endroits pour une seule question,
      et aucun ne disait à quoi ressemble une pièce sur ce thème.
- [x] **Le Laboratoire reste à UN écran.** iOS en a deux (réglages, puis
      série). Écart de forme assumé, décidé le 20/09 après l'avoir rouvert.
- [x] **Le Duck Chess garde « Roi capturé »**, contre l'« échec et mat » d'iOS
      — voir plus haut : c'est iOS qui se contredit. **Repris le 21/09** :
      plutôt que de garder deux phrases, c'est iOS qui a été corrigé.

## ⬜ Écart OUVERT — les tablettes, 19/09/2026

**iOS s'adapte à l'iPad, Android ne s'adapte pas aux tablettes.** Dix fichiers
Swift lisent `horizontalSizeClass` pour remettre en page sur grand écran ;
Android n'a aucun équivalent, et la découverte s'est faite en prenant les
captures d'écran de tablette pour la fiche Play.

Mesuré sur un émulateur 2560 × 1600 :

- **l'accueil** étale ses huit tuiles sur une rangée de sept plus une
  orpheline, et laisse les deux tiers inférieurs vides ;
- **l'entrée de l'analyse** montre trois lignes puis 70 % de noir ;
- **une partie** place bien le plateau à gauche — la mise en page paysage
  fonctionne — mais la colonne de droite est vide aux trois quarts et le
  plateau colle au bord ;
- seul **l'écran de nouvelle partie** tient : sa grille de personnages remplit
  la largeur.

L'app MARCHE, elle n'est pas mise en page. Rien n'est cassé, rien n'est
inaccessible.

**Décision du 19/09 : on publie sans captures de tablette.** Google affichera
« conçue pour les téléphones », ce qui est exact. Publier les captures telles
quelles aurait desservi la fiche — une app aux deux tiers vide se referme.

**FAIT le 20/09**, mesuré sur l'émulateur 2560 × 1600 (1280 × 800 dp) :

- [x] **Accueil** : la grille est bornée à la mesure de lecture et centrée —
      trois colonnes de trois, au lieu de sept plus une orpheline.
- [x] **Entrée de l'analyse** : bornée et centrée.
- [x] **Partie** : le plateau prend la hauteur à gauche, la colonne de droite
      est plafonnée à 420 dp — sans cap, les commandes s'éparpillaient d'un
      bord à l'autre — et elle porte maintenant la LISTE DES COUPS, qui se
      cachait derrière un bouton. C'est ce que fait l'iPad : il y a la place,
      la feuille modale n'a plus lieu d'être.
- [x] **Listes d'ouvertures et de finales** : bornées à la mesure de lecture,
      champ de recherche compris. **PAS en deux colonnes** : c'était le plan du
      19/09, mais iOS ne le fait pas — il n'a ni grille ni deux colonnes sur
      ces écrans, et le suivre aurait fabriqué une divergence au lieu d'en
      corriger une.
- [x] **Les captures, prises le 20/09** — quatre jeux de six : 10 pouces
      (2560 × 1600) et 7 pouces (1200 × 1920), en français et en anglais.

      Deux pièges rencontrés. Le premier : les images 10 pouces étaient parties
      dans le créneau `tablet-screenshots`, réservé au 7 pouces — le script
      prend le dossier en argument, et rien ne vérifie que la taille
      correspond. Le second : enchaîner les passes dans une même boucle échoue
      en silence, l'émulateur de la précédente n'étant pas encore libéré. Une
      par une, elles passent.

**Ce que les captures montrent, et la décision qui reste** : le 7 pouces en
PORTRAIT est le plus flatteur — deux colonnes qui remplissent l'écran. Le
10 pouces en paysage garde environ un cinquième de vide sous la grille de
l'accueil ; les autres écrans (nouvelle partie, ouvertures, analyse) tiennent
la largeur. Le motif du 19/09 — « une app aux deux tiers vide se referme » —
ne tient plus, mais l'accueil en paysage n'est pas éclatant pour autant.
Publier ou non ces captures reste une décision produit.

Le gabarit vit dans `ui/Layout.kt` : `Metrics.readableWidth` (720 dp, la valeur
d'iOS), les deux largeurs minimales de tuile, et le seuil de 600 dp au-delà
duquel on n'est plus sur un téléphone.

**Un piège Compose, documenté dans le code** : `fillMaxWidth()` AVANT
`widthIn()` perd la borne, sans erreur ni avertissement — le premier fixe la
largeur au maximum du parent, le second ne peut plus la réduire. L'ordre
correct est `widthIn` d'abord. La première tentative n'avait aucun effet
visible, et c'est une capture d'écran qui l'a dit.

Ce chantier a gagné en importance le 19/09 : viser le SDK 36 fait qu'Android 16
IGNORE les restrictions de redimensionnement sur grand écran. L'app y sera
redimensionnable qu'on le veuille ou non.

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

### Modules « Ouvertures » et « Finales » — FAIT le 15/09
- [x] **Les noms de cours sont TRADUITS**. Le nom (« Italian Game », « The
      Opposition ») est une chaîne unique dans `opening_catalog.json` ; iOS
      s'en sert comme clé de traduction et affiche « Partie italienne ».
      Android lisait le nom brut : cent trente-six titres anglais dans une app
      en français, dont les 78 finales. La table est GÉNÉRÉE au build depuis
      `Localizable.xcstrings` (`generateCourseNames`) — pas recopiée dans Git,
      pour qu'une traduction changée d'un côté n'ait pas à être reportée de
      l'autre. Un test refuse tout cours dont le nom n'a pas de français.
- [x] **La recherche garde le nom d'ORIGINE** : taper « Sicilian » dans une app
      en français trouve la Sicilienne, comme sur iOS.
- [x] **Les lignes du répertoire tiennent sur UNE ligne** : le nom de la
      variante passe à droite au lieu de s'empiler sous le coup, comme sur
      iOS — huit branches faisaient sinon descendre le répertoire hors de
      l'écran. Marges alignées (16 dp) et étiquettes rendues à leur taille.
- [x] **« À mémoriser »**, l'étiquette du coup critique, manquait à Android.

### Module « Puzzles » — les COULEURS — FAIT le 15/09
- [x] **Le palier, pas la cote brute** : l'en-tête affichait « 1 742 » là où iOS
      dit « Confirmé ». Quatre paliers lisibles, c'est le choix explicite de
      `DifficultyTier`, et la cote nue le défaisait.
- [x] **Les teintes des paliers** étaient différentes des deux côtés
      (vert-bleu-jaune-rouge contre vert-bleu-ambre-rose) : celles d'iOS font foi.
- [x] **La phase a sa couleur et son icône** — ouverture en turquoise,
      milieu en violet, finale en ambre. Android la peignait toujours en bleu,
      sans icône.
- [x] **Les pastilles sont CERCLÉES** : sur fond sombre, un aplat à 15 % se
      confond avec la surface et la pastille redevient du texte gris.
- [x] **Chaque groupe de filtres a sa couleur** (niveau vert, phase bleue,
      thème ambre) et chaque puce son icône : trois rangées toutes vertes se
      ressemblaient trop pour qu'on retrouve la sienne d'un coup d'œil.
      `ChipButton` accepte désormais une teinte, comme le `FilterChip` d'iOS.

### Interrupteurs et curseurs — FAIT le 15/09 (vu sur appareil)
- [x] **Plus d'interrupteurs VIOLETS.** Material 3 peint un `Switch` sans
      couleurs explicites avec sa teinte primaire par défaut, qui n'est celle
      d'aucun élément de l'app : les Réglages, le Laboratoire et l'éditeur de
      position avaient donc des interrupteurs violets à côté des verts.
      `chessLabSwitchColors()` les tient tous.
- [x] **Plus de piste violette ni de graduations** sur les curseurs :
      `chessLabSliderColors()`. Le curseur de réflexion du Laboratoire
      affichait quatre-vingt-dix-huit points — un pointillé illisible — parce
      que le pas était donné à Material au lieu d'être appliqué à la valeur.
- [x] **« Commencer » monte avec le clavier** sur l'écran de réglage d'une
      variante : saisir un numéro Chess960 ouvrait le clavier PAR-DESSUS le
      bouton, et il fallait deviner qu'il fallait d'abord le refermer.

### Moteur de variantes : une recherche annulée s'ARRÊTE — FAIT le 15/09
Signalé à l'essai : l'app s'arrête net « vers la fin » d'une partie de Horde.
- [x] `FairyEngine.capture` n'arrêtait pas le moteur quand elle sortait sans
      avoir vu `bestmove` — au délai, et surtout à l'ANNULATION. Le verrou
      était rendu pendant que la recherche tournait encore, et l'appelant
      suivant réécrivait la position sous le thread de recherche :
      `SIGSEGV` à l'adresse `0x1470`. `StockfishEngine.search` tenait cette
      discipline depuis toujours ; Fairy ne l'avait jamais eue, et personne ne
      l'annulait avant que la barre d'évaluation et les indices n'arrivent.
- [x] **`MultiPV` revient à 1** même si l'indice est annulé — des trois côtés
      (Fairy, Duck Chess, Coup Volé). Sinon le moteur cherchait trois lignes à
      chaque coup pour le reste de la partie, en silence.

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

## Le Duck Chess, repris des deux côtés — 21/09/2026

Demandé après la revue : « y a-t-il des choses à corriger sur iOS ? ». Il y en
avait une, et la chercher en a montré quatre autres — toutes dans la même
variante, et aucune visible autrement qu'en la jouant.

**Les deux corrections d'iOS** — les seules de la revue, avec la barre
d'évaluation :

- [x] **« Échec et mat » au Duck Chess.** La variante n'a ni échec ni mat : le
      canard masque le coup qui vient, donc on ne peut pas exiger d'un joueur
      qu'il voie la menace, et la partie se gagne en PRENANT le roi. L'app
      écrivait `Dxe8++` sur la bande des coups, puis « échec et mat » dans le
      panneau juste dessous. `GameOutcome.Reason` reçoit `.kingCaptured`
      (« roi capturé » / « king captured »), sa neuvième raison de variante.
- [x] **« Vous a gagné ».** L'écran composait la phrase à la façon du jeu à
      deux — « X a gagné » — avec X valant « Vous ». Les trois autres écrans
      de variante disent « Vous avez gagné (…) » ; le Duck Chess était seul de
      son espèce. La forme nom-verbe ne sert plus qu'à deux, où les camps ont
      des noms.

**Et quatre défauts côté Android**, trouvés en portant la première :

- [x] **La phrase de fin avait sa tournure à elle** — « Roi capturé — les
      blancs gagnent » — quand toutes les autres variantes disent « Vous avez
      gagné (…) » / « Blancs a gagné (…) ». Même forme partout désormais.
- [x] **Le réglage « Deux joueurs » ne servait à rien.** L'écran d'avant le
      proposait, `DuckChessViewModel` ne le lisait pas : la machine jouait
      quand même, et le second joueur regardait. Le modèle connaît maintenant
      un `engineColor` nul, comme iOS ; avec lui partent la barre
      d'évaluation, l'indice et l'alerte de gaffe — trois aides qui demandent
      un adversaire artificiel — et l'abandon demande QUI abandonne.
- [x] **Pas de proposition de NULLE**, qu'iOS offre. Le Duck Chess n'a pas de
      nulle « selon les règles » (ni pat, ni matériel insuffisant : un fou
      seul prend un roi), mais deux joueurs peuvent convenir d'en rester là,
      et le moteur juge comme ailleurs. S'il n'a pas d'avis sous la main —
      barre d'évaluation éteinte — on le lui DEMANDE, au lieu de refuser pour
      une raison étrangère à la position.
- [x] **Les règles s'affichaient encore au-dessus du plateau**, au Duck Chess
      et au Coup Volé. Le chantier du 20/09 les avait retirées de l'écran
      partagé des variantes et oublié les deux variantes ARBITRÉES PAR L'APP,
      qui ont chacune le leur.
- [x] **La règle du Coup Volé montrait son `%1$d`** sur l'écran de réglages :
      c'est la seule dont le texte porte un chiffre, et la section « Règle »
      du 20/09 ne le lui passait pas.
- [x] **Aucun bandeau joueur**, et la ligne de pendule DISPARAISSAIT sans
      cadence : l'écran ne disait alors nulle part qui jouait quoi. Même
      défaut que celui corrigé le 20/09 sur l'écran partagé des variantes, que
      le Duck Chess avait gardé faute d'y passer. Il porte maintenant l'icône,
      « Ordinateur » / « Vous » — ou la couleur, à deux —, le témoin de
      réflexion et la pendule s'il y en a une.

**Prouvé par des parties jouées**, pas par des positions montées :
`DuckChessViewModelTests.kingCaptureIsNotCheckmate` côté iOS et
`DuckChessOutcomeTest` sur l'appareil — 1.e4 f6 2.Dh5 a6 3.Dxe8++ des deux
côtés, plus un test qui attend deux secondes pour prouver qu'à deux la machine
ne joue pas.

**Un écart de FORME laissé ouvert, sur l'écran PARTAGÉ des autres variantes** :
à deux, le Duck Chess nomme désormais les camps comme iOS — « Blancs a gagné
(abandon) », « Noirs a gagné (temps écoulé) » — et demande QUI abandonne. Les
autres variantes disent encore « Vous avez abandonné » et « Temps écoulé —
vous perdez » à deux joueurs, où il n'y a pas de « vous ». À reprendre d'un
seul mouvement pour les onze. Le Coup Volé, lui, annonce le mat par « les
blancs gagnent » (`StolenMoveViewModel`) là où iOS écrit « Vous avez perdu
(échec et mat) » : même famille de défaut, même correctif.

## L'alerte de coup risqué, faussée dans les variantes — 26/09/2026

Signalé depuis la Horde : « l'alerte ne me semble pas tout à fait juste ».
Elle ne l'était pas, et pas seulement à la Horde — les trois modes de variante
étaient touchés. **iOS a toujours eu raison ; c'est Android qui se contredisait
lui-même**, son mode « Contre l'ordinateur » faisant déjà la chose correcte.

**Le défaut** : le moteur annonce `score mate N` **ou** `score cp N`, jamais
les deux — sur un mat, le champ `cp` est simplement ABSENT. Les trois modes de
variante le ramenaient alors à **zéro**, c'est-à-dire à 50 % de probabilité de
gain, l'égalité parfaite, pour une position gagnée ou perdue.

Conséquence, mesurée sur le vrai moteur compilé pour le bureau :

| situation | iOS | Android (avant) |
| --- | --- | --- |
| on gagne (+400), le coup FORCE le mat | rien | « coup risqué, 4 pions perdus » |
| on était maté en 4, le coup en SORT | rien | « coup risqué, 3 pions perdus » |

Dans les deux cas l'app prévenait sur le **meilleur coup de la position**.

**Pourquoi la Horde le montre** : le moteur y rend l'extinction de la horde
comme un **mat** (mesuré : deux pions restants → `mate 5`, un seul → `mate 3`).
Les scores de mat y sont donc bien plus fréquents qu'aux échecs classiques, où
il faut un vrai mat pour en voir un.

- [x] `BlunderAlert.MATE_CENTIPAWNS` et `BlunderAlert.centipawns()` — la
      convention ±10 000 (celle d'`EngineScore.mateCentipawns` sur iOS) n'est
      plus écrite qu'à UN endroit, pour qu'un quatrième mode ne la recopie pas
      de travers.
- [x] Les trois appels corrigés : `VariantPlayViewModel` (les neuf variantes
      arbitrées par le moteur, dont la Horde), `DuckChessViewModel`,
      `StolenMoveViewModel`. Le mode principal, qui avait déjà raison, cite
      désormais la constante au lieu d'un littéral.
- [x] **Duck Chess, seconde divergence au même endroit** : iOS écarte
      VOLONTAIREMENT le mat dans cette variante — le canard peut barrer la
      ligne au coup suivant, donc un mat annoncé n'en est pas un, et la barre
      d'évaluation n'y affiche jamais « M3 ». Android le prenait au sérieux et
      pouvait annoncer « vous concédez un mat » pour une fin que rien ne
      garantit. Aligné.
- [x] Trois tests JVM, dont deux qui affirment AUSSI ce que l'ancien code
      faisait — la raison d'être du correctif est écrite, pas déduite.
- [ ] **Pas encore vérifié sur appareil** : le téléphone n'était pas branché.
      *Toujours vrai le 01/10 : le Galaxy n'était pas branché pour la passe.*

**Une question de FOND — TRANCHÉE le 26/09 : on garde un seuil UNIQUE.** Le
barème est calibré sur les échecs classiques. Mesuré au moteur, l'écart entre
le meilleur et le pire coup d'une position vaut **46 à 56 points** de
probabilité de gain aux échecs, et seulement **17 à 22** à la Horde : le seuil
de 15 points y est donc proportionnellement bien plus sévère, et seul un coup
proche du pire déclenche l'alerte. Un seuil par variante a été envisagé puis
écarté — douze barèmes à calibrer et à tenir, pour une alerte qui se contente
d'être plus discrète là où les positions bougent moins. Ce n'était pas un
défaut, et ce n'en devient pas un.

## Retour d'un testeur anglophone — CORRIGÉ SUR iOS, À PORTER — 28/09/2026

Trois défauts signalés le 27/09 par un testeur sur iPad Pro 13" et iPhone 16,
interface en anglais. Les correctifs sont faits **côté iOS seulement** — la
demande portait explicitement sur l'iPhone et l'iPad. Ce qui suit est donc
l'écart créé ce jour-là, à refermer.

- [x] **Le nom du joueur s'affichait « Vous » dans une interface anglaise.**
      La bibliothèque stocke le mot français EN CLAIR (c'est aussi la
      sentinelle qui dit de quel côté on jouait) et l'affichait tel quel.
      iOS a désormais un point de résolution unique, `PlayerName`
      (`ChessLab/Localization/PlayerName.swift`) : il traduit les noms
      « spéciaux » — « Vous »/« You », « Blancs »/« White »,
      « Noirs »/« Black », « Ordinateur »/« Computer »/« Stockfish » — dans la
      langue DU JOUR, et laisse intact un vrai nom. Le stockage, lui, ne
      change pas : le sentinelle reste le mot français. Vérifier côté Android
      la ligne de bibliothèque, l'accueil, l'en-tête d'analyse et la plaque de
      joueur.
      **Porté le 01/10** : `library/PlayerName.kt`, pendant exact de `PlayerName.swift` — accueil, bibliothèque (ligne, recherche, suppression), en-tête d'analyse, plaque du joueur, annonce TalkBack, plaques des variantes. Android avait le même défaut dans la bibliothèque.
- [x] **Aucun réglage pour se renommer.** iOS ajoute `AppSettings.playerName`
      (clé `settings.playerName`, synchronisée iCloud, nettoyée des
      guillemets/crochets/sauts de ligne et bornée à 40 caractères) et un
      champ « Votre nom » dans Réglages, juste sous la langue. Vide = « Vous ».
      Le nom choisi remplace la sentinelle PARTOUT où elle s'affiche, y compris
      dans les parties déjà enregistrées, et part dans les balises PGN.
      **Porté le 01/10** : `SettingsStore.playerName` (même nettoyage, même borne de 40) et un champ « Votre nom » sous la langue. Vérifié sur tablette (`ParityPassTest`) : le champ écrit le réglage, et le nom arrive sur la plaque pendant la partie.
- [x] **Le PGN exporté n'avait AUCUNE balise ni résultat.** C'était exact :
      `ChessKit.Game.pgn` ne sérialise que les balises renseignées, et l'app
      n'en renseignait aucune. `PGNExport` porte désormais un `Metadata` et
      émet les sept balises obligatoires — Event (le mode, dans la langue de
      l'app), Site « ChessLab », Date « AAAA.MM.JJ », Round « - », White,
      Black, Result (« * » si la partie n'est pas finie) — plus `SetUp`/`FEN`
      pour une position de départ personnalisée. Le résultat clôt aussi le
      movetext. Les neuf exports de VARIANTES, qui assemblaient leurs balises
      à la main, passent par le même constructeur
      (`PGNExport.tagLines(event:white:black:result:variant:startFEN:)`) et
      gagnent au passage les joueurs, le site et la date.
      Côté Android, l'équivalent est `AnalysisViewModel.pgn()` et les exports
      de variantes : même manque à vérifier.
      **Porté le 01/10** : `library/PgnExport.kt`. Android posait déjà joueurs, résultat et date à la FIN de la partie, mais un export PENDANT la partie n'en portait aucune, et Site/Round manquaient toujours. Les sept balises sortent désormais de Jouer, Deux joueurs, l'analyse et des quatre exports de variantes ; le résultat clôt les coups. Douze tests JVM (`PgnExportTest`). L'enrichissement des vieilles parties à la réouverture n'est PAS porté, et n'a pas à l'être : l'enregistreur Android posait déjà leurs balises.

- [x] **Une fenêtre étroite prend la disposition téléphone (29/09).** Le
      quatrième point du testeur, élucidé : ce n'était ni la barre latérale ni
      le paysage, mais la fenêtre RÉDUITE pour partager l'écran. Le rognage
      visible sur ses captures est un artefact de redimensionnement d'iPadOS,
      pas un défaut de l'app (mesuré : à 744 pt rien ne déborde). En revanche
      iPadOS garde la classe `regular` bien en dessous de la largeur d'un
      écran d'iPad, et l'app y montrait encore deux colonnes — barre latérale
      de 290 pt, plateau à 454 pt sur 744. iOS pose désormais une classe de
      taille CORRIGÉE au plus haut de l'arbre (`ChessLab/NarrowWindowLayout.swift`,
      seuil 744 pt = largeur en portrait de l'iPad mini) : sous ce seuil, tous
      les écrans prennent la disposition téléphone, plateau pleine largeur.
      **Côté Android, il n'y a rien d'équivalent à porter tel quel** :
      l'app n'a pas d'ossature à deux colonnes, et ses écrans de jeu ne
      décident que de l'ORIENTATION (`isLandscape()` dans `ui/BoardScaffold.kt`,
      qui lit `LocalConfiguration` — donc la fenêtre, et non l'écran, en
      multi-fenêtre). Ce qui reste à vérifier sur une grande tablette en écran
      partagé : une fenêtre plus large que haute mais ÉTROITE y prend la
      disposition côte à côte, où le plateau est borné par la hauteur — c'est
      exactement le cas qui a mal tourné côté iOS.
      **Clos le 01/10.** Sans ossature à deux colonnes, Android ne peut pas avoir le défaut d'iOS. Son équivalent — le côte à côte dans une petite fenêtre en largeur — est couvert par le garde-fou de `BoardLayout` : le panneau n'y prend jamais plus de la moitié, l'échiquier n'est jamais plus petit qu'avant (`BoardLayoutTest`).
- [x] **Le partage plateau / panneau, revu le 29/09.** Deux règles côté iOS
      (`PlayView`), toutes deux nées d'un essai sur appareil : en paysage, le
      plateau prend son carré et le panneau prend CE QUI RESTE, borné entre
      340 et 420 pt — ils se disputaient la largeur à parts égales et le
      panneau en emportait 43 % dans une fenêtre réduite ; en colonne unique,
      la liste des coups passe dans la feuille dès que `hauteur − largeur`
      tombe sous 330 pt, au lieu de rogner l'échiquier. Gains mesurés : 626 →
      706 pt en paysage sur 13", 401 → 463 sur mini, 916 → 1032 en portrait
      barre repliée. Côté Android, `BoardScaffold` partage lui aussi le
      paysage entre plateau et panneau : vérifier dans quelle proportion, et
      ce que devient la liste des coups quand la fenêtre est basse.
      **Porté le 01/10** : `ui/BoardLayout.kt` dans `BoardScaffold`, `PlayScreen` et `TwoPlayerScreen` — trois écrans qui partageaient À PARTS ÉGALES. Le plancher de 340 ne dépasse jamais la moitié de la largeur : Android, contrairement à iOS, met plateau et panneau côte à côte sur un téléphone en paysage. En portrait sur grand écran, la liste des coups passe dans sa feuille quand `hauteur − largeur < 330`, et le bouton « Coups » n'apparaît que lorsqu'elle n'est pas affichée (comme sur iOS). Vu sur la tablette 10" : l'échiquier prend toute la hauteur.

## La passe de réalignement du 01/10/2026

Demandée explicitement : « que l'app Android soit au même niveau » qu'iOS, sans
toucher à iOS. Les cinq écarts nés côté iOS les 28-29/09 sont refermés plus haut.
La passe en a trouvé d'autres, qu'aucune liste ne portait.

- [x] **Les écrans de JEU des variantes n'avaient pas de menu d'export.** iOS en
      a un sur chacun (copier la position, copier ou partager la partie) ;
      Android ne l'avait que sur la REVUE. On ne pouvait pas envoyer une partie
      en cours. Ajouté aux trois écrans (générique, Duck Chess, Coup Volé), avec
      un score PGN (`pgnResult`) posé à chaque fin de partie — mat, verdict de
      la variante, abandon, nulle, drapeau — et transmis à la revue, dont
      l'export le porte désormais. Le Coup Volé annote `[jeton]` comme iOS.
      Vérifié sur tablette (`ParityPassTest`).
- [x] **L'import n'écartait AUCUN doublon.** Réimporter le même fichier doublait
      la bibliothèque, et analyser cinq fois une partie collée la rangeait cinq
      fois. iOS reconnaît une partie par ses joueurs et ses coups :
      `library/GameSignature.kt` en est le pendant (« ? » vaut absent), et le
      message dit combien étaient déjà là. Sept tests JVM.
- [x] **Les noms des thèmes de plateau étaient écrits en dur en français** :
      « Classique, Bleu, Noyer » au milieu d'un écran anglais, là où iOS dit
      « Classic, Blue, Walnut ». Les traductions existaient, inutilisées. Le
      quatrième s'appelle comme sur iOS : « Contraste élevé » / « High
      contrast ». Un balayage du code ne trouve plus d'autre texte affiché qui
      échappe aux ressources.
- [x] **La visite guidée du premier lancement, vérifiée de bout en bout**, à la
      demande : installation VIERGE sur l'émulateur téléphone (Pixel 7) puis
      tablette (10"), les onze étapes parcourues, chaque projecteur sur sa
      cible, « Done » ramène à l'accueil, et elle ne revient pas au lancement
      suivant. Elle n'est posée « vue » qu'à la fin ou à l'abandon — une
      recréation d'activité en cours de route ne la perd donc pas.
- [x] **Le README annonçait quatre manques qui n'existaient plus** (Crazyhouse,
      surchauffe, affinage, écrans annexes) : réécrit.

**La suite instrumentée complète**, sur l'émulateur tablette (le Galaxy n'était
pas branché) : 119 réussis, 6 échecs, tous expliqués.

- [x] **Quatre venaient de la passe**, et c'est le comportement voulu : sur grand
      écran, la liste des coups est affichée et le bouton « Coups » n'existe
      plus — or `AppTest` (×3) et `StaleAnswerTest` le touchaient, écrits pour
      le Galaxy où il reste. Ils ouvrent désormais la feuille SI le bouton est
      là, et lisent la liste directement sinon. Repassés : 30/30 sur tablette,
      33/33 sur téléphone.
- [x] **`VariantVictoryTest` n'avait pas de règle de langue** : il ne passait
      que sur un appareil réglé en français. Échouait à l'identique sur le code
      d'AVANT la passe. `LanguageRule` ajoutée, il passe sur l'émulateur anglais.
- [ ] **`OpeningIndexTest.taperUnCoupDeLIndexAmeneASaPosition` échoue sur la
      tablette en paysage**, à l'identique sur le code d'avant la passe : la
      puce `fil-4` du fil d'Ariane existe mais sort de sa rangée défilante.
      Probablement le test qui ne la fait pas venir, pas l'écran qui casse —
      à trancher en le regardant.

## Publication Play de la 2.0 (27/10/2026)

- [ ] **Le binaire publié sur Play est une version INTERMÉDIAIRE (AAB versionCode 33), laissée en l'état
      par décision du 27/10.** Le code d'`android/` est, lui, à jour avec iOS 2.0 build 19 : il contient en
      plus le garde-fou de roque (`UciPositionSanitizer`), le récapitulatif « Créer des puzzles ? », le
      libellé « Analyser = revoir vos coups et créer des puzzles avec vos erreurs » et la puce « Ratés »
      grisée quand il n'y en a aucun. Ces changements ne seront dans le binaire qu'à la prochaine
      publication (versionCode ≥ 34, voir `PLAY-2.0.md`).
