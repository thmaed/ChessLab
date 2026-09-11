//
//  jni_fairy.cpp
//  Pont JNI ↔ shim Fairy-Stockfish.
//
//  Copie conforme de `jni_bridge.cpp`, préfixes changés. Les deux moteurs ont
//  des files et des états SÉPARÉS : c'est ce qui permet de passer de l'un à
//  l'autre sans qu'une réponse en retard pollue l'autre.
//
//  (entête d'origine ci-dessous)
//
//  Pont JNI ↔ shim Stockfish.
//
//  Le shim (Vendor/CStockfish/Sources/CStockfish/shim.cpp) est repris TEL
//  QUEL : c'est du C++ standard qui détourne std::cin/std::cout et fait
//  tourner la boucle UCI sur un thread dédié. Rien à y changer pour Android.
//
//  Choix de conception : le callback du shim ne remonte PAS directement en
//  Kotlin. Appeler du code JVM depuis le thread moteur imposerait un
//  AttachCurrentThread/DetachCurrentThread à chaque ligne — coûteux et une
//  source classique de plantages. À la place, les lignes sont empilées dans
//  une file C++ et Kotlin vient les chercher avec `nativeReadLine()`, qui
//  BLOQUE jusqu'à la ligne suivante. Côté Kotlin, un simple thread lecteur
//  alimente une file — l'équivalent de l'`AsyncStream<EngineResponse>` de
//  EngineController.swift.
//

#include <jni.h>

#include <condition_variable>
#include <deque>
#include <mutex>
#include <string>

#include "cfairystockfish.h"

namespace {

std::mutex gMutex;
std::condition_variable gCondition;
std::deque<std::string> gLines;
bool gClosed = false;

/// Appelé par le shim, sur le thread moteur, pour chaque ligne UCI complète.
void onEngineLine(const char *line, void *) {
    {
        std::lock_guard<std::mutex> lock(gMutex);
        gLines.emplace_back(line ? line : "");
    }
    gCondition.notify_one();
}

} // namespace

extern "C" {

JNIEXPORT jint JNICALL
Java_com_chesslab_engine_FairyStockfish_nativeStart(JNIEnv *env, jobject, jstring path) {
    const char *nativePath = env->GetStringUTFChars(path, nullptr);
    {
        std::lock_guard<std::mutex> lock(gMutex);
        gLines.clear();
        gClosed = false;
    }
    const int result = cfairystockfish_start(nativePath, onEngineLine, nullptr);
    env->ReleaseStringUTFChars(path, nativePath);
    return result;
}

JNIEXPORT void JNICALL
Java_com_chesslab_engine_FairyStockfish_nativeSend(JNIEnv *env, jobject, jstring command) {
    const char *nativeCommand = env->GetStringUTFChars(command, nullptr);
    cfairystockfish_send(nativeCommand);
    env->ReleaseStringUTFChars(command, nativeCommand);
}

/// Bloque jusqu'à la prochaine ligne du moteur. Rend `null` quand le moteur
/// est arrêté — ce qui fait sortir la boucle du thread lecteur côté Kotlin.
JNIEXPORT jstring JNICALL
Java_com_chesslab_engine_FairyStockfish_nativeReadLine(JNIEnv *env, jobject) {
    std::string line;
    {
        std::unique_lock<std::mutex> lock(gMutex);
        gCondition.wait(lock, [] { return !gLines.empty() || gClosed; });
        if (gLines.empty()) {
            return nullptr;
        }
        line = std::move(gLines.front());
        gLines.pop_front();
    }
    return env->NewStringUTF(line.c_str());
}

JNIEXPORT void JNICALL
Java_com_chesslab_engine_FairyStockfish_nativeStop(JNIEnv *, jobject) {
    cfairystockfish_stop();
    {
        std::lock_guard<std::mutex> lock(gMutex);
        gClosed = true;
    }
    gCondition.notify_all();
}

JNIEXPORT jboolean JNICALL
Java_com_chesslab_engine_FairyStockfish_nativeIsRunning(JNIEnv *, jobject) {
    return cfairystockfish_is_running() ? JNI_TRUE : JNI_FALSE;
}

} // extern "C"
