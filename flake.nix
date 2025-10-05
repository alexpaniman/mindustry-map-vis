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

        xorgConfig = pkgs.writeText "dummy-xorg.conf" ''
          Section "ServerLayout"
            Identifier     "dummy_layout"
            Screen         0 "dummy_screen"
            InputDevice    "dummy_keyboard" "CoreKeyboard"
            InputDevice    "dummy_mouse" "CorePointer"
          EndSection

          Section "ServerFlags"
            Option "DontVTSwitch" "true"
            Option "AllowMouseOpenFail" "true"
            Option "PciForceNone" "true"
            Option "AutoEnableDevices" "false"
            Option "AutoAddDevices" "false"
          EndSection

          Section "Files"
            ModulePath "${pkgs.xorg.xorgserver.out}/lib/xorg/modules"
            ModulePath "${pkgs.xorg.xf86videodummy}/lib/xorg/modules"
            ModulePath "${pkgs.xorg.xf86inputvoid}/lib/xorg/modules/input/"
            ModulePath "${pkgs.xorg.xf86inputlibinput}/lib/xorg/modules/input/"
            XkbDir "${pkgs.xkeyboard_config}/share/X11/xkb"
            FontPath "${pkgs.xorg.fontadobe75dpi}/lib/X11/fonts/75dpi"
            FontPath "${pkgs.xorg.fontadobe100dpi}/lib/X11/fonts/100dpi"
            FontPath "${pkgs.xorg.fontmiscmisc}/lib/X11/fonts/misc"
            FontPath "${pkgs.xorg.fontcursormisc}/lib/X11/fonts/misc"
            FontPath "${pkgs.xorg.fontbhlucidatypewriter75dpi}/lib/X11/fonts/75dpi"
            FontPath "${pkgs.xorg.fontbhlucidatypewriter100dpi}/lib/X11/fonts/100dpi"
            FontPath "${pkgs.xorg.fontbh100dpi}/lib/X11/fonts/100dpi"
          EndSection

          Section "Module"
            Load           "dbe"
            Load           "extmod"
            Load           "freetype"
            Load           "glx"
          EndSection

          Section "InputDevice"
            Identifier     "dummy_mouse"
            Driver         "void"
          EndSection

          Section "InputDevice"
            Identifier     "dummy_keyboard"
            Driver         "void"
          EndSection

          Section "Monitor"
            Identifier     "dummy_monitor"
            HorizSync       30.0 - 130.0
            VertRefresh     50.0 - 250.0
            Option         "DPMS"
          EndSection

          Section "Device"
            Identifier     "dummy_device"
            Driver         "dummy"
            VideoRam       192000
          EndSection

          Section "Screen"
            Identifier     "dummy_screen"
            Device         "dummy_device"
            Monitor        "dummy_monitor"
            DefaultDepth    24
            SubSection     "Display"
              Depth       24
              Modes      "1280x1024"
            EndSubSection
          EndSection
        '';

        my-xdummy = pkgs.writeScriptBin "xdummy" ''
          #!${pkgs.runtimeShell}
          exec ${pkgs.xorg.xorgserver.out}/bin/Xorg \
            -noreset \
            +extension GLX \
            +extension RANDR \
            +extension RENDER \
            -logfile xdummy.log \
            -logverbose 9 \
            "$@" \
            -config "${xorgConfig}"
        '';

        run-server = pkgs.writeScriptBin "run-server" ''
          #!${pkgs.runtimeShell}
          export XDG_RUNTIME_DIR=/tmp
          export DISPLAY=:99
          xdummy "$DISPLAY" &
          ${patched-mindustry}/bin/mindustry
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
              virtualgl
              # xvfb-run

              # xorg.xorgproto
              # xorg.libX11
              # xorg.libXext
              # xorg.libXrender
              # xorg.libXrandr
              # xorg.libXcursor
              # xorg.libXinerama
              # xorg.libXi
              # xorg.xvfb
              # SDL2

              mesa
              mesa-demos

              bash
              coreutils
              vim

              # xorg.xorgserver
              xorg.xf86videodummy

              # xpra
              my-xdummy

              xorg.xf86inputvoid
              xorg.xf86inputlibinput

              dbus
              xorg.xeyes

              xorg.xdpyinfo
              xorg.xvfb

              strace
            ];

            extraCommands = ''
              #ln -s ${pkgs.mesa}/lib/dri run/opengl-driver/lib/

              mkdir -p run/opengl-driver/
              ln -s ${pkgs.mesa}/lib run/opengl-driver/

              echo ${pkgs.xorg.xf86inputvoid}/lib/xorg/modules/input/void_drv.so > x
              echo ${pkgs.xorg.xf86inputlibinput}/lib/xorg/modules/input/libinput_drv.so >> x
            '';

            config = {
              Cmd = [ "${run-server}/bin/run-server" ];
            };
          };
        };
      }
    );
}
