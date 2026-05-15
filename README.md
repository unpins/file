# file

Standalone build of [file](https://www.darwinsys.com/file/).

[![CI](https://github.com/unpins/file/actions/workflows/file.yml/badge.svg)](https://github.com/unpins/file/actions)
![Linux](https://img.shields.io/badge/Linux-✓-success?logo=linux&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-✓-success?logo=apple&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-✓-success?logo=windows&logoColor=white)

Part of the [unpins](https://unpins.org) project — native single-binary builds with no third-party runtime dependencies.

## Installation

Install with [unpin](https://github.com/unpins/unpin):

```bash
unpin file
```

Or run without installing:

```bash
unpin run file
```

`unpin` also extracts the companion `magic.mgc` database into `share/misc/` next to the binary, so `file <path>` works out of the box.

## Build locally

```bash
nix build github:unpins/file
./result/bin/file ./result/bin/file
```

Or run directly:

```bash
nix run github:unpins/file
```

The first invocation will offer to add the [unpins.cachix.org](https://unpins.cachix.org) substituter so most pulls come pre-built.

## Manual download

The [Releases](https://github.com/unpins/file/releases) page has standalone binaries and a `.tar.zst` data archive (the compiled `magic.mgc` database plus man pages) for manual download. Drop `magic.mgc` next to the binary (or under `share/misc/` one level up) and `file` will pick it up automatically.
