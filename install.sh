#!/usr/bin/env bash
# Sign the built modules with the existing DKMS MOK key and install them so they
# take priority over Ubuntu's stock modules. Takes effect after a reboot.
# Usage: sudo ./install.sh [kernel-version]   (default: running kernel)
set -euo pipefail
source "$(dirname "$0")/common.sh"

[[ $EUID -eq 0 ]] || die "run with sudo"
[[ -f $MOK_KEY && -f $MOK_CERT ]] || die "MOK signing key not found in /var/lib/shim-signed/mok"
SIGN_FILE="/lib/modules/$KVER/build/scripts/sign-file"
[[ -x $SIGN_FILE ]] || die "$SIGN_FILE not found"

for entry in "${MODULES[@]}"; do
	[[ -f $OUT_DIR/${entry##*:}.ko ]] || die "missing $OUT_DIR/${entry##*:}.ko, run ./build.sh $KVER first"
done

mkdir -p "$INSTALL_DIR"
for entry in "${MODULES[@]}"; do
	mod="${entry##*:}"
	echo ">> Signing and installing $mod"
	install -m 0644 "$OUT_DIR/$mod.ko" "$INSTALL_DIR/$mod.ko"
	"$SIGN_FILE" sha512 "$MOK_KEY" "$MOK_CERT" "$INSTALL_DIR/$mod.ko"
done

echo ">> depmod"
depmod -a "$KVER"

# intel-lpss-pci is loaded from the initramfs, so it must be rebuilt too.
echo ">> update-initramfs"
update-initramfs -u -k "$KVER"

echo
for entry in "${MODULES[@]}"; do
	modinfo -k "$KVER" -F filename "${entry##*:}"
done
echo
echo "Installed. Reboot to test. Undo with: sudo ./uninstall.sh $KVER"
