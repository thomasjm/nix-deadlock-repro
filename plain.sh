#!/usr/bin/env bash

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPTDIR"

STORE=$(mktemp -d -p $(pwd) store.XXXXXXXXXX)

cleanup() {
  echo "Cleaning up $STORE..."
  chmod -R u+w "$STORE"
  rm -rf "$STORE"
}
trap cleanup EXIT

cp -r store-template/* "$STORE"
chmod u+w "$STORE/nix" "$STORE/nix/store" "$STORE/bin"
chmod -R u+w "$STORE/nix/var"

export NIX_CONF_DIR="$(pwd)"
echo "NIX_CONF_DIR: $NIX_CONF_DIR"

export NIX_STATE_DIR="$STORE/nix/var/nix"
echo "NIX_STATE_DIR: $NIX_STATE_DIR"

nix build \
  --arg system $'"x86_64-linux"' \
  --file ./expr-plain.nix \
  --store "$STORE" \
  --extra-substituters $'file:///nix/store/vcnr5zi809gmf3jxpxxnbsvpz8phkwyf-binary-cache?priority=10&trusted=true' \
  --extra-trusted-substituters $'file:///nix/store/vcnr5zi809gmf3jxpxxnbsvpz8phkwyf-binary-cache?priority=10&trusted=true' \
  --option always-allow-substitutes true
  # --option max-jobs 1 \
  # --debug -v
