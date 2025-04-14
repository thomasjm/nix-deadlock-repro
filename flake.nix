{
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.gitignore = {
    url = "github:hercules-ci/gitignore.nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.nix.url = "github:NixOS/nix/2.28-maintenance";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/fdfc4347e915779fe00aca31012e23941b6cd610";

  outputs = { self, flake-utils, gitignore, nix, nixpkgs }:
    flake-utils.lib.eachSystem ["x86_64-linux"] (system:
      let
        pkgs = import nixpkgs { inherit system; };

        nixToUse = pkgs.nix;
        # nixToUse = pkgs.nixVersions.nix_2_25;

        bashStatic = with pkgs; runCommand "bash-static" { allowedReferences = [ pkgsStatic.ncurses pkgsStatic.bashInteractive ]; } ''
          mkdir -p $out/bin
          cp ${pkgsStatic.bashInteractive}/bin/bash $out/bin/bash
          cp -a ${pkgsStatic.bashInteractive}/bin/sh $out/bin/sh
        '';

        contents = with pkgs; [
          bashStatic
          git
          nixToUse
        ];

        store-template = with pkgs; runCommand "store-template" {} ''
          mkdir -p $out/nix/store
          for path in $(cat "${closureInfo { rootPaths = contents; }}/store-paths"); do
            cp -r $path $out/nix/store/$(path##*/)
          done

          mkdir -p $out/nix/etc/nix
          cp ${./nix.conf} $out/nix/etc/nix/nix.conf

          mkdir -p $out/nix/var/nix
          export NIX_STATE_DIR=$out/nix/var/nix
          ${nixToUse}/bin/nix-store --load-db < ${closureInfo { rootPaths = contents; }}/registration

          mkdir -p $out/nix/var/nix/gcroots

          mkdir -p $out/bin
          for f in ${bashStatic}/bin/*; do
            ln -s $f $out/bin/$(basename "$f")
          done
          for f in ${git}/bin/*; do
            ln -s $f $out/bin/$(basename "$f")
          done
          for f in ${nixToUse}/bin/*; do
            ln -s $f $out/bin/$(basename "$f")
          done
        '';

        # store-template = ./store-template;

        binary-cache = import ./binary-cache.nix { inherit system; bootstrap = pkgs; };

        nixStatic_228 = nix.outputs.packages.${system}.nix-cli-static;

      in
        {
          packages = {
            go = pkgs.writeShellScriptBin "nix-deadlock-repro.sh" ''
              #!/usr/bin/env bash

              # Make a fresh store to test with
              STORE=$(mktemp -d store.XXXXXXXXXX)

              cleanup() {
                echo "Cleaning up $STORE..."
                chmod -R u+w "$STORE"
                rm -rf "$STORE"
              }
              trap cleanup EXIT

              ${pkgs.bubblewrap}/bin/bwrap \
                --dev /dev \
                --proc /proc \
                --clearenv \
                --tmpfs /tmp \
                --setenv TMPDIR /tmp \
                --setenv USER user \
                --tmpfs /build-home \
                --setenv HOME /build-home \
                --ro-bind ${./nix.conf} /nix_conf/nix.conf \
                --setenv NIX_CONF_DIR /nix_conf \
                --setenv LANG en_US.UTF-8 \
                --setenv LC_CTYPE en_US.UTF-8 \
                --setenv NIX_SSL_CERT_FILE /etc/ssl/certs/ca-certificates.crt \
                --setenv CURL_CA_BUNDLE /etc/ssl/certs/ca-certificates.crt \
                --setenv TERM xterm-256color \
                --setenv PATH "/bin" \
                --bind "$STORE" /nix \
                --ro-bind ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt /etc/ssl/certs/ca-certificates.crt \
                --ro-bind "${nixStatic_228}/bin" /bin \
                --ro-bind /etc/resolv.conf /etc/resolv.conf \
                --ro-bind /nix/store/vcnr5zi809gmf3jxpxxnbsvpz8phkwyf-binary-cache /binary-substituter-0 \
                --ro-bind ./nixpkgs-slim /bootstrap-nixpkgs \
                --ro-bind ${./expr.nix} /expr.nix \
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
            '';

            inherit nixToUse store-template;
          };
        }
    );
}
