{ config, lib, pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    baseIndex = 1;
    clock24 = true;
    historyLimit = 100000;
    keyMode = "vi";
    # extraTmuxConf is based on my .tmux.conf from dotfiles.git.
    extraTmuxConf = ''
      # Let the mouse select panes, resize panes, scroll, select and copy text.
      set-option -g mouse on

      # Show tmux messages for N ms (or until a key is pressed)
      set-option -g display-time 4000

      # How long to display pane numbers (<prefix> + q). When pane numbers are
      # displayed, you can press numeric keys to jump to that pane.
      set-option -g display-panes-time 4000

      # When a window is closed, renumber higher numbered windows to fill the gap.
      set-option -g renumber-windows on

      # Move between panes using Vim keys.
      # NOTE: This clobbers <prefix> + l to select last active window.
      bind-key h select-pane -L
      bind-key j select-pane -D
      bind-key k select-pane -U
      bind-key l select-pane -R

      # Move between panes using Shift+<Arrow>. It's very similar (in effort) though
      # to use the default binding: <prefix> + <arrow>.
      # WARN: konsole eats these for itself, always.
      bind-key -n S-Left select-pane -L
      bind-key -n S-Down select-pane -D
      bind-key -n S-Up select-pane -U
      bind-key -n S-Right select-pane -R

      # Switch windows with Alt+number.
      # WARN: gnome-terminal eats these for itself, if using tabs.
      bind-key -n M-1 select-window -t 1
      bind-key -n M-2 select-window -t 2
      bind-key -n M-3 select-window -t 3
      bind-key -n M-4 select-window -t 4
      bind-key -n M-5 select-window -t 5
      bind-key -n M-6 select-window -t 6
      bind-key -n M-7 select-window -t 7
      bind-key -n M-8 select-window -t 8
      bind-key -n M-9 select-window -t 9

      # Inherit current working directory when splitting panes
      bind-key '%' split-window -h -c '#{pane_current_path}'
      bind-key '"' split-window -v -c '#{pane_current_path}'
      # and creating windows
      #bind-key c new-window -c '#{pane_current_path}'

      bind-key R source-file ~/.tmux.conf \; display-message "tmux config reloaded..."

      source-file ${pkgs.pythonPackages.powerline}/share/tmux/powerline.conf
    '';
  };

  environment.systemPackages = with pkgs; [
    pythonPackages.powerline
  ];
}
