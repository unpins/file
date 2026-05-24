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

The compiled magic database is embedded in the binary, so `file <path>` works without any companion data files.

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

The [Releases](https://github.com/unpins/file/releases) page has standalone binaries plus a `.tar.zst` data archive containing the man pages.

## Build notes

- **Windows** uses mingw. file only opens paths it receives on the command line — it doesn't enumerate directories — so the mingw cross builds cleanly without any wide-char filesystem shims.
- **Embedded magic database**: the compiled `magic.mgc` (~8.5 MB raw) is baked into the binary. The release artifact is itself zstd-compressed for download, so the disk size is the only place the raw blob shows — `.zst` end-to-end is ~470 KB regardless. file looks up its magic via the embedded buffer by default; `-m <path>` and `$MAGIC` still work for users who want to override.
- **`--version`** prints `magic file from (embedded)` to signal the embed path is in use.
- **No upstream features are disabled; no platforms are excluded.**
