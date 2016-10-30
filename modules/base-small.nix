{ config, lib, pkgs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ../hardware-configuration.nix
    ./users-and-groups.nix
    ./custom-packages.nix
  ];

  # List swap partitions activated at boot time.
  #swapDevices = [
  #  { device = "/dev/disk/by-label/swap"; }
  #];

  boot.loader.grub = {
    enable = true;
    version = 2;
    # Define on which hard drive you want to install Grub. Set to "nodev" to
    # not install it to the MBR at all, but only install the boot menu. This is
    # handy if you have NixOS installed on a USB stick that gets a different
    # device name when you plug it in different ports or on different machines.
    # Then you install using "/dev/..." and set it to "nodev" afterwards.
    #device = /*lib.mkDefault*/ "nodev";
  };

  # Select Linux version
  boot.kernelPackages = pkgs.linuxPackages;

  networking = {
    firewall.enable = false;
    networkmanager.enable = true;
  };

  nix = {
    useChroot = true;
    # To not get caught by the '''"nix-collect-garbage -d" makes "nixos-rebuild
    # switch" unusable when nixos.org is down"''' issue:
    extraOptions = ''
      gc-keep-outputs = true
      log-servers = http://hydra.nixos.org/log
      build-cores = 0  # 0 means auto-detect number of CPUs (and use all)
    '';
  };

  # Select internationalisation properties.
  i18n.consoleKeyMap = "qwerty/no";

  security.setuidOwners = [
    (lib.mkIf (builtins.elem pkgs.wireshark config.environment.systemPackages) {
      # Limit access to dumpcap to root and members of the wireshark group.
      source = "${pkgs.wireshark}/bin/dumpcap";
      program = "dumpcap";
      owner = "root";
      group = "wireshark";
      setuid = true;
      setgid = false;
      permissions = "u+rx,g+x";
    })
    (lib.mkIf (builtins.elem pkgs.smartmontools config.environment.systemPackages) {
      # Limit access to smartctl to root and members of the munin group.
      source = "${pkgs.smartmontools}/bin/smartctl";
      program = "smartctl";
      owner = "root";
      group = "munin";
      setuid = true;
      setgid = false;
      permissions = "u+rx,g+x";
    })
  ];

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  security.pam.loginLimits = [
    { domain = "@audio"; type = "-"; item = "rtprio"; value = "75"; }
    { domain = "@audio"; type = "-"; item = "memlock"; value = "500000"; }
  ];

  # Override similar to ~/.nixpkgs/config.nix (see "man configuration.nix" and
  # search for "nixpkgs.config"). Also, make sure to read
  # http://nixos.org/nixos/manual/#sec-customising-packages
  nixpkgs.config = {
    allowUnfree = true;  # allow proprietary packages
    firefox.enableAdobeFlash = true;
    chromium.enablePepperFlash = true;
    packageOverrides = pkgs: {
      #qtcreator = pkgs.qtcreator.override { qt48 = pkgs.qt48Full; };
      #qemu = pkgs.qemu.override { spiceSupport = true; };
    };
  };

  time.timeZone = "Europe/Oslo";

  environment.shellAliases = {
    ".." = "cd ..";
    "..." = "cd ../..";
    "..2" = "cd ../..";
    "..3" = "cd ../../..";
    "..4" = "cd ../../../..";
  };

  environment.interactiveShellInit = ''
    # A nix query helper function
    nq()
    {
      case "$@" in
        -h|--help|"")
          printf "nq: A tiny nix-env wrapper to search for packages in package name, attribute name and description fields\n";
          printf "\nUsage: nq <case insensitive regexp>\n";
          return;;
      esac
      nix-env -qaP --description \* | grep -i "$@"
    }

    export HISTCONTROL=ignoreboth   # ignorespace + ignoredups
    export HISTSIZE=1000000         # big big history
    export HISTFILESIZE=$HISTSIZE
    shopt -s histappend             # append to history, don't overwrite it
  '';

  environment.profileRelativeEnvVars = {
    GRC_BLOCKS_PATH = [ "/share/gnuradio/grc/blocks" ];
    PYTHONPATH = [ "/lib/python2.7/site-packages" ];
  };

  environment.sessionVariables = {
    NIX_AUTO_INSTALL = "1";
  };

  # Block advertisement domains (see
  # http://winhelp2002.mvps.org/hosts.htm)
  environment.etc."hosts".source =
    pkgs.fetchurl {
      url = "http://winhelp2002.mvps.org/hosts.txt";
      sha256 = "18as5cm295yyrns4i2hzxlb1h52x68gbnb1b3yksvzqs283pvbfi";
    };

  # for "attic mount -o allow_other" to be shareable with samba
  environment.etc."fuse.conf".text = ''
    user_allow_other
  '';

  # Make it easier to work with external scripts
  system.activationScripts.fhsCompat = ''
    fhscompat=0  # set to 1 or 0
    if [ "$fhscompat" = 1 ]; then
        echo "enabling (simple) FHS compatibility"
        mkdir -p /bin /usr/bin
        ln -sfv ${pkgs.bash}/bin/sh /bin/bash
        ln -sfv ${pkgs.perl}/bin/perl /usr/bin/perl
        ln -sfv ${pkgs.python2}/bin/python /usr/bin/python
        ln -sfv ${pkgs.python2}/bin/python /usr/bin/python2
    else
        # clean up
        find /bin /usr/bin -type l | while read file; do if [ "$file" != "/bin/sh" -a "$file" != "/usr/bin/env" ]; then rm -v "$file"; fi; done
    fi
  '';

  # Show git info in bash prompt and display a colorful hostname if using ssh.
  programs.bash.promptInit = ''
    export GIT_PS1_SHOWDIRTYSTATE=1
    source ${pkgs.gitAndTools.gitFull}/share/git/contrib/completion/git-prompt.sh

    __prompt_color="1;32m"
    # Alternate color for hostname if the generated color clashes with prompt color
    __alternate_color="1;33m"
    __hostnamecolor="$__prompt_color"
    # If logged in with ssh, pick a color derived from hostname
    if [ -n "$SSH_CLIENT" ]; then
      __hostnamecolor="1;$(${pkgs.nettools}/bin/hostname | od | tr ' ' '\n' | ${pkgs.gawk}/bin/awk '{total = total + $1}END{print 30 + (total % 6)}')m"
      # Fixup color clash
      if [ "$__hostnamecolor" = "$__prompt_color" ]; then
        __hostnamecolor="$__alternate_color"
      fi
    fi

    __red="1;31m"

    PS1='\n$(ret=$?; test $ret -ne 0 && printf "\[\e[$__red\]$ret\[\e[0m\] ")\[\e[$__prompt_color\]\u@\[\e[$__hostnamecolor\]\h \[\e[$__prompt_color\]\w$(__git_ps1 " [git:%s]")\[\e[0m\]\n$ '
  '';

  programs.bash.enableCompletion = true;

  services = {
    openssh = {
      enable = true;
      passwordAuthentication = false;
      extraConfig = ''
        AllowUsers bfo

        # Allow password authentication (only) from local network
        Match Address 192.168.1.0/24
          PasswordAuthentication yes
          # End the match group so that any remaining options (up to the end
          # of file) applies globally
          Match All
      '';
    };

    avahi = {
      enable = true;
      nssmdns = true;
      publish.enable = true;
      publish.addresses = true;
      publish.workstation = true;
    };
  };
}
