{ stdenv, fetchurl, mkDerivation, dpkg, autoPatchelfHook
, qtserialport, qtwebsockets
, libredirect, makeWrapper, gzip, gnutar
}:

# The default user and password for the WebApp is delight/delight. Hm, it looks
# like the "WebApp" is deprecated, and the new Phoscon App is its replacement
# (the button to the left of the WebApp). The Phoscon App asks to create
# user/password at first startup, instead of hardcoding a default.

mkDerivation rec {
  name = "deconz-${version}";
  version = "2.05.77";

  src = fetchurl {
    url = "http://deconz.dresden-elektronik.de/ubuntu/beta/deconz-${version}-qt5.deb";
    sha256 = "16ssp6rxnqpgl9avdlcaabja05rr3l4xhghbv2l8afv0wcgbj29k";
  };

  devsrc = fetchurl {
    url = "http://deconz.dresden-elektronik.de/ubuntu/beta/deconz-dev-${version}.deb";
    sha256 = "0xav93kd9l8lpaw0fikghmrxfglan85krgh47rjpd7napr648ikg";
  };

  nativeBuildInputs = [ dpkg autoPatchelfHook makeWrapper ];

  buildInputs = [ qtserialport qtwebsockets ];

  unpackPhase = ''
    dpkg -x $src ./deconz-src
    dpkg -x $devsrc ./deconz-devsrc
  '';

  installPhase = ''
    mkdir -p "$out"
    cp -r deconz-src/* "$out"
    cp -r deconz-devsrc/* "$out"

    # Flatten /usr and manually merge lib/ and usr/lib/, since mv refuses to.
    mv "$out/lib" "$out/orig_lib"
    mv "$out/usr/"* "$out/"
    mv "$out/orig_lib/systemd/system/"* "$out/lib/systemd/system/"
    rmdir "$out/orig_lib/systemd/system"
    rmdir "$out/orig_lib/systemd"
    rmdir "$out/orig_lib"
    rmdir "$out/usr"

    # Remove empty directory tree
    rmdir "$out/etc/systemd/system"
    rmdir "$out/etc/systemd"
    rmdir "$out/etc"

    for f in "$out/lib/systemd/system/"*.service \
             "$out/share/applications/"*.desktop; do
        substituteInPlace "$f" \
            --replace "/usr/" "$out/"
    done

    wrapProgram "$out/bin/deCONZ" \
        --set LD_PRELOAD "${libredirect}/lib/libredirect.so" \
        --set NIX_REDIRECTS "/usr/share=$out/share" \
        --prefix PATH : "${stdenv.lib.makeBinPath [ gzip gnutar ]}"
  '';

  meta = with stdenv.lib; {
    description = "Manage ZigBee network with ConBee, ConBee II or RaspBee hardware";
    # 2019-08-19: The homepage links to old software that doesn't even work --
    # it fails to detect ConBee2.
    homepage = "https://www.dresden-elektronik.de/funktechnik/products/software/pc-software/deconz/?L=1";
    license = licenses.unfree;
    platforms = with platforms; linux;
    maintainers = with maintainers; [ bjornfor ];
  };
}
