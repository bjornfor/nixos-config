{ stdenv, fetchzip, wxGTK30 }:

stdenv.mkDerivation rec {
  name = "winusb-2017-01-30";

  src = fetchzip {
    url = "https://github.com/slacka/WinUSB/archive/599f00cdfd5c931056c576e4b2ae04d9285c4192.zip";
    sha256 = "1219425d1m4463jy85nrc5xz5qy5m8svidbiwnqicy7hp8pdwa7x";
  };

  buildInputs = [ wxGTK30 ];

  meta = with stdenv.lib; {
    description = "Create bootable USB disks from Windows ISO images";
    homepage = https://github.com/slacka/WinUSB;
    license = licenses.gpl3;
    maintainers = [ maintainers.bjornfor ];
  };
}
