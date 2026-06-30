{ self }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.cursor;
  system = pkgs.stdenv.hostPlatform.system;
  flakePackages = self.packages.${system} or (throw "CursorNix does not provide packages for ${system}");
in
{
  options.programs.cursor = {
    enable = lib.mkEnableOption "the Cursor AI code editor";

    package = lib.mkOption {
      type = lib.types.package;
      default = flakePackages.cursor or (throw "CursorNix does not provide cursor for ${system}");
      defaultText = lib.literalExpression "cursornix.packages.\${pkgs.stdenv.hostPlatform.system}.cursor";
      description = "Cursor desktop editor package.";
    };

    agent = {
      enable = lib.mkEnableOption "the Cursor Agent CLI";

      package = lib.mkOption {
        type = lib.types.package;
        default = flakePackages."cursor-agent";
        defaultText = lib.literalExpression "cursornix.packages.\${pkgs.stdenv.hostPlatform.system}.cursor-agent";
        description = "Cursor Agent CLI package.";
      };
    };
  };

  config = lib.mkIf (cfg.enable || cfg.agent.enable) {
    assertions = [
      {
        assertion = !cfg.enable || (flakePackages.cursor or null) != null;
        message = "Cursor AppImage is not available for ${system}.";
      }
    ];

    nixpkgs.config.allowUnfree = true;

    environment.systemPackages =
      lib.optional cfg.enable cfg.package
      ++ lib.optional cfg.agent.enable cfg.agent.package;
  };
}
