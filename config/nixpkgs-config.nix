# Nixpkgs configuration file.

{
  allowUnfree = true;  # allow proprietary packages

  firefox.enableAdobeFlash = true;
  chromium.enablePepperFlash = true;
  packageOverrides = pkgs: {
    #qtcreator = pkgs.qtcreator.override { qt48 = pkgs.qt48Full; };
    #qemu = pkgs.qemu.override { spiceSupport = true; };
  };
}
