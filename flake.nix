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
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          cursor = pkgs.callPackage ./pkgs/cursor { inherit sources; };
          cursorAgent = pkgs.callPackage ./pkgs/cursor-agent { inherit sources; };
        in
        {
          inherit cursor;
          "cursor-agent" = cursorAgent;
          default = cursor;
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          cursor = self.packages.${system}.cursor;
        in
        {
          inherit (self.packages.${system}) cursor;
          "cursor-agent" = self.packages.${system}."cursor-agent";

          cursor-mime = pkgs.runCommand "cursor-mime-check" { } ''
            grep -Fq 'MimeType=application/x-cursor-workspace;' \
              ${cursor}/share/applications/cursor.desktop
            grep '^MimeType=' ${cursor}/share/applications/cursor.desktop \
              | grep -Fq 'x-scheme-handler/cursor'
            grep -Fq 'MimeType=x-scheme-handler/cursor;' \
              ${cursor}/share/applications/cursor-url-handler.desktop
            grep -Fq 'Exec=cursor --open-url %U' \
              ${cursor}/share/applications/cursor-url-handler.desktop
            test ! -e ${cursor}/bin/cursor-url-handler
            test -f ${cursor}/share/mime/packages/cursor-workspace.xml
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
