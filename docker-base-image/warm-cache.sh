#!/usr/bin/env bash
set -euo pipefail

# Prefetch APT packages into /var/cache/apt/archives (download only)
if [[ -n "${PKGS:-}" ]]; then
  echo "==> Prefetching APT packages: ${PKGS}"
  apt-get update

  # Compute dependency closure (Depends/PreDepends) without recommends/suggests
  read -r -a pkgs <<< "${PKGS}"
  tmpdir="$(mktemp -d)"
  {
    printf '%s\n' "${pkgs[@]}"
    apt-cache depends --recurse \
      --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances --no-recommends \
      "${pkgs[@]}" 2>/dev/null | awk '/^(  PreDepends|  Depends): /{print $2}' | sed 's/|//g'
  } | awk 'NF' | sort -u > "${tmpdir}/allpkgs"

  # Download all packages (batched) into APT archive cache
  xargs -r -a "${tmpdir}/allpkgs" -n 20 bash -lc 'apt-get install -y \
    --reinstall --download-only --no-install-recommends "$@" || true' _

  rm -rf "${tmpdir}"
else
  echo "NOTE: PKGS is empty – skipping APT prefetch."
fi

# Diagnostics
echo "==> go version: $(go version)"
echo "==> GOMODCACHE: $(go env GOMODCACHE)"
echo "==> GOCACHE:    $(go env GOCACHE)"

# Warm Go module and build caches for every module under /workspace
mods=$(find /workspace -type f -name go.mod -not -path '*/vendor/*' | sort || true)
if [[ -z "${mods}" ]]; then
  echo "NOTE: No go.mod found under /workspace – skipping Go cache warm."
  # Still print APT cache stats if present
  num_deb_files=$(find /var/cache/apt/archives -name '*.deb' 2>/dev/null | wc -l || true)
  echo "==> APT .deb files:   ${num_deb_files}"
  exit 0
fi

while IFS= read -r m; do
  dir="$(dirname "${m}")"
  echo "==> Warming module: ${dir#/workspace/}"
  ( cd "${dir}" && go mod download )
  ( cd "${dir}" && CGO_ENABLED=0 go build ./... ) || true
done <<< "${mods}"

num_mod_files=$(find "$(go env GOMODCACHE)" -type f | wc -l || true)
num_go_cache_files=$(find "$(go env GOCACHE)" -type f | wc -l || true)
num_deb_files=$(find /var/cache/apt/archives -name '*.deb' | wc -l || true)

echo "==> GOMODCACHE files: ${num_mod_files}"
echo "==> GOCACHE files:    ${num_go_cache_files}"
echo "==> APT .deb files:   ${num_deb_files}" 