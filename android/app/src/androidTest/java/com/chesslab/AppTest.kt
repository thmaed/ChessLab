package com.chesslab

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.rules.RuleChain
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Les tests de bout en bout de l'app. On clique des ÉLÉMENTS NOMMÉS et non des
 * pixels : ils restent valides quand la mise en page bouge.
 *
 * Ce sont les seuls tests du projet qui demandent un appareil ; la couche de
 * règles, elle, se teste sur la JVM en dix secondes.
 */
@RunWith(AndroidJUnit4::class)
class AppTest {

    // La langue passe AVANT l'activité : les assertions sont en français,
    // et l'émulateur, lui, peut être réglé sur n'importe quoi.
    private val compose = createAndroidComposeRule<MainActivity>()

    @get:Rule val rules: RuleChain = RuleChain.outerRule(LanguageRule()).around(compose)

    private fun awaitText(text: String, timeoutMs: Long = 60_000) =
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithText(text, substring = true, ignoreCase = true)
                .fetchSemanticsNodes().isNotEmpty()
        }

    private fun awaitTag(tag: String, timeoutMs: Long = 60_000) =
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty()
        }

    /**
     * Attend que ce soit au camp [name] de jouer, dans une partie à deux.
     *
     * Le mode ne porte plus de ligne d'état depuis l'alignement sur iOS : le
     * trait se lit sur la ligne du joueur DU BAS, qui est justement celle du
     * camp au trait (le plateau pivote vers lui). C'est ce que voit un
     * humain, donc c'est ce que vérifie le test.
     */
    private fun awaitTurn(name: String, timeoutMs: Long = 20_000) =
        compose.waitUntil(timeoutMs) {
            compose.onAllNodes(
                hasTestTag("joueur-bas") and hasText(name, substring = true, ignoreCase = true),
                useUnmergedTree = false,
            ).fetchSemanticsNodes().isNotEmpty()
        }

    /**
     * Ouvre un mode depuis l'accueil.
     *
     * L'accueil défile : une tuile sous la ligne de flottaison existe mais
     * n'est pas à l'écran. On la fait venir avant de la toucher.
     */
    private fun open(mode: String) {
        compose.onNodeWithTag("mode-$mode").performScrollTo().performClick()
    }

    /**
     * Deux joueurs passe d'abord par l'écran de RÉGLAGES — noms, présentation
     * du plateau, cadence — depuis le 12/09. On le traverse avec les valeurs
     * par défaut : c'est bien la partie qu'on vient tester.
     */
    private fun openTwoPlayers() {
        open("two")
        awaitTag("commencer")
        compose.onNodeWithTag("commencer").performClick()
    }

    /**
     * Lance une partie depuis l'accueil, en passant par la configuration —
     * c'est le chemin de l'utilisateur depuis que l'écran « Nouvelle partie »
     * existe, comme sur iOS.
     *
     * [opponent] : le repère d'une vignette de personnage, ou `null` pour
     * Stockfish (qui vit derrière le contrôle segmenté).
     */
    /**
     * Ouvre l'écran de réglage et lance une partie.
     *
     * Les réglages sont MÉMORISÉS d'une partie à l'autre depuis le 14/09 :
     * l'écran peut donc s'ouvrir sur Stockfish, et la galerie des personnages
     * n'est alors pas affichée. On choisit donc explicitement le camp avant
     * de désigner un adversaire — ce que fait aussi l'utilisateur.
     */
    private fun startGame(opponent: String? = null) {
        open("play")
        awaitTag("commencer", 120_000)
        compose.onNodeWithTag(if (opponent == null) "segment-1" else "segment-0").performScrollTo().performClick()
        if (opponent != null) compose.onNodeWithTag(opponent).performScrollTo().performClick()
        compose.onNodeWithTag("commencer").performClick()
        awaitText("À vous de jouer", 120_000)
    }

    /** Ouvre la feuille des coups joués et rend la main quand elle est là. */
    private fun openMoveList() {
        compose.onNodeWithTag("coups-joues").performClick()
        awaitTag("coup-0", 15_000)
    }

    @Test fun theHomeOffersTheModes() {
        compose.onNodeWithTag("mode-play").assertIsDisplayed()
        compose.onNodeWithTag("mode-two").assertIsDisplayed()
        compose.onNodeWithTag("mode-analysis").assertIsDisplayed()
    }

    @Test fun playingAMoveMakesTheEngineReply() {
        startGame()

        compose.onNodeWithTag("case-e2").performClick()
        compose.onNodeWithTag("case-e4").performClick()
        // Le moteur répond, la main revient, et les DEUX demi-coups sont là.
        compose.waitUntil(90_000) {
            compose.onAllNodesWithTag("coups-joues").fetchSemanticsNodes().isNotEmpty()
        }
        compose.waitUntil(90_000) {
            compose.onNodeWithTag("coups-joues").performClick()
            val found = compose.onAllNodesWithTag("coup-1").fetchSemanticsNodes().isNotEmpty()
            if (!found) compose.onNodeWithTag("case-e4").performClick()   // referme la feuille
            found
        }
    }

    @Test fun twoPlayersAlternate() {
        openTwoPlayers()
        awaitTurn("Blancs")

        compose.onNodeWithTag("case-d2").performClick()
        compose.onNodeWithTag("case-d4").performClick()
        awaitTurn("Noirs")

        // le plateau s'est retourné : d7 reste cliquable par son nom
        compose.onNodeWithTag("case-d7").performClick()
        compose.onNodeWithTag("case-d5").performClick()
        awaitTurn("Blancs")
        // La notation reste MASQUÉE pendant la partie (parti pris d'iOS) ;
        // ce qui prouve que les coups ont été joués, c'est la barre de
        // consultation, qui n'apparaît qu'à partir du premier.
        awaitTag("transport")
    }

    /**
     * Le mode Deux joueurs sait finir une partie autrement que par le mat :
     * l'un des deux abandonne, et c'est SON nom qui décide du résultat.
     */
    @Test fun twoPlayersCanResign() {
        openTwoPlayers()
        awaitTurn("Blancs")
        compose.onNodeWithTag("case-e2").performClick()
        compose.onNodeWithTag("case-e4").performClick()
        awaitTurn("Noirs")

        compose.onNodeWithTag("abandonner-bas").performClick()
        awaitTag("abandon-black")
        compose.onNodeWithTag("abandon-black").performClick()

        awaitTag("fin-de-partie")
        awaitText("Blancs a gagné")
        // La notation se révèle enfin, sur l'écran de résultat.
        compose.onNodeWithTag("notation-finale").assertIsDisplayed()
    }

    /** La nulle par accord : deux joueurs d'accord, et rien d'autre à décider. */
    @Test fun twoPlayersCanAgreeToADraw() {
        openTwoPlayers()
        awaitTurn("Blancs")
        compose.onNodeWithTag("case-d2").performClick()
        compose.onNodeWithTag("case-d4").performClick()
        awaitTurn("Noirs")

        compose.onNodeWithTag("nulle-bas").performClick()
        awaitTag("nulle-confirmer")
        compose.onNodeWithTag("nulle-confirmer").performClick()

        awaitTag("fin-de-partie")
        awaitText("Partie nulle")
    }

    /**
     * On remonte la partie avec la barre de consultation, puis on la RELANCE
     * depuis le coup consulté : les coups suivants sont écartés, et le pion
     * qu'on venait de jouer n'est plus là.
     */
    @Test fun twoPlayersCanResumeFromAPastMove() {
        openTwoPlayers()
        awaitTurn("Blancs")
        compose.onNodeWithTag("case-e2").performClick()
        compose.onNodeWithTag("case-e4").performClick()
        awaitTurn("Noirs")
        compose.onNodeWithTag("case-e7").performClick()
        compose.onNodeWithTag("case-e5").performClick()
        awaitTurn("Blancs")

        compose.onNodeWithTag("precedent").performClick()
        awaitTag("reprendre-ici")
        compose.onNodeWithTag("reprendre-ici").performClick()

        // La partie est repartie après 1. e4 : c'est de nouveau aux Noirs,
        // et l'annulation est offerte pendant quelques secondes.
        awaitTurn("Noirs")
        awaitTag("annuler-reprise")
    }

    @Test fun analysingAPgnShowsAnEvaluation() {
        open("analysis")
        // Analyser ouvre d'abord le CHOIX de la source, comme sur iOS, et
        // « Coller » vit sous « Autres sources » — les chemins qui demandent
        // un travail sont repliés.
        awaitTag("entree-autres", 15_000)
        compose.onNodeWithTag("entree-autres").performScrollTo().performClick()
        awaitTag("entree-coller", 10_000)
        compose.onNodeWithTag("entree-coller").performScrollTo().performClick()
        awaitTag("saisie", 10_000)
        compose.onNodeWithTag("saisie").performTextInput("1. e4 e5 2. Nf3 Nc6 3. Bb5 a6")
        compose.onNodeWithTag("charger").performClick()

        awaitTag("coup-5", 10_000)     // les six demi-coups sont là

        // Le moteur a analysé la position : il PROPOSE un coup. C'est le seul
        // signal franc qui reste depuis que le chiffre d'évaluation s'écrit
        // dans la barre — il s'y efface quand la position est égale, et la
        // ligne d'état retombe sur « Moteur en attente » dès que l'évaluation
        // affichée sort du cache de la revue plutôt que de l'analyse en
        // direct. iOS se comporte pareil.
        compose.waitUntil(60_000) {
            compose.onAllNodesWithTag("candidat-1").fetchSemanticsNodes().isNotEmpty()
        }

        // et on peut remonter dans la partie
        compose.onNodeWithTag("precedent").performClick()
    }

    @Test fun puzzlesLoadFromTheLibrary() {
        open("puzzles")
        // Les puzzles passent d'abord par le CHOIX de la séance, comme sur
        // iOS : on décide ce qu'on travaille avant de résoudre.
        awaitTag("commencer-puzzles", 15_000)
        compose.onNodeWithTag("commencer-puzzles").performClick()
        // la bibliothèque fait 19 Mo : on laisse le temps de la parcourir
        awaitTag("score", 60_000)
        compose.onNodeWithTag("case-e4").assertIsDisplayed()

        compose.onNodeWithTag("passer").performClick()
        awaitTag("score", 10_000)
    }

    @Test fun openingCoursesCanBeRead() {
        open("openings")
        awaitTag("compte")
        // la liste est paresseuse : on filtre pour amener la ligne à l'écran
        compose.onNodeWithTag("recherche").performTextInput("Italian")
        awaitTag("cours-italian-game", 10_000)
        compose.onNodeWithTag("cours-italian-game").performScrollTo().performClick()

        // Le lecteur DESCEND l'arbre : la racine, puis les suites.
        awaitTag("racine")
        compose.onNodeWithTag("case-e4").assertIsDisplayed()
        // le premier coup commenté de la Partie italienne est Fc4, au 5e demi-coup
        // Un clic, puis on laisse l'écran se reposer : enchaîner cinq clics
        // sans respirer détache le nœud sous la main de Compose.
        repeat(5) {
            compose.onNodeWithTag("suivant").performClick()
            compose.waitForIdle()
        }
        awaitTag("commentaire", 10_000)
    }

    @Test fun endgameCoursesAreListedApart() {
        open("endgames")
        awaitTag("compte")
        compose.onNodeWithTag("recherche").performTextInput("Opposition")
        awaitTag("cours-eg-opposition", 10_000)
        // `performScrollTo()` AVANT le tap : le champ de recherche flotte en
        // bas et ouvre le clavier, qui couvre alors une partie de la liste —
        // un tap sur une ligne à moitié cachée atterrit à côté, sans erreur.
        // Le test échouait ensuite soixante secondes sur la page suivante.
        compose.onNodeWithTag("cours-eg-opposition").performScrollTo().performClick()
        awaitTag("racine")
    }

    @Test fun settingsChangeTheBoardTheme() {
        compose.onNodeWithTag("reglages").performClick()
        // Les sections suivent l'ordre d'iOS depuis le 20/09, et une section
        // peut donc être hors de l'écran : un clic sur un nœud non affiché
        // échoue, d'où le défilement.
        //
        // Ni « temps-1000 » ni le plateau d'aperçu ne sont attendus : le
        // réglage du temps de réflexion et le grand aperçu ont été RETIRÉS le
        // 20/09 — iOS n'a ni l'un ni l'autre, et chaque ligne de thème porte
        // désormais ses propres pièces.
        compose.onNodeWithTag("theme-blue").performScrollTo().performClick()
        compose.onNodeWithTag("piece-merida").performScrollTo().performClick()
        compose.onNodeWithTag("theme-blue").performScrollTo().assertIsDisplayed()

        // on repose les valeurs par défaut : un test ne doit pas déteindre
        // sur les suivants, et les réglages sont PERSISTÉS
        compose.onNodeWithTag("theme-classic").performScrollTo().performClick()
        compose.onNodeWithTag("piece-classic").performScrollTo().performClick()
    }

    @Test fun aCharacterPlaysWithMaia() {
        // le réseau fait 43 Mo : son chargement prend du temps
        startGame("adversaire-nadia")

        // Le statut dit « À vous de jouer » AVANT que le réseau soit chargé :
        // le tap tombe alors sur un plateau qui n'écoute pas encore, et rien
        // ne le rejoue — le test attendait ensuite une liste de coups vide.
        // On insiste jusqu'à ce que Nadia se mette à réfléchir, seule preuve
        // que le coup est parti. Rejouer un coup déjà joué ne fait rien : sa
        // case de départ est vide.
        var parti = false
        for (essai in 1..5) {
            compose.onNodeWithTag("case-e2").performClick()
            compose.onNodeWithTag("case-e4").performClick()
            if (runCatching { awaitText("réfléchit", 15_000) }.isSuccess) { parti = true; break }
        }
        require(parti) { "le coup n'est jamais parti : le plateau n'a pas répondu en cinq essais" }

        awaitText("À vous de jouer", 120_000)   // Nadia a répondu
        openMoveList()
        compose.onNodeWithTag("coup-1").assertIsDisplayed()
    }

    @Test fun theLaboratoryPlaysByItself() {
        open("lab")
        // deux Stockfish : pas d'attente de chargement du réseau
        compose.onNodeWithTag("camp-a-stockfish").performClick()
        compose.onNodeWithTag("camp-b-stockfish").performClick()
        // Le bouton vit sous le bilan détaillé, donc bien sous le pli.
        compose.onNodeWithTag("lancer").performScrollTo().performClick()

        awaitTag("coup-3", 120_000)      // quatre demi-coups joués tout seuls
        compose.onNodeWithTag("lancer").performScrollTo().performClick()   // pause
    }

    @Test fun aVariantIsRefereedByTheEngine() {
        open("variants")
        compose.onNodeWithTag("variante-kingofthehill").performClick()
        // Depuis le 15/09, la tuile ouvre un RÉGLAGE : on le valide tel quel.
        compose.onNodeWithTag("commencer").performClick()

        // le moteur doit répondre à `d` et `go perft 1` avant qu'on puisse jouer
        awaitText("À vous de jouer", 60_000)

        compose.onNodeWithTag("case-e2").performClick()
        compose.onNodeWithTag("case-e4").performClick()

        // notre coup, puis celui du moteur : deux demi-coups au compteur
        compose.waitUntil(90_000) {
            compose.onAllNodesWithText("2 demi-coups").fetchSemanticsNodes().isNotEmpty()
        }
    }

    /**
     * Le Crazyhouse s'ouvre et se joue. La RÉSERVE, elle, se vérifie sur le
     * moteur (`EngineTest`) : provoquer une prise à travers l'interface
     * demanderait que l'adversaire veuille bien prendre, ce qu'aucun test ne
     * peut exiger d'un moteur qui réfléchit.
     */
    @Test fun leCrazyhouseSeJoue() {
        open("variants")
        compose.onNodeWithTag("variante-crazyhouse").performScrollTo().performClick()
        // Depuis le 15/09, la tuile ouvre un RÉGLAGE : on le valide tel quel.
        compose.onNodeWithTag("commencer").performClick()
        awaitText("À vous de jouer", 60_000)
        compose.onNodeWithTag("case-e2").performClick()
        compose.onNodeWithTag("case-e4").performClick()
        compose.waitUntil(90_000) {
            compose.onAllNodesWithText("2 demi-coups").fetchSemanticsNodes().isNotEmpty()
        }
    }

    /**
     * Les Barricades se jouent, murs compris. Que le moteur les REFUSE
     * vraiment aux pièces se vérifie sur lui (`EngineTest`) ; ici on vérifie
     * que la variante s'ouvre et avance, c'est-à-dire que la définition a
     * bien été chargée avant que l'écran la demande.
     */
    @Test fun lesBarricadesSeJouent() {
        open("variants")
        compose.onNodeWithTag("variante-barricades").performScrollTo().performClick()
        // Depuis le 15/09, la tuile ouvre un RÉGLAGE : on le valide tel quel.
        compose.onNodeWithTag("commencer").performClick()
        awaitText("À vous de jouer", 60_000)
        compose.onNodeWithTag("case-e2").performClick()
        compose.onNodeWithTag("case-e4").performClick()
        compose.waitUntil(90_000) {
            compose.onAllNodesWithText("2 demi-coups").fetchSemanticsNodes().isNotEmpty()
        }
    }

    /**
     * Les murs mobiles : la position se réécrit entre les coups, et le
     * compteur continue de monter.
     *
     * Le test n'impose AUCUN coup précis : les trois murs se posent au hasard
     * sur les rangées 3 à 6, donc e4 est muré une fois sur cinq environ et
     * « 1.e4 » n'est alors même pas légal. On pousse le premier pion qui
     * accepte de bouger — c'est le va-et-vient qu'on vérifie, pas un coup.
     */
    @Test fun lesBarricadesAleatoiresDeplacentLeursMurs() {
        open("variants")
        compose.onNodeWithTag("variante-randombarricades").performScrollTo().performClick()
        // Depuis le 15/09, la tuile ouvre un RÉGLAGE : on le valide tel quel.
        compose.onNodeWithTag("commencer").performClick()
        awaitText("À vous de jouer", 60_000)

        val pushes = listOf("e2" to "e4", "d2" to "d4", "a2" to "a4", "h2" to "h4", "b2" to "b4", "g2" to "g4")
        for ((from, to) in pushes) {
            compose.onNodeWithTag("case-$from").performClick()
            compose.onNodeWithTag("case-$to").performClick()
            val joue = runCatching {
                compose.waitUntil(20_000) {
                    compose.onAllNodesWithText("demi-coup", substring = true).fetchSemanticsNodes()
                        .isNotEmpty() && compose.onAllNodesWithText("0 demi-coup").fetchSemanticsNodes().isEmpty()
                }
            }.isSuccess
            if (joue) break
        }
        // Notre coup, puis celui du moteur — chacun suivi d'un redéploiement
        // des murs, donc de deux interrogations de plus.
        compose.waitUntil(120_000) {
            compose.onAllNodesWithText("2 demi-coups").fetchSemanticsNodes().isNotEmpty()
        }
    }

    /**
     * Le Duck Chess : un tour en DEUX temps. On déplace une pièce, puis on
     * pose le canard — et c'est la pose qui rend la main. Le compteur ne monte
     * donc que d'un demi-coup par TOUR complet.
     */
    @Test fun leDuckChessSeJoueEnDeuxTemps() {
        open("variants")
        compose.onNodeWithTag("variante-duck").performScrollTo().performClick()
        // Depuis le 15/09, la tuile ouvre un RÉGLAGE : on le valide tel quel.
        compose.onNodeWithTag("commencer").performClick()
        awaitText("À vous de jouer", 30_000)

        compose.onNodeWithTag("case-e2").performClick()
        compose.onNodeWithTag("case-e4").performClick()
        // Le trait n'a PAS changé : le canard reste à poser.
        awaitText("Posez le canard", 10_000)

        compose.onNodeWithTag("case-e5").performClick()
        compose.onNodeWithTag("canard", useUnmergedTree = true).assertExists()

        // L'ordinateur joue son tour entier, canard compris.
        compose.waitUntil(120_000) {
            compose.onAllNodesWithText("2 demi-coups").fetchSemanticsNodes().isNotEmpty()
        }
        awaitText("À vous de jouer", 30_000)
        compose.onNodeWithTag("canard", useUnmergedTree = true).assertExists()
    }

    @Test fun chess960ShufflesTheBackRank() {
        open("variants")
        // Depuis le 13/09, la tuile ouvre un RÉGLAGE : on y choisit la
        // position par son numéro. « Au hasard » retrouve le geste d'avant.
        compose.onNodeWithTag("variante-chess960").performClick()
        compose.onNodeWithTag("hasard-960").performScrollTo().performClick()
        compose.onNodeWithTag("commencer").performClick()
        awaitText("À vous de jouer", 60_000)
        compose.onNodeWithTag("case-a1").assertIsDisplayed()
    }

    @Test fun aFinishedGameLandsInTheLibrary() {
        openTwoPlayers()
        awaitTurn("Blancs")

        // le mat du berger, en sept demi-coups
        val moves = listOf(
            "e2" to "e4", "e7" to "e5",
            "f1" to "c4", "b8" to "c6",
            "d1" to "h5", "g8" to "f6",
            "h5" to "f7",
        )
        for ((from, to) in moves) {
            compose.onNodeWithTag("case-$from").performClick()
            compose.onNodeWithTag("case-$to").performClick()
        }
        // Le résultat porte les NOMS des joueurs, comme sur iOS.
        awaitText("Blancs a gagné", 10_000)

        // la partie doit se retrouver dans la bibliothèque de l'écran Analyser
        compose.onNodeWithTag("retour").performClick()
        open("analysis")
        awaitTag("entree-bibliotheque", 15_000)
        compose.onNodeWithTag("entree-bibliotheque").performScrollTo().performClick()
        awaitText("Blancs — Noirs", 15_000)
    }

    @Test fun anInterruptedGameCanBeResumed() {
        startGame()
        compose.onNodeWithTag("case-d2").performClick()
        compose.onNodeWithTag("case-d4").performClick()
        awaitText("À vous de jouer", 90_000)   // le moteur a répondu

        // on quitte en pleine partie : l'accueil doit proposer de reprendre
        compose.onNodeWithTag("retour").performClick()
        awaitTag("reprendre", 15_000)
        compose.onNodeWithTag("reprendre").performClick()

        awaitText("Partie reprise", 60_000)
        openMoveList()
        compose.onNodeWithTag("coup-1").assertIsDisplayed()
    }

    @Test fun progressionShowsWhatTheAppHasSeen() {
        compose.onNodeWithTag("progression").performClick()
        // Selon ce que la suite a déjà laissé derrière elle, l'écran montre le
        // bilan contre l'ordinateur, les puzzles, la mémorisation — ou dit
        // honnêtement qu'il n'a rien à montrer. Jamais des zéros, et jamais
        // rien du tout : la carte « Mémorisation » manquait à cette liste, et
        // le test tombait dès qu'une séance d'ouvertures précédait la première
        // partie enregistrée.
        // `ignoreCase` n'est pas un détail : les titres de section sont écrits
        // EN CAPITALES, et la comparaison sensible à la casse ne trouvait
        // « Contre l'ordinateur » que lorsqu'une autre carte le sauvait.
        compose.waitUntil(30_000) {
            listOf("Contre l'ordinateur", "Puzzles", "Mémorisation", "Rien à afficher").any { text ->
                compose.onAllNodesWithText(text, substring = true, ignoreCase = true)
                    .fetchSemanticsNodes().isNotEmpty()
            }
        }
    }

    @Test fun soundsCanBeTurnedOff() {
        compose.onNodeWithTag("reglages").performClick()
        awaitText("Sons du plateau", 10_000)
        compose.onNodeWithTag("sons").performClick()
        compose.onNodeWithTag("sons").performClick()   // et remis, pour ne rien laisser derrière
    }

    @Test fun thePositionEditorBuildsAFen() {
        // L'éditeur vit sous Analyser, comme sur iOS, dans « Autres
        // sources » : composer une position est un travail, pas un raccourci.
        open("analysis")
        awaitTag("entree-autres", 15_000)
        compose.onNodeWithTag("entree-autres").performScrollTo().performClick()
        awaitTag("entree-editeur", 10_000)
        compose.onNodeWithTag("entree-editeur").performScrollTo().performClick()
        awaitTag("fen", 10_000)

        // la position de départ, puis l'analyse
        compose.onNodeWithTag("depart").performClick()
        compose.waitUntil(10_000) {
            compose.onAllNodesWithText(
                "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w - - 0 1",
            ).fetchSemanticsNodes().isNotEmpty()
        }

        // une pièce posée à la main change la FEN
        compose.onNodeWithTag("vider").performClick()
        compose.onNodeWithTag("palette-R").performClick()
        compose.onNodeWithTag("case-e1").performClick()
        compose.waitUntil(10_000) {
            compose.onAllNodesWithText("8/8/8/8/8/8/8/4K3 w - - 0 1").fetchSemanticsNodes().isNotEmpty()
        }
    }

    @Test fun helpExplainsWhatTheAppActuallyDoes() {
        compose.onNodeWithTag("aide").performClick()
        awaitText("Les neuf personnages", 10_000)
        awaitText("Le filet de sécurité", 10_000)
    }

    @Test fun licencesListWhatTheAppEmbeds() {
        compose.onNodeWithTag("reglages").performClick()
        compose.onNodeWithTag("licences").performScrollTo().performClick()
        awaitText("Stockfish 17.1", 10_000)
        awaitText("Fairy-Stockfish", 10_000)
        // le dépôt des sources, tout en bas : c'est LUI que la GPLv3 exige
        compose.onNodeWithTag("licence-source").performScrollTo().assertIsDisplayed()
        compose.onNodeWithTag("licence-cburnett").performScrollTo().assertIsDisplayed()
    }

    @Test fun backReturnsHome() {
        open("analysis")
        compose.onNodeWithTag("retour").performClick()
        compose.onNodeWithTag("mode-analysis").assertIsDisplayed()
    }

    @Test fun leJeuResteJouableEnPaysage() {
        openTwoPlayers()
        awaitTurn("Blancs")

        compose.activityRule.scenario.onActivity {
            it.requestedOrientation = android.content.pm.ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
        }
        compose.waitForIdle()

        // Couché, le plateau doit rester ENTIER et cliquable : c'était le
        // défaut — le panneau mangeait la hauteur et seule la 8e rangée
        // restait visible.
        compose.onNodeWithTag("case-a1").assertIsDisplayed()
        compose.onNodeWithTag("case-h8").assertIsDisplayed()
        compose.onNodeWithTag("case-d2").performClick()
        compose.onNodeWithTag("case-d4").performClick()
        awaitTurn("Noirs")

        compose.activityRule.scenario.onActivity {
            it.requestedOrientation = android.content.pm.ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        }
        compose.waitForIdle()
        // Le coup survit à la rotation : l'activité ne se recrée pas.
        awaitTurn("Noirs")
        compose.onNodeWithTag("case-a1").assertIsDisplayed()
    }
}
