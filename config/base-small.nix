{ config, lib, pkgs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ../hardware-configuration.nix
    ./users-and-groups.nix
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

  boot.extraModprobeConfig = ''
    # Disable UAS for Seagate Expansion Drive, because it is unstable. At least
    # on USB3. The end result is disconnects and filesystem corruption (NTFS).
    # TODO: Report to upstream about UAS instability. (Run
    # '<linux>/scripts/get_maintainer.pl -f ./drivers/usb/storage/uas.c') to
    # see who to email.)
    #
    # UPDATE: The blacklisting doesn't have any effect on my main desktop
    # system, the disk is still handled by "uas" driver. My main system is
    # Intel i5-3570K, Zotac Z77ITX motherboard, running the mini.nix NixOS
    # configuration. However, on _another_ Intel i5-3570K system, with an MSI
    # Z68A-GD65 motherboard and running a minimal configuration on top of
    # base-medium.nix, the blacklisting _does work_:
    #
    #   kernel: usb 6-2: UAS is blacklisted for this device, using usb-storage instead
    #
    # How weird.
    options usb-storage quirks=0bc2:2322:u
  '';

  networking = {
    firewall.enable = false;
    networkmanager.enable = true;
  };

  nix = {
    useSandbox = true;
    buildCores = 0;  # 0 means auto-detect number of CPUs (and use all)

    extraOptions = ''
      # To not get caught by the '''"nix-collect-garbage -d" makes
      # "nixos-rebuild switch" unusable when nixos.org is down"''' issue:
      gc-keep-outputs = true

      # For 'nix-store -l $(which vim)'
      log-servers = http://hydra.nixos.org/log

      # Number of seconds to wait for binary-cache to accept() our connect()
      connect-timeout = 15
    '';

    # Automatic garbage collection
    gc.automatic = true;
    gc.dates = "03:15";
    gc.options = "--delete-older-than 14d";
  };

  # Select internationalisation properties.
  i18n.consoleKeyMap = "qwerty/no";

  security.wrappers = {}
    // (if (builtins.elem pkgs.wireshark config.environment.systemPackages) then {
         dumpcap = {
           # Limit access to dumpcap to root and members of the wireshark group.
           source = "${pkgs.wireshark}/bin/dumpcap";
           program = "dumpcap";
           owner = "root";
           group = "wireshark";
           setuid = true;
           setgid = false;
           permissions = "u+rx,g+x";
         };
       } else {})
    // (if (builtins.elem pkgs.smartmontools config.environment.systemPackages) then {
         smartctl = {
           # Limit access to smartctl to root and members of the munin group.
           source = "${pkgs.smartmontools}/bin/smartctl";
           program = "smartctl";
           owner = "root";
           group = "munin";
           setuid = true;
           setgid = false;
           permissions = "u+rx,g+x";
         };
       } else {});

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  security.pam.loginLimits = [
    { domain = "@audio"; type = "-"; item = "rtprio"; value = "75"; }
    { domain = "@audio"; type = "-"; item = "memlock"; value = "500000"; }
  ];

  nixpkgs.config = import ./nixpkgs-config.nix;

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
  #environment.etc."hosts".source =
  #  pkgs.fetchurl {
  #    url = "http://winhelp2002.mvps.org/hosts.txt";
  #    sha256 = "18as5cm295yyrns4i2hzxlb1h52x68gbnb1b3yksvzqs283pvbfi";
  #  };

  # for "attic mount -o allow_other" to be shareable with samba
  environment.etc."fuse.conf".text = ''
    user_allow_other
  '';

  environment.etc."gitconfig".text = ''
    [core]
      editor = vim
      excludesfile = ~/.gitignore
    [color]
      ui = auto
    [alias]
      st = status
      df = diff
      ci = commit
      co = checkout
      wc = whatchanged
      br = branch
      f = fetch
      a = add
      l = log
      lga = log --graph --pretty=oneline --abbrev-commit --decorate --all
      rup = remote update -p
      # Working with github pull-requests:
      #   - git pullify  # just once
      #   - git fetch
      #   - git checkout pr/PULL_REQUEST_NUMBER
      pullify = config --add remote.origin.fetch '+refs/pull/*/head:refs/remotes/origin/pr/*'
      incoming = log ..@{u}
      outgoing = log @{u}..
      # "git serve" is from https://gist.github.com/datagrok/5080545
      serve = daemon --verbose --export-all --base-path=.git --reuseaddr --strict-paths .git/
    [sendemail]
      smtpserver = /run/current-system/sw/bin/msmtp
    [diff "word"]
      textconv = antiword
    [push]
      default = simple
  '';

  # Make it easier to work with external scripts
  system.activationScripts.fhsCompat = ''
    fhscompat=0  # set to 1 or 0
    if [ "$fhscompat" = 1 ]; then
        echo "enabling (simple) FHS compatibility"
        mkdir -p /bin /usr/bin
        ln -sfv ${pkgs.bash}/bin/sh /bin/bash
        ln -sfv ${pkgs.perl}/bin/perl /usr/bin/perl
        ln -sfv ${pkgs.python2Full}/bin/python /usr/bin/python
        ln -sfv ${pkgs.python2Full}/bin/python /usr/bin/python2
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
        AllowUsers git bfo

        # Doesn't work on NixOS: https://github.com/NixOS/nixpkgs/issues/18503
        ## Allow password authentication (only) from local network
        #Match Address 192.168.1.0/24
        #  PasswordAuthentication yes
        #  # End the match group so that any remaining options (up to the end
        #  # of file) applies globally
        #  Match All
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
