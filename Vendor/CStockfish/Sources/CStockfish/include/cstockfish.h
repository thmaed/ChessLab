//
//  cstockfish.h
//  Interface C d'un Stockfish embarqué, piloté en process.
//
//  Contrairement à un wrapper « UCI par tuyaux + dup2 sur le stdout global »,
//  cette intégration redirige uniquement std::cin / std::cout DU C++ (l'app
//  n'utilise que os_log, jamais std::cout) et draine la sortie du moteur sur
//  un THREAD DÉDIÉ — jamais le run loop principal. Pas de dup2 sur le
//  descripteur de fichier du process, donc pas de SIGPIPE ni d'interférence
//  avec la journalisation de l'app.
//
//  Un seul moteur par process (comme Stockfish lui-même : état global).
//

#ifndef CSTOCKFISH_H
#define CSTOCKFISH_H

#ifdef __cplusplus
extern "C" {
#endif

/// Appelé pour CHAQUE ligne complète émise par le moteur (sans le '\n' final).
/// Invoqué sur le thread du moteur, jamais sur le thread principal.
typedef void (*cstockfish_output_callback)(const char *line, void *context);

/// Démarre le moteur sur un thread dédié.
/// - binaryPath : chemin FICTIF dont le dossier parent est fouillé par
///   Stockfish pour trouver les réseaux NNUE (`nn-*.nnue`). Passer un chemin
///   dans le dossier des ressources du bundle, p. ex. « <Resources>/stockfish ».
/// - callback / context : reçoivent la sortie UCI, ligne par ligne.
/// - returns: 0 si le moteur a démarré, **-1 si un moteur tourne déjà**.
///
/// Ce code de retour n'existait pas : la fonction sortait en silence quand
/// `gRunning` était vrai, SANS reconfigurer le callback. L'appelant croyait
/// alors avoir démarré, ne recevait plus aucune ligne (le callback pointait
/// toujours l'instance précédente), attendait `uciok` en vain jusqu'au
/// délai de 5 s — et pendant ce temps ses commandes partaient quand même
/// dans le moteur de l'AUTRE écran, dont elles polluaient le flux.
int cstockfish_start(const char *binaryPath,
                     cstockfish_output_callback callback,
                     void *context);

/// Envoie une commande UCI (une ligne ; le '\n' est ajouté au besoin).
/// Sans effet si le moteur n'est pas démarré.
void cstockfish_send(const char *command);

/// Envoie « quit », attend la fin du thread moteur et restaure les flux.
/// Idempotent.
void cstockfish_stop(void);

/// Vrai (1) si le thread moteur est en cours d'exécution.
int cstockfish_is_running(void);

/// 1 si aucun fil moteur détaché ne traîne (voir shim.cpp).
int cstockfish_is_settled(void);

#ifdef __cplusplus
}
#endif

#endif /* CSTOCKFISH_H */
