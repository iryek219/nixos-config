#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo
  echo "Please specify a host:"
  echo "  p-wsl"
  echo "  h-nitro"
  echo "  h-tuf"
  echo "  h-pc"
  echo "  oci-arm"
  echo "  n40l"
  echo
  echo "Usage: $0 <host>"
  exit 1
fi

HOST="$1"

echo
echo "nixos-rebuild switch --sudo --flake .#${HOST} --impure"
echo

export NIXPKGS_ALLOW_INSECURE=1

# Evaluate and fetch inputs as the invoking user (whose SSH key can read the
# private git+ssh inputs, e.g. windmill); only activation runs under sudo.
nixos-rebuild switch --sudo --flake ".#${HOST}" --impure "${@:2}"
