# Nixpkgs configuration file.

{
  allowUnfree = true;  # allow proprietary packages

  firefox.enableAdobeFlash = true;
  chromium.enablePepperFlash = true;

  packageOverrides = pkgs:
    import ../pkgs/default.nix { inherit pkgs;  };
}
