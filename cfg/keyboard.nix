{
  i18n.consoleUseXkbConfig = true;
  # This does not _enable_ X11, so it can still be used by headless configs.
  services.xserver = {
    layout = "no";
    # For xkbOptions inspiration, see
    # $(nix-build -A xkeyboard_config)/share/X11/xkb/rules/base.lst
    xkbOptions = "ctrl:nocaps";  # Caps Lock as Ctrl
  };
}
