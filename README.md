# Alienware x16 R1 speaker fix (Linux)

Enables all six internal speakers on the Alienware x16 R1 (subsystem ID
`1028:0bf0`) by patching three kernel modules. Out of the box only one speaker
pair plays.

## Why only one pair plays

| Speakers | Hardware | Problem |
|---|---|---|
| Pair 1 | Realtek ALC289 pin `0x14` | Works |
| Pair 2 | Realtek ALC289 pin `0x17` | No codec quirk for `1028:0bf0`, so the pin is never enabled |
| Pair 3 (likely woofers) | 2x Cirrus CS35L41 on SPI (`CSC3551`) | BIOS has no `_DSD`, so the driver fails with `Platform not supported`. The SPI controller clock is also stuck at 3051 Hz (Dell firmware bug) |

The board layout matches the Dell XPS 15 9530 (`1028:0beb`), which upstream
already supports. Each patch adds this laptop next to the XPS 9530 entry:

| Patch | Module | Change |
|---|---|---|
| `0001` | `intel-lpss-pci` | `QUIRK_CLOCK_DIVIDER_UNITY` for SPI controller `8086:51aa` / `1028:0bf0` |
| `0002` | `snd-hda-scodec-cs35l41` | Amp properties for `10280BF0`: 2 amps, external boost, reset = GPIO index 1, CS for amp 2 = GPIO index 0 |
| `0003` | `snd-hda-codec-alc269` | `ALC289_FIXUP_DELL_CS35L41_SPI_2` for `1028:0bf0` (enables pin `0x17` and binds the amps) |

The GPIO indices in `0002` are inferred from the ACPI `_CRS` in the Cirrus
SSDT (`SPKRAMPS`), which follows the same layout as the XPS 9530.

## Usage

```sh
./build.sh                 # as your user; fetches Ubuntu source, patches, builds
sudo ./install.sh          # signs with the DKMS MOK key, installs to updates/, rebuilds initramfs
reboot
```

All scripts take an optional kernel version (default: `uname -r`).

Check after reboot:

```sh
journalctl -k -b | grep -iE 'cs35l41|lpss'
grep -A20 '^Node 0x17' /proc/asound/card*/codec#0 | grep Pin-ctls
```

## Undo

```sh
sudo ./uninstall.sh
reboot
```

If the system misbehaves before you can run that, pick the previous kernel
under "Advanced options" in GRUB. These modules are not needed to boot.

## After a kernel update

The patched modules are built for one kernel version only. After updating:

```sh
./build.sh && sudo ./install.sh && reboot
```

If `build.sh` reports that a patch does not apply, the driver source changed;
update the patch in `patches/` against the new source in `.cache/<kver>/src`.

## Requirements

- Ubuntu with `deb-src` enabled, and `linux-headers-<kver>` installed
- Secure Boot: the DKMS MOK key in `/var/lib/shim-signed/mok/` must be enrolled
  (`mokutil --test-key /var/lib/shim-signed/mok/MOK.der`)
