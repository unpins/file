{
  description = "Standalone build of file";

  nixConfig = {
    extra-substituters = [ "https://unpins.cachix.org" ];
    extra-trusted-public-keys = [ "unpins.cachix.org-1:DDaShjbZ8VvcqxeTcAU3kV9vxZQBlyb7V/uLBHfTynI=" ];
  };

  inputs.unpins-lib.url = "github:unpins/nix-lib";

  # Two patches:
  #   file-magic-relative.patch — Linux/macOS. file's compiled-in MAGIC points
  #     into the Nix build store, which doesn't exist on the target host once
  #     unpin downloads the binary. Add a `<exedir>/../share/misc/magic.mgc`
  #     lookup using /proc/self/exe (Linux) or _NSGetExecutablePath (macOS),
  #     mirroring the existing _w32_get_magic_relative_to on Windows. The
  #     companion data archive places magic.mgc exactly there.
  #   file-mingw.patch — mingw cross. Upstream cdf.h aliases `struct timespec`
  #     to `struct timeval` on WIN32 as a legacy pre-mingw-w64 shim; modern
  #     mingw-w64 ships its own timespec with a 64-bit tv_sec, while
  #     timeval.tv_sec is 32-bit, so the alias makes `cdf_ctime(&ts.tv_sec, ...)`
  #     a pointer-type mismatch. Remove the alias on mingw.
  #
  # Windows libgnurx note: nixpkgs's libgnurx only builds a DLL plus an import
  # library; even with `--enable-static --disable-shared`, the resulting
  # `libgnurx.a` is just a symlink to the import lib. Recompile regex.o into a
  # real static archive via `ar rcs` (single source file, trivial) and drop the
  # DLL artifacts so file.exe links statically.
  outputs = { self, unpins-lib }:
    unpins-lib.lib.mkStandaloneFlake {
      inherit self;
      name = "file";
      package_data = true;

      build = pkgs:
        pkgs.pkgsStatic.file.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [ ./file-magic-relative.patch ];
        });

      windowsBuild = pkgs:
        let
          cross = unpins-lib.lib.mingwStaticCross pkgs;
          libgnurxStatic = cross.windows.libgnurx.overrideAttrs (old: {
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
          patches = (old.patches or [ ]) ++ [ ./file-mingw.patch ];
          makeFlags = (old.makeFlags or [ ]) ++ [ "LDFLAGS=-all-static" ];
        });
    };
}
