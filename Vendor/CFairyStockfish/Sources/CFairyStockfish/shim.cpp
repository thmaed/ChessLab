//
//  shim.cpp
//  Pont C ↔ Fairy-Stockfish, en process — copie conforme de
//  ``CStockfish/shim.cpp`` (même transport : streambuf remplacés, thread
//  dédié, aucun dup2), adaptée au point d'entrée renommé `_fairy_main` et
//  aux symboles publics préfixés `cfairystockfish_`.
//

#include "include/cfairystockfish.h"
#include "fairystockfish/_fairymain.h"

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <deque>
#include <mutex>
#include <streambuf>
#include <string>
#include <thread>
#include <iostream>

/// L'entrée UCI DÉDIÉE de ce moteur — lue par son uci.cpp à la place du
/// `std::cin` global (voir la déclaration `extern` là-bas). Posée une fois au
/// premier démarrage et jamais remise à zéro : le tampon qu'elle enveloppe
/// est global au shim et vit aussi longtemps que le process.
std::istream* chesslab_fsf_stdin = nullptr;

namespace {

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

class OutputBuffer : public std::streambuf {
public:
    void configure(cfairystockfish_output_callback callback, void *context) {
        callback_ = callback;
        context_ = context;
    }

protected:
    int_type overflow(int_type ch) override {
        if (ch == traits_type::eof()) {
            return ch;
        }
        char c = traits_type::to_char_type(ch);
        if (c == '\n') {
            flushLine();
        } else if (c != '\r') {
            line_.push_back(c);
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
    void flushLine() {
        if (callback_) {
            callback_(line_.c_str(), context_);
        }
        line_.clear();
    }

    cfairystockfish_output_callback callback_ = nullptr;
    void *context_ = nullptr;
    std::string line_;
};

InputBuffer gInput;
OutputBuffer gOutput;
std::thread gEngineThread;
// Générations du fil moteur — et non un simple booléen « fini », qui était
// PARTAGÉ entre un fil détaché et son successeur : le zombie posait le
// drapeau du neuf, le neuf passait pour mort (ou l'inverse), et l'arrêt
// borné joignait le mauvais fil. Chaque fil reçoit SA génération à la
// création et la pose en sortant ; `gThreadGeneration != gDoneGeneration`
// dit précisément « le dernier fil lancé vit encore ».
std::atomic<uint64_t> gThreadGeneration{0};
std::atomic<uint64_t> gDoneGeneration{0};
std::streambuf *gOldCout = nullptr;
bool gRunning = false;
std::mutex gLifecycleMutex;

} // namespace

extern "C" {

int cfairystockfish_start(const char *binaryPath,
                          cfairystockfish_output_callback callback,
                          void *context) {
    std::lock_guard<std::mutex> lock(gLifecycleMutex);
    if (gThreadGeneration.load() != gDoneGeneration.load()) {
        // Le fil moteur PRÉCÉDENT, détaché par un arrêt borné, vit encore :
        // démarrer une seconde boucle UCI du même moteur corromprait leurs
        // états globaux partagés (Threads, options). On refuse — l'app
        // affiche « moteur indisponible » avec « Réessayer », ce qui est
        // exactement vrai, et la voie se libère dès que le fil sourd lit le
        // « quit » resté dans sa file.
        return -1;
    }
    if (gRunning) {
        return -1;
    }

    const uint64_t generation = gThreadGeneration.fetch_add(1) + 1;
    gOutput.configure(callback, context);
    static std::istream gEngineInput(&gInput);
    chesslab_fsf_stdin = &gEngineInput;
    gOldCout = std::cout.rdbuf(&gOutput);

    std::string path = binaryPath ? binaryPath : "fairy-stockfish";
    gEngineThread = std::thread([path, generation]() {
        std::string arg0 = path;
        char *argv[] = {const_cast<char *>(arg0.c_str())};
        _fairy_main(1, argv);
        gDoneGeneration.store(generation);
    });
    gRunning = true;
    return 0;
}

void cfairystockfish_send(const char *command) {
    if (!command) {
        return;
    }
    std::string line(command);
    if (line.empty() || line.back() != '\n') {
        line.push_back('\n');
    }
    gInput.push(line);
}

void cfairystockfish_stop(void) {
    std::lock_guard<std::mutex> lock(gLifecycleMutex);
    if (!gRunning) {
        return;
    }
    gInput.push("quit\n");
    // Join BORNÉ, et ce n'est pas un luxe : `getline(std::cin, …)` lit le
    // tampon COURANT de std::cin, que l'AUTRE shim peut avoir détourné si
    // les deux moteurs se sont chevauchés un instant. Le « quit » poussé
    // ci-dessus atterrit alors dans un tampon que le fil moteur ne lit pas :
    // il attend sur la mauvaise variable de condition, et un join aveugle
    // gelait le MainActor POUR TOUJOURS (constaté le 31/08 : une suite de
    // tests pendue 5 h 40 dans `PlayViewModel.deinit → cstockfish_stop`,
    // le fil moteur dans `InputBuffer::underflow`). Deux secondes suffisent
    // à tout arrêt sain — au-delà, on DÉTACHE : le fil sourd garde son
    // « quit » en file et sortira de lui-même si les tampons lui
    // reviennent ; en attendant, `gEngineZombie` interdit de redémarrer ce
    // shim par-dessus.
    const uint64_t generation = gThreadGeneration.load();
    bool finished = false;
    for (int i = 0; i < 200; ++i) {
        if (gDoneGeneration.load() >= generation) { finished = true; break; }
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }
    if (gEngineThread.joinable()) {
        if (finished) {
            gEngineThread.join();
        } else {
            // Fil sourd (voir le commentaire au-dessus) : détaché. L'écart
            // `gThreadGeneration != gDoneGeneration` interdit tout
            // redémarrage tant qu'il vit.
            gEngineThread.detach();
        }
    }
    // Voir ``CStockfish/shim.cpp`` : on ne restaure QUE si les flux sont
    // encore les nôtres. Sinon un arrêt qui traîne réinstallait son ancien
    // tampon par-dessus celui d'un moteur démarré entre-temps, qui passait
    // alors pour muet.
    if (gOldCout && std::cout.rdbuf() == &gOutput) {
        std::cout.rdbuf(gOldCout);
    }
    gOldCout = nullptr;
    gRunning = false;
}

int cfairystockfish_is_running(void) {
    std::lock_guard<std::mutex> lock(gLifecycleMutex);
    return gRunning ? 1 : 0;
}

} // extern "C"
