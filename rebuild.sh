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
  echo
  echo "Usage: $0 <host>"
  exit 1
fi

HOST="$1"

echo
echo "sudo nixos-rebuild switch --flake .#${HOST} --impure"
echo

export NIXPKGS_ALLOW_INSECURE=1

sudo --preserve-env=NIXPKGS_ALLOW_INSECURE nixos-rebuild switch --flake ".#${HOST}" --impure
