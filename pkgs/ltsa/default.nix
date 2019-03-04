{ stdenv, fetchurl, unzip, jre, bash }:

stdenv.mkDerivation rec {
  name = "ltsa-3.0";

  src = fetchurl {
    # The archive is unfortunately unversioned
    url = "http://www.doc.ic.ac.uk/~jnm/book/ltsa/ltsatool.zip";
    sha256 = "0ilhzr2m0k2gas2sr9l5zvw0i2xk6qznx3pllhcy28mfyb299n4y";
  };

  buildInputs = [ unzip ];

  phases = [ "installPhase" ];

  installPhase = ''
    unzip "$src"

    mkdir -p "$out/bin"
    mkdir -p "$out/lib"
    mkdir -p "$out/share/ltsa"

    cd ltsatool
    cp *.jar "$out/lib"
    cp *.txt "$out/share/ltsa"
    cp -r Chapter_examples/ "$out/share/ltsa"

    # Keep a ref to the source, in case it disappears from the Internet.
    ln -s "${src}" "$out/share/ltsa/ltsatool.zip"

    cat > "$out/bin/ltsa" << EOF
    #!${bash}/bin/sh
    exec ${jre}/bin/java -jar "$out/lib/ltsa.jar" "\$@"
    EOF

    chmod +x "$out/bin/ltsa"
  '';

  meta = with stdenv.lib; {
    description = "Verification tool for concurrent systems";
    longDescription = ''
      LTSA (Labelled Transition System Analyser) mechanically checks that
      the specification of a concurrent system satisfies the properties
      required of its behaviour. In addition, LTSA supports specification
      animation to facilitate interactive exploration of system
      behaviour.

      A system in LTSA is modelled as a set of interacting finite state
      machines. The properties required of the system are also modelled
      as state machines. LTSA performs compositional reachability
      analysis to exhaustively search for violations of the desired
      properties.
    '';
    homepage = http://www.doc.ic.ac.uk/ltsa/;
    license = "unknown";
  };
}
