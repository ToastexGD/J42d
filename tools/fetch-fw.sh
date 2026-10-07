#!/bin/sh
set -eu

out=${1:-fw}
url=${IPSW_URL:-$(curl -fsSL 'https://api.ipsw.me/v4/device/AppleTV5,3?type=ipsw' | python3 -c 'import json,sys; print([f for f in json.load(sys.stdin)["firmwares"] if f["signed"]][0]["url"])')}

mkdir -p "$out"
ipsw extract --remote --dtree "$url" -o "$out"
ipsw extract --remote --kernel "$url" -o "$out"
ipsw img4 im4p extract -o "$out/j42d.adt" "$(find "$out" -name 'DeviceTree.j42dap.im4p' | head -n1)"
python3 "$(dirname "$0")/adt.py" "$out/j42d.adt" dump -v > "$out/j42d-adt.txt"
echo "$out/j42d.adt"
