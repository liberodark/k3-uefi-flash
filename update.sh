#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")"

SUITE="${K3_SUITE:-resolute}"
BASE="https://ppa.launchpadcontent.net/ubuntu-risc-v-team/k3/ubuntu"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

for t in curl tar python3; do
	command -v "$t" >/dev/null || { echo "missing tool: $t" >&2; exit 1; }
done

PAYLOADS=(
	"edk2-spacemit:/usr/lib/uefi/spacemit/edk2.itb:edk2.itb"
	"opensbi-spacemit:/usr/lib/riscv64-linux-gnu/opensbi/generic/fw_dynamic.itb:fw_dynamic.itb"
	"esos-spacemit:/usr/lib/riscv64-linux-gnu/esos/esos.itb:esos.itb"
	"u-boot-spl-spacemit:/usr/lib/u-boot/spacemit/FSBL.bin:factory/FSBL.bin"
	"u-boot-spl-spacemit:/usr/lib/u-boot/spacemit/bootinfo_spinor.bin:factory/bootinfo_spinor.bin"
	"u-boot-spl-spacemit:/usr/lib/u-boot/spacemit/env.bin:env.bin"
	"u-boot-spacemit:/usr/lib/u-boot/spacemit/u-boot.itb:u-boot.itb"
	"spacemit-ec-firmware:/lib/firmware/k3-pico-itx/ec.bin:ec.bin"
)

echo "package index"
curl -fsSL "$BASE/dists/$SUITE/main/binary-riscv64/Packages.gz" | gunzip > "$TMP/Packages"
curl -fsSL "$BASE/dists/$SUITE/main/binary-all/Packages.gz" 2>/dev/null | gunzip >> "$TMP/Packages" || true

field() {
	awk -v p="$1" -v f="$2" '$1 == "Package:" { c = ($2 == p) } c && $1 == f":" { print $2; exit }' "$TMP/Packages"
}

fetch() {
	local pkg=$1 dir="$TMP/$1" ver file
	[ -d "$dir" ] && return 0
	ver=$(field "$pkg" Version)
	file=$(field "$pkg" Filename)
	[ -n "$file" ] || { echo "  $pkg not in index" >&2; return 1; }
	mkdir -p "$dir"
	printf '  %-22s %s\n' "$pkg" "$ver"
	curl -fsSL "$BASE/$file" -o "$dir/pkg.deb"
	python3 - "$dir/pkg.deb" "$dir" <<-'EOF'
	import sys, os
	deb, out = sys.argv[1], sys.argv[2]
	with open(deb, "rb") as fh:
	    assert fh.read(8) == b"!<arch>\n"
	    while True:
	        hdr = fh.read(60)
	        if len(hdr) < 60:
	            break
	        name = hdr[0:16].decode().strip().rstrip("/")
	        size = int(hdr[48:58].decode().strip())
	        data = fh.read(size)
	        if size % 2:
	            fh.read(1)
	        if name.startswith("data.tar"):
	            open(os.path.join(out, name), "wb").write(data)
	            break
	EOF
	( cd "$dir" && tar -xaf data.tar.* )
}

echo "downloading"
for entry in "${PAYLOADS[@]}"; do
	fetch "${entry%%:*}" || true
done

echo "updating blobs"
for entry in "${PAYLOADS[@]}"; do
	IFS=: read -r pkg src dst <<<"$entry"
	if [ ! -f "$TMP/$pkg$src" ]; then
		printf '  %-30s missing\n' "$dst"
		continue
	fi
	mkdir -p "$(dirname "$dst")"
	if [ -f "$dst" ] && cmp -s "$dst" "$TMP/$pkg$src"; then
		printf '  %-30s unchanged\n' "$dst"
	else
		cp "$TMP/$pkg$src" "$dst"
		printf '  %-30s updated\n' "$dst"
	fi
done

files=()
for f in factory/FSBL.bin factory/bootinfo_spinor.bin factory/bootinfo_block.bin \
	factory/bootinfo_spinand.bin env.bin esos.itb fw_dynamic.itb edk2.itb \
	u-boot.itb ec.bin partition_4M.json; do
	[ -f "$f" ] && files+=("$f")
done
sha256sum "${files[@]}" > SHA256SUMS

echo "SHA256SUMS regenerated (${#files[@]} files)"
