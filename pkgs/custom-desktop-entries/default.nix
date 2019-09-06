{ lib, fetchurl, makeDesktopItem, runCommand }:

# StartupWMClass is found with `xprop WM_CLASS`. When multiple entries are
# returned, use the first one (most specific). (Ideally, all values could be
# used, for most precise match, but I haven't found a way to do so.)

let
  makeSimpleWebApp =
    { server
    , icon ? null
    , comment ? null
    , desktopName ? comment
    , categories ? null
    , browser ? "chromium-browser"
    }:
    makeDesktopItem
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

  entries = [

    (makeSimpleWebApp {
      server = "tv.get.no";
      # Chromium fails with
      #   This video file cannot be played.
      #   (Error Code: 102630)
      # so use google-chrome instead.
      browser = "google-chrome-stable";
      icon = fetchurl {
        name = "get-nett-tv-favicon.png";
        url = "https://tv.get.no/favicon.png";
        sha256 = "0acrlix5qmnb32zaqcch0khb6s7ajrw4qv5ikx33bpf71mimkc94";
      };
      comment = "Get Nett-TV";
    })

    (makeSimpleWebApp {
      server = "mail.google.com";
      icon = fetchurl {
        url = "https://upload.wikimedia.org/wikipedia/commons/a/ab/Gmail_Icon.svg";
        sha256 = "1avrc2laqmviih3gx4pkxrd7v2hkcgp48c7zcb1wmxbnxvcqxgqr";
      };
      comment = "GMail";
    })

    (makeSimpleWebApp {
      server = "www.netflix.com";
      # It's a pain to maintain widewine for Chromium (slow to build, breaks), so
      # use google-chrome for netflix.
      browser = "google-chrome-stable";
      icon = fetchurl {
        url = "http://www.iconarchive.com/download/i106070/papirus-team/papirus-apps/netflix.svg";
        sha256 = "06n3crmfc3k8yahybic399p832vzj5afrdqvlizrk8lbk3plrjd2";
      };
      comment = "Netflix";
    })

    (makeSimpleWebApp {
      server = "tv.nrk.no";
      icon = fetchurl {
        name = "nrk-tv-logo.png";
        url = "http://mirrors.kodi.tv/addons/leia/plugin.video.nrk/icon.png";
        sha256 = "0a0cn831qcn1wn2zqrgjhw3q3ch9li7fqgazvcii4a8gcrvcc3sm";
      };
      comment = "NRK TV";
    })

    (makeSimpleWebApp {
      server = "sbanken.no";
      # icon from google play
      # (https://play.google.com/store/apps/details?id=no.skandiabanken)
      icon = fetchurl {
        name = "sbanken_icon.png";
        url = "https://lh3.googleusercontent.com/qY0PzdGykNPdmbLmHQKGYAesB7CgmXO-bqCJdI957RRMZ57p82BME081WcSgDCH4OSQ=s180";
        sha256 = "1n4mjyhjn3npc785bvb3r0cpwndrzdzq8qq60d93hbgh9y04mdda";
      };
      comment = "Sbanken";
    })

    (makeSimpleWebApp {
      server = "www.youtube.com";
      icon = fetchurl {
        url = "https://upload.wikimedia.org/wikipedia/commons/4/40/Youtube_icon.svg";
        sha256 = "0gqnp61pbcsfd34w6r9bjxnpzkrlb0nhwb8z3h2a4xbyawa9dpcq";
      };
      comment = "YouTube";
    })

  ];

  mkCommand = drv: ''
    cp -r "${drv}/"* "$out"; chmod -R +w "$out"
  '';

in
  runCommand "custom-desktop-entries" {} (''
    mkdir -p "$out"
  '' + (lib.concatMapStringsSep "\n" mkCommand entries))
