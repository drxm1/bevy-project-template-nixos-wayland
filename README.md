# 🎮 Bevy Starter Template for NixOS

A streamlined template for Bevy game development on NixOS, leveraging direnv and Nix flakes for a seamless setup.

## 🌟 Features

- **Optimized Compilation**: Fast linking with LLD
- **Nightly Rust**: Latest features
- **Bevy Enhancements**: Dynamic linking and Wayland support
- **Nix-Powered**: Consistent development environment

## 🚀 Quick Start

```bash
git clone https://github.com/drxm1/bevy-project-template-nixos-wayland.git
cd bevy-project-template-nixos-wayland
direnv allow
cargo run
```

## 🛠 Project Structure

- `.cargo/config.toml`: LLD linker configuration
- `rust-toolchain.toml`: Nightly Rust specification
- `Cargo.toml`: Workspace and Bevy feature settings
- `flake.nix`: Nix development environment definition
- `.envrc`: Direnv configuration for Nix flake

## 🧰 Development Environment

- **Nix Flakes**: Reproducible development setup
- **Direnv**: Automatic environment loading
- **Rust Nightly**: Latest features necessary with our build flags

## 📝 Notes

- Requires Nix and direnv
- `.direnv` is gitignored
- Update `flake.lock` with `nix flake update` after `flake.nix` changes

## 🚫 Limitations

- No WebGPU or web serving capabilities ensured right now, add that yourself
- Designed for local development (well tested in emacs with direnv-mode)

## 🔧 Using This Template for Your Project

1. Clone the repository:
   ```bash
   git clone https://github.com/drxm1/bevy-project-template-nixos-wayland.git your-project-name
   cd your-project-name
   ```

2. Remove the existing git history:
   ```bash
   rm -rf .git
   ```

3. Initialize a new git repository:
   ```bash
   git init
   ```

4. Update the project name in `Cargo.toml` and `flake.nix`.

5. Update this README.md with your project details.

6. Create your initial commit:
   ```bash
   git add .
   git commit -m "Initial commit: Bevy project setup from template"
   ```

7. Link to your new GitHub repository:
   ```bash
   git remote add origin https://github.com/yourusername/your-project-name.git
   git branch -M main
   git push -u origin main
   ```

8. Start developing your Bevy game!

Remember to customize the `flake.nix` if you need additional dependencies for your specific project.
