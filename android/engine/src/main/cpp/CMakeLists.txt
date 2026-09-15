# Stockfish 17.1 compilé pour Android, à partir des MÊMES sources que l'app
# iOS (Vendor/CStockfish) — aucun fichier n'est dupliqué ni modifié.
#
# Les options reproduisent celles de Vendor/CStockfish/Package.swift, avec
# une addition propre à Android :
#
#   USE_PTHREADS — sur Android les threads secondaires reçoivent 1 Mo de pile
#   par défaut, ce qui est INSUFFISANT pour la recherche profonde de
#   Stockfish (voir thread_win32_osx.h : « too low for deep searches »). Sans
#   ce define, thread_win32_osx.h ne s'active que sur __APPLE__ et Stockfish
#   déborde la pile en recherche profonde. Avec, il crée ses threads via
#   pthread_create avec 8 Mo, comme sur iOS.
#
# Ne PAS activer dotprod/i8mm : la baseline NEON suffit et couvre tout arm64.

cmake_minimum_required(VERSION 3.22.1)
project(chesslab_engine CXX)

# PAGES DE 16 Ko — obligatoire pour publier une app qui vise Android 15+.
#
# Les appareils récents passent à des pages mémoire de 16 Ko ; une
# bibliothèque dont les segments sont alignés sur 4 Ko n'y démarre pas, et le
# Play Store refuse l'envoi. Le NDK r27 sait le faire mais ne le fait pas par
# défaut : il faut le lui demander, une fois par bibliothèque.
#
# Vérification, après compilation :
#   llvm-readelf -l libchesslab_engine.so | grep LOAD   →  0x4000, pas 0x1000
set(PAGE_16K "-Wl,-z,max-page-size=16384,-z,common-page-size=16384")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS ON)   # gnu++17, comme cxxLanguageStandard côté SPM

set(SF_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../../../../../Vendor/CStockfish/Sources/CStockfish)

if(NOT EXISTS ${SF_ROOT}/shim.cpp)
    message(FATAL_ERROR "Sources Stockfish introuvables : ${SF_ROOT}")
endif()

set(SF_SOURCES
    ${SF_ROOT}/stockfish/_main.cpp
    ${SF_ROOT}/stockfish/benchmark.cpp
    ${SF_ROOT}/stockfish/bitboard.cpp
    ${SF_ROOT}/stockfish/engine.cpp
    ${SF_ROOT}/stockfish/evaluate.cpp
    ${SF_ROOT}/stockfish/memory.cpp
    ${SF_ROOT}/stockfish/misc.cpp
    ${SF_ROOT}/stockfish/movegen.cpp
    ${SF_ROOT}/stockfish/movepick.cpp
    ${SF_ROOT}/stockfish/position.cpp
    ${SF_ROOT}/stockfish/score.cpp
    ${SF_ROOT}/stockfish/search.cpp
    ${SF_ROOT}/stockfish/thread.cpp
    ${SF_ROOT}/stockfish/timeman.cpp
    ${SF_ROOT}/stockfish/tt.cpp
    ${SF_ROOT}/stockfish/tune.cpp
    ${SF_ROOT}/stockfish/uci.cpp
    ${SF_ROOT}/stockfish/ucioption.cpp
    ${SF_ROOT}/stockfish/nnue/network.cpp
    ${SF_ROOT}/stockfish/nnue/nnue_accumulator.cpp
    ${SF_ROOT}/stockfish/nnue/nnue_misc.cpp
    ${SF_ROOT}/stockfish/nnue/features/half_ka_v2_hm.cpp
    ${SF_ROOT}/stockfish/syzygy/tbprobe.cpp
)

add_library(chesslab_engine SHARED
    ${SF_SOURCES}
    ${SF_ROOT}/shim.cpp
    jni_bridge.cpp
)

target_include_directories(chesslab_engine PRIVATE
    ${SF_ROOT}
    ${SF_ROOT}/include
    ${SF_ROOT}/stockfish
)

target_compile_definitions(chesslab_engine PRIVATE
    NNUE_EMBEDDING_OFF   # réseaux livrés en fichiers, pas dans le binaire
    NO_PEXT              # x86 uniquement
    USE_POPCNT
    USE_NEON=8
    USE_PTHREADS         # piles de 8 Mo — voir l'entête
    NDEBUG
)

target_compile_options(chesslab_engine PRIVATE -O3)

find_library(log-lib log)
target_link_libraries(chesslab_engine ${log-lib})
target_link_options(chesslab_engine PRIVATE ${PAGE_16K})

# ---------------------------------------------------------------------------
# Fairy-Stockfish : les variantes (Chess960, Duck, Coup Volé…)
#
# Les deux moteurs tiennent dans la MÊME bibliothèque parce qu'ils ne partagent
# aucun symbole : Stockfish vit dans `namespace Stockfish`, Fairy dans
# `namespace FairyEngine`, et leurs points d'entrée sont renommés (`_main` et
# `_fairy_main`). Ils partagent en revanche le `std::cout` du process, que les
# deux shims détournent — d'où la discipline « un seul moteur à la fois »,
# tenue côté Kotlin par EngineService.

set(FS_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../../../../../Vendor/CFairyStockfish/Sources/CFairyStockfish)

if(EXISTS ${FS_ROOT}/shim.cpp)
    file(GLOB_RECURSE FS_SOURCES
        ${FS_ROOT}/fairystockfish/*.cpp
        ${FS_ROOT}/fairystockfish/nnue/*.cpp
        ${FS_ROOT}/fairystockfish/nnue/features/*.cpp
        ${FS_ROOT}/fairystockfish/syzygy/*.cpp
    )

    add_library(chesslab_fairy SHARED
        ${FS_SOURCES}
        ${FS_ROOT}/shim.cpp
        jni_fairy.cpp
    )

    target_include_directories(chesslab_fairy PRIVATE
        ${FS_ROOT}
        ${FS_ROOT}/include
        ${FS_ROOT}/fairystockfish
    )

    target_compile_definitions(chesslab_fairy PRIVATE
        NNUE_EMBEDDING_OFF
        NO_PEXT
        USE_POPCNT
        USE_NEON=8
        USE_PTHREADS      # mêmes piles de 8 Mo que Stockfish — voir l'entête
        NDEBUG
    )

    target_compile_options(chesslab_fairy PRIVATE -O3)
    target_link_libraries(chesslab_fairy ${log-lib})
    target_link_options(chesslab_fairy PRIVATE ${PAGE_16K})
endif()
