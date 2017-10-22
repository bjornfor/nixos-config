{ stdenv, fetchurl, pythonPackages }:

# Tested at nixpkgs.git commit 99f63b4ded22117186eeba671c1657d155b45a20.

pythonPackages.buildPythonApplication rec {
  name = "spotify-ripper-${version}";
  version = "2.10.3";

  src = fetchurl {
    name = name + ".tar.gz";
    url = "https://github.com/jrnewell/spotify-ripper/archive/2.10.3.tar.gz";
    sha256 = "0rrgi2zyxjfh37a9rn8fn5shgghf170pf48xj8nc73sqsrwx5hyw";
  };

  # propagated* because we need the modules at runtime
  propagatedBuildInputs = with pythonPackages; [
    pyspotify requests2 schedule colorama mutagen
  ];

  # * Disable creating $HOME/.spotify-ripper at build time.
  # * Loosen up colorama and mutagen version requirements (WARNING)
  # TODO: Inject dependencies on encoding tools (flaac, lame, ...)?
  # For now, "nix-env -iA nixos.lame".
  preConfigure = ''
    sed -i -e "s/^create_default_dir()//" setup.py
    sed -i -e "s/colorama\=\=/colorama>=/" setup.py
    sed -i -e "s/mutagen\=\=/mutagen>=/" setup.py
  '';

  meta = with stdenv.lib; {
    description = "Download music from Spotify";
    longDescription = ''
      Spotify-ripper is a small ripper script for Spotify that rips Spotify
      URIs to audio files and includes ID3 tags and cover art. By default
      spotify-ripper will encode to MP3 files, but includes the ability to rip
      to WAV, FLAC, Ogg Vorbis, Opus, AAC, and MP4/M4A.
    '';
    license = licenses.mit;
  };
}
