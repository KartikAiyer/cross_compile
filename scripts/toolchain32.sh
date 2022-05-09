#!/bin/bash

# ===============================================
# Raspberry Pi Toolchains(raspberry-pi-cross-compilers): This project
# provides latest automated GCC Cross Compiler & Native (ARM & ARM64)
# build-scripts and precompiled standalone toolchains for Raspberry Pi.

# Copyright (C) 2020 Abhishek Thakur(@abhiTronix) <abhi.una12@gmail.com>

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
# ===============================================

# This script auto downloads, compiles, and compresses Cross & Native GCC ARM Toolchain binaries
# targeting Raspberry Pi 32-bit Stretch(Debian 9) and Buster(Debian 10) OSes only.

set -eo pipefail

helpfunction() {
	#helper function that prints custom usage help menu
	echo ""
	echo ""
	# figlet -t -k -f /usr/share/figlet/standard.flf "Raspberry Pi Toolchains Builder 32-bit"
	echo ""
	# figlet -t -k -f /usr/share/figlet/term.flf "Copyright (c) 2020 abhiTronix"
	echo ""
	echo ""
	echo "Usage: $0 -g [GCC version] -r [Target Pi type] -o [Target Pi OS type] -V"
	echo -e "\t-g GCC version you want to compile?: (7.1.0|7.2.0|7.3.0|7.4.0|7.5.0|8.1.0|8.2.0|8.3.0|8.4.0|9.1.0|9.2.0|9.3.0|9.4.0|10.1.0|10.2.0|10.3.0|11.1.0|11.2.0)"
	echo -e "\t-r What's yours Target Raspberry Pi type?: (0-1|2-3|3+)"
	echo -e "\t-o What's yours Target Raspberry Pi OS type?: (stretch|buster|bullseye)"
	echo -e "\t-V Verbose output for debugging?"
	echo ""
	echo ""
	exit 1 # Exit script after printing help
}

#input arguments handler
while getopts "g:r:o:V" opt; do
	case "$opt" in
	g) GCC_VERSION="$OPTARG" ;;
	r) RPI_TYPE="$OPTARG" ;;
	o) RPIOS_TYPE="$OPTARG" ;;
	V)
		VERBOSE=1
		echo "Info: Activated verbose output!"
		echo ""
		set -v # Set verbose mode.
		;;
	?) helpfunction ;; #prints help function for invalid parameter
	esac
done
#validates parameters and print usage helper function in case parameters are missing
if [ -z "$VERBOSE" ]; then
	VERBOSE=0
fi
if [ -z "$GCC_VERSION" ] || [ -z "$RPI_TYPE" ] || [ -z "$RPIOS_TYPE" ]; then
	echo "Error: Required parameters are missing!"
	helpfunction
fi

#collect parameters from raspbery pi type
if [ "$RPI_TYPE" = "2-3" ]; then
	FOLDER_VERSION=1
	KERNEL=kernel7
	ARCH=armv7-a
	FPU=neon-vfpv4
elif [ "$RPI_TYPE" = "3+" ]; then
	FOLDER_VERSION=2
	KERNEL=kernel7
	ARCH=armv8-a
	FPU=neon-fp-armv8
elif [ "$RPI_TYPE" = "0-1" ]; then
	FOLDER_VERSION=0
	KERNEL=kernel
	ARCH=armv6
	FPU=vfp
else
	echo "Invalid argument value: $RPI_TYPE"
	exit
fi

#collect dependencies versions from raspberry pi os
if [ "$RPIOS_TYPE" = "stretch" ]; then
	if echo ${GCC_VERSION%.*} "6.3" | awk '{exit ( $1 >= $2 )}'; then
		echo "$GCC_VERSION is not supported on stretch!"
		exit 0
	else
		GCCBASE_VERSION=6.3.0
	fi
	GLIBC_VERSION=2.24
	BINUTILS_VERSION=2.28
elif [ "$RPIOS_TYPE" = "buster" ]; then
	if echo ${GCC_VERSION%.*} "8.3" | awk '{exit ( $1 >= $2 )}'; then
		echo "$GCC_VERSION is not supported on buster!"
		exit 0
	else
		GCCBASE_VERSION=8.3.0
	fi
	GLIBC_VERSION=2.28
	BINUTILS_VERSION=2.31.1
elif [ "$RPIOS_TYPE" = "bullseye" ]; then
	if echo ${GCC_VERSION%.*} "10.2" | awk '{exit ( $1 >= $2 )}'; then
		echo "$GCC_VERSION is not supported on bullseye!"
		exit 0
	else
		GCCBASE_VERSION=10.2.0
	fi
	GLIBC_VERSION=2.31
	BINUTILS_VERSION=2.35.2
