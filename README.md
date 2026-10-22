# EffectCraft Nix Flake

An unofficial [Nix flake](https://nixos.wiki/wiki/Flakes) for
[EffectCraft](https://github.com/storytold/effectcraft), the open-source motion
graphics and compositing tool written in pure Rust.

With this flake you can run, build, or install EffectCraft on Linux (and
experimentally macOS) without installing a Rust toolchain or hunting down
system libraries yourself.

> This project is not affiliated with or endorsed by the EffectCraft / ArtCraft
> team. EffectCraft itself is young and in alpha; see the
> [upstream README](https://github.com/storytold/effectcraft#where-it-stands)
> for its current status and known gaps.

## What you get

- `effectcraft`: the desktop app
- `effectcraft-cli`: the command-line tool (headless rendering, scripting, and
  the MCP server for agents)

The flake builds both from upstream's source using a current stable Rust
toolchain (EffectCraft requires Rust 1.95 or newer). It does not build the
browser (WebAssembly) version.

## Quick start

You need Nix with flakes enabled
(`experimental-features = nix-command flakes`).

Run the app without installing anything:

```sh
nix run github:NAXLAB/effectcraft-flake
```

Run the CLI, for example to render the demo composition headless:

```sh
nix run github:NAXLAB/effectcraft-flake#effectcraft-cli -- render --out intro.mp4
```

Install into your profile:

```sh
nix profile install github:NAXLAB/effectcraft-flake
```

## Using it in your own flake

```nix
{
  inputs.effectcraft.url = "github:NAXLAB/effectcraft-flake";

  outputs = { self, nixpkgs, effectcraft, ... }: {
    # NixOS
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: {
          environment.systemPackages = [
            effectcraft.packages.${pkgs.stdenv.hostPlatform.system}.default
          ];
        })
      ];
    };
  };
}
```

The same package works in Home Manager's `home.packages`.

## Development shell

```sh
nix develop
```

This gives you stable Rust with `rust-analyzer`, `clippy`, `rustfmt` and the
`wasm32-unknown-unknown` target, plus the native libraries EffectCraft needs.
Inside a checkout of the upstream repository you can then use upstream's own
workflow:

```sh
cargo run --release -p effectcraft -- --demo
cargo xtask ci
```

## Supported platforms

| System           | Status                        |
|------------------|-------------------------------|
| `x86_64-linux`   | Primary target                |
| `aarch64-linux`  | Expected to work              |
| `aarch64-darwin` | Experimental, less exercised  |

Upstream notes that macOS is its most tested platform and that Linux and
Windows users have hit basic interaction bugs, so rough edges in the app itself
may come from upstream rather than from this packaging.

## Notes

- **Graphics drivers.** EffectCraft renders with wgpu (Vulkan) and falls back to
  OpenGL. On NixOS, enable your GPU driver as usual (`hardware.graphics.enable`).
  On non-NixOS Linux, Nix-built graphical apps often cannot see the host's GPU
  drivers; a tool such as [nixGL](https://github.com/nix-community/nixGL) can
  help.
- **Wayland file drag-and-drop.** Upstream's windowing backend does not deliver
  drag-and-drop events on native Wayland. Use **File > Import > File...** in the
  app, or launch under XWayland with `env -u WAYLAND_DISPLAY effectcraft`.
- **Tests are not run during the build.** The upstream test suite includes
  GPU and UI snapshot tests that don't work in the Nix sandbox.

## Contributing

Issues and pull requests are welcome, especially for platform fixes, missing
runtime libraries, or build breakage after an upstream update. If the problem is
in EffectCraft itself rather than the packaging, please report it
[upstream](https://github.com/storytold/effectcraft/issues).

## License

The files in this repository (the flake and its documentation) are released
under the [MIT License](LICENSE).

EffectCraft is developed by the ArtCraft team and contributors and is licensed
by them under MIT or Apache-2.0, at your option. Its bundled assets keep their
own licenses; see the upstream repository for details. The ArtCraft name and
logos are trademarks of the ArtCraft team.
