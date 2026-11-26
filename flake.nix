{
  description = "Bevy 0.19 development environment for NixOS + Wayland";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    sccache = {
      url = "github:mozilla/sccache/v0.20.1";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils, sccache, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        overlays = [ rust-overlay.overlays.default ];
        pkgs = import nixpkgs { inherit system overlays; };

        # Use the same nightly and components as cargo and rust-analyzer.
        rustToolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;

        # This nixpkgs uses system libraries for sccache's TLS and compression backends.
        sccachePackage = sccache.packages.${system}.default.overrideAttrs (old: {
          buildInputs = old.buildInputs ++ [ pkgs.aws-lc pkgs.zstd ];
        });

        # wgpu and winit look up some of these libraries by name at runtime.
        runtimeLibs = with pkgs; [
          vulkan-loader   # libvulkan.so.1 — wgpu's Vulkan backend dlopens this
          libxkbcommon    # required at runtime even on a pure-Wayland build
          wayland         # libwayland-client.so — winit's Wayland backend
          alsa-lib        # bevy_audio / rodio
          udev            # gamepad + input device enumeration
          # winit can also open the window through X11 or XWayland.
          libx11
          libxcursor
          libxi
          libxrandr
        ];
      in {
        devShells.default = pkgs.mkShell {
          # The shell has no output libraries. Keep its checkout path out of linker flags.
          NIX_NO_SELF_RPATH = 1;
          nativeBuildInputs = with pkgs; [ pkg-config rustPlatform.bindgenHook ];
          buildInputs = with pkgs; [
            rustToolchain
            clang                         # linker driver for -fuse-ld=mold
            mold                          # fast linker (wired in .cargo/config.toml)
            llvmPackages.bintools         # lld fallback + llvm-* tools
            vulkan-tools                  # vulkaninfo / vkcube to diagnose GPU/ICD issues
            glib.dev
          ] ++ runtimeLibs;

          shellHook = ''
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath runtimeLibs}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

            echo "Bevy 0.19 dev environment (NixOS/Wayland) ready."
          '';
        };

        devShells.cached = self.devShells.${system}.default.overrideAttrs (old: {
          nativeBuildInputs = old.nativeBuildInputs ++ [ sccachePackage ];
          RUSTC_WRAPPER = "${sccachePackage}/bin/sccache";
          SCCACHE_ALLOW_INCREMENTAL = "cache";
          # Paths in crate metadata also affect cache hits in downstream crates.
          CARGO_PROFILE_DEV_TRIM_PATHS = "all";
          CARGO_PROFILE_RELEASE_TRIM_PATHS = "all";

          shellHook = old.shellHook + ''
            # Keep paths that crates read with env!() specific to their worktree.
            export SCCACHE_BASEDIRS_VERBATIM_ENV_DEPS="CARGO_MANIFEST_DIR,CARGO_MANIFEST_PATH,OUT_DIR''${SCCACHE_BASEDIRS_VERBATIM_ENV_DEPS:+,$SCCACHE_BASEDIRS_VERBATIM_ENV_DEPS}"
            if [[ -z ''${SCCACHE_BASEDIRS:-} ]]; then
              while IFS= read -r -d "" field; do
                # sccache uses a colon to separate root paths on Linux.
                if [[ $field == "worktree "* && $field != *:* ]]; then
                  SCCACHE_BASEDIRS="''${SCCACHE_BASEDIRS:+$SCCACHE_BASEDIRS:}''${field#worktree }"
                fi
              done < <(${pkgs.git}/bin/git worktree list --porcelain -z 2>/dev/null)
              export SCCACHE_BASEDIRS
            fi
          '';
        });
      });
}
