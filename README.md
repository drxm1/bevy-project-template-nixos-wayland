# Bevy starter template for NixOS + Wayland

A small, reproducible [Bevy](https://bevy.org) project skeleton for game development
on NixOS under Wayland. Everything needed to build and run is pinned in a Nix flake,
so there is nothing to install system-wide and a fresh clone builds the same on any
machine. The default settings are tuned for fast iteration.

- Bevy **0.18**
- Self-contained Nix flake dev shell (Rust toolchain, system libraries, linker)
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

You should see a window open and `hello ...` lines printed to the terminal every two
seconds.

## How the fast compile times work

Bevy is a large dependency, so the template trades a slower first build for much
faster incremental rebuilds. Each piece is configured in one place and explained
below.

| Technique | Where | What it does |
|---|---|---|
| Dynamic linking | `app-bevy` `dev` feature → `cargo dev` | Compiles Bevy into a shared library once; afterwards only your code is relinked. Opt-in, never in release. |
| `mold` linker | `.cargo/config.toml` (`-fuse-ld=mold`) + flake | Links far faster than the default `ld`. Driven by `clang`. |
| Cranelift backend | `.cargo/config.toml` (`[profile.dev] codegen-backend`) | Generates debug code for *your* crates much faster than LLVM. Dependencies stay on LLVM so the engine still runs fast in dev. Requires nightly. |
| `-Z share-generics=y` | `.cargo/config.toml` rustflags | Reuses generic instantiations across crates instead of recompiling them. Requires nightly. |
| Optimization split | `Cargo.toml` profiles | Your code at `opt-level = 1` (quick to recompile); dependencies at `opt-level = 3` (fast at runtime). |

> One subtlety worth knowing: cargo reads extra `rustflags` from a single source
> (first of `RUSTFLAGS` env, `target.*.rustflags`, `build.rustflags`) and never merges
> them. That is why the dev shell does **not** export `RUSTFLAGS` and all flags live in
> `.cargo/config.toml` — otherwise the linker and `share-generics` flags would be
> silently dropped.

## Dev vs. release

```bash
# Fast iteration — dynamic linking + Cranelift. Binary needs libbevy_dylib at runtime.
cargo dev

# Shippable build — self-contained, no dynamic linking, LLVM, thin LTO.
cargo build --release -p app-bevy
```

Never ship a `--features dev` build: a dynamically linked binary depends on
`libbevy_dylib.so` and is incompatible with LTO.

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

Prefer stable? Set `channel = "stable"` (≥ 1.89, Bevy 0.18's minimum), remove
`rustc-codegen-cranelift-preview` from the components, and remove the `[unstable]` /
`codegen-backend` blocks and the `-Z share-generics` flag from `.cargo/config.toml`.
You keep dynamic linking, `mold`, and the optimization split — the largest wins all
work on stable.

## NixOS / Wayland notes

The dev shell adds the libraries Bevy `dlopen`s at runtime (`vulkan-loader`,
`libxkbcommon`, `wayland`, `alsa-lib`, `udev`, plus the X11 libraries for the XWayland
fallback) to `LD_LIBRARY_PATH`. This is scoped to the shell. winit selects Wayland
automatically when `WAYLAND_DISPLAY` is set; force a backend with
`WINIT_UNIX_BACKEND=wayland` (or `=x11`).

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
| `vulkaninfo` warns about the `dzn`/`lvp` ICD | Mesa's software drivers being skipped | Harmless — the loader falls back to your real GPU driver. |
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
