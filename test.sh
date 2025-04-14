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

/nix/store/03i1p74cdy9scviyzfggza77p5j8bssx-server-static-with-deps-env/bin/bwrap \
  --dev /dev \
  --proc /proc \
  --clearenv \
  --tmpfs /tmp \
  --setenv TMPDIR /tmp \
  --setenv USER user \
  --tmpfs /build-home \
  --setenv HOME /build-home \
  --ro-bind ./nix.conf /nix_conf/nix.conf \
  --setenv NIX_CONF_DIR /nix_conf \
  --setenv LANG en_US.UTF-8 \
  --setenv LC_CTYPE en_US.UTF-8 \
  --setenv NIX_SSL_CERT_FILE /etc/ssl/certs/ca-certificates.crt \
  --setenv CURL_CA_BUNDLE /etc/ssl/certs/ca-certificates.crt \
  --setenv TERM xterm-256color \
  --setenv PATH $'/bin' \
  --bind "$STORE" /nix \
  --ro-bind ./ca-bundle.crt /etc/ssl/certs/ca-certificates.crt \
  --ro-bind ./nix_bin /bin \
  --ro-bind ./terminfo /etc/terminfo \
  --ro-bind /etc/resolv.conf /etc/resolv.conf \
  --ro-bind /nix/store/vcnr5zi809gmf3jxpxxnbsvpz8phkwyf-binary-cache /binary-substituter-0 \
  --ro-bind ./nixpkgs-slim /bootstrap-nixpkgs \
  --ro-bind "$(pwd)/expr.nix" /expr.nix \
  nix build \
  --arg system $'"x86_64-linux"' \
  --file /expr.nix \
  --extra-substituters $'file:///binary-substituter-0?priority=10&trusted=true' \
  --extra-trusted-substituters $'file:///binary-substituter-0?priority=10&trusted=true' \
  --option always-allow-substitutes true \
  --extra-experimental-features nix-command \
  --extra-experimental-features flakes \
  --option max-jobs 1 \
  --debug -v
