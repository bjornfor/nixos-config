{ pkgs }:

{
  makeSimpleWebApp =
    { server
    , icon ? null
    , comment ? null
    , desktopName ? comment
    , categories ? null
    , browser ? "chromium-browser"
    }:
    pkgs.makeDesktopItem
    ({
      name = server;
      exec = "${browser} --app=https://${server}/";
      extraEntries = ''
        StartupWMClass=${server}
      '';
    } // (if icon != null then { inherit icon; } else {})
      // (if comment != null then { inherit comment; } else {})
      // (if desktopName != null then { inherit desktopName; } else {})
      // (if categories != null then { inherit categories; } else {}));
}
