{ config, lib, pkgs, ... }:

{
  environment.etc."tmux.conf".text = ''
    ${builtins.readFile ./tmux.conf}

    # NixOS specific config here:
    bind-key R source-file /etc/tmux.conf \; display-message "tmux config reloaded..."
    source-file ${pkgs.pythonPackages.powerline}/share/tmux/powerline.conf
  '';

  environment.systemPackages = with pkgs; [
    tmux
    pythonPackages.powerline
  ];

  fonts.fonts = with pkgs; [
    #pythonPackages.powerline  # looks ok
    powerline-fonts            # looks better
  ];
}