else
	echo "Invalid argument value: $RPIOS_TYPE"
	exit 1
fi

#collect build directory if not defined
if [ "$BUILDDIR" = "" ]; then
	#select temp directory as default
	echo "Build directory is empty, using temp directory!"
	BUILDDIR=$(dirname "$(mktemp tmp.XXXXXXXXXX -ut)")
fi

#collect programming languages if not defined
if [ "$LANGUAGES" = "" ]; then
	#select `c,c++,fortran` as default
	echo "Building binaries for c,c++,fortran programming languages!"
	LANGUAGES=c,c++,fortran
fi

#pre-defined params
TARGET=arm-linux-gnueabihf
GDB_VERSION=10.2

#validate env variables
if ! [[ "$GCC_VERSION" =~ ^(6.3.0|7.1.0|7.2.0|7.3.0|7.4.0|7.5.0|8.1.0|8.2.0|8.3.0|9.1.0|9.2.0|9.3.0|9.4.0|10.1.0|10.2.0|10.3.0|11.1.0|11.2.0)$ ]]; then exit 1; fi
if ! [[ "$GCCBASE_VERSION" =~ ^(6.3.0|8.3.0|10.2.0)$ ]]; then exit 1; fi
if ! [[ "$GLIBC_VERSION" =~ ^(2.24|2.28|2.31)$ ]]; then exit 1; fi
if ! [[ "$BINUTILS_VERSION" =~ ^(2.28|2.31.1|2.35.2)$ ]]; then exit 1; fi
if ! [[ "$FOLDER_VERSION" =~ ^(0|1|2)$ ]]; then exit 1; fi
if ! [[ "$KERNEL" =~ ^(kernel|kernel7)$ ]]; then exit 1; fi
if ! [[ "$ARCH" =~ ^(armv6|armv7-a|armv8-a)$ ]]; then exit 1; fi
if ! [[ "$FPU" =~ ^(vfp|neon-vfpv4|neon-fp-armv8)$ ]]; then exit 1; fi
if [ "$BUILDDIR" = "" ]; then exit 1; fi
if [ "$LANGUAGES" = "" ]; then exit 1; fi

#download binaries if not found
echo "Downloading and Setting up build directories"

DOWNLOADDIR=$BUILDDIR/build_toolchains
INSTALLDIR=$BUILDDIR/cross-pi-gcc-$GCC_VERSION-$FOLDER_VERSION
SYSROOTDIR=$BUILDDIR/cross-pi-gcc-$GCC_VERSION-$FOLDER_VERSION/$TARGET/libc

mkdir -p "$DOWNLOADDIR"
mkdir -p "$INSTALLDIR"

cd "$DOWNLOADDIR" || exit

if [ ! -d "linux" ]; then
	git clone --depth=1 https://github.com/raspberrypi/linux
