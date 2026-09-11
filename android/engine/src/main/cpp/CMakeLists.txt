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
