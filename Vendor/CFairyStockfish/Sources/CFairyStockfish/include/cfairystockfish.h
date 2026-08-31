//
//  cfairystockfish.h
//  Interface C d'un Fairy-Stockfish embarqué, piloté en process — même
//  patron que ``CStockfish/include/cstockfish.h`` (nommage préfixé
//  `cfairystockfish_` pour ne jamais entrer en collision avec les symboles
//  C `cstockfish_*` du moteur standard : les deux vivent dans le MÊME
//  binaire d'app).
//
//  Un seul moteur — Stockfish OU Fairy-Stockfish — actif à la fois : les
//  deux se disputent les MÊMES flux globaux `std::cin`/`std::cout`
//  (contrainte déjà vraie entre deux instances de Stockfish ; elle
//  s'étend ici aux deux moteurs). La discipline « un moteur par écran,
//  arrêté avant le suivant » déjà en place dans l'app suffit.
//

#ifndef CFAIRYSTOCKFISH_H
#define CFAIRYSTOCKFISH_H

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*cfairystockfish_output_callback)(const char *line, void *context);

/// Démarre le moteur sur un thread dédié. `binaryPath` : voir
/// ``cstockfish_start`` — même contrat (dossier des réseaux NNUE).
/// - returns: 0 si démarré, -1 si un moteur (Fairy-Stockfish) tourne déjà.
int cfairystockfish_start(const char *binaryPath,
                          cfairystockfish_output_callback callback,
                          void *context);

/// Envoie une commande UCI (une ligne ; le '\n' est ajouté au besoin).
void cfairystockfish_send(const char *command);

/// Envoie « quit », attend la fin du thread moteur et restaure les flux.
void cfairystockfish_stop(void);

/// Vrai (1) si le thread moteur est en cours d'exécution.
int cfairystockfish_is_running(void);

/// 1 si aucun fil moteur détaché ne traîne (voir shim.cpp).
int cfairystockfish_is_settled(void);

#ifdef __cplusplus
}
#endif

#endif /* CFAIRYSTOCKFISH_H */
