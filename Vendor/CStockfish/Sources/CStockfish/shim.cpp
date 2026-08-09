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

    cstockfish_output_callback callback_ = nullptr;
    void *context_ = nullptr;
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

void cstockfish_start(const char *binaryPath,
                      cstockfish_output_callback callback,
                      void *context) {
    std::lock_guard<std::mutex> lock(gLifecycleMutex);
    if (gRunning) {
        return;
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
    // Restaure les flux d'origine.
    if (gOldCin) {
        std::cin.rdbuf(gOldCin);
        gOldCin = nullptr;
    }
    if (gOldCout) {
        std::cout.rdbuf(gOldCout);
        gOldCout = nullptr;
    }
    gRunning = false;
}

int cstockfish_is_running(void) {
    std::lock_guard<std::mutex> lock(gLifecycleMutex);
    return gRunning ? 1 : 0;
}

} // extern "C"
