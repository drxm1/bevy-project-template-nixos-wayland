# Bevy starter template for NixOS + Wayland

A small Bevy project for game development on NixOS under Wayland. The flake pins
the Rust toolchain, linker and system libraries. The default settings are tuned
for fast iteration.

- Bevy **0.19.1** with the default 2D, 3D, UI and audio features.
  [Release notes](https://bevy.org/news/bevy-0-19/) · [0.18 to 0.19 migration guide](https://bevy.org/learn/migration-guides/0-18-to-0-19/)
- Nix dev shell for `x86_64-linux` and `aarch64-linux` (Rust toolchain, system libraries, linker)
- Fast compile times: Bevy dynamic linking, the `mold` linker, the Cranelift codegen
  backend, generic sharing, and a split optimization profile
- Cargo workspace: an `app-bevy` binary and a `lib-utils` library, to show how to
  split a project across crates

## Prerequisites

- [Nix](https://nixos.org/download) with flakes enabled
  (`experimental-features = nix-command flakes`).
- A working **Vulkan** driver on the host. On NixOS set `hardware.graphics.enable =
  true`; the dev shell provides the Vulkan *loader* but cannot provide the GPU driver
  (ICD) itself.
- Optional: [direnv](https://direnv.net) to enter the dev shell automatically.

## Quick start

```bash
git clone https://github.com/drxm1/bevy-project-template-nixos-wayland.git
cd bevy-project-template-nixos-wayland

# Enter the dev shell (or run `direnv allow` once and it happens on cd):
nix develop

# Run with fast-iteration settings (Bevy dynamically linked):
cargo dev          # alias for: cargo run -p app-bevy --features dev
```

You should see a window open and three greetings in the terminal every two seconds.
If your shell filters out info logs, run `RUST_LOG=app_bevy=info,lib_utils=info cargo dev`.

`cargo dev` also enables Bevy's debug names, developer tools and asset hot reloading.
Put game assets in `app-bevy/assets/`.

## How the fast compile times work

Bevy is a large dependency, so the template trades a slower first build for much
faster incremental rebuilds. Each piece is configured in one place and explained
below.

| Technique | Where | What it does |
|---|---|---|
| Dynamic linking | `app-bevy` `dev` feature → `cargo dev` | Cargo reuses the Bevy shared library when you edit game code. |
| `mold` linker | `.cargo/config.toml` (`-fuse-ld=mold`) + flake | Links far faster than the default `ld`. Driven by `clang`. |
| Cranelift backend | `.cargo/config.toml` (`[profile.dev] codegen-backend`) | Generates debug code for *your* crates much faster than LLVM. Dependencies stay on LLVM so the engine still runs fast in dev. Requires nightly. |
| `-Z share-generics=y` | `.cargo/config.toml` rustflags | Reuses generic instantiations across crates instead of recompiling them. Requires nightly. |
| Optimization split | `Cargo.toml` profiles | Your code at `opt-level = 1` (quick to recompile); dependencies at `opt-level = 3` (fast at runtime). |

The dev shell leaves `RUSTFLAGS` unset. Exporting it overrides the linker and
`share-generics` flags in `.cargo/config.toml`.

## Dev vs. release

```bash
# Fast iteration — dynamic linking + Cranelift. Binary needs libbevy_dylib at runtime.
cargo dev

# Release build with Bevy linked into the binary, LLVM and thin LTO.
cargo build --release -p app-bevy
```

Leave `--features dev` off when shipping the game. The dev binary needs
`libbevy_dylib.so` at runtime. [Bevy build settings](https://bevy.org/learn/quick-start/getting-started/setup/)

## Project layout

```
.
├── flake.nix            # dev shell: Rust toolchain, system libs, linker, env
├── rust-toolchain.toml  # pinned toolchain — read by BOTH Nix and cargo
├── .cargo/config.toml   # linker, rustflags, Cranelift, the `cargo dev` alias
├── Cargo.toml           # workspace: dependencies and build profiles
├── Cargo.lock           # committed for reproducible builds
├── app-bevy/            # the binary crate (main.rs)
└── lib-utils/           # a library crate (a Bevy plugin)
```

`cargo run -p app-bevy` (or `cargo run`) runs the app; `cargo test --workspace` tests
everything; `cargo add <dep> -p lib-utils` adds a dependency to the library crate.

## Toolchain

`rust-toolchain.toml` is the single source of truth and is read by both cargo and the
Nix flake (`rust-bin.fromRustupToolchainFile`), so they cannot drift apart. It pins a
**nightly** because Cranelift and `share-generics` are nightly-only.

To move to a newer nightly, change the date in `rust-toolchain.toml` to one whose
manifest still contains `rustc-codegen-cranelift-preview`, then run `nix flake update`.

Prefer stable? Pin Rust 1.95 or newer in `rust-toolchain.toml`, remove
`rustc-codegen-cranelift-preview` from the components, and remove the `[unstable]` /
`codegen-backend` blocks and the `-Z share-generics` flag from `.cargo/config.toml`.
You keep dynamic linking, `mold`, and the optimization split — the largest wins all
work on stable.

## NixOS / Wayland notes

The dev shell adds Bevy's native libraries (`vulkan-loader`,
`libxkbcommon`, `wayland`, `alsa-lib`, `udev`, plus the X11 libraries for the XWayland
fallback) to `LD_LIBRARY_PATH`. This is scoped to the shell. Bevy's default
features include both Wayland and X11. winit uses Wayland when `WAYLAND_DISPLAY`
or `WAYLAND_SOCKET` is set. In a Wayland session with XWayland, you can test the
X11 backend with `env -u WAYLAND_DISPLAY -u WAYLAND_SOCKET cargo dev`.

Sanity-check the GPU before blaming the app — `vulkan-tools` is in the shell:

```bash
vulkaninfo --summary   # should list your GPU and a Vulkan version
vkcube                 # should show a spinning cube
```

| Symptom | Cause | Fix |
|---|---|---|
| `libvulkan.so.1: cannot open shared object file` | loader not found | Provided by the dev shell; make sure you are inside `nix develop`. |
| "Unable to find a GPU" / no suitable adapter | no usable Vulkan ICD (host-side) | `hardware.graphics.enable = true`; verify with `vulkaninfo`. |
| `libxkbcommon.so.0` / winit panic on startup | xkbcommon missing | Provided by the dev shell (required even on pure Wayland). |
| `vulkaninfo` skips an ICD | A driver failed to load | Check that `vulkaninfo --summary` still lists your GPU. If it is missing, check the loader error for that driver. |
| `cargo run` works but a packaged binary fails | `LD_LIBRARY_PATH` is not carried outside the shell | Ship via a real Nix derivation (e.g. crane/naersk) with the libraries as `buildInputs`, not via the dev env var. |

## Using this template for your own project

```bash
# Start from a clean history:
rm -rf .git && git init

# Rename the crates in Cargo.toml, app-bevy/Cargo.toml, lib-utils/Cargo.toml,
# and the description in flake.nix to match your project.

git add . && git commit -m "Initial commit"
git remote add origin https://github.com/you/your-game.git
git push -u origin main
```

For distributing a real game build, package it as a Nix derivation rather than
relying on the dev shell's `LD_LIBRARY_PATH` (see the table above), and build with
`cargo build --release`.
