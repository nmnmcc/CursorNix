# CursorNix

[English](README.md)

将 downloads.cursor.com 上的 Cursor 官方 Linux deb 包和 agent CLI
打包为 Nix flake。

与 nixpkgs 可能滞后于上游不同，本 flake 直接获取最新官方 deb 包——无需编译，即装即用。

## 包含内容

- `cursor`：Cursor AI 代码编辑器（Linux deb 包）。
- `cursor-agent`：Cursor Agent 命令行工具（`agent` 和 `cursor-agent` 命令）。
- NixOS 模块：`cursornix.nixosModules.default`。

支持的系统：`x86_64-linux`、`aarch64-linux`（即 Cursor API 当前发布的所有
官方 Linux deb 变体）。

你需要启用 flakes 的 Nix，并设置 `allowUnfree = true`（Cursor 为专有软件）。

## 快速开始

```sh
nix run github:nmnmcc/CursorNix#cursor
nix run github:nmnmcc/CursorNix#cursor-agent -- --version
```

## Flake 配置

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

## NixOS 配置

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

## 更新

```sh
nix flake update cursornix
```

或手动运行：

```sh
python3 update.py
```

更新脚本从 Cursor API 获取最新 Linux deb 包，并从 cursor.com/install
固定 agent CLI 版本到 `sources.json`。

## 故障排除

在 NixOS 上，如果 Cursor 渲染失败，可尝试通过 nixGL 启动：

```sh
nix run --impure github:nix-community/nixGL -- cursor .
```

## 许可

打包的二进制文件由 Anysphere 以其专有许可分发。本 flake 将这些发布版本
打包供 Nix 使用。
