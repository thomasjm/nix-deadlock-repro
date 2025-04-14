
# nixpkgs-slim

A special version of Nixpkgs, which only supports a few basic fetchers and operations. Currently:

* `fetchFromGitHub`
* `fetchgit`
* `symlinkJoin`

This is used as a lightweight (distributable) Nixpkgs that be used to bootstrap Nix builds.

For the generation code, see https://github.com/codedownio/nixpkgs-slim-generate.
