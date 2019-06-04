{ stdenv
, shellcheck, git, nix, utillinux, gnused
, repositories ? "/var/lib/gitolite/repositories"
, miniciGcRootDir ? "/nix/var/nix/gcroots/mini-ci"
}:

stdenv.mkDerivation {
  name = "mini-ci";
  src = ./mini-ci.sh;
  unpackPhase = "true";
  installPhase = ''
    mkdir -p "$out/bin"
    install -m 755 "$src" "$out/bin/mini-ci"
    # Set configurable paths
    sed -e "s|^repositories=.*|repositories=\"${repositories}\"|" \
        -e "s|^default_datadir=.*|default_datadir=${miniciGcRootDir}|" \
        -e "s|^GIT_BIN=.*|GIT_BIN=${git}/bin/git|" \
        -e "s|^NIX_BUILD_BIN=.*|NIX_BUILD_BIN=${nix}/bin/nix-build|" \
        -e "s|^NIX_STORE_BIN=.*|NIX_STORE_BIN=${nix}/bin/nix-store|" \
        -e "s|^FLOCK_BIN=.*|FLOCK_BIN=${utillinux}/bin/flock|" \
        -e "s|^SED_BIN=.*|SED_BIN=${gnused}/bin/sed|" \
        -i "$out/bin/mini-ci"
    ${shellcheck}/bin/shellcheck "$out/bin/mini-ci"
  '';
}
