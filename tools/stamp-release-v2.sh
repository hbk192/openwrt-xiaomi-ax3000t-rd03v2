#!/bin/bash
# stamp-release-v2.sh <tree> <tag> [repository URL]: write the release stamp and the package
# repository list that go into the image (files/etc/rd03v2-release and
# files/etc/apk/repositories.d/distfeeds.list). build.sh calls it when it prepares a tree;
# finish-build-v2.sh calls it again when TAG is given, so a tree is never re-tagged by hand
# (an earlier build once shipped its predecessor's repository line that way).
#
# The repository URL is optional. Without it the image lists only OpenWrt's snapshot userspace
# feeds and its stamp names no repository: a repository of ours that is not published answers
# 404, and `apk update` then reports it as unavailable on every run. With a URL, that
# repository comes first in the list.
set -euo pipefail
V2=$(cd "$(dirname "$0")/.." && pwd)
TREE=${1:?usage: $0 <tree> <tag> [repository URL]}
TAG=${2:?missing tag}
REPO_URL=${3:-}
case "$TAG" in *[!A-Za-z0-9._-]*|'') echo "stamp-release-v2: unsafe tag '$TAG'" >&2; exit 1 ;; esac
case "$REPO_URL" in
	'') ;;
	http://*/packages.adb|https://*/packages.adb) ;;
	*) echo "stamp-release-v2: '$REPO_URL' is not a packages.adb URL" >&2; exit 1 ;;
esac
. "$V2/upstream.lock"
mkdir -p "$TREE/files/etc/apk/repositories.d"
{
	[ -z "$REPO_URL" ] || echo "$REPO_URL"
	for f in base luci packages routing telephony video; do
		echo "https://downloads.openwrt.org/snapshots/packages/aarch64_cortex-a53/$f/packages.adb"
	done
} >"$TREE/files/etc/apk/repositories.d/distfeeds.list"
{
	echo "RD03V2_TAG='$TAG'"
	echo "RD03V2_BASE='kuncy7/openwrt-nss-edma $RELEASE $COMMIT'"
	echo "RD03V2_FEEDS_LOCK='$(sha256sum "$V2/feeds.lock" | cut -c1-16)'"
	[ -z "$REPO_URL" ] || echo "RD03V2_REPO='$REPO_URL'"
} >"$TREE/files/etc/rd03v2-release"
echo "stamp: $TAG, repository ${REPO_URL:-none}"
