#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
out=$root/build
ver=1.37.0
sum=3311dff32e746499f4df0d5df04d7eb396382d7e108bb9250e7b519b837043a4
src=$out/busybox-$ver

if [ "$(uname -m)" != aarch64 ]; then
	export CROSS_COMPILE=${CROSS_COMPILE:-aarch64-linux-gnu-}
fi

mkdir -p "$out/overlay/bin"

if [ ! -d "$src" ]; then
	curl -fsSL -o "$out/busybox.tar.bz2" "https://busybox.net/downloads/busybox-$ver.tar.bz2"
	echo "$sum  $out/busybox.tar.bz2" | sha256sum -c -
	tar -xjf "$out/busybox.tar.bz2" -C "$out"
fi

make -C "$src" -s allnoconfig
for o in STATIC DEVMEM I2CGET I2CSET I2CDETECT I2CDUMP I2CTRANSFER; do
	sed -i "s/^# CONFIG_$o is not set/CONFIG_$o=y/" "$src/.config"
done
yes '' | make -C "$src" -s oldconfig >/dev/null
make -C "$src" -s -j"$(nproc)"

cp "$src/busybox" "$out/overlay/bin/bb-j42d"
for a in devmem i2cget i2cset i2cdetect i2cdump i2ctransfer; do
	ln -sf bb-j42d "$out/overlay/bin/$a"
done
