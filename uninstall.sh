#!/usr/bin/env bash
# Remove the patched modules and go back to Ubuntu's stock ones (after a reboot).
# Usage: sudo ./uninstall.sh [kernel-version]   (default: running kernel)
set -euo pipefail
source "$(dirname "$0")/common.sh"

[[ $EUID -eq 0 ]] || die "run with sudo"

if [[ -d $INSTALL_DIR ]]; then
	rm -rf "$INSTALL_DIR"
	echo ">> Removed $INSTALL_DIR"
else
	echo ">> Nothing installed for $KVER"
fi

depmod -a "$KVER"
update-initramfs -u -k "$KVER"

echo
for entry in "${MODULES[@]}"; do
	modinfo -k "$KVER" -F filename "${entry##*:}"
done
echo
echo "Stock modules restored. Reboot to finish."
