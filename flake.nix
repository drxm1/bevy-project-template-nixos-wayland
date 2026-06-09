{
  description = "Self-contained Bevy 0.18 dev environment for NixOS + Wayland";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };

        # Single source of truth: rust-toolchain.toml drives BOTH this devShell and
        # cargo/rust-analyzer (pinned nightly + cranelift). This is what fixes the
        # old "toolchain.toml says nightly but the flake forced stable" drift.
        rustToolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;

        # Libraries dlopen'd at runtime by wgpu (Vulkan) and winit (Wayland/X11).
        # The cargo-run binary carries no RPATH into the Nix store, so the devShell
        # bridges them via LD_LIBRARY_PATH (confined to this shell).
        runtimeLibs = with pkgs; [
          vulkan-loader   # libvulkan.so.1 — wgpu's Vulkan backend dlopens this
          libxkbcommon    # required at runtime even on a pure-Wayland build
          wayland         # libwayland-client.so — winit's Wayland backend
          alsa-lib        # bevy_audio / rodio
          udev            # gamepad + input device enumeration
          # X11 libs: only dlopen'd on the XWayland / WINIT_UNIX_BACKEND=x11 fallback.
          libx11
          libxcursor
          libxi
          libxrandr
        ];
      in {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [ pkg-config ];
          buildInputs = with pkgs; [
            rustToolchain
            clang                         # linker driver for -fuse-ld=mold
            mold                          # fast linker (wired in .cargo/config.toml)
            llvmPackages_latest.bintools  # lld fallback + llvm-* tools
            vulkan-tools                  # vulkaninfo / vkcube to diagnose GPU/ICD issues
            glibc.dev                     # headers for bindgen (BINDGEN_EXTRA_CLANG_ARGS)
            glib.dev
          ] ++ runtimeLibs;

          shellHook = ''
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath runtimeLibs}:$LD_LIBRARY_PATH"
            export LIBCLANG_PATH="${pkgs.llvmPackages_latest.libclang.lib}/lib"
            export BINDGEN_EXTRA_CLANG_ARGS="-I${pkgs.glibc.dev}/include -I${pkgs.llvmPackages_latest.libclang.lib}/lib/clang/${pkgs.llvmPackages_latest.libclang.version}/include -I${pkgs.glib.dev}/include/glib-2.0 -I${pkgs.glib.out}/lib/glib-2.0/include/"

            # Deliberately NOT exporting RUSTFLAGS. Setting it would override the ENTIRE
            # .cargo/config.toml rustflags array (cargo reads flags from one source only,
            # with no merging), silently dropping the linker and -Zshare-generics flags.
            # All rustflags live in .cargo/config.toml instead.

            echo "Bevy 0.18 dev environment (NixOS/Wayland) ready."
          '';
        };
      });
}
