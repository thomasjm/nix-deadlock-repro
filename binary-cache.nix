{ system ? builtins.currentSystem
, bootstrap
}:

let
  channel0 = import (bootstrap.fetchgit {
    url = "https://github.com/codedownio/codedown-languages.git";
    rev = "d77863f14b5123c97c8044f0e255a8c44bb68b82";
    hash = "sha256-9TaDcid3PiXhp2Eq2EJQ6aegK5qYXjSmKNqu2+eiNkg=";
  }) { inherit system; inherit (bootstrap) fetchFromGitHub; };

in

let
  getPkgs = c: builtins.filter (x: x != null) [(c.pkgsStableSrc or null) (c.pkgsMasterSrc or null)];
  paths = (
  [
      (bootstrap.fetchFromGitHub {
        owner = "NixOS";
        repo = "nixpkgs";
        rev = "fdfc4347e915779fe00aca31012e23941b6cd610";
        hash = "sha256-pCglMme56MWxtTNRWrLj55/eJXw4dX4HmZYXUm6+DO4=";
      })
      ((builtins.fetchTree { type = "path"; path = "/nix/store/j8si7r4fdnajf2q6f4bkqgfpwjccfwpa-source"; narHash = "sha256-pCglMme56MWxtTNRWrLj55/eJXw4dX4HmZYXUm6+DO4="; }))
  ] ++ [
      (channel0.makeEnvironment {
        kernels.rust.enable = true;
      })
  ]
  ++ (builtins.concatMap getPkgs [channel0])
  );

in

bootstrap.mkBinaryCache {
  rootPaths = paths ++ (builtins.filter (x: x != null) (map (x: x.inputDerivation or null) paths));
}
