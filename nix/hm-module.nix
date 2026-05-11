self: { config, lib, pkgs, ... }:

let
  cfg = config.programs.ratty;
  tomlFormat = pkgs.formats.toml { };
in
{
  options.programs.ratty = {
    enable = lib.mkEnableOption "the Ratty terminal emulator";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.ratty;
      defaultText = lib.literalExpression "ratty.packages.\${system}.ratty";
      description = "The ratty package to install.";
    };

    settings = lib.mkOption {
      type = tomlFormat.type;
      default = { };
      example = lib.literalExpression ''
        {
          window = { width = 1280; height = 800; opacity = 0.85; };
          font   = { family = "JetBrainsMono Nerd Font"; size = 16; };
          cursor.animation.spin_speed = 2.0;
        }
      '';
      description = ''
        Free-form attrset written to `~/.config/ratty/ratty.toml`.
        Mirrors the structure of `config/ratty.toml` upstream.
        Leave empty to use ratty's built-in defaults.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.configFile."ratty/ratty.toml" = lib.mkIf (cfg.settings != { }) {
      source = tomlFormat.generate "ratty.toml" cfg.settings;
    };
  };
}
