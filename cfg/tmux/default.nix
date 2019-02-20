{ config, lib, pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    extraTmuxConf = ''
      # extraTmuxConf starts here
      ${builtins.readFile ./tmux.conf}

      # NixOS specific config here:
      bind-key R source-file /etc/tmux.conf \; display-message "tmux config reloaded..."
      source-file ${pkgs.pythonPackages.powerline}/share/tmux/powerline.conf
    '';
  };

  environment.systemPackages = with pkgs; [
    pythonPackages.powerline
  ];

  fonts.fonts = with pkgs; [
    #pythonPackages.powerline  # looks ok
    powerline-fonts            # looks better
  ];
}
