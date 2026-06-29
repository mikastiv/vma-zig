{
  description = "zig flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    zig-flake.url = "github:silversquirl/zig-flake";
    zig-flake.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      zig-flake,
    }:
    let
      forAllSystems =
        f:
        builtins.mapAttrs (
          system: pkgs: f system pkgs zig-flake.packages.${system}.zig_0_16_0
        ) nixpkgs.legacyPackages;
    in
    {
      devShells = forAllSystems (
        system: pkgs: zig: {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              vulkan-loader
            ];
            nativeBuildInputs = [
              zig
              zig.zls
            ];

            LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (
              with pkgs;
              [
                vulkan-loader
              ]
            );
          };
        }
      );
    };
}
