{ stdenv, fetchurl, utillinux, file, bash, glibc, pkgsi686Linux, writeScript
, nukeReferences, glibcLocales, libfaketime
# Runtime libraries:
, zlib, glib, libpng12, freetype, libSM, libICE, libXrender, fontconfig
, libXext, libX11, libXtst, gtk2, bzip2, libelf
}:

let

  sources = import ./sources.nix { inherit fetchurl; };

  buildQuartus = import ./generic.nix {
    inherit
      stdenv fetchurl utillinux file bash glibc pkgsi686Linux writeScript
      nukeReferences glibcLocales libfaketime
      # Runtime libraries:
      zlib glib libpng12 freetype libSM libICE libXrender fontconfig
      libXext libX11 libXtst gtk2 bzip2 libelf;
  };

  mkCommonQuartus = srcAttrs:
    buildQuartus {
      inherit (srcAttrs) baseName prettyName is32bitPackage;
      version = srcAttrs.updates.version;
      components = with srcAttrs.components; [
        quartus cyclonev
      ];
      updateComponents = with srcAttrs.updates.components; [
        quartus
      ];
    };

in rec {

  inherit sources;

  altera-quartus-ii-web-13 =
    mkCommonQuartus sources.v13.web_edition;

  altera-quartus-ii-subscription-13 =
    mkCommonQuartus sources.v13.subscription_edition;

  altera-quartus-ii-web-14 =
    mkCommonQuartus sources.v14.web_edition;

  altera-quartus-ii-subscription-14 =
    mkCommonQuartus sources.v14.subscription_edition;

  altera-quartus-prime-lite-15 =
    mkCommonQuartus sources.v15.lite_edition;

  altera-quartus-prime-standard-15 =
    mkCommonQuartus sources.v15.standard_edition;

  altera-quartus-prime-lite-16 =
    mkCommonQuartus sources.v16.lite_edition;

  altera-quartus-prime-standard-16 =
    mkCommonQuartus sources.v16.standard_edition;

  # Aliases to latest versions
  altera-quartus-prime-lite = altera-quartus-prime-lite-16;
  altera-quartus-prime-standard = altera-quartus-prime-standard-16;

}
