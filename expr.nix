{ system ? builtins.currentSystem }:

let
  bootstrap = import ((builtins.fetchTree { type = "path"; path = "/bootstrap-nixpkgs"; narHash = "sha256-8qC/XMLDtIn6GN/x7g4VrtYZVKZRiKLW5DZqtea81j0="; })) { inherit system; };


  # bootstrap = import ((builtins.fetchTree { type = "path"; path = "/bootstrap-nixpkgs"; narHash = "sha256-pCglMme56MWxtTNRWrLj55/eJXw4dX4HmZYXUm6+DO4="; })) { inherit system; };


  # bootstrap = import ((builtins.fetchTree { type = "path"; path = "/home/tom/tools/nix-deadlock-repro/nixpkgs-slim"; narHash = "sha256-UQy4h0IUApOxbabFN6zLedi69KcQpj9i2UKaJHTfaOU="; })) { inherit system; };

  channel0 = import (bootstrap.fetchgit {
    url = "https://github.com/codedownio/codedown-languages.git";
    rev = "d77863f14b5123c97c8044f0e255a8c44bb68b82";
    hash = "sha256-9TaDcid3PiXhp2Eq2EJQ6aegK5qYXjSmKNqu2+eiNkg=";
  }) { inherit system; inherit (bootstrap) fetchFromGitHub; };

in

channel0.makeEnvironment {
  kernels.rust.enable = true;
}
