#if DEBUG
import Testing
@testable import ChessLab

/// ÉTUDE Whisper (19/11/2026) : le découpage Swift des phrases doit être CELUI du tokeniseur de Whisper
/// (`tools/whisper-spike/convertir.py`), sinon les notes calculées sur l'iPhone ne veulent rien dire.
struct WhisperMoveChooserTests {
    @Test func theSwiftPretokensMatchWhispers() {
        #expect(WhisperMoveChooser.pretokens(" Pion e4.") == [" Pion", " e", "4", "."])
        #expect(WhisperMoveChooser.pretokens(" Cavalier B1 en D2.") == [" Cavalier", " B", "1", " en", " D", "2", "."])
        #expect(WhisperMoveChooser.pretokens(" Petit roque") == [" Petit", " roque"])
        #expect(WhisperMoveChooser.pretokens(" E8 dame.") == [" E", "8", " dame", "."])
        #expect(WhisperMoveChooser.pretokens(" Roi prend h7") == [" Roi", " prend", " h", "7"])
    }

    @Test func theSurfacesAreThoseOfTheMacMeasure() {
        #expect(WhisperMoveChooser.surfaces("pion e4") == ["Pion e4", "Pion e4.", "Pion E4", "Pion E4."])
        #expect(WhisperMoveChooser.surfaces("petit roque") == ["Petit roque", "Petit roque.", "Petit roque", "Petit roque."])
    }
}
#endif
