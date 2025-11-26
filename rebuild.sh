#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo
  echo "Please specify a host:"
  echo "  p-wsl"
  echo "  oci-arm"
  echo "  h-pc"
  echo
  echo "Usage: $0 <host>"
  exit 1
fi

HOST="$1"

echo
echo "sudo nixos-rebuild switch --flake .#${HOST} --impure"
echo

sudo nixos-rebuild switch --flake ".#${HOST}" --impure
