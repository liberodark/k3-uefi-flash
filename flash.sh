#!/usr/bin/env bash
#
# Flash K3 Pico-ITX NOR to UEFI from running Bianbu (flashcp/mtd-utils).
# mtd1=bootinfo mtd2=fsbl mtd3=env mtd4=esos mtd5=opensbi mtd6=uboot(<-edk2)
#
# Mapping MTD :
#   mtd1 = bootinfo (128K)
#   mtd2 = fsbl     (512K)
#   mtd3 = env      (64K)
#   mtd4 = esos     (1M)
#   mtd5 = opensbi  (384K)
#   mtd6 = uboot    (5.94M) ← edk2.itb here
#
# After reboot, the board starts in UEFI mode (EDK2).
# Bianbu on UFS stays accessible via the EDK2 Boot Manager menu.

set -euo pipefail
cd "$(dirname "$0")"

[ "$(id -u)" = 0 ] || { echo "Run as root (sudo)."; exit 1; }
command -v flashcp >/dev/null || apt-get install -y mtd-utils

sha256sum -c SHA256SUMS

read -p "Replace U-Boot with EDK2 in NOR? UFS stays intact. [yes] " c
[ "$c" = yes ] || { echo "Aborted."; exit 0; }

exp="bootinfo fsbl env esos opensbi uboot"; i=1
for n in $exp; do
  grep -q "^mtd$i:.*\"$n\"" /proc/mtd || { echo "mtd$i != $n, abort."; exit 1; }
  i=$((i+1))
done

flashcp -v factory/bootinfo_spinor.bin /dev/mtd1
flashcp -v factory/FSBL.bin            /dev/mtd2
flashcp -v env.bin                     /dev/mtd3
flashcp -v esos.itb                    /dev/mtd4
flashcp -v fw_dynamic.itb              /dev/mtd5
flashcp -v edk2.itb                    /dev/mtd6

echo "Done. Reboot"