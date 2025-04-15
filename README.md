
# nix-deadlock-repro

This is a repro for an issue I've been facing, where Nix gets stuck in a build indefinitely. When I run with debug logging, I see lots of messages like this:

``` shell
download thread waiting for 10000 ms
download thread waiting for 10000 ms
download thread waiting for 10000 ms
download thread waiting for 10000 ms
download thread waiting for 10000 ms
```

This seems to happen when I'm running Nix inside a `bubblewrap` call (a lightweight sandboxing tool), and when I'm using a local binary cache constructed using the `mkBinaryCache` function.

## To run

To run, just do

``` shell
nix run .#go
```

Or, to drop into a bash shell to look inside the bwrapped environment:

``` shell
nix run .#shell
```
