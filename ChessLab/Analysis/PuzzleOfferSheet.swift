import ChessKit
import SwiftUI

/// Le récapitulatif de fin d'analyse : ce que l'app PEUT créer comme puzzles depuis cette partie — les
/// mats manqués et les erreurs —, que l'utilisateur accepte ou refuse. Rien n'est écrit avant son accord.
/// Pendant Android : `PuzzleOfferSheet.kt`.
struct PuzzleOfferSheet: View {
    let offer: PuzzleOffer
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    IconBadge(systemImage: "puzzlepiece.fill", tint: Theme.violet, size: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Créer des puzzles de cette partie ?")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Ils rejoindront « Mes parties », dans Puzzles.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                if !offer.mates.isEmpty {
                    section(LocalizationController.string("%lld mat(s) manqué(s)", offer.mates.count), offer.mates, Theme.danger)
                }
                if !offer.mistakes.isEmpty {
                    section(LocalizationController.string("%lld erreur(s) à retravailler", offer.mistakes.count), offer.mistakes, Theme.warning)
                }
                Button(action: onAccept) {
                    Text(LocalizationController.string("Créer %lld puzzle(s)", offer.candidates.count))
                        .font(.headline)
                        .foregroundStyle(Theme.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.accentGradient, in: Capsule())
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("puzzleOfferAccept")
                Button(action: onDecline) {
                    Text("Non merci")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .accessibilityIdentifier("puzzleOfferDecline")
            }
            .padding(20)
        }
        .appBackground()
        .accessibilityIdentifier("puzzleOffer")
    }

    private func section(_ title: String, _ items: [PuzzleCandidate], _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .textCase(.uppercase)
                .tracking(0.4)
            ForEach(items) { candidate in
                HStack(spacing: 12) {
                    MiniBoardView(fen: candidate.fen, flipped: candidate.mover == .black)
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    Text(candidate.isMate
                         ? LocalizationController.string("Coup %lld : un mat était possible (vous avez joué %@).", candidate.moveNumber, candidate.playedSAN)
                         : LocalizationController.string("Coup %lld : %@ était une erreur.", candidate.moveNumber, candidate.playedSAN))
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}
