{
  description = "Cursor — official Linux deb packages and agent CLI from downloads.cursor.com";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = lib.genAttrs systems;
      sources = builtins.fromJSON (builtins.readFile ./sources.json);
    in
    {
      overlays.default = final: prev: {
        cursor = final.callPackage ./pkgs/cursor { inherit sources; };
        "cursor-agent" = final.callPackage ./pkgs/cursor-agent { inherit sources; };
      };

      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
            config.allowUnfree = true;
          };
        in
        {
          inherit (pkgs) cursor;
          "cursor-agent" = pkgs."cursor-agent";
          default = pkgs.cursor;
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
            config.allowUnfree = true;
          };
          cursorNixosConfig = lib.nixosSystem {
            inherit system;
            modules = [
              self.nixosModules.default
              {
                programs.cursor.enable = true;
                system.stateVersion = "26.05";
              }
            ];
          };
        in
        {
          inherit (self.packages.${system}) cursor;
          "cursor-agent" = self.packages.${system}."cursor-agent";

          cursor-mime = pkgs.runCommand "cursor-mime-check" { } ''
            grep -Fq 'MimeType=application/x-cursor-workspace;' \
              ${pkgs.cursor}/share/applications/cursor.desktop
            grep -Fq 'MimeType=x-scheme-handler/cursor;' \
              ${pkgs.cursor}/share/applications/cursor-url-handler.desktop
            test -f ${pkgs.cursor}/share/mime/packages/cursor-workspace.xml
            touch $out
          '';

          cursor-handler = pkgs.runCommand "cursor-handler-check" { } ''
            grep -Fxq 'x-scheme-handler/cursor=cursor-url-handler.desktop' \
              ${cursorNixosConfig.config.environment.etc."xdg/mimeapps.list".source}
            touch $out
          '';
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShellNoCC {
            packages = with pkgs; [
              curl
              jq
              nixfmt
            ];
          };
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);

      nixosModules.cursor = import ./modules/cursor.nix { inherit self; };
      nixosModules.default = self.nixosModules.cursor;
    };
}
