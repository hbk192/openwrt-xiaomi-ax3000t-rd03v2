#!/bin/bash
# Stage luci-theme-argon from its pinned release tarball.
#
# The theme is third-party source (jerrykuku/luci-theme-argon) and this
# repository must not carry it. build.sh calls us with a scratch directory and
# then copies the result into the tree like any other overlay file. It has to
# be a staging step and not a plain PKG_SOURCE: luci.mk derives LUCI_LANGUAGES,
# LUCI_DEFAULTS and the i18n install rules from po/ and root/ at parse time,
# long before a download would unpack (see 11 §4 and the bump notes).
#
# The tarball is pinned by sha256 and kept in the download cache (dl-v2), so a
# repeat build and an offline rebuild never touch the network.
#
# Usage: stage-argon-v2.sh <dest-dir> <download-cache-dir>
#   V2_ARGON_TARBALL    use this tarball instead of <cache>/luci-theme-argon-3.1.1.tar.gz
set -euo pipefail

TAG=v3.1.1
VERSION=${TAG#v}
URL="https://github.com/jerrykuku/luci-theme-argon/archive/refs/tags/$TAG.tar.gz"
SHA256=7ab782b9b2ecfef7f8d3caad1430b1282249a55b9d9f02053842e491f6484540
# OpenWrt's dl/ convention is <package>-<version>.tar.*; keep the cache name the same.
NAME=luci-theme-argon-$VERSION.tar.gz
# Screenshots/less/docs/tests and the GitHub metadata are not needed by the
# package: dropping them keeps the staged tree at ~1 MB instead of ~12 MB.
DROP=".github Screenshots docs less tests"
REQUIRED="htdocs ucode root po"

die() { echo "stage-argon-v2: $*" >&2; exit 1; }

[ $# -eq 2 ] || die "usage: $0 <dest-dir> <download-cache-dir>"
dest=$1 cache=$2
tarball=${V2_ARGON_TARBALL:-$cache/$NAME}

if [ ! -f "$tarball" ]; then
	mkdir -p "$cache"
	echo "stage-argon-v2: downloading $TAG"
	curl -fsSL --retry 3 --connect-timeout 20 --max-time 300 \
		-o "$tarball.part" "$URL" || { rm -f "$tarball.part"; die "cannot download $URL"; }
	mv "$tarball.part" "$tarball"
fi
echo "$SHA256  $tarball" | sha256sum -c - >/dev/null 2>&1 ||
	die "$tarball does not match $SHA256; delete it and rebuild"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/argon.XXXXXX")
trap 'rm -rf "$tmp"' EXIT INT TERM
excludes=()
for d in $DROP; do excludes+=("--exclude=$d"); done
tar -xzf "$tarball" -C "$tmp" --strip-components=1 "${excludes[@]}" || die "cannot unpack $tarball"

for d in $REQUIRED; do
	[ -d "$tmp/$d" ] || die "unpacked tarball has no $d/; did upstream change its layout?"
done

mkdir -p "$dest"
(cd "$tmp" && find . -type f -printf '%P\n') | while read -r f; do
	mkdir -p "$dest/$(dirname "$f")"
	cp -p "$tmp/$f" "$dest/$f"
done
echo "stage-argon-v2: staged $TAG ($(find "$dest" -type f | wc -l) files, $(du -sh "$dest" | cut -f1))"
