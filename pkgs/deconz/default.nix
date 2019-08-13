{ stdenv, fetchurl, mkDerivation, dpkg, autoPatchelfHook
, qtserialport, qtwebsockets
, buildFHSUserEnv, writeScript
}:

# deCONZ is a prebuilt app that hardcodes "/usr/..." in several places (i.e. in
# ELF files). Notably, the webui (and probably firmware update app) doesn't
# work out of the box with Nix. The workaround is to use buildFHSUserEnv.

let
  deconz =
mkDerivation rec {
  name = "deconz-${version}";
  version = "2.05.66";

  src = fetchurl {
    url = "https://www.dresden-elektronik.de/deconz/ubuntu/beta/deconz-${version}-qt5.deb";
    sha256 = "1b2c0r5l4n0sgjmswmp5cvg95z7hwjkys66k9c3hywxrispyz7vy";
  };

  nativeBuildInputs = [ dpkg autoPatchelfHook ];

  buildInputs = [ qtserialport qtwebsockets ];

  unpackPhase = "dpkg -x $src ./";

  installPhase = ''
    mkdir -p "$out"
    cp -r usr/* etc "$out"
    substituteInPlace "$out/share/applications/deCONZ.desktop" \
        --replace "/usr/" "$out/"
  '';

  meta = with stdenv.lib; {
    description = "Manage ZigBee network with ConBee, ConBee II or RaspBee hardware";
    homepage = "https://www.dresden-elektronik.de/funktechnik/products/software/pc-software/deconz/?L=1";
    license = licenses.unfree;
    platforms = with platforms; linux;
    maintainers = with maintainers; [ bjornfor ];
  };
};

deconz-fhs = buildFHSUserEnv {
  name = "deCONZ";

  targetPkgs = pkgs: with pkgs; [
    deconz
  ];

  runScript = writeScript "run-deconz" ''
    exec "${deconz}/bin/deCONZ" "$@"
  '';
};

in
  deconz-fhs   # working webapp etc.
  #deconz      # broken webapp etc.
