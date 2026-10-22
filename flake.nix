{
  description = "EffectCraft: open-source motion graphics and compositing tool in pure Rust";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # The workspace needs Rust >= 1.95 (edition 2024), so use a current stable
    # toolchain from rust-overlay instead of relying on nixpkgs' rustc version.
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Source tree. If you drop this flake.nix into a checkout of the repo
    # (and `git add` it), you can delete this input and use `src = self;` below.
    effectcraft-src = {
      url = "github:storytold/effectcraft";
      flake = false;
    };
  };

  outputs =
    { self, nixpkgs, rust-overlay, effectcraft-src }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];

      forAllSystems =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          f (import nixpkgs {
            inherit system;
            overlays = [ rust-overlay.overlays.default ];
          })
        );

      # Libraries the app loads at runtime via dlopen (wgpu/Vulkan, GL/EGL,
      # winit on X11 + Wayland, xkbcommon) plus ALSA, which cpal links against.
      linuxLibs =
        pkgs: with pkgs; [
          alsa-lib
          libglvnd
          libxkbcommon
          vulkan-loader
          wayland
          libx11
          libxcb
          libxcursor
          libxi
          libxrandr
        ];

      mkPackage =
        pkgs:
        let
          inherit (pkgs) lib stdenv;
          isLinux = stdenv.hostPlatform.isLinux;

          rustToolchain = pkgs.rust-bin.stable.latest.minimal;
          rustPlatform = pkgs.makeRustPlatform {
            cargo = rustToolchain;
            rustc = rustToolchain;
          };

          # src = self;
          src = effectcraft-src;
        in
        rustPlatform.buildRustPackage {
          pname = "effectcraft";
          version = "unstable-${effectcraft-src.shortRev or "unknown"}";

          inherit src;

          cargoLock = {
            lockFile = "${src}/Cargo.lock";
            # The filmcraft-* codec crates come from a git dependency pinned by
            # rev in Cargo.lock. This lets Nix fetch it without having to list a
            # hash per crate in `outputHashes`.
            allowBuiltinFetchGit = true;
          };

          # `default-members` also includes the wasm-only web app; build just the
          # native desktop app and the CLI.
          cargoBuildFlags = [
            "--package" "effectcraft"
            "--package" "effectcraft-cli"
          ];

          # The test suite includes GPU/UI snapshot tests; don't run it in the sandbox.
          doCheck = false;

          nativeBuildInputs = [ pkgs.pkg-config ] ++ lib.optionals isLinux [ pkgs.patchelf ];

          buildInputs = lib.optionals isLinux (linuxLibs pkgs);

          postInstall = lib.optionalString isLinux ''
            if [ -d assets/app-icon/hicolor ]; then
              mkdir -p $out/share/icons
              cp -r assets/app-icon/hicolor $out/share/icons/
            fi

            mkdir -p $out/share/applications
            cat > $out/share/applications/ai.storyteller.effectcraft.desktop <<EOF
            [Desktop Entry]
            Type=Application
            Name=EffectCraft
            Comment=Motion graphics and visual effects
            Exec=$out/bin/effectcraft %F
            Icon=ai.storyteller.effectcraft
            Categories=Graphics;AudioVideo;Video;
            Terminal=false
            EOF
          '';

          # dlopen'd libraries are not in DT_NEEDED, so add them to the rpath.
          postFixup = lib.optionalString isLinux ''
            for bin in $out/bin/*; do
              patchelf --add-rpath "${lib.makeLibraryPath (linuxLibs pkgs)}" "$bin"
            done
          '';

          meta = {
            description = "Open-source motion graphics and compositing tool written in pure Rust";
            homepage = "https://github.com/storytold/effectcraft";
            license = with lib.licenses; [ mit asl20 ];
            mainProgram = "effectcraft";
            platforms = systems;
          };
        };
    in
    {
      packages = forAllSystems (pkgs: rec {
        effectcraft = mkPackage pkgs;
        default = effectcraft;
      });

      apps = forAllSystems (pkgs: rec {
        effectcraft = {
          type = "app";
          program = "${self.packages.${pkgs.stdenv.hostPlatform.system}.effectcraft}/bin/effectcraft";
        };
        effectcraft-cli = {
          type = "app";
          program = "${self.packages.${pkgs.stdenv.hostPlatform.system}.effectcraft}/bin/effectcraft-cli";
        };
        default = effectcraft;
      });

      devShells = forAllSystems (
        pkgs:
        let
          inherit (pkgs) lib stdenv;
          isLinux = stdenv.hostPlatform.isLinux;
          rustToolchain = pkgs.rust-bin.stable.latest.default.override {
            extensions = [ "rust-src" "rust-analyzer" "clippy" "rustfmt" ];
            targets = [ "wasm32-unknown-unknown" ]; # for `cargo xtask web`
          };
        in
        {
          default = pkgs.mkShell {
            nativeBuildInputs = [ rustToolchain pkgs.pkg-config ];
            buildInputs = lib.optionals isLinux (linuxLibs pkgs);
            LD_LIBRARY_PATH = lib.optionalString isLinux (lib.makeLibraryPath (linuxLibs pkgs));
          };
        }
      );

      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);
    };
}
