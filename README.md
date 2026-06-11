# k3-uefi-flash

Replace U-Boot with **EDK2 (UEFI)** in the SPI NOR flash of the SpacemiT K3
Pico-ITX, from a running Bianbu system. The internal UFS is left untouched, so
Bianbu stays bootable through the EDK2 Boot Manager.

Blobs come from the official SpacemiT `Bianbu-LXQt-UEFI-K3` image. Hashes are in
`SHA256SUMS`.

## NOR layout

| Offset | Size | Partition | Image |
| ------ | ---- | --------- | ----- |
| 0 | 128K | bootinfo | `factory/bootinfo_spinor.bin` |
| 128K | 512K | fsbl | `factory/FSBL.bin` |
| 640K | 64K | env | `env.bin` |
| 704K | 1M | esos | `esos.itb` |
| 1728K | 384K | opensbi | `fw_dynamic.itb` |
| 2112K | 3M | uboot | `edk2.itb` (replaces `u-boot.itb`) |

## Usage

Run on the board, from within Bianbu, as root:

```sh
sudo ./flash.sh
```

The script checks the MTD mapping against `/proc/mtd`, verifies the blob hashes,
asks for confirmation, then writes each partition with `flashcp`. EDK2 is flashed
last, so an interrupted run still leaves a bootable board.

Reboot when it finishes. You should see the EDK2 banner on UART (115200); press
**F2** within the first 3 seconds for the EDK2 setup.

## Recovery

`u-boot.itb` is kept so you can roll back to stock: flash it to the `uboot`
partition (mtd6) instead of `edk2.itb`. The BootROM flashing mode is always
reachable (hold **FDL** + cold power-on) even with an invalid NOR.
