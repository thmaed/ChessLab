package com.chesslab.scanner

/**
 * Le type de source d'une image du scanner — pendant de `ScanSource.swift`.
 *
 * Les deux sont des « diagrammes numériques » et se DÉDUISENT de l'image, sans
 * rien demander à l'utilisateur : si le motif de damier se reconnaît avec
 * certitude (net, aligné sur les axes), c'est une capture ; sinon l'image a été
 * photographiée, avec son moiré, ses reflets et sa perspective.
 */
enum class ScanSource {
    /** Capture d'écran d'une app ou d'un site : glyphes nets, aucune déformation. */
    screenshot,

    /** Photo d'un écran affichant un plateau : mêmes glyphes, mais moiré, reflets, perspective. */
    screenPhoto,
}
