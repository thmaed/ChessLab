//
//  shim.cpp
//  Pont C ↔ Fairy-Stockfish, en process — copie conforme de
//  ``CStockfish/shim.cpp`` (même transport : streambuf remplacés, thread
//  dédié, aucun dup2), adaptée au point d'entrée renommé `_fairy_main` et
//  aux symboles publics préfixés `cfairystockfish_`.
//

#include "include/cfairystockfish.h"
#include "fairystockfish/_fairymain.h"

#include <condition_variable>
#include <deque>
#include <mutex>
#include <streambuf>
#include <string>
#include <thread>
#include <iostream>

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
std::streambuf *gOldCin = nullptr;
std::streambuf *gOldCout = nullptr;
bool gRunning = false;
std::mutex gLifecycleMutex;

} // namespace

extern "C" {

int cfairystockfish_start(const char *binaryPath,
                          cfairystockfish_output_callback callback,
                          void *context) {
    std::lock_guard<std::mutex> lock(gLifecycleMutex);
    if (gRunning) {
        return -1;
    }

    gOutput.configure(callback, context);
    gOldCin = std::cin.rdbuf(&gInput);
    gOldCout = std::cout.rdbuf(&gOutput);

    std::string path = binaryPath ? binaryPath : "fairy-stockfish";
    gEngineThread = std::thread([path]() {
        std::string arg0 = path;
        char *argv[] = {const_cast<char *>(arg0.c_str())};
        _fairy_main(1, argv);
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
    if (gEngineThread.joinable()) {
        gEngineThread.join();
    }
    // Voir ``CStockfish/shim.cpp`` : on ne restaure QUE si les flux sont
    // encore les nôtres. Sinon un arrêt qui traîne réinstallait son ancien
    // tampon par-dessus celui d'un moteur démarré entre-temps, qui passait
    // alors pour muet.
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

int cfairystockfish_is_running(void) {
    std::lock_guard<std::mutex> lock(gLifecycleMutex);
    return gRunning ? 1 : 0;
}

} // extern "C"
