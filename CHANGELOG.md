# Changelog

## [Unreleased]

### Changed

- The binary is about 12× smaller — 11.0 MB to 927 KB on Linux, 11.0 MB to
  771 KB on Windows. The magic database is stored compressed inside the binary
  now (10.7 MB of magic in 340 KB) instead of raw.
- The Windows binary is built by the same compiler as the Linux and macOS ones.
  It now uses the Universal C Runtime, which is part of Windows 10 and later.
  On Windows 7 or 8.1 that runtime has to be installed first — it comes through
  Windows Update. The previous binary did not need it.

### Fixed

- The binary no longer carries a leftover reference to a build-time path under
  `/nix/store` for its magic database.
