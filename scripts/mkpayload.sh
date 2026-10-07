#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
out=$root/build
dl=$out/dl
mkdir -p "$dl"

fetch_zip() {
	[ -e "$3" ] && return
	curl -fsSL -o "$dl/tmp.zip" "$1"
	python3 -m zipfile -e "$dl/tmp.zip" "$2"
	rm -f "$dl/tmp.zip"
}

fetch_zip https://nightly.link/hoolocklinux/m1n1/workflows/build/idevice/m1n1.zip "$dl/m1n1" "$dl/m1n1/m1n1.bin"
fetch_zip https://nightly.link/HoolockLinux/HoolockRD/workflows/build/master/initramfs.gz.zip "$dl" "$dl/initramfs.gz"

args=${BOOTARGS:-console=tty0 loglevel=7}
initrd=${INITRD:-$dl/initramfs.gz}

rm -rf "$out/rootfs"
mkdir -p "$out/rootfs"
cp -a "$root/initramfs/." "$out/rootfs/"
[ -d "$out/overlay" ] && cp -a "$out/overlay/." "$out/rootfs/"
(cd "$out/rootfs" && find . | cpio -o -H newc -R 0:0 --quiet) > "$out/overlay.cpio"
{ gzip -dc "$initrd"; cat "$out/overlay.cpio"; } | gzip -9 > "$out/initramfs.gz"

for m in m1n1.bin m1n1-idevice.macho; do
	{
		cat "$dl/m1n1/$m"
		printf 'chosen.bootargs=%s\n' "$args"
		cat "$out/t7000-j42d.dtb" "$out/Image.gz" "$out/initramfs.gz"
	} > "$out/m1n1-linux.${m##*.}"
done

ls -l "$out/m1n1-linux.bin" "$out/m1n1-linux.macho"
