import SwiftUI
import UIKit

/// Aide : décrit brièvement chaque module de l'app.
///
/// Volontairement succinct — une carte par module, l'essentiel de ce qu'on y
/// fait. Tous les libellés sont des `LocalizedStringKey` : ils basculent
/// FR/EN comme le reste de l'app.
struct HelpView: View {
    private struct Module: Identifiable {
        let id = UUID()
        let icon: String
        let tint: Color
        let title: LocalizedStringKey
        let body: LocalizedStringKey
    }

    private let modules: [Module] = [
        .init(
            icon: "sparkles", tint: Theme.accent,
            title: "Nouveautés de la version 1.6",
            body: "• Nouveau : le module Variantes. Chess960 (position aléatoire, par numéro ou composée soi-même), et trois variantes de plus — Roi de la colline, Trois échecs, Horde — chacune contre l'ordinateur avec indice, alerte gaffe et barre d'évaluation.\n• Ouvertures repensées : un index en arbre où chaque variante se lit sans doublon, et un tap sur n'importe quel coup ouvre la position.\n• Sous le plateau : les coups des maîtres avec leurs pourcentages, les trois meilleurs coups de Stockfish, et une barre d'évaluation.\n• Les 58 cours d'ouvertures complétés par une seconde passe : les réponses noires qui manquaient sont là.\n• Finales : « Pions électriques » ajoutée — 78 cours — « pion passé éloigné » corrigé, et une recherche par nom comme dans Ouvertures.\n• « Reprendre ici » agit au premier toucher : plus de confirmation, une annulation prend la place du bouton pendant quelques secondes.\n• « Changer de mode » : le même bouton violet sur tous les écrans, au lieu d'être caché dans les menus d'export.\n• Le thème du plateau se choisit dans les Réglages, et s'applique partout.\n• Laboratoire : touchez une statistique (LOS, écart Elo…) pour savoir ce qu'elle mesure.\n• L'app occupe 60 Mo au lieu de 175."
        ),
        .init(
            icon: "cpu", tint: Theme.accent,
            title: "Contre l'ordinateur",
            body: "Jouez une partie contre le moteur Stockfish. Réglez votre couleur, la force de l'adversaire (Elo), la cadence, et les aides : indice (flèches des meilleurs coups), alerte en cas de coup risqué et barre d'évaluation. Après la partie, un bouton mène directement à l'analyse. En cours de partie, « Changer de mode » (en haut à droite) envoie la position affichée vers l'analyse, le Laboratoire ou une partie à deux — la partie vous attend au retour."
        ),
        .init(
            icon: "person.2.fill", tint: Theme.info,
            title: "Deux joueurs",
            body: "Deux personnes jouent sur le même appareil. Le mode « table » retourne les pièces pour rester lisible face à face. La partie terminée s'enregistre dans la bibliothèque."
        ),
        .init(
            icon: "die.face.5.fill", tint: Theme.violet,
            title: "Variantes",
            body: "D'autres façons de jouer aux échecs, présentées en tuiles. Chess960 (Fischer Random) : position de départ tirée au hasard, choisie par numéro (0-959), ou composée vous-même en échangeant les pièces de la première rangée — jeu contre l'ordinateur ou à deux, avec la même analyse de fin de partie qu'en mode « Jouer ». Six variantes de plus, contre l'ordinateur : Roi de la colline (le premier roi au centre gagne), Trois échecs (le troisième échec délivré gagne), Horde (les Blancs n'ont que des pions), Course des rois (le premier roi en 8e rangée gagne, sans jamais mettre l'adversaire en échec), Atomique (chaque capture fait exploser les cases voisines) et Antéchecs (but inversé : perdez toutes vos pièces, ou restez bloqué, pour gagner). Indice, alerte gaffe et barre d'évaluation partout ; la force de l'ordinateur se règle comme ailleurs."
        ),
        .init(
            icon: "puzzlepiece.fill", tint: Theme.violet,
            title: "Puzzles",
            body: "Résolvez des problèmes tactiques, issus de la bibliothèque Lichess embarquée ou générés depuis vos propres erreurs en analyse. Filtrez par niveau, phase de partie et thème. Vous avez UN essai : un puzzle se résout en calculant la variante jusqu'au bout, pas en tentant un coup pour voir. Si vous préférez chercher en tâtonnant, repassez à trois essais dans les Réglages. La répétition espacée planifie les révisions et un bilan suit votre réussite et vos thèmes faibles. « Changer de mode » (en haut à droite) emporte la position du puzzle vers le Laboratoire, l'ordinateur ou Deux joueurs."
        ),
        .init(
            icon: "chart.bar.fill", tint: Theme.rose,
            title: "Progrès",
            body: "Un tableau de bord accessible depuis l'accueil : votre bilan face à l'ordinateur (victoires, nulles, défaites) et vos statistiques de puzzles par thème. Le bilan contre l'ordinateur se filtre sur les 7 ou 30 derniers jours, ou sur tout l'historique. En un tap sur un thème faible, l'app vous prépare un set de puzzles ciblé pour le travailler."
        ),
        .init(
            icon: "books.vertical.fill", tint: Theme.warning,
            title: "Ouvertures",
            body: "Progressez sur 58 ouvertures rédigées à la main et bilingues, toutes relues au moteur. Un index en arbre montre toutes les variantes sans doublon : touchez n'importe quel coup pour ouvrir sa position. Sous le plateau, les coups des maîtres avec leurs pourcentages, les trois meilleurs coups de Stockfish et une barre d'évaluation ; des flèches colorées signalent le coup recommandé, les pièges et les imprécisions. Entraînez-les en répétition espacée — l'app planifie vos révisions toute seule — et retrouvez votre progression sur tous vos appareils via iCloud. Depuis le lecteur, « Changer de mode » envoie la position atteinte vers le Laboratoire, l'ordinateur ou une partie à deux."
        ),
        .init(
            icon: "crown.fill", tint: Theme.gold,
            title: "Finales",
            body: "78 cours pour convertir vos finales, groupés par famille : pions, tours, fous, cavaliers, déséquilibres, dames, mats élémentaires, études célèbres (Réti, Saavedra, Lasker, Troitsky, Kubbel…) et thèmes transversaux (deux faiblesses, domination, pat comme ressource…). Chaque ligne est vérifiée par table de finales — le verdict mathématique exact : aucun coup enseigné ne lâche le gain, aucune défense proposée ne perd la nulle. Depuis le lecteur, le menu « S'entraîner » propose la ligne guidée OU l'entraînement libre — conclure la position contre la meilleure défense, où tout coup qui préserve le verdict est accepté, pas seulement celui de la leçon, et un coup qui le lâche est repris avec l'explication. Révision espacée et synchronisation iCloud, comme les ouvertures."
        ),
        .init(
            icon: "square.and.arrow.up", tint: Theme.warning,
            title: "Vos répertoires et le partage",
            body: "AJOUTER LE VÔTRE\nDans Ouvertures, touchez « + » en haut à droite. Collez un PGN, ou ouvrez un fichier .pgn : les variantes entre parenthèses sont conservées, vous obtenez donc l'arbre complet et pas seulement la ligne principale. Indiquez le camp que vous étudiez — c'est le seul renseignement qu'un PGN ne contient pas. Vos annotations suivent : ? et ?? deviennent des pièges signalés, ?! des imprécisions, et vos commentaires s'affichent sous le plateau.\n\nLE PARTAGER\nTouchez le bouton « … » à droite d'un de vos répertoires, puis « Partager » : l'app envoie un simple fichier, par AirDrop, Messages, Fichiers ou ce que vous voulez. Celui qui le reçoit fait « + » puis « Ouvrir un fichier ». Il n'y a ni compte à créer, ni serveur ChessLab : le fichier EST le répertoire, et il ne passe que par où vous l'envoyez.\n\nCE QUI EST PARTAGÉ, ET CE QUI NE L'EST PAS\nLe fichier contient les coups, vos commentaires et vos annotations. Il ne contient PAS votre progression : ce que vous avez mémorisé reste chez vous. À l'inverse, un répertoire que vous importez profite tout de suite de ce que vous savez déjà des positions qu'il contient, même apprises dans une ouverture livrée avec l'app — la mémorisation est attachée aux positions, pas aux fichiers.\n\nSUPPRIMER\nLe même bouton « … », puis « Supprimer ». Le fichier quitte cet appareil ; votre progression sur ces positions est conservée. Les 58 ouvertures livrées, elles, ne peuvent être ni supprimées ni partagées.\n\nSUR TOUS VOS APPAREILS\nVos répertoires suivent la synchronisation iCloud, comme vos parties et votre progression : importé sur l'iPhone, un répertoire apparaît sur l'iPad. Activez la synchronisation dans les Réglages — elle est désactivée par défaut, l'app fonctionnant entièrement hors ligne.\n\nET LES DROITS D'AUTEUR\nLe contenu d'un livre ou d'un cours payant appartient à son auteur. Le saisir pour votre usage personnel est une chose ; le rediffuser en est une autre. Partagez ce que vous avez écrit, ou ce que vous avez le droit de partager."
        ),
        .init(
            icon: "chart.xyaxis.line", tint: Theme.teal,
            title: "Analyser",
            body: "Analysez une partie ou une position avec Stockfish : classification des coups (imprécision, erreur, gaffe), courbe d'évaluation, flèches des meilleurs coups et flèche rouge de la menace adverse, lecture automatique, et création de puzzles depuis les erreurs. Export PGN rechargeable. Entrée par PGN, FEN, éditeur ou scanner."
        ),
        .init(
            icon: "flask", tint: Theme.rose,
            title: "Laboratoire",
            body: "Faites s'affronter deux instances de Stockfish sur une série de parties pour comparer des réglages. Statistiques, écart Elo estimé avec intervalle de confiance, courbe de progression et répartition des résultats. On y arrive aussi depuis une partie ou une analyse — « Changer de mode », puis « Laboratoire » : la série démarre alors sur votre position. En fin de série, la dernière partie s'ouvre d'un tap dans l'analyse."
        ),
        .init(
            icon: "camera.viewfinder", tint: Theme.accent,
            title: "Éditeur et scanner de position",
            body: "Composez une position à la main sur le plateau, ou scannez-la depuis une capture d'écran, la photo d'un écran, ou un plateau réel vu du dessus. Un écran de confirmation vous laisse corriger la lecture avant de jouer ou d'analyser la position."
        ),
        .init(
            icon: "gearshape.fill", tint: Theme.textSecondary,
            title: "Réglages",
            body: "Langue de l'interface (français, anglais, ou celle du système), thème du plateau — choisi ici une fois pour tous les écrans —, notation des pièces (française R D T F C ou anglaise), et synchronisation iCloud."
        ),
        .init(
            icon: "icloud", tint: Theme.info,
            title: "Synchronisation iCloud",
            body: "Activez-la dans les Réglages pour que vos parties suivent tous vos appareils via votre iCloud privé — aucun compte à créer, aucun serveur tiers. Désactivée par défaut : l'app fonctionne entièrement hors ligne. La modification prend effet au prochain lancement.\n\nCE QUI SUIT\nVos parties terminées, votre progression sur les ouvertures et les finales, vos répertoires personnels, et vos préférences — thème de plateau, jeu de pièces, notation, essais par puzzle, réglages de partie.\n\nCE QUI RESTE SUR CHAQUE APPAREIL\nLa langue et les sons, pour que chaque appareil garde les siens. Et votre partie EN COURS : elle reste là où vous la jouez. Deux appareils, deux parties commencées, il faudrait en sacrifier une — mieux vaut que chacune vous attende où vous l'avez laissée."
        ),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Chaque mode de ChessLab en bref.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.bottom, 2)

