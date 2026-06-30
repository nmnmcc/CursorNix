# CursorNix

Nix flake for Cursor — official Linux AppImage and agent CLI from
downloads.cursor.com.

Translations: [简体中文](README.zh-CN.md).

Unlike nixpkgs which may lag behind upstream, this flake fetches the
latest official AppImage directly. No compilation, instant installs.

## What you get

- `cursor`: the Cursor AI code editor (Linux AppImage).
- `cursor-agent`: the Cursor Agent CLI (`agent` and `cursor-agent` commands).
- A NixOS module at `cursornix.nixosModules.default`.
- A package overlay at `cursornix.overlays.default`.

Supported systems: `x86_64-linux`, `aarch64-linux`.

You need Nix with flakes enabled and `allowUnfree = true` (Cursor is
proprietary software).

## Quick start

```sh
nix run github:nmnmcc/CursorNix#cursor
nix run github:nmnmcc/CursorNix#cursor-agent -- --version
```

## Flake setup

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    cursornix.url = "github:nmnmcc/CursorNix";
  };

  outputs = { nixpkgs, cursornix, ... }: {
    devShells.x86_64-linux.default = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in pkgs.mkShell {
      packages = [
        cursornix.packages.x86_64-linux.cursor
        cursornix.packages.x86_64-linux.cursor-agent
      ];
    };
  };
}
```

## NixOS setup

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    cursornix.url = "github:nmnmcc/CursorNix";
  };

  outputs = { nixpkgs, cursornix, ... }: {
    nixosConfigurations.your-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        cursornix.nixosModules.default
        {
          programs.cursor = {
            enable = true;
            agent.enable = true;
          };
        }
      ];
    };
  };
}
```

## Using the overlay

```nix
{
  nixpkgs.overlays = [
    cursornix.overlays.default
  ];

  environment.systemPackages = with pkgs; [
    cursor
    cursor-agent
  ];
}
```

## Updating

```sh
nix flake update cursornix
```

Or manually:

```sh
python3 update.py
```

The update script fetches the latest Linux AppImage from the Cursor API
and pins the agent CLI from cursor.com/install into `sources.json`.

## Troubleshooting

On NixOS, if Cursor fails to render, try nixGL:

```sh
nix run --impure github:nix-community/nixGL -- cursor .
```

## License

The packaged binaries are distributed by Anysphere under their proprietary
license. This flake packages those releases for Nix.
