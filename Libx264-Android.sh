#!/bin/bash

DEST=`pwd`/build/libx264 && rm -rf $DEST
SOURCE=`pwd`/libx264

if [ -d libx264 ]; then
    cd libx264
else
    git clone git://git.videolan.org/x264.git libx264
    cd libx264
fi

git reset --hard
git clean -f -d
git checkout stable

git log --pretty=format:%H -1 > ../libx264-version

TOOLCHAIN=/tmp/gavin
SYSROOT=$TOOLCHAIN/sysroot/
$ANDROID_NDK/build/tools/make-standalone-toolchain.sh --platform=android-18 --install-dir=$TOOLCHAIN --system=darwin-x86

export PATH=$TOOLCHAIN/bin:$PATH
export CC="arm-linux-androideabi-gcc"
export LD=arm-linux-androideabi-ld
export AR=arm-linux-androideabi-ar

CFLAGS="-O3 -Wall -mthumb -pipe -fpic -fasm \
  -finline-limit=300 -ffast-math \
  -fstrict-aliasing -Werror=strict-aliasing \
  -fmodulo-sched -fmodulo-sched-allow-regmoves \
  -Wno-psabi -Wa,--noexecstack \
  -D__ARM_ARCH_5__ -D__ARM_ARCH_5E__ -D__ARM_ARCH_5T__ -D__ARM_ARCH_5TE__ \
  -DANDROID -DNDEBUG"

LIBX264_FLAGS=" --enable-pic \
  --enable-static \
  --disable-cli \
  --host=arm-linux \
  --cross-prefix=arm-linux-androideabi- "

# neon armv7 vfp armv6
for version in armv7; do

  cd $SOURCE

  case $version in
    neon)
      EXTRA_CFLAGS="-march=armv7-a -mfpu=neon -mfloat-abi=softfp -mvectorize-with-neon-quad"
      EXTRA_LDFLAGS="-Wl,--fix-cortex-a8"
      ;;
    armv7)
      EXTRA_CFLAGS="-march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=softfp"
      EXTRA_LDFLAGS="-Wl,--fix-cortex-a8"
      ;;
    vfp)
      EXTRA_CFLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=softfp"
      EXTRA_LDFLAGS=""
      ;;
    armv6)
      EXTRA_CFLAGS="-march=armv6"
      EXTRA_LDFLAGS=""
      ;;
    *)
      EXTRA_CFLAGS=""
      EXTRA_LDFLAGS=""
      ;;
  esac

  PREFIX="$DEST/$version" && mkdir -p $PREFIX
  LIBX264_FLAGS="$LIBX264_FLAGS --prefix=$PREFIX"

  ./configure $LIBX264_FLAGS --extra-cflags="$CFLAGS $EXTRA_CFLAGS" --extra-ldflags="$EXTRA_LDFLAGS" | tee $PREFIX/configuration.txt
  cp config.* $PREFIX
  [ $PIPESTATUS == 0 ] || exit 1

  make clean
  make -j4 || exit 1
  make install || exit 1

  #not in our version....

  #cp $PREFIX/libx264.so.* $PREFIX/libx264.so
  #cp $PREFIX/libx264.so $PREFIX/libx264-debug.so
  #arm-linux-androideabi-strip --strip-unneeded $PREFIX/libx264.so

done
