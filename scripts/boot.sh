#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
out=$root/build
dl=$out/dl
mode=${1:-iboot}

case $mode in
iboot)
	rb=$out/remote_boot
	[ -d "$rb" ] || git clone --recursive https://github.com/HoolockLinux/remote_boot "$rb"
	cd "$rb"
	./remoteboot.sh build
	ls cache/RestoreDeviceTree_*AppleTV5,3.img4 >/dev/null 2>&1 || sudo ./remoteboot.sh prep
	sudo ./remoteboot.sh boot "$out/m1n1-linux.macho" "$dl/m1n1/monitor-stub.macho"
	;;
m1n1)
	rb=$out/remote_boot
	cd "$rb"
	sudo ./remoteboot.sh boot "$dl/m1n1/m1n1-idevice.macho" "$dl/m1n1/monitor-stub.macho"
	;;
pongo)
	[ -f "$dl/Pongo.bin" ] || curl -fsSL -o "$dl/Pongo.bin" https://github.com/HoolockLinux/docs/raw/master/binaries/Pongo.bin
	sudo PALERA1N_BYPASS_PASSCODE_CHECK=1 palera1n -lp -k "$dl/Pongo.bin" || true
	printf '/send %s\nbootm\n' "$out/m1n1-linux.bin" | sudo pongoterm
	;;
*)
	echo "usage: $0 [iboot|m1n1|pongo]" >&2
	exit 1
	;;
esac
