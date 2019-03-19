{ fetchurl, makeDesktopItem, runCommand }:

# StartupWMClass is found with `xprop WM_CLASS`. When multiple entries are
# returned, use the first one (most specific). (Ideally, all values could be
# used, for most precise match, but I haven't found a way to do so.)

let
  get-nett-tv = makeDesktopItem {
    name = "get-nett-tv";  # nix store path name
    # Chromium fails with
    #   This video file cannot be played.
    #   (Error Code: 102630)
    # so use google-chrome instead.
    exec = "google-chrome-stable --app=https://tv.get.no/";
    icon = fetchurl {
      name = "get-nett-tv-favicon.png";
      url = "https://tv.get.no/favicon.png";
      sha256 = "0acrlix5qmnb32zaqcch0khb6s7ajrw4qv5ikx33bpf71mimkc94";
    };
    comment = "Get Nett-TV";
    desktopName = "Get Nett-TV";
    #categories = "Network;WebBrowser";
    extraEntries = ''
      StartupWMClass=tv.get.no
    '';
  };

  netflix = makeDesktopItem {
    name = "netflix";  # nix store path name
    # It's a pain to maintain widewine for Chromium (slow to build, breaks), so
    # use google-chrome for netflix.
    exec = "google-chrome-stable --app=https://www.netflix.com/";
    icon = fetchurl {
      url = "http://www.iconarchive.com/download/i106070/papirus-team/papirus-apps/netflix.svg";
      sha256 = "06n3crmfc3k8yahybic399p832vzj5afrdqvlizrk8lbk3plrjd2";
    };
    comment = "Watch TV series and movies online";
    desktopName = "Netflix";
    #categories = "Network;WebBrowser";
    extraEntries = ''
      StartupWMClass=www.netflix.com
    '';
  };

  nrk-tv = makeDesktopItem {
    name = "nrk-tv";  # nix store path name
    exec = "chromium-browser --app=https://tv.nrk.no/";
    icon = fetchurl {
      name = "nrk-tv-logo.png";
      url = "http://mirrors.kodi.tv/addons/leia/plugin.video.nrk/icon.png";
      sha256 = "0a0cn831qcn1wn2zqrgjhw3q3ch9li7fqgazvcii4a8gcrvcc3sm";
    };
    comment = "NRK TV";
    desktopName = "NRK TV";
    #categories = "Network;WebBrowser";
    extraEntries = ''
      StartupWMClass=tv.nrk.no
    '';
  };

in
  runCommand "custom-desktop-entries" {} ''
    mkdir -p "$out"
    cp -r "${get-nett-tv}/"* "$out"; chmod -R +w "$out"
    cp -r "${netflix}/"* "$out"; chmod -R +w "$out"
    cp -r "${nrk-tv}/"* "$out"; chmod -R +w "$out"
  ''