                ForEach(modules) { module in
                    moduleCard(module)
                }

                contactCard
                thanksCard
            }
            .padding(20)
            .frame(maxWidth: Theme.readableWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .appBackground()
        .navigationTitle("Aide")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func moduleCard(_ module: Module) -> some View {
        HStack(alignment: .top, spacing: 14) {
            IconBadge(systemImage: module.icon, tint: module.tint, size: 42)
            VStack(alignment: .leading, spacing: 4) {
                Text(module.title)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text(module.body)
                    .font(.callout)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }

    /// Largeur de la photo de l'auteur : 60 % de la **fenêtre**.
    ///
    /// C'était 60 % de `UIScreen.main.bounds`, consommé en `.frame(width:)`,
    /// donc une largeur DURE calculée sur l'écran physique — jamais sur la
    /// fenêtre. Sur iPhone portrait ça passait (marge d'environ 22 pt), mais
    /// en **Slide Over** sur iPad (fenêtre de 320 pt, écran de 1 024) l'image
    /// réclamait 670 pt : 420 pt hors cadre, et la valeur ne s'invalidait
    /// jamais au redimensionnement. `UIScreen.main` est par ailleurs déprécié
    /// depuis iOS 16.
    ///
    /// Le bon modèle était déjà dans le dépôt : ``AppBackground`` mesure la
    /// **vue**. On fait pareil, avec un `containerRelativeFrame`, qui suit la
    /// fenêtre et se réévalue à chaque redimensionnement.
    private static let authorImageWidthFraction: CGFloat = 0.6

    /// Largeur de la colonne icône + espacement du `moduleCard` — reprise ici
    /// pour aligner la photo sous le même retrait que le titre et le texte.
    private static let cardLeadingInset: CGFloat = 42 + 14

    private var contactCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                IconBadge(systemImage: "envelope.fill", tint: Theme.accent, size: 42)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Contactez le développeur")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text("Vos retours et suggestions pour améliorer l'app sont toujours les bienvenus : tout est lu, et chaque message compte. En cas de bug ou de comportement inattendu, n'hésitez pas à écrire par e-mail, en précisant le modèle de votre iPhone ou iPad, la version d'iOS, et une courte description du problème.")
                        .font(.callout)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Link("variospeed67@gmail.com", destination: URL(string: "mailto:variospeed67@gmail.com")!)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(Theme.accent)
                }
            }
            HStack {
                Spacer().frame(width: Self.cardLeadingInset)
                Image("Author")
                    .resizable()
                    .scaledToFit()
                    .containerRelativeFrame(.horizontal) { width, _ in
                        width * Self.authorImageWidthFraction
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }

    /// Dernière carte de l'aide, après le contact : ce que l'app doit à
    /// quelqu'un d'autre que son développeur.
    private var thanksCard: some View {
        HStack(alignment: .top, spacing: 14) {
            IconBadge(systemImage: "heart.fill", tint: Theme.rose, size: 42)
            VStack(alignment: .leading, spacing: 4) {
                Text("Remerciements")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text("Un grand merci à Nils Gauthey pour tout le travail accompli sur ChessLab. Ses relectures, ses corrections et ses idées ont fait progresser l'app dans son ensemble, et tout particulièrement la qualité des ouvertures et des finales : les lignes que vous étudiez ici lui doivent beaucoup.")
                    .font(.callout)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}
