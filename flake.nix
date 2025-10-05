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

        mindustry-map-vis = pkgs.mindustry.overrideAttrs (old: {
          patches = [
            ./patches/mindustry/0001-Implement-screenshot-server.patch
            ./patches/arc/0001-Optimize-for-the-case-when-I-don-t-need-a-window.patch
          ];
        });

        run-mindustry-map-vis = pkgs.writeScriptBin "run-mindustry-map-vis" ''
          #!${pkgs.runtimeShell}
          export XDG_RUNTIME_DIR=/tmp/
          export DISPLAY=:99
          xdummy "$DISPLAY" &> /tmp/xdummy.log &
          ${mindustry-map-vis}/bin/mindustry
        '';
      in
      {
        packages = {
          default = mindustry-map-vis;

          docker = pkgs.dockerTools.buildImage {
            name = "mindustry-map-vis-dockerized";
            tag = "latest";
  
            copyToRoot = with pkgs; [
              mindustry-map-vis
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
              Cmd = [ "${run-mindustry-map-vis}/bin/run-mindustry-map-vis" ];
            };
          };
        };
      }
    );
}
