import UIKit
import UniformTypeIdentifiers

/// L'extension « Partager › ChessLab » : reçoit UNE image (Photos, Fichiers,
/// Safari…) et la dépose dans ``SharedImageInbox``. L'app ouvre ensuite le
/// scanner dessus à son prochain réveil.
///
/// Pendant iOS du filtre `ACTION_SEND` d'Android (`SharedImage`). Une extension
/// de partage ne peut pas lancer l'app qui la contient : l'écran dit donc
/// d'ouvrir ChessLab, là où Android y passe tout seul — limite de la
/// plateforme, consignée dans `android/PARITE.md`.
///
/// L'extension ne lit pas l'image : elle copie le fichier tel quel. Pas de
/// décodage ici — une extension vit sous une limite de mémoire serrée, et le
/// travail se fait dans l'app.
final class ShareViewController: UIViewController {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.07, green: 0.09, blue: 0.10, alpha: 1)
        buildInterface()
        Task { await receive() }
    }

    // MARK: Réception

    private func receive() async {
        guard let provider = imageProvider() else {
            return finish(sent: false)
        }
        let deposited = await withCheckedContinuation { continuation in
            // Le fichier fourni n'existe que le temps de ce rappel : on le copie ici.
            provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, _ in
                guard let url else { return continuation.resume(returning: false) }
                continuation.resume(returning: (try? SharedImageInbox.deposit(contentsOf: url)) != nil)
            }
        }
        finish(sent: deposited)
    }

    private func imageProvider() -> NSItemProvider? {
        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        return items.flatMap { $0.attachments ?? [] }
            .first { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }
    }

    private func finish(sent: Bool) {
        DispatchQueue.main.async { [self] in
            iconView.image = UIImage(systemName: sent ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            iconView.tintColor = sent ? UIColor(red: 0.30, green: 0.80, blue: 0.62, alpha: 1) : .systemOrange
            titleLabel.text = sent
                ? String(localized: "Image envoyée à ChessLab")
                : String(localized: "Impossible d'envoyer l'image")
            detailLabel.text = sent
                ? String(localized: "Ouvrez ChessLab : la position s'y lira.")
                : String(localized: "Partagez une image depuis Photos, puis réessayez.")
            DispatchQueue.main.asyncAfter(deadline: .now() + (sent ? 1.6 : 2.4)) { [self] in
                extensionContext?.completeRequest(returningItems: nil)
            }
        }
    }

    // MARK: Interface

    private func buildInterface() {
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 54)
        iconView.image = UIImage(systemName: "square.and.arrow.down.fill")
        iconView.tintColor = UIColor(white: 1, alpha: 0.5)
        iconView.contentMode = .scaleAspectFit

        titleLabel.font = .preferredFont(forTextStyle: .title3)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        detailLabel.font = .preferredFont(forTextStyle: .subheadline)
        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.textColor = UIColor(white: 1, alpha: 0.65)
        detailLabel.textAlignment = .center
        detailLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, detailLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.layoutMarginsGuide.trailingAnchor),
        ])
    }
}
