{
  description = "Mindustry screenshot server, derived from original Mindustry source code.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        patched-mindustry = pkgs.mindustry.overrideAttrs (old: {
          patches = [
            ./patches/mindustry/0001-Implement-screenshot-server.patch
            ./patches/arc/0001-Optimize-for-the-case-when-I-don-t-need-a-window.patch
          ];
        });

        run-mindustry = pkgs.writeScriptBin "run-mindustry" ''
          #!${pkgs.runtimeShell}
          export XDG_RUNTIME_DIR=/tmp/
          export DISPLAY=:99
          xdummy "$DISPLAY" &> /tmp/xdummy.log &
          ${patched-mindustry}/bin/mindustry &> /tmp/mindustry.log
        '';
      in
      {
        packages = {
          default = patched-mindustry;

          docker = pkgs.dockerTools.buildImage {
            name = "mindustry-dockerized";
            tag = "latest";
  
            copyToRoot = with pkgs; [
              patched-mindustry
              mesa

              bash
              busybox

              xorg.xf86videodummy
              xdummy
            ];

            extraCommands = ''
              mkdir -p tmp/.X11-unix/

              mkdir -p run/opengl-driver/
              ln -s ${pkgs.mesa}/lib run/opengl-driver/
            '';

            config = {
              Cmd = [ "${run-mindustry}/bin/run-mindustry" ];
            };
          };
        };
      }
    );
}
