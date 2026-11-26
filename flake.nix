{
  description = "Bevy 0.19 development environment for NixOS + Wayland";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        overlays = [ rust-overlay.overlays.default ];
        pkgs = import nixpkgs { inherit system overlays; };

        # Use the same nightly and components as cargo and rust-analyzer.
        rustToolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;

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
      });
}
