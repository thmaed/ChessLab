#!/bin/bash
set -u
OUT=${ENGINES_DIR:-$PWD/eng}
NDK=${NDK_BIN:-/opt/homebrew/share/android-commandlinetools/ndk/27.2.12479018/toolchains/llvm/prebuilt/darwin-x86_64/bin}
REPO=$(cd "$(dirname "$0")/../.." && pwd)
rm -rf $OUT && mkdir -p $OUT/tar
for t in sf_17.1 sf_19; do mkdir -p $OUT/tar/$t; curl -sL --max-time 180 https://github.com/official-stockfish/Stockfish/archive/refs/tags/$t.tar.gz | tar xz -C $OUT/tar/$t --strip-components=1; done
git -C $REPO show ${OLD_COMMIT:-844d88e}:ChessLab/Resources/nn-1c0000000000.nnue > $OUT/tar/sf_17.1/src/nn-1c0000000000.nnue
git -C $REPO show ${OLD_COMMIT:-844d88e}:ChessLab/Resources/nn-37f18f62d772.nnue > $OUT/tar/sf_17.1/src/nn-37f18f62d772.nnue
cp $REPO/ChessLab/Resources/nn-1a298aa575a0.nnue $OUT/tar/sf_19/src/
for v in sf_17.1 sf_19; do
  for t in mac ndk; do cp -R $OUT/tar/$v $OUT/$t-$v; done
  (cd $OUT/mac-$v/src && make -j8 build ARCH=apple-silicon COMP=clang > make.log 2>&1; echo "mac $v exit $?")
  extra=""; [ $v = sf_17.1 ] && extra="KERNEL=Linux"
  (cd $OUT/ndk-$v/src && PATH=$NDK:$PATH make -j8 build ARCH=armv8 COMP=ndk $extra > make.log 2>&1; echo "ndk $v exit $?")
done
ls -la $OUT/*/src/stockfish | awk '{print $5, $9}'
