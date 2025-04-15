{ system ? builtins.currentSystem
, bootstrapSrc
}:

let
  bootstrap = import ((builtins.fetchTree { type = "path"; path = bootstrapSrc; narHash = "sha256-pCglMme56MWxtTNRWrLj55/eJXw4dX4HmZYXUm6+DO4="; })) { inherit system; };

  channelSrc = bootstrap.fetchgit {
    url = "https://github.com/codedownio/codedown-languages.git";
    rev = "d77863f14b5123c97c8044f0e255a8c44bb68b82";
    hash = "sha256-9TaDcid3PiXhp2Eq2EJQ6aegK5qYXjSmKNqu2+eiNkg=";
  };
  channel = import channelSrc { inherit system; inherit (bootstrap) fetchFromGitHub; };

  environment = channel.makeEnvironment {
    kernels.rust.enable = true;
    kernels.rust.lsp.rust-analyzer.enable = false;
    kernels.rust.packages = ["serde" "serde_json"];
  };

in

let
  getPkgs = c: builtins.filter (x: x != null) [(c.pkgsStableSrc or null) (c.pkgsMasterSrc or null)];
  paths = [
    (builtins.fetchTree { type = "path"; path = bootstrapSrc; narHash = "sha256-pCglMme56MWxtTNRWrLj55/eJXw4dX4HmZYXUm6+DO4="; })
    environment
    channelSrc
  ] ++ (builtins.concatMap getPkgs [channel]);

in

bootstrap.mkBinaryCache {
  rootPaths = paths ++ (builtins.filter (x: x != null) (map (x: x.inputDerivation or null) paths));
}
