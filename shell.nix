{ pkgs ? import <nixpkgs> { } }:
let overrides = (builtins.fromTOML (builtins.readFile ./rust-toolchain.toml));
in pkgs.mkShell rec {
  nativeBuildInputs = with pkgs; [ pkg-config ];
  buildInputs = with pkgs; [
    clang
    # Replace llvmPackages with llvmPackages_X, where X is the latest LLVM version (at the time of writing, 16)
    llvmPackages.bintools
    rustup
    udev
    alsa-lib
    vulkan-loader
    xorg.libX11
    xorg.libXcursor
    xorg.libXi
    xorg.libXrandr # To use the x11 feature
    libxkbcommon
    wayland # To use the wayland feature
  ];
  RUSTC_VERSION = overrides.toolchain.channel;
  # https://github.com/rust-lang/rust-bindgen#environment-variables
  LIBCLANG_PATH =
    pkgs.lib.makeLibraryPath [ pkgs.llvmPackages_latest.libclang.lib ];
  shellHook = ''
    export PATH=$PATH:''${CARGO_HOME:-~/.cargo}/bin
    export PATH=$PATH:''${RUSTUP_HOME:-~/.rustup}/toolchains/$RUSTC_VERSION-x86_64-unknown-linux-gnu/bin/
  '';
  # Add precompiled library to rustc search path
  RUSTFLAGS = (builtins.map (a: "-L ${a}/lib") [
    # add libraries here (e.g. pkgs.libvmi)
  ]);
  LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath buildInputs;
  # Add glibc, clang, glib, and other headers to bindgen search path
  BINDGEN_EXTRA_CLANG_ARGS =
    # Includes normal include path
    (builtins.map (a: ''-I"${a}/include"'') [
      # add dev libraries here (e.g. pkgs.libvmi.dev)
      pkgs.glibc.dev
    ])
    # Includes with special directory paths
    ++ [
      ''
        -I"${pkgs.llvmPackages_latest.libclang.lib}/lib/clang/${pkgs.llvmPackages_latest.libclang.version}/include"''
      ''-I"${pkgs.glib.dev}/include/glib-2.0"''
      "-I${pkgs.glib.out}/lib/glib-2.0/include/"
    ];
}
