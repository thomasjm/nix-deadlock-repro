{
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.gitignore = {
    url = "github:hercules-ci/gitignore.nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/master";

  outputs = { self, flake-utils, gitignore, nixpkgs }:
    flake-utils.lib.eachSystem ["x86_64-linux"] (system:
      let
        pkgs = import nixpkgs { inherit system; };

        bashStatic = with pkgs; runCommand "bash-static" { allowedReferences = [ pkgsStatic.ncurses pkgsStatic.bashInteractive ]; } ''
          mkdir -p $out/bin
          cp ${pkgsStatic.bashInteractive}/bin/bash $out/bin/bash
          cp -a ${pkgsStatic.bashInteractive}/bin/sh $out/bin/sh
        '';

        contents = with pkgs; [
          bashStatic
          git
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
          ${nix}/bin/nix-store --load-db < ${closureInfo { rootPaths = contents; }}/registration

          mkdir -p $out/nix/var/nix/gcroots

          mkdir -p $out/bin
          for f in ${bashStatic}/bin/*; do
            ln -s $f $out/bin/$(basename "$f")
          done
          for f in ${git}/bin/*; do
            ln -s $f $out/bin/$(basename "$f")
          done
        '';

        binary-cache = import ./binary-cache.nix { inherit system; bootstrap = pkgs; };

      in
        {
          packages = {
            go = pkgs.writeShellScriptBin "nix-deadlock-repro.sh" ''
              # Make a fresh store to test with
              STORE=$(mktemp -d store.XXXXXXXXXX)

              cleanup() {
                echo "Cleaning up $STORE..."
                chmod -R u+w "$STORE"
                rm -rf "$STORE"
              }
              trap cleanup EXIT

              cp -r ${store-template}/* "$STORE"
              chmod u+w "$STORE/nix" "$STORE/nix/store" "$STORE/bin"
              chmod -R u+w "$STORE/nix/var"

              ${pkgs.bubblewrap}/bin/bwrap \
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
                --ro-bind ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt /etc/ssl/certs/ca-certificates.crt \
                --ro-bind ${pkgs.nix}/bin /bin \
                --ro-bind "$STORE/bin" /bin0 \
                --ro-bind /etc/resolv.conf /etc/resolv.conf \
                --ro-bind ${binary-cache} /binary-substituter-0 \
                --ro-bind ${pkgs.path} /bootstrap-nixpkgs \
                --ro-bind "$(pwd)/expr.nix" ${./expr.nix} \
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
          };
        }
    );
}
