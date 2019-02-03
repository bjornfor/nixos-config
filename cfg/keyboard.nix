let
  keymap = "no";
in
{
  i18n.consoleKeyMap = "qwerty/${keymap}";
  # This does not _enable_ X11, so it can still be used by headless configs.
  services.xserver = {
    layout = keymap;
  };
}
