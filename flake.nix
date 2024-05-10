{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, flake-utils, nixpkgs }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };
        fetch-hash = pkgs.writeScriptBin "fetch-hash" ''
          #!/usr/bin/env bash
          wget $1 -q && \
          tarfile=''${1##*/}
          zig fetch --debug-hash $tarfile | tail -n 1
          rm $tarfile
        '';
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [
            fetch-hash
          ];
          buildInputs = with pkgs; [
            SDL2
            pkg-config
          ];
        };
      }
    );
}