fi
if [ ! -d "gcc-$GCCBASE_VERSION" ]; then
	if [ ! -f "gcc-$GCCBASE_VERSION.tar.gz" ]; then wget -q --no-check-certificate https://ftp.gnu.org/gnu/gcc/gcc-$GCCBASE_VERSION/gcc-$GCCBASE_VERSION.tar.gz; fi
	tar xf gcc-$GCCBASE_VERSION.tar.gz
	cd gcc-$GCCBASE_VERSION || exit
	if [ "$GCCBASE_VERSION" = "10.2.0" ]; then
		echo "Applying GCC patch!"
		sed -i -e '66i#define PATH_MAX 4096\' libsanitizer/asan/asan_linux.cpp
	fi
	mkdir -p build
	if [ "$GCCBASE_VERSION" = "6.3.0" ]; then
		sed -i contrib/download_prerequisites -e 's/ftp/http/'
	else
		sed -i contrib/download_prerequisites -e '/base_url=/s/ftp/http/'
	fi
	contrib/download_prerequisites
	rm ./*.tar.*
	if [ "$GCCBASE_VERSION" = "6.3.0" ]; then sed -i "1474s/.*/      || xloc.file[0] == '\\\0' || xloc.file[0] == '\\\xff'/" ./gcc/ubsan.c; fi #apply patch
	cd "$DOWNLOADDIR" || exit
	rm ./*.tar.*
fi
if [ ! -d "binutils-$BINUTILS_VERSION" ]; then
	if [ ! -f "binutils-$BINUTILS_VERSION.tar.bz2" ]; then wget -q --no-check-certificate https://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_VERSION.tar.bz2; fi
	tar xf binutils-$BINUTILS_VERSION.tar.bz2
	cd binutils-$BINUTILS_VERSION || exit
	mkdir -p build
	cd "$DOWNLOADDIR" || exit
	rm ./*.tar.*
fi
if [ ! -d "glibc-$GLIBC_VERSION" ]; then
	# Download patched Glibc 2.31 if GCC 10 series are being built
	if [[ "$GCCBASE_VERSION" =~ ^10.* ]] && [ "$GLIBC_VERSION" = "2.31" ]; then
		echo "Downloading patched Glibc v2.31!"
		git clone https://sourceware.org/git/glibc.git --branch release/2.31/master
		mv glibc glibc-$GLIBC_VERSION
	else
		if [ ! -f "glibc-$GLIBC_VERSION.tar.bz2" ]; then wget -q --no-check-certificate https://ftp.gnu.org/gnu/glibc/glibc-$GLIBC_VERSION.tar.bz2; fi
		tar xf glibc-$GLIBC_VERSION.tar.bz2
	fi
	cd glibc-$GLIBC_VERSION || exit
	mkdir -p build
	cd "$DOWNLOADDIR" || exit
	rm ./*.tar.*
fi
if [ ! -d "gdb-$GDB_VERSION" ]; then
	if [ ! -f "gdb-$GDB_VERSION.tar.xz" ]; then wget -q --no-check-certificate https://ftp.gnu.org/gnu/gdb/gdb-$GDB_VERSION.tar.xz; fi
	tar xf gdb-$GDB_VERSION.tar.xz
	cd gdb-$GDB_VERSION || exit
	mkdir -p build
	cd "$DOWNLOADDIR" || exit
	rm ./*.tar.*
fi
if [ ! -d "gcc-$GCC_VERSION" ]; then
	# Download patched GCC 10 series for bullseye
	if [ "$RPIOS_TYPE" = "bullseye" ] && [[ "$GCC_VERSION" =~ ^10.* ]] && [ "$GCC_VERSION" != "10.2.0" ]; then
		echo "Downloading patched GCC-10!"
		git clone https://sourceware.org/git/gcc.git --branch releases/gcc-10
		mv gcc gcc-$GCC_VERSION
	else
		if [ ! -f "gcc-$GCC_VERSION.tar.gz" ]; then wget -q --no-check-certificate https://ftp.gnu.org/gnu/gcc/gcc-"$GCC_VERSION"/gcc-"$GCC_VERSION".tar.gz; fi
		tar xf gcc-"$GCC_VERSION".tar.gz
	fi
	cd gcc-"$GCC_VERSION" || exit
	mkdir -p build
	sed -i contrib/download_prerequisites -e '/base_url=/s/ftp/http/'
	contrib/download_prerequisites
	rm ./*.tar.*
	cd "$DOWNLOADDIR" || exit
	rm ./*.tar.*
fi

echo "Setting up paths..."
PATH=$BUILDDIR/cross-pi-gcc-$GCC_VERSION-$FOLDER_VERSION/bin:$PATH
unset LD_LIBRARY_PATH #patch

echo "Building Kernel Headers..."
cd "$DOWNLOADDIR"/linux || exit
KERNEL=$KERNEL
make -s ARCH=arm INSTALL_HDR_PATH="$SYSROOTDIR"/usr headers_install
mkdir -p "$SYSROOTDIR"/usr/lib

echo "Building binutils..."
if [ -n "$(ls -A "$DOWNLOADDIR"/binutils-$BINUTILS_VERSION/build)" ]; then rm -rf "$DOWNLOADDIR"/binutils-$BINUTILS_VERSION/build/*; fi
cd "$DOWNLOADDIR"/binutils-$BINUTILS_VERSION/build || exit
../configure --target=$TARGET --prefix= --with-arch=$ARCH --with-sysroot=/$TARGET/libc --with-build-sysroot="$SYSROOTDIR" --with-fpu=$FPU --with-float=hard --disable-multilib
make -s -j$(nproc)
make -s install-strip DESTDIR="$INSTALLDIR"
if [ -n "$(ls -A "$DOWNLOADDIR"/binutils-$BINUTILS_VERSION/build)" ]; then rm -rf "$DOWNLOADDIR"/binutils-$BINUTILS_VERSION/build/*; fi

echo "Building Cross GCC $GCCBASE_VERSION Binaries..."
if [ -n "$(ls -A "$DOWNLOADDIR"/gcc-$GCCBASE_VERSION/build)" ]; then rm -rf "$DOWNLOADDIR"/gcc-$GCCBASE_VERSION/build/*; fi
cd "$DOWNLOADDIR"/gcc-$GCCBASE_VERSION/build || exit
../configure --prefix= --target=$TARGET --enable-languages=$LANGUAGES --with-sysroot=/$TARGET/libc --with-build-sysroot="$SYSROOTDIR" --with-arch=$ARCH --with-fpu=$FPU --with-float=hard --disable-multilib
make -s -j$(nproc) all-gcc
make -s install-strip-gcc DESTDIR="$INSTALLDIR"
if [ -n "$(ls -A "$DOWNLOADDIR"/glibc-$GLIBC_VERSION/build)" ]; then rm -rf "$DOWNLOADDIR"/glibc-$GLIBC_VERSION/build/*; fi
cd "$DOWNLOADDIR"/glibc-$GLIBC_VERSION/build || exit
../configure --prefix=/usr --build="$MACHTYPE" --host=$TARGET --target=$TARGET --with-arch=$ARCH --with-sysroot=/$TARGET/libc --with-build-sysroot="$SYSROOTDIR" --with-fpu=$FPU --with-float=hard --with-headers="$SYSROOTDIR"/usr/include --with-lib="$SYSROOTDIR"/usr/lib --disable-multilib libc_cv_forced_unwind=yes
make -s install-bootstrap-headers=yes install-headers DESTDIR="$SYSROOTDIR"
make -s -j$(nproc) csu/subdir_lib
install csu/crt1.o csu/crti.o csu/crtn.o "$SYSROOTDIR"/usr/lib
$TARGET-gcc -nostdlib -nostartfiles -shared -x c /dev/null -o "$SYSROOTDIR"/usr/lib/libc.so
touch "$SYSROOTDIR"/usr/include/gnu/stubs.h "$SYSROOTDIR"/usr/include/bits/stdio_lim.h
cd "$DOWNLOADDIR"/gcc-$GCCBASE_VERSION/build || exit
make -s -j$(nproc) all-target-libgcc
make -s install-target-libgcc DESTDIR="$INSTALLDIR"
cd "$DOWNLOADDIR"/glibc-$GLIBC_VERSION/build || exit
make -s -j$(nproc)
make -s install DESTDIR="$SYSROOTDIR"
cd "$DOWNLOADDIR"/gcc-$GCCBASE_VERSION/build || exit
if [ -n "$(ls -A "$DOWNLOADDIR"/glibc-$GLIBC_VERSION/build)" ]; then rm -rf "$DOWNLOADDIR"/glibc-$GLIBC_VERSION/build/*; fi
make -s -j$(nproc)
make -s install-strip DESTDIR="$INSTALLDIR"
if [ -n "$(ls -A "$DOWNLOADDIR"/gcc-$GCCBASE_VERSION/build)" ]; then rm -rf "$DOWNLOADDIR"/gcc-$GCCBASE_VERSION/build/*; fi

if [ "$GCC_VERSION" != "$GCCBASE_VERSION" ]; then
	cd "$DOWNLOADDIR"/gcc-"$GCC_VERSION"/build || exit
	if [ -n "$(ls -A "$DOWNLOADDIR"/gcc-"$GCC_VERSION"/build)" ]; then rm -rf "$DOWNLOADDIR"/gcc-"$GCC_VERSION"/build/*; fi
	../configure --prefix= --target=$TARGET --enable-languages=$LANGUAGES --with-sysroot=/$TARGET/libc --with-build-sysroot="$SYSROOTDIR" --with-arch=$ARCH --with-fpu=$FPU --with-float=hard --disable-multilib
	make -s -j$(nproc)
	make -s install-strip DESTDIR="$INSTALLDIR"
	if [ -n "$(ls -A "$DOWNLOADDIR"/gcc-"$GCC_VERSION"/build)" ]; then rm -rf "$DOWNLOADDIR"/gcc-"$GCC_VERSION"/build/*; fi

	echo "Building GCC Native GCC $GCC_VERSION Binaries..."
	mkdir -p "$BUILDDIR"/native-pi-gcc-"$GCC_VERSION"-$FOLDER_VERSION
	cd "$DOWNLOADDIR"/gcc-"$GCC_VERSION"/build || exit
	if [ -n "$(ls -A "$DOWNLOADDIR"/gcc-"$GCC_VERSION"/build)" ]; then rm -rf "$DOWNLOADDIR"/gcc-"$GCC_VERSION"/build/*; fi
	../configure --prefix= --build="$MACHTYPE" --host=$TARGET --target=$TARGET --enable-languages=$LANGUAGES --with-arch=$ARCH --with-fpu=$FPU --with-float=hard --disable-multilib --program-suffix=-"$GCC_VERSION"
	make -s -j$(nproc)
	make -s install-strip DESTDIR="$BUILDDIR"/native-pi-gcc-"$GCC_VERSION"-$FOLDER_VERSION
	if [ -n "$(ls -A "$DOWNLOADDIR"/gcc-"$GCC_VERSION"/build)" ]; then rm -rf "$DOWNLOADDIR"/gcc-"$GCC_VERSION"/build/*; fi
	cd "$DOWNLOADDIR"/gcc-"$GCC_VERSION" || exit
	cat gcc/limitx.h gcc/glimits.h gcc/limity.h >"$BUILDDIR"/native-pi-gcc-"$GCC_VERSION"-$FOLDER_VERSION/lib/gcc/$TARGET/"$GCC_VERSION"/include-fixed/limits.h

	echo "Building Native GDB Binaries..."
	cd "$DOWNLOADDIR"/gdb-$GDB_VERSION/build || exit
	if [ -n "$(ls -A "$DOWNLOADDIR"/gdb-$GDB_VERSION/build)" ]; then rm -rf "$DOWNLOADDIR"/gdb-$GDB_VERSION/build/*; fi
	../configure --prefix= --build="$MACHTYPE" --host=$TARGET --target=$TARGET --with-arch=$ARCH --with-fpu=$FPU --with-float=hard --program-suffix=-"$GCC_VERSION"
	make -s -j$(nproc)
	make -s install DESTDIR="$BUILDDIR"/native-pi-gcc-"$GCC_VERSION"-$FOLDER_VERSION
	if [ -n "$(ls -A "$DOWNLOADDIR"/gdb-$GDB_VERSION/build)" ]; then rm -rf "$DOWNLOADDIR"/gdb-$GDB_VERSION/build/*; fi
	echo "Done Building Native GDB Binaries..."

	cd "$BUILDDIR" || exit
	#compress with maximum possible compression level.
	tar cf - native-pi-gcc-"$GCC_VERSION"-$FOLDER_VERSION | pigz -9 -p 32 >native-gcc-"$GCC_VERSION"-pi_"$RPI_TYPE".tar.gz
	#rm -rf "$HOME"/native-pi-gcc-"$GCC_VERSION"-$FOLDER_VERSION
	echo "Done Building Native GCC $GCC_VERSION Binaries..."
fi

cd "$DOWNLOADDIR"/gcc-"$GCC_VERSION" || exit
cat gcc/limitx.h gcc/glimits.h gcc/limity.h >$(dirname $($TARGET-gcc -print-libgcc-file-name))/include-fixed/limits.h

echo "Building Cross GDB Binaries..."
cd "$DOWNLOADDIR"/gdb-$GDB_VERSION/build || exit
if [ -n "$(ls -A "$DOWNLOADDIR"/gdb-$GDB_VERSION/build)" ]; then rm -rf "$DOWNLOADDIR"/gdb-$GDB_VERSION/build/*; fi #cleanup
../configure --prefix= --target=$TARGET --with-arch=$ARCH --with-fpu=$FPU --with-float=hard
make -s -j$(nproc)
make -s install DESTDIR="$INSTALLDIR"
if [ -n "$(ls -A "$DOWNLOADDIR"/gdb-$GDB_VERSION/build)" ]; then rm -rf "$DOWNLOADDIR"/gdb-$GDB_VERSION/build/*; fi #cleanup
echo "Done Building Cross GDB Binaries..."

cd "$BUILDDIR" || exit
#compress with maximum possible compression level.
tar cf - cross-pi-gcc-"$GCC_VERSION"-$FOLDER_VERSION | pigz -9 >cross-gcc-"$GCC_VERSION"-pi_"$RPI_TYPE".tar.gz
echo "Done Building Cross GCC $GCC_VERSION Binaries..."
# rm -rf "$HOME"/cross-pi-gcc-"$GCC_VERSION"-$FOLDER_VERSION

#clean path
PATH=$(echo "$PATH" | sed -e 's;:\?$BUILDDIR/cross-pi-gcc-$GCC_VERSION-$FOLDER_VERSION/bin;;' -e 's;$BUILDDIR/cross-pi-gcc-$GCC_VERSION-$FOLDER_VERSION/bin:\?;;')