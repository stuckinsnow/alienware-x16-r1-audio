# Shared settings for build.sh, install.sh and uninstall.sh.
# shellcheck shell=bash

KVER="${1:-$(uname -r)}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$REPO_DIR/.cache/$KVER"
OUT_DIR="$REPO_DIR/build/$KVER"
INSTALL_DIR="/lib/modules/$KVER/updates/speaker-fix"

MOK_KEY="/var/lib/shim-signed/mok/MOK.priv"
MOK_CERT="/var/lib/shim-signed/mok/MOK.der"

# "<source dir>:<module name>" for each patched module.
MODULES=(
	"drivers/mfd:intel-lpss-pci"
	"sound/hda/codecs/side-codecs:snd-hda-scodec-cs35l41"
	"sound/hda/codecs/realtek:snd-hda-codec-alc269"
)

die() {
	echo "error: $*" >&2
	exit 1
}
