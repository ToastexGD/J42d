#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
out=$root/build
src=${LINUX_SRC:-$out/linux}
ref=6831bc701a6ce059e71e5aaa9488c9195bea6927

if [ "$(uname -m)" != aarch64 ]; then
	export CROSS_COMPILE=${CROSS_COMPILE:-aarch64-linux-gnu-}
fi

if [ ! -d "$src/.git" ]; then
	git init -q "$src"
	git -C "$src" remote add origin https://github.com/HoolockLinux/linux
	git -C "$src" fetch -q --depth 1 origin "$ref"
	git -C "$src" checkout -q FETCH_HEAD
	for p in "$root"/linux/patches/*.patch; do
		git -C "$src" apply "$p"
	done
fi

cp "$root/linux/j42d_defconfig" "$src/arch/arm64/configs/j42d_defconfig"
make -C "$src" ARCH=arm64 j42d_defconfig
make -C "$src" ARCH=arm64 -j"$(nproc)" Image.gz apple/t7000-j42d.dtb

mkdir -p "$out"
cp "$src/arch/arm64/boot/Image.gz" "$out/Image.gz"
cp "$src/arch/arm64/boot/dts/apple/t7000-j42d.dtb" "$out/t7000-j42d.dtb"
