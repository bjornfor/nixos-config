{ config, lib, pkgs, ... }:

{
  users.extraUsers = {
    bf = {
      description = "Bjørn Forsman";
      uid = 1000;
      extraGroups = [
        "audio"
        "cdrom"
        "dialout"  # for access to /dev/ttyUSBx
        "docker"
        "git"  # for read-only access to gitolite repos on the filesystem
        "libvirtd"
        "motion"
        "networkmanager"
        "plugdev"
        "scanner"
        "syncthing"
        "systemd-journal"
        "tracing"
        "transmission"
        "tty"
        "usbmon"
        "usbtmc"
        "vboxusers"
        "video"
        "wheel"  # admin rights
        "wireshark"
      ];
      isNormalUser = true;
      initialPassword = "bf";
      # Subordinate user ids that user is allowed to use. They are set into
      # /etc/subuid and are used by newuidmap for user namespaces. (Needed for
      # LXC.)
      subUidRanges = [
        { startUid = 100000; count = 65536; }
      ];
      subGidRanges = [
        { startGid = 100000; count = 65536; }
      ];
      openssh.authorizedKeys.keys = with config.local.resources.sshKeys; [
        mini.bf.default
        whitetip.bf.default
      ];
    };
  };

  #home-manager.users.bf = ...;

}
