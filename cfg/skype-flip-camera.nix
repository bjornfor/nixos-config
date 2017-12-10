{ config, lib, pkgs, ... }:

{
  # This modifies 'pkgs.skype' so that it flips the video camera input 180 degress.
  nixpkgs.config = {
    packageOverrides = pkgs: {
      skype =
        let
          libv4l_i686 = pkgs.callPackage_i686 <nixpkgs/pkgs/os-specific/linux/v4l-utils> { qt5 = null; };
        in
        lib.overrideDerivation pkgs.skype (attrs: {
          installPhase = attrs.installPhase +
            ''
              sed -i "2iexport LD_PRELOAD=${libv4l_i686}/lib/v4l1compat.so" "$out/bin/skype"
            '';
        });
    };
  };
}
