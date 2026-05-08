{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.mugen-shell;
in
{
  options.programs.mugen-shell = {
    enable = lib.mkEnableOption "system-wide mugen-shell desktop bits (Quickshell + Hyprland + runtime deps)";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.mugen-shell or null;
      defaultText = lib.literalExpression "pkgs.mugen-shell";
      description = "The mugen-shell QML package (UI tree, scripts, assets).";
    };

    includeSystemDeps = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Install mugen-shell's runtime dependencies (Quickshell, hypridle,
        hyprlock, mpvpaper, awww, matugen, playerctl, ...) into
        environment.systemPackages and enable programs.hyprland so the
        Wayland session, portals, and keyring integrations are wired up.

        Set to <literal>false</literal> if you already manage Hyprland and
        the rest of the stack yourself; the module will then only put
        cfg.package on the system path.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.hyprland.enable = lib.mkIf cfg.includeSystemDeps true;

    environment.systemPackages =
      lib.optionals cfg.includeSystemDeps (
        with pkgs;
        [
          quickshell
          hypridle
          hyprlock
          mpvpaper
          awww
          matugen
          playerctl
          wl-clipboard
          cliphist
          libnotify
          grim
          slurp
          cava
          ffmpeg
          imv
          pavucontrol
          pulseaudio # paplay
          pamixer    # volume mute keybind in keybinds.conf
          socat      # mpvpaper IPC in change-wallpaper.sh
          curl       # AI assistant HTTP / SSE
          fastfetch
          fcitx5
          python3
          # Default user apps referenced by hyprland.conf $terminal/$fileManager/$browser.
          kitty
          thunar
          firefox
        ]
      )
      ++ [ cfg.package ];
  };
}
