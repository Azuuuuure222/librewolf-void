#!/bin/sh
set -eu

export LC_ALL=C

template=${1:?usage: fetch-librewolf-source.sh TEMPLATE CACHE_DIR [DESTINATION_DIR]}
cache_dir=${2:?usage: fetch-librewolf-source.sh TEMPLATE CACHE_DIR [DESTINATION_DIR]}
destination_dir=${3:-}

pkgname=$(sed -n 's/^pkgname=//p' "$template")
version=$(sed -n 's/^version=//p' "$template")
_rev=$(sed -n 's/^_rev=//p' "$template")
distfiles=$(sed -n 's/^distfiles="//p' "$template" | sed 's/"$//')
checksum=$(sed -n 's/^checksum=//p' "$template")

: "${pkgname:?missing pkgname}"
: "${version:?missing version}"
: "${_rev:?missing _rev}"
: "${distfiles:?missing distfiles}"
: "${checksum:?missing checksum}"

printf '%s\n' "$checksum" | grep -Eq '^[0-9A-Fa-f]{64}$' || {
	echo "librewolf: checksum must be exactly one 64-character SHA-256 digest" >&2
	exit 1
}

set -- $distfiles
[ "$#" -eq 1 ] || {
	echo "librewolf: exactly one distfile URL is required" >&2
	exit 1
}
disturl=$1
case "$disturl" in
	https://*) ;;
	*)
		echo "librewolf: distfile URL must use HTTPS" >&2
		exit 1
		;;
esac

distfile=${pkgname}-${version}-${_rev}.source.tar.gz
disturl=$(printf '%s\n' "$disturl" |
	sed -e "s/\\\${pkgname}/$pkgname/g" -e "s/\\\${version}/$version/g" -e "s/\\\${_rev}/$_rev/g")

cache_file="$cache_dir/$checksum/$distfile"
mkdir -p "$(dirname "$cache_file")"

verify_sha256() {
	file=$1
	[ -s "$file" ] || return 1
	printf '%s  %s\n' "$checksum" "$file" | sha256sum -c - >/dev/null 2>&1
}

install_source() {
	source_file=$1
	[ -n "$destination_dir" ] || return 0
	mkdir -p "$destination_dir"
	install -m 0644 "$source_file" "$destination_dir/$distfile"
	verify_sha256 "$destination_dir/$distfile"
}

# A valid source already present in the xbps source directory is authoritative
# enough to seed the persistent cache, but it is still SHA-256 verified first.
if [ -n "$destination_dir" ] && verify_sha256 "$destination_dir/$distfile"; then
	if ! verify_sha256 "$cache_file"; then
		install -m 0644 "$destination_dir/$distfile" "$cache_file"
	fi
	echo "librewolf source: verified existing source"
	exit 0
fi

# Cache contents are untrusted input; never use them without verification.
if verify_sha256 "$cache_file"; then
	install_source "$cache_file"
	echo "librewolf source: cache hit"
	exit 0
fi

command -v aria2c >/dev/null 2>&1 || {
	sudo apt-get update -qq
	sudo apt-get install -y --no-install-recommends aria2
}

partial="$cache_file.part"
aria2c \
	--max-connection-per-server=8 \
	--split=8 \
	--min-split-size=4M \
	--continue=true \
	--max-tries=8 \
	--retry-wait=5 \
	--connect-timeout=30 \
	--timeout=30 \
	--file-allocation=none \
	--auto-file-renaming=false \
	--checksum="sha-256=$checksum" \
	--check-integrity=true \
	--dir="$(dirname "$partial")" \
	--out="$(basename "$partial")" \
	"$disturl"

verify_sha256 "$partial" || {
	echo "librewolf: downloaded source failed mandatory SHA-256 verification" >&2
	rm -f "$partial" "$partial.aria2"
	exit 1
}

mv -f "$partial" "$cache_file"
rm -f "$partial.aria2"
verify_sha256 "$cache_file"
install_source "$cache_file"

echo "librewolf source: downloaded, SHA-256 verified, and cached"
