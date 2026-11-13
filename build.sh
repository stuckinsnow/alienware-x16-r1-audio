#!/usr/bin/env bash
# Fetch Ubuntu's source for a kernel, apply patches/, and build the three modules.
# Usage: ./build.sh [kernel-version]   (default: running kernel)
# Runs as your user. Touches nothing outside this repo.
set -euo pipefail
source "$(dirname "$0")/common.sh"

[[ $EUID -ne 0 ]] || die "run build.sh as your user, not root"

KDIR="/lib/modules/$KVER/build"
[[ -d $KDIR ]] || die "kernel headers for $KVER not found (install linux-headers-$KVER)"

read -r SRC_PKG SRC_VER < <(dpkg-query -W -f='${source:Package} ${source:Version}\n' "linux-modules-$KVER") ||
	die "linux-modules-$KVER is not installed"

SRC="$WORK_DIR/src"
BUILD="$WORK_DIR/build"

if [[ ! -f $SRC/Makefile ]]; then
	echo ">> Fetching $SRC_PKG $SRC_VER"
	mkdir -p "$WORK_DIR/dl"
	(cd "$WORK_DIR/dl" && apt-get source --download-only "$SRC_PKG=$SRC_VER")
	rm -rf "$SRC"
	dpkg-source -x "$WORK_DIR"/dl/*.dsc "$SRC"
fi

echo ">> Preparing a clean copy of the driver sources"
rm -rf "$BUILD"
mkdir -p "$BUILD/sound" "$BUILD/drivers"
cp -a "$SRC/sound/hda" "$BUILD/sound/"
cp -a "$SRC/drivers/mfd" "$BUILD/drivers/"

echo ">> Applying patches"
for p in "$REPO_DIR"/patches/*.patch; do
	echo "   $(basename "$p")"
	patch -d "$BUILD" -p1 --forward --batch --quiet --dry-run <"$p" >/dev/null ||
		die "$(basename "$p") does not apply to $KVER; the patch needs updating"
	patch -d "$BUILD" -p1 --forward --batch --quiet <"$p"
done

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
for entry in "${MODULES[@]}"; do
	dir="${entry%%:*}"
	mod="${entry##*:}"
	echo ">> Building $mod"
	make -C "$KDIR" M="$BUILD/$dir" obj-m="$mod.o" -j"$(nproc)" modules >"$WORK_DIR/$mod.log" 2>&1 ||
		die "build of $mod failed, see $WORK_DIR/$mod.log"
	cp "$BUILD/$dir/$mod.ko" "$OUT_DIR/"
done

echo
echo "Built (unsigned) into $OUT_DIR:"
ls -1 "$OUT_DIR"
echo
echo "Next: sudo ./install.sh $KVER"
