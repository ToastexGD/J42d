#!/bin/sh
set -eu

if grep -q '^ID=ubuntu' /etc/os-release; then
	sudo add-apt-repository -y universe
fi

sudo apt-get update
sudo apt-get install -y build-essential git curl python3 flex bison bc \
	libssl-dev libelf-dev device-tree-compiler clang lld xxd usbutils cpio \
	libusb-1.0-0-dev irecovery libirecovery-1.0-dev telnet picocom

if ! command -v ipsw >/dev/null; then
	case $(uname -m) in
	aarch64) arch=arm64 ;;
	x86_64) arch=x86_64 ;;
	*) echo "unsupported host $(uname -m)" >&2; exit 1 ;;
	esac
	tag=$(curl -fsSL https://api.github.com/repos/blacktop/ipsw/releases/latest | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])')
	ver=${tag#v}
	tmp=$(mktemp -d)
	curl -fsSL -o "$tmp/ipsw.tgz" "https://github.com/blacktop/ipsw/releases/download/$tag/ipsw_${ver}_linux_${arch}.tar.gz"
	tar -xzf "$tmp/ipsw.tgz" -C "$tmp"
	sudo install -m755 "$tmp/ipsw" /usr/local/bin/ipsw
	rm -rf "$tmp"
fi

if [ "$(uname -m)" != aarch64 ]; then
	sudo apt-get install -y gcc-aarch64-linux-gnu
fi
