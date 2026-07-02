{
  description = "file as a single self-contained binary";

  nixConfig = {
    extra-substituters = [ "https://unpins.cachix.org" ];
    extra-trusted-public-keys = [ "unpins.cachix.org-1:DDaShjbZ8VvcqxeTcAU3kV9vxZQBlyb7V/uLBHfTynI=" ];
  };

  inputs.unpins-lib.url = "github:unpins/nix-lib";

  # magic.mgc (file's magic database) is not compiled into rodata — it rides the
  # binary's EOF ZIP (withRuntimeData), zstd-compressed (~31x: 10.6 MB → 340 KB).
  # file.c::load() reads it back via the unpin-vfs self-EOF reader. Keeping it
  # out of rodata also keeps it out of the mega's bitcode module. See
  # docs/runtime-data.md (Pattern 2). The Windows path is the same, in marker
  # mode (mingw has no memfd → temp file); the marker #define is inert on Linux,
  # so injectVfs is shared.
  outputs = { self, unpins-lib }:
    let
      lib = unpins-lib.lib;

      # VFS mount root, unique so a folded mega never confuses it with another
      # package's runtime data. Must match -DUNPIN_VFS_ROOT and the ZIP entry.
      vfsRoot = "/__unpin_filemagic__/";

      # The slash-free middle of vfsRoot: on mingw vfs.c matches by strstr (not
      # POSIX prefix), so a backslash/drive-mangled path still resolves.
      vfsMarker = "__unpin_filemagic__";

      # magic.mgc from the build host's native file: it's arch-independent data,
      # so one cached copy serves every arch and skips an extra engine build.
      magicDbFor = pkgs: pkgs.buildPackages.runCommand "file-magic-db" { } ''
        mkdir -p "$out"
        cp ${pkgs.buildPackages.file}/share/misc/magic.mgc "$out/magic.mgc"
      '';

      # Vendor the unpin-vfs core so load() can read magic.mgc from the ZIP.
      # Objects are precompiled with the right -D knobs (the implicit .c.o rule
      # carries none) and injected via file_LDADD, kept out of file_SOURCES so
      # make never rebuilds them with the wrong flags. Shared with windowsBuild.
      injectVfs = pkgs: drv: drv.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./file-vfs-magic.patch ];

        postPatch = (old.postPatch or "") + ''
          echo "==> inject unpin-vfs core (self-EOF + zstd) for embedded magic.mgc"
          cp ${./vfs.c}          src/vfs.c
          cp ${./vfs.h}          src/vfs.h
          cp ${./miniz.c}        src/miniz.c
          cp ${./miniz.h}        src/miniz.h
          cp ${./unpin_zstd.c}   src/unpin_zstd.c
          cp ${./unpin_zstd.h}   src/unpin_zstd.h
          cp ${./zstddeclib.c}   src/zstddeclib.c
          cp ${./unpin_magic.c}  src/unpin_magic.c
          cp ${./unpin_magic.h}  src/unpin_magic.h
        '';

        # Precompile with $CC (the engine wrapper → bitcode, so they fold into
        # the module). makeFlagsArray, so the spaces in the value survive.
        preBuild = (old.preBuild or "") + ''
          echo "==> precompile unpin-vfs objects for file"
          ( cd src
            MZ='-DMINIZ_USE_ZSTD -DMINIZ_NO_TIME -DMINIZ_NO_ARCHIVE_WRITING_APIS -DMINIZ_NO_ZLIB_APIS -DMINIZ_NO_ZLIB_COMPATIBLE_NAMES'
            $CC $CFLAGS -c -I. \
              -DUNPIN_VFS_SELF -DUNPIN_VFS_ROOT='"${vfsRoot}"' -DMINIZ_USE_ZSTD \
              -DUNPIN_VFS_WIN_MARKER='"${vfsMarker}"' \
              vfs.c -o vfs.o
            $CC $CFLAGS -c -I. $MZ -w miniz.c -o miniz.o
            $CC $CFLAGS -c -I. -DMINIZ_USE_ZSTD -DUNPIN_ZSTD_VENDORED -w unpin_zstd.c -o unpin_zstd.o
            $CC $CFLAGS -c -I. -DUNPIN_VFS_ROOT='"${vfsRoot}"' unpin_magic.c -o unpin_magic.o
          )
          makeFlagsArray+=("file_LDADD=libmagic.la vfs.o miniz.o unpin_zstd.o unpin_magic.o${if pkgs.stdenv.hostPlatform.isDarwin then "" else " -lm"}")
        '';

        # magic.mgc rides the ZIP now; drop the on-disk copy to stay single-file.
        postInstall = (old.postInstall or "") + ''
          rm -rf $out/share/misc
        '';
      });
    in
    lib.mkStandaloneFlake {
      inherit self;
      name = "file";

      engine = "unpin-llvm";
      multicall = {
        programs = [{ name = "file"; }];
        # Points the mega at the magic db tree so it's merged into the mega's
        # ZIP (like the man pages).
        runtimeDataRoot = pkgs: "${magicDbFor pkgs}";
        windows = true;
      };

      # PRISTINE VFS base (no embed). The magic.mgc runtime tree is embedded once,
      # post-build, via runtimeEmbed → unpinEmbedWrap (man is auto-harvested since
      # embedMan defaults on); the same magic db is declared to the mega via
      # multicall.runtimeDataRoot above.
      build = pkgs:
        injectVfs pkgs (pkgs.pkgsStatic.file.overrideAttrs (old: {
          # Run file's test suite on native runners; auto-skips on crosses the
          # build host can't execute. The harness builds its own `test` binary
          # against libmagic + the in-tree magic db, so it's independent of our
          # embedded-VFS magic path (which only touches the `file` program).
          doCheck = pkgs.pkgsStatic.file.stdenv.buildPlatform.canExecute
            pkgs.pkgsStatic.file.stdenv.hostPlatform;
          # nix-lib's filterEnableStaticOnDarwin strips --disable-shared (to
          # keep libSystem dynamic), but then file emits a stray libmagic dylib.
          # Push it back via configureFlagsArray, out of the Nix-list filter's
          # reach.
          preConfigure = (old.preConfigure or "") + ''
            configureFlagsArray+=("--disable-shared" "--enable-static")
          '';
        }));

      runtimeEmbed =
        let stage = pkgs: ''
          cp ${magicDbFor pkgs}/magic.mgc "$__unpin_stage/magic.mgc"
          chmod u+w "$__unpin_stage/magic.mgc"
        '';
        in {
          native = pkgs: base: { runtimeStage = stage pkgs; };
          windows = pkgs: base: { runtimeStage = stage pkgs; };
        };

      windowsBuild = pkgs:
        let
          cross = lib.mingwStaticCross pkgs;
          libgnurxStatic = cross.windows.libgnurx.overrideAttrs (old: {
            # libgnurx's vintage glibc regex uses `bool` as a plain identifier,
            # which GCC 15's default -std=gnu23 rejects. Pin the pre-C23 dialect.
            NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "") + " -std=gnu17";
            # libgnurx's Makefile force-links a DLL even under --disable-shared,
            # but the engine's mingw CRT has no DLL startup. file links regex
            # statically anyway, so build only regex.o → a real libgnurx.a and
            # never reach the DLL target.
            buildPhase = ''
              runHook preBuild
              make regex.o
              $AR rcs libgnurx.a regex.o
              runHook postBuild
            '';
            # Clear nixpkgs' postInstall, which symlinks libgnurx.a onto the
            # import lib — it'd collide with the real archive we install.
            postInstall = "";
            installPhase = ''
              runHook preInstall
              mkdir -p $out/lib $out/include
              install -m 644 libgnurx.a $out/lib/libgnurx.a
              install -m 644 regex.h $out/include/regex.h
              runHook postInstall
            '';
          });
        in
        # PRISTINE VFS base; the magic.mgc runtime is embedded post-build via
        # runtimeEmbed.windows above (the single embed path).
        injectVfs pkgs
          ((cross.file.override { libgnurx = libgnurxStatic; }).overrideAttrs (old: {
            # cdf.h aliases timespec→timeval on WIN32, a pre-mingw-w64 shim
            # that mismatches modern mingw's 64-bit tv_sec. Remove it.
            patches = (old.patches or [ ]) ++ [ ./file-mingw.patch ];
            # -all-static: the engine's mingw CRT has no DLL startup, so the
            # PE32+ must link fully static.
            makeFlags = (old.makeFlags or [ ]) ++ [ "LDFLAGS=-all-static" ];
          }));
    };
}
