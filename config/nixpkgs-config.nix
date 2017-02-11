# Nixpkgs configuration file.

{
  allowUnfree = true;  # allow proprietary packages

  firefox.enableAdobeFlash = true;
  chromium.enablePepperFlash = true;

  packageOverrides = pkgs: {
    ltsa = pkgs.callPackage ../packages/ltsa/default.nix { };
    spotify-ripper = pkgs.callPackage ../packages/spotify-ripper/default.nix { };
    winusb = pkgs.callPackage ../packages/winusb/default.nix { };
  };
}
