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

/nix/store/03i1p74cdy9scviyzfggza77p5j8bssx-server-static-with-deps-env/bin/bwrap \
  --dev /dev \
  --proc /proc \
  --clearenv \
  --tmpfs /tmp \
  --setenv TMPDIR /tmp \
  --setenv USER user \
  --tmpfs /build-home \
  --setenv HOME /build-home \
  --setenv NIX_CONF_DIR /nix/etc/nix \
  --setenv LANG en_US.UTF-8 \
  --setenv LC_CTYPE en_US.UTF-8 \
  --setenv NIX_SSL_CERT_FILE /etc/ssl/certs/ca-certificates.crt \
  --setenv CURL_CA_BUNDLE /etc/ssl/certs/ca-certificates.crt \
  --setenv TERM xterm-256color \
  --setenv PATH $'/bin:/bin0' \
  --bind "$STORE/nix" /nix \
  --ro-bind ./ca-bundle.crt /etc/ssl/certs/ca-certificates.crt \
  --ro-bind ./nix_bin /bin \
  --ro-bind "$STORE/bin" /bin0 \
  --ro-bind ./terminfo /etc/terminfo \
  --ro-bind /etc/resolv.conf /etc/resolv.conf \
  --ro-bind ./binary-cache /binary-substituter-0 \
  --ro-bind ./nixpkgs-slim /bootstrap-nixpkgs \
  --ro-bind "$(pwd)/expr.nix" /expr.nix \
  /nix/store/hcq5bmz5781nhg0kxzspyw3q8ns559wa-bash-static/bin/bash
