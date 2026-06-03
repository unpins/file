# file

Standalone build of [file](https://www.darwinsys.com/file/).

[![CI](https://github.com/unpins/file/actions/workflows/file.yml/badge.svg)](https://github.com/unpins/file/actions)
![Linux](https://img.shields.io/badge/Linux-✓-success?logo=linux&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-✓-success?logo=apple&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-✓-success?logo=windows&logoColor=white)

Part of the [unpins](https://unpins.org) project — native single-binary builds with no third-party runtime dependencies.

## Usage

Run the `file` program with [unpin](https://github.com/unpins/unpin):

```bash
unpin file /bin/sh    # identify a file's type
```

The compiled magic database is embedded in the binary, so this works without any companion data files.

To install it onto your PATH:

```bash
unpin install file
```

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

The [Releases](https://github.com/unpins/file/releases) page has standalone binaries for manual download.

## Build notes

- **Windows** uses mingw. file only opens paths it receives on the command line — it doesn't enumerate directories — so the mingw cross builds cleanly without any wide-char filesystem shims.
- **Embedded magic database**: the compiled `magic.mgc` (~8.5 MB raw) is baked into the binary. The release artifact is itself zstd-compressed for download, so the disk size is the only place the raw blob shows — `.zst` end-to-end is ~470 KB regardless. file looks up its magic via the embedded buffer by default; `-m <path>` and `$MAGIC` still work for users who want to override.
- **`--version`** prints `magic file from (embedded)` to signal the embed path is in use.
- **Embedded man pages**: `file.1` (plus `magic.4` / `libmagic.3`) are baked into the binary — read with `unpin man file`. No companion data files are shipped.
- **No upstream features are disabled; no platforms are excluded.**
