package com.chesslab.play
import org.junit.Test
class TmpHeardDumpTest {
    @Test fun dump() {
        val phrases = listOf("OK 4","ok quatre","à 4","A4","pione A4","puis on des 5","puis on des cinq","on sait des 5","fiancé en dessin","fiancé en D5",
            "dans ces quatre en dessin","fou c'est","fou ces","cavalier à 8","cavalier 2","cavalier dessin","cavalier ces trois","tour pro","tour pour le cavalier F2",
            "cavalier prend d'âme","cavalier Panda","cavalier des","cavalier possède","pions","pions B5","fou B5","cavalier D5","cavalier C6","cavalier E7")
        val out = StringBuilder()
        for (p in phrases) { val h = VoiceMoveParser.heard(p); out.append("$p -> piece=${h.piece} squares=${h.squares} castle=${h.castle}\n") }
        java.io.File("/tmp/claude-501/vx/heard-dump.txt").writeText(out.toString())
    }
}
