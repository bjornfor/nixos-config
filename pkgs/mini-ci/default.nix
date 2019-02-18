{ stdenv
, shellcheck
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
        -i "$out/bin/mini-ci"
    ${shellcheck}/bin/shellcheck "$out/bin/mini-ci"
  '';
}
