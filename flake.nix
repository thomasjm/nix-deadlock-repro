{
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nix.url = "github:NixOS/nix/2.28-maintenance";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/fdfc4347e915779fe00aca31012e23941b6cd610";

  outputs = { self, flake-utils, nix, nixpkgs }:
    flake-utils.lib.eachSystem ["x86_64-linux"] (system:
      let
        pkgs = import nixpkgs { inherit system; };

        binary-cache = import ./binary-cache.nix { inherit system; bootstrapSrc = pkgs.path; };

        nixStatic_228 = nix.outputs.packages.${system}.nix-cli-static;

        # Run a command inside a bubblewrap container. This:
        # - Sets up some basic paths like /tmp
        # - Sets up some common environment variables, including NIX_SSL_CERT_FILE
        # - Mounts the provided bin directory as "/bin"
        # - Mounts the binary cache as "/binary-substituter-0"
        # - Mounts the expr.nix from this repo as "/expr.nix"
        #
        # You can try running the Nix build with "nix run .#go",
        # or open a Bash shell to look around with "nix run .#shell"
        scriptWithBinary = binDir: command: ''
          #!/usr/bin/env bash

          # Make a fresh store to test with
          STORE=$(mktemp -d store.XXXXXXXXXX)
          cleanup() {
            echo "Cleaning up $STORE..."
            chmod -R u+w "$STORE"
            rm -rf "$STORE"
          }
          trap cleanup EXIT

          echo "Starting HTTP substituter"
          ${pkgs.python3}/bin/python -m http.server 8888 --directory ${binary-cache} &
          SERVER_PID=$!
          trap "echo 'Shutting down Python server with PID $SERVER_PID...'; kill $SERVER_PID; exit" EXIT INT TERM
          echo "Sleeping 5s"
          sleep 5

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
            --ro-bind "${binDir}" /bin \
            --ro-bind /etc/resolv.conf /etc/resolv.conf \
            --ro-bind ${binary-cache} /binary-substituter-0 \
            --ro-bind ./nixpkgs-slim /bootstrap-nixpkgs \
            --ro-bind ${./expr.nix} /expr.nix \
            ${command}
        '';

      in
        {
          packages = {
            go = pkgs.writeShellScriptBin "nix-deadlock-repro.sh" (scriptWithBinary "${nixStatic_228}/bin" ''
              nix build \
                --arg system $'"x86_64-linux"' \
                --file /expr.nix \
                --extra-substituters $'http://localhost:8888?priority=10&trusted=true' \
                --extra-trusted-substituters $'http://localhost:8888?priority=10&trusted=true' \
                --option always-allow-substitutes true \
                --option max-jobs 1 \
                --debug -v
            '');

            shell = let
              binDir = pkgs.runCommand "shell-bin-dir" {} ''
                mkdir -p $out
                cp ${pkgs.pkgsStatic.bashInteractive}/bin/bash $out
                cp -a ${pkgs.pkgsStatic.coreutils}/bin/* $out
              '';
              in
                pkgs.writeShellScriptBin "nix-deadlock-repro-shell.sh" (scriptWithBinary binDir "bash");
          };
        }
    );
}
