//
//  shim.cpp
//  Pont C ↔ Stockfish, en process, avec un transport propre.
//
//  Stockfish parle UCI en lisant `getline(std::cin, …)` et en écrivant sur
//  `std::cout` (via `sync_cout`). On remplace les `streambuf` de ces DEUX flux
//  C++ globaux — l'app n'utilise que os_log, donc c'est sans effet de bord — et
//  on exécute la boucle UCI de Stockfish (`_main`) sur un thread dédié :
//
//   • Entrée : `InputBuffer` bloque `getline` jusqu'à ce qu'une commande soit
//     poussée par `cstockfish_send` (file protégée + condition_variable).
//   • Sortie : `OutputBuffer` découpe le flux en LIGNES et les remet au
//     callback — sur le thread moteur, jamais le thread principal (fini les
//     freezes dus au parsing des `info` sur le run loop principal).
//
//  Aucun `dup2` sur le descripteur de fichier du process : pas de SIGPIPE, pas
//  d'interférence avec la sortie standard de l'app.

#include "include/cstockfish.h"
#include "stockfish/_main.h"

#include <condition_variable>
#include <deque>
#include <mutex>
#include <streambuf>
#include <string>
#include <thread>
#include <iostream>

namespace {

/// Flux d'ENTRÉE bloquant : sert à Stockfish les commandes ligne par ligne,
/// en attendant qu'elles arrivent. Chaque commande poussée porte déjà son
/// '\n' final, ce que `getline` consomme comme séparateur.
class InputBuffer : public std::streambuf {
public:
    void push(const std::string &line) {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            queue_.push_back(line);
        }
        condition_.notify_one();
    }

protected:
    int_type underflow() override {
        if (gptr() < egptr()) {
            return traits_type::to_int_type(*gptr());
        }
        std::unique_lock<std::mutex> lock(mutex_);
        condition_.wait(lock, [this] { return !queue_.empty(); });
        current_ = std::move(queue_.front());
        queue_.pop_front();
        lock.unlock();

        if (current_.empty()) {
            return traits_type::eof();
        }
        char *base = &current_[0];
        setg(base, base, base + current_.size());
        return traits_type::to_int_type(*gptr());
    }

private:
    std::mutex mutex_;
    std::condition_variable condition_;
    std::deque<std::string> queue_;
    std::string current_;
};

/// Flux de SORTIE : accumule les caractères et remet chaque LIGNE complète au
/// callback (sans le '\n').
class OutputBuffer : public std::streambuf {
public:
    void configure(cstockfish_output_callback callback, void *context) {
        callback_ = callback;
        context_ = context;
    }

protected:
    // `mutex_` : la ligne en cours est une `std::string` que DEUX threads
    // pouvaient toucher en même temps.
    //
    // Les deux shims — celui-ci et celui de Fairy-Stockfish — détournent le
    // MÊME `std::cout` global. Si les deux moteurs vivent un instant
    // ensemble (arrêt de l'un qui traîne pendant le démarrage de l'autre),
    // leurs deux threads finissent par écrire dans le même `OutputBuffer`, et
    // `line_.push_back()` corrompt le tas. Constaté le 30/08 : abandon sur
    // `POINTER_BEING_FREED_WAS_NOT_ALLOCATED`, pile
    // `UCIEngine::loop → OutputBuffer::overflow → std::string::__grow_by`.
    // Le process entier tombait, et les tests voisins ne voyaient qu'un
    // moteur « indisponible ».
    //
    // Le verrou ne remplace pas la discipline côté app (un seul moteur à la
    // fois) : il fait que son non-respect coûte une ligne mélangée, et non
    // le process.
    int_type overflow(int_type ch) override {
        if (ch == traits_type::eof()) {
            return ch;
        }
        char c = traits_type::to_char_type(ch);
        std::string finished;
        {
            std::lock_guard<std::mutex> lock(mutex_);
            if (c == '\n') {
                finished.swap(line_);
            } else if (c != '\r') {
                line_.push_back(c);
            } else {
                return ch;
            }
        }
        // Le callback est appelé HORS du verrou : il remonte en Swift, et le
        // tenir pendant ce trajet inviterait l'interblocage.
        if (c == '\n' && callback_) {
            callback_(finished.c_str(), context_);
        }
        return ch;
    }

    std::streamsize xsputn(const char *s, std::streamsize count) override {
        for (std::streamsize i = 0; i < count; ++i) {
            overflow(traits_type::to_int_type(s[i]));
        }
        return count;
    }

private:
    cstockfish_output_callback callback_ = nullptr;
    void *context_ = nullptr;
    std::mutex mutex_;
    std::string line_;
};

// État global : un seul moteur par process, comme Stockfish (état statique).
InputBuffer gInput;
OutputBuffer gOutput;
std::thread gEngineThread;
std::streambuf *gOldCin = nullptr;
std::streambuf *gOldCout = nullptr;
bool gRunning = false;
std::mutex gLifecycleMutex;

} // namespace

extern "C" {

int cstockfish_start(const char *binaryPath,
                     cstockfish_output_callback callback,
                     void *context) {
    std::lock_guard<std::mutex> lock(gLifecycleMutex);
    if (gRunning) {
        // Le process est DÉJÀ pris. On le dit à l'appelant au lieu de sortir
        // en silence : reconfigurer `gOutput` ici détournerait la sortie du
        // propriétaire actuel vers le nouveau venu, ce qui est pire.
        return -1;
    }

    gOutput.configure(callback, context);
    gOldCin = std::cin.rdbuf(&gInput);
    gOldCout = std::cout.rdbuf(&gOutput);

    std::string path = binaryPath ? binaryPath : "stockfish";
    gEngineThread = std::thread([path]() {
        // argv[0] : son dossier parent est fouillé par Stockfish pour les
        // réseaux NNUE (voir CommandLine::get_binary_directory).
        std::string arg0 = path;
        char *argv[] = {const_cast<char *>(arg0.c_str())};
        _main(1, argv);
    });
    gRunning = true;
    return 0;
}

void cstockfish_send(const char *command) {
    if (!command) {
        return;
    }
    std::string line(command);
    if (line.empty() || line.back() != '\n') {
        line.push_back('\n');
    }
    gInput.push(line);
}

void cstockfish_stop(void) {
    std::lock_guard<std::mutex> lock(gLifecycleMutex);
    if (!gRunning) {
        return;
    }
    // « quit » fait sortir la boucle UCI de Stockfish, donc le thread se
    // termine proprement.
    gInput.push("quit\n");
    if (gEngineThread.joinable()) {
        gEngineThread.join();
    }
    // Restaure les flux d'origine — mais SEULEMENT s'ils sont encore les
    // nôtres.
    //
    // Sans cette vérification, un shim qui s'arrête réinstallait son
    // « ancien » tampon par-dessus celui d'un moteur démarré entre-temps :
    // la sortie du nouveau venu partait dans le vide, et il passait pour
    // muet. Les deux shims se marchant sur le même `std::cout` global, c'est
    // exactement le scénario que produit un arrêt qui traîne.
    if (gOldCin && std::cin.rdbuf() == &gInput) {
        std::cin.rdbuf(gOldCin);
    }
    gOldCin = nullptr;
    if (gOldCout && std::cout.rdbuf() == &gOutput) {
        std::cout.rdbuf(gOldCout);
    }
    gOldCout = nullptr;
    gRunning = false;
}

int cstockfish_is_running(void) {
    std::lock_guard<std::mutex> lock(gLifecycleMutex);
    return gRunning ? 1 : 0;
}

} // extern "C"
