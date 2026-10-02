#!/usr/bin/env bash
set -euo pipefail

template=${1:?template path required}
: "${GITHUB_OUTPUT:=}"

bash -n "$template"
pkgname=$(sed -n 's/^pkgname=//p' "$template")
version=$(sed -n 's/^version=//p' "$template")
revision=$(sed -n 's/^revision=//p' "$template")
_rev=$(sed -n 's/^_rev=//p' "$template")
checksum=$(sed -n 's/^checksum=//p' "$template")
distfiles=$(sed -n 's/^distfiles="//p' "$template" | sed 's/"$//')

: "${pkgname:?}" "${version:?}" "${revision:?}" "${_rev:?}" "${checksum:?}" "${distfiles:?}"

[ "$pkgname" = "librewolf" ] || {
  echo "workflow is only valid for pkgname=librewolf" >&2
  exit 1
}

case "$version" in
  ''|*[!0-9.]*) echo "invalid LibreWolf version: $version" >&2; exit 1 ;;
esac

case "$revision" in
  ''|0|*[!0-9]*) echo "revision must be a positive integer: $revision" >&2; exit 1 ;;
esac

case "$_rev" in
  ''|*[!0-9]*) echo "_rev must be a non-negative integer: $_rev" >&2; exit 1 ;;
esac

printf '%s\n' "$checksum" | grep -Eq '^[0-9A-Fa-f]{64}$' || {
  echo "template checksum must be exactly one 64-character SHA-256 digest" >&2
  exit 1
}

set -- $distfiles
[ "$#" -eq 1 ] || {
  echo "template must contain exactly one distfile URL" >&2
  exit 1
}

case "$1" in
  https://*) ;;
  *) echo "distfile must use HTTPS: $1" >&2; exit 1 ;;
esac

expected_template_distfile='${pkgname}-${version}-${_rev}.source.tar.gz'
actual_distfile="${1##*/}"
[ "$actual_distfile" = "$expected_template_distfile" ] || {
  echo "distfile basename mismatch: expected $expected_template_distfile, got $actual_distfile" >&2
  exit 1
}

distfile="${pkgname}-${version}-${_rev}.source.tar.gz"
release_tag="${version}-${_rev}"

if [ -n "$GITHUB_OUTPUT" ]; then
  {
    echo "sha256=$checksum"
    echo "distfile=$distfile"
    echo "version=$version"
    echo "rev=$_rev"
    echo "release_tag=$release_tag"
  } >> "$GITHUB_OUTPUT"
fi

printf 'validated: %s %s (source %s)\n' "$pkgname" "$release_tag" "$distfile"
