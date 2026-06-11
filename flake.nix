{
  description = "file as a single self-contained binary";

  nixConfig = {
    extra-substituters = [ "https://unpins.cachix.org" ];
    extra-trusted-public-keys = [ "unpins.cachix.org-1:DDaShjbZ8VvcqxeTcAU3kV9vxZQBlyb7V/uLBHfTynI=" ];
  };

  inputs.unpins-lib.url = "github:unpins/nix-lib";

  # magic.mgc is embedded directly in the binary (uncompressed, ~8.5MB).
  # The build runs once normally, which generates `magic/magic.mgc` from the
  # ASCII Magdir/ tables, then a postBuild step writes `src/embedded_magic.h`
  # via `xxd -i` and relinks the file binary. file-embed-magic.patch wires
  # file.c::load() to feed the blob to magic_load_buffers when no -m and no
  # $MAGIC; user-supplied -m / $MAGIC still go through magic_load so power
  # users can override.
  #
  # Raw (not gzip): the release artifact is itself zstd-19 compressed for
  # download; over a pre-gzipped blob zstd-19 recovers ~nothing, so raw embed
  # gives a smaller .zst than embed-gzip would. On disk both are ~8.5MB
  # (magic db is dense and doesn't compress in-place). Keeping it raw also
  # avoids dragging zlib into file.c.
  #
  # Companion data tarball keeps only `share/man` (man pages); no more
  # magic.mgc on disk next to the binary.
  #
  # file-mingw.patch (Windows): upstream cdf.h aliases `struct timespec` to
  # `struct timeval` on WIN32 as a legacy pre-mingw-w64 shim; modern
  # mingw-w64 ships its own timespec with a 64-bit tv_sec while timeval's
  # is 32-bit, so the alias makes cdf_ctime(&ts.tv_sec, ...) a pointer-type
  # mismatch. Remove the alias on mingw.
  #
  # Windows libgnurx note: nixpkgs's libgnurx only builds a DLL plus an
  # import library; even with --enable-static --disable-shared, the resulting
  # libgnurx.a is just a symlink to the import lib. Recompile regex.o into a
  # real static archive via `ar rcs` and drop the DLL artifacts so file.exe
  # links statically.
  outputs = { self, unpins-lib }:
    unpins-lib.lib.mkStandaloneFlake {
      inherit self;
      name = "file";

      build = pkgs:
        (pkgs.pkgsStatic.file.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [ ./file-embed-magic.patch ];
          nativeBuildInputs = (old.nativeBuildInputs or [ ])
            ++ [ pkgs.buildPackages.xxd ];
          # On darwin, nix-lib's filterEnableStaticOnDarwin strips
          # --enable-static / --disable-shared from configureFlags to keep
          # libSystem dynamic (it's the only system lib). file doesn't need
          # that workaround; without --disable-shared we end up with
          # libmagic.1.dylib next to the binary, which breaks our
          # single-binary promise. Push --disable-shared back in via the
          # bash configureFlagsArray so the filter (which operates on the
          # Nix list) can't reach it. Also: libtool by default builds .a
          # only when --enable-static is set; let it default to dynamic OR
          # add it back too — autotools' default is --enable-static for
          # convenience libraries, but be explicit.
          preConfigure = (old.preConfigure or "") + ''
            configureFlagsArray+=("--disable-shared" "--enable-static")
          '';
          postPatch = (old.postPatch or "") + ''
            cat > src/embedded_magic.h <<'EOF'
            static const unsigned char magic_mgc[1] = { 0 };
            static const unsigned int magic_mgc_len = 0;
            EOF
          '';
          postBuild = (old.postBuild or "") + ''
            test -f magic/magic.mgc || { echo "embed: magic.mgc not built"; exit 1; }
            xxd -n magic_mgc -i magic/magic.mgc > src/embedded_magic.h
            rm -f src/file.o src/.libs/file src/file
            make
          '';
          postInstall = (old.postInstall or "") + ''
            rm -rf $out/share/misc
          '';
        }));

      windowsBuild = pkgs:
        let
          cross = unpins-lib.lib.mingwStaticCross pkgs;
          libgnurxStatic = cross.windows.libgnurx.overrideAttrs (old: {
            # GCC 15 (nixpkgs 26.05) defaults to -std=gnu23, where `bool`,
            # `true`, `false` become keywords. libgnurx's vintage glibc regex
            # (regex_internal.h) still uses `bool` as a plain identifier, so
            # the C23 keyword makes regex.o fail with "expected ';' before
            # 'bool'". Pin the pre-C23 dialect to restore identifier `bool`.
            NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "") + " -std=gnu17";
            postBuild = (old.postBuild or "") + ''
              $AR rcs libgnurx-real.a regex.o
            '';
            postInstall = ''
              install -m 644 libgnurx-real.a $out/lib/libgnurx.a
              rm -f $out/lib/libgnurx.dll.a $out/lib/libregex.a
              rm -f $out/bin/libgnurx-0.dll
              rmdir $out/bin 2>/dev/null || true
            '';
          });
        in
        (cross.file.override { libgnurx = libgnurxStatic; }).overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [ ./file-mingw.patch ./file-embed-magic.patch ];
          nativeBuildInputs = (old.nativeBuildInputs or [ ])
            ++ [ pkgs.buildPackages.xxd ];
          postPatch = (old.postPatch or "") + ''
            cat > src/embedded_magic.h <<'EOF'
            static const unsigned char magic_mgc[1] = { 0 };
            static const unsigned int magic_mgc_len = 0;
            EOF
          '';
          postBuild = (old.postBuild or "") + ''
            test -f magic/magic.mgc || { echo "embed: magic.mgc not built"; exit 1; }
            xxd -n magic_mgc -i magic/magic.mgc > src/embedded_magic.h
            rm -f src/file.o src/.libs/file.exe src/file.exe
            make
          '';
          postInstall = (old.postInstall or "") + ''
            rm -rf $out/share/misc
          '';
          makeFlags = (old.makeFlags or [ ]) ++ [ "LDFLAGS=-all-static" ];
        });
    };
}
