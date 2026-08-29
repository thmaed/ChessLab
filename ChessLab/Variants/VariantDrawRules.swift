import ChessKit

/// Ce que « nulle » veut dire dans une variante — proposée, ou constatée.
///
/// Deux règles distinctes, et une seule chose en commun : elles n'ont pas le
/// même sens d'une variante à l'autre, et il vaut mieux le dire une fois ici
/// que le supposer partout.
enum VariantDrawRules {

    // MARK: Nulle PROPOSÉE

    /// Écart d'évaluation en deçà duquel l'ordinateur accepte une nulle.
    ///
    /// Même seuil qu'en mode « Contre l'ordinateur » : il accepte s'il ne se
    /// voit pas mieux qu'une quasi-égalité sur son dernier coup, refuse
    /// sinon — et refuse aussi tant qu'il n'a pas joué, faute d'avoir un avis.
    static let acceptanceCentipawns = 50

    /// - parameter lastEngineEvalCp: dernière évaluation du moteur, DE SON
    ///   point de vue (positif = il se voit mieux).
    static func engineAcceptsDraw(lastEngineEvalCp: Int?) -> Bool {
        guard let lastEngineEvalCp else { return false }
        return abs(lastEngineEvalCp) <= acceptanceCentipawns
    }

    // MARK: Nulle par MATÉRIEL INSUFFISANT

    /// La règle du matériel insuffisant s'applique-t-elle à cette variante ?
    ///
    /// Elle dit : « avec ce matériel, personne ne peut plus mater ». Elle
    /// suppose donc que gagner, c'est mater — ce qui est faux dans la moitié
    /// du hub, et l'appliquer partout déclarerait nulles des parties encore
    /// gagnables. Le détail, variante par variante :
    ///
    /// - **Barricades** et **Barricades aléatoires** — oui : les murs ne
    ///   matent pas, ils bloquent. Roi + fou contre roi reste nul.
    /// - **Crazyhouse** — oui, mais SEULEMENT les deux réserves vides : une
    ///   pièce en main se repose et mate, si peu de matériel qu'il reste sur
    ///   le plateau.
    /// - **Atomique** — non. Une explosion tue le roi adverse sans jamais le
    ///   mater : roi + fou y gagne.
    /// - **Antéchecs** — non. Le but est inversé, perdre son matériel est la
    ///   victoire ; « plus assez pour mater » n'y veut rien dire.
    /// - **Course des rois** — non. On gagne en atteignant la 8e rangée,
    ///   deux rois seuls suffisent à faire une partie.
    /// - **Roi de la colline**, **Trois échecs** — non, pour la même raison :
    ///   la victoire ne passe pas par le mat. Un fou seul donne trois échecs.
    /// - **Horde** — non, ses deux camps n'ont pas le même matériel ni le
    ///   même but.
    /// - **Duck Chess** — non, et c'est le cas le plus contre-intuitif : on y
    ///   gagne en CAPTURANT le roi, pas en le matant. Un fou seul peut le
    ///   prendre.
    /// - **Coup Volé** — oui : les échecs ordinaires, avec un tour double.
    ///   Deux coups d'affilée ne font pas mater roi + fou contre roi.
    static func declaresInsufficientMaterial(variantID: String) -> Bool {
        switch variantID {
        case "barricades", "randombarricades", "crazyhouse", "stolenmove", "chess", "chess960":
            true
        default:
            false
        }
    }

    /// La position est-elle nulle faute de matériel ?
    ///
    /// - parameter fen: FEN du MOTEUR (réserve et murs compris) — assainie ici.
    /// - parameter pocketIsEmpty: les deux réserves sont-elles vides ?
    ///   Sans objet hors Crazyhouse, où l'on passe `true`.
    static func isInsufficientMaterial(
        fen: String, variantID: String, pocketIsEmpty: Bool
    ) -> Bool {
        guard declaresInsufficientMaterial(variantID: variantID), pocketIsEmpty else { return false }
        guard let position = Position(fen: VariantFEN.forChessKit(fen)) else { return false }
        return position.hasInsufficientMaterial
    }
}
