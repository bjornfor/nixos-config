{ config, lib, pkgs, ... }:

{
  # Make it easier to work with external scripts
  system.activationScripts.fhsCompat = ''
    fhscompat=0  # set to 1 or 0
    if [ "$fhscompat" = 1 ]; then
        echo "enabling (simple) FHS compatibility"
        mkdir -p /bin /usr/bin
        ln -sfv ${pkgs.bash}/bin/sh /bin/bash
        ln -sfv ${pkgs.perl}/bin/perl /usr/bin/perl
        ln -sfv ${pkgs.python3Full}/bin/python /usr/bin/python
        ln -sfv ${pkgs.python3Full}/bin/python /usr/bin/python3
    else
        # clean up
        find /bin /usr/bin -type l | while read file; do if [ "$file" != "/bin/sh" -a "$file" != "/usr/bin/env" ]; then rm -v "$file"; fi; done
    fi
  '';
}
