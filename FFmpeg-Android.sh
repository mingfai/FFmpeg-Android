#!/bin/bash
#
# FFmpeg-Android, a bash script to build FFmpeg for Android.
#
# Copyright (c) 2012 Cedric Fung <root@vec.io>
#
# FFmpeg-Android will build FFmpeg for Android automatically,
# with patches from VPlayer's Android version <https://vplayer.net/>.
#
# FFmpeg-Android is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 3 of the License, or (at your option) any later version.

# FFmpeg-Android is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.

# You should have received a copy of the GNU Lesser General Public
# License along with FFmpeg-Android; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
#
#
# Instruction:
#
# 0. Install git and Android ndk
# 1. $ export ANDROID_NDK=/path/to/your/android-ndk
# 2. $ ./FFmpeg-Android.sh
# 3. libffmpeg.so will be built to build/ffmpeg/{neon,armv7,vfp,armv6}/
#
#

DEST=`pwd`/build/ffmpeg && rm -rf $DEST
SOURCE=`pwd`/ffmpeg

if [ -d ffmpeg ]; then
  cd ffmpeg
else
  git clone git://source.ffmpeg.org/ffmpeg.git ffmpeg
  cd ffmpeg
fi

git reset --hard
git clean -f -d
git checkout `cat ../ffmpeg-version`
#patch -p1 <../FFmpeg-VPlayer.patch
#[ $PIPESTATUS == 0 ] || exit 1

git log --pretty=format:%H -1 > ../ffmpeg-version

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

FFMPEG_FLAGS="--target-os=linux \
  --arch=arm \
  --enable-cross-compile \
  --cross-prefix=arm-linux-androideabi- \
  --enable-shared \
  --disable-symver \
  --disable-doc \
  --disable-htmlpages \
  --disable-manpages \
  --disable-podpages \
  --disable-txtpages \
  --disable-ffplay \
  --disable-ffmpeg \
  --disable-ffprobe \
  --disable-ffserver \
  --disable-avdevice \
  --disable-bsfs \
  --disable-devices \
  --disable-everything \
  --enable-protocols  \
  --enable-parsers \
  --enable-demuxers \
  --enable-muxers \
  --disable-demuxer=sbg \
  --enable-decoders \
  --disable-encoders \
  --enable-encoder=aac \
  --enable-encoder=libx264 \
  --enable-gpl \
  --enable-libx264 \
  --extra-cflags=-I../build/libx264/armv7/include/ \
  --extra-ldflags=-L../build/libx264/armv7/lib  \
  --enable-network \
  --enable-swscale  \
  --enable-hwaccels 
  --enable-avfilter \
  --enable-filter=transpose \
  --enable-filter=scale \
  --enable-asm \
  --enable-version3 \
  --enable-debug=3 "

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
  FFMPEG_FLAGS="$FFMPEG_FLAGS --prefix=$PREFIX"

  ./configure $FFMPEG_FLAGS --extra-cflags="$CFLAGS $EXTRA_CFLAGS" --extra-ldflags="$EXTRA_LDFLAGS" | tee $PREFIX/configuration.txt
  cp config.* $PREFIX
  [ $PIPESTATUS == 0 ] || exit 1

  make clean
  make -j10 || exit 1
  make install || exit 1

  #not in our version....
  #rm libavcodec/inverse.o
  rm libavcodec/log2_tab.o
  rm libswresample/log2_tab.o
  rm libavformat/log2_tab.o
  $CC -L../build/libx264/armv7/lib -lm -lz -shared --sysroot=$SYSROOT -Wl,--no-undefined -Wl,-z,noexecstack $EXTRA_LDFLAGS libavutil/*.o libavutil/arm/*.o libavcodec/*.o libavcodec/arm/*.o libavformat/*.o libswresample/*.o libswscale/*.o libswscale/arm/*.o compat/*.o libswresample/arm/*.o libavfilter/*.o -lx264 -o $PREFIX/libffmpeg.so

  cp $PREFIX/libffmpeg.so $PREFIX/libffmpeg-debug.so
  arm-linux-androideabi-strip --strip-unneeded $PREFIX/libffmpeg.so

done
