{ config, lib, pkgs, ... }:
{
  users.extraUsers = {
    bfo = {
      description = "Bjørn Forsman";
      uid = 1000;
      extraGroups = [
        "adm"
        "audio"
        "cdrom"
        "dialout"
        "docker"
        "libvirtd"
        "networkmanager"
        "plugdev"
        "scanner"
        "systemd-journal"
        "tracing"
        "transmission"
        "tty"
        "usbtmc"
        "vboxusers"
        "video"
        "wheel"
        "wireshark"
      ];
      isNormalUser = true;
      initialPassword = "initialpw";
      # Subordinate user ids that user is allowed to use. They are set into
      # /etc/subuid and are used by newuidmap for user namespaces. (Needed for
      # LXC.)
      subUidRanges = [
        { startUid = 100000; count = 65536; }
      ];
      subGidRanges = [
        { startGid = 100000; count = 65536; }
      ];

    };
  };

  users.extraGroups = {
    plugdev = { gid = 500; };
    tracing = { gid = 501; };
    usbtmc = { gid = 502; };
    wireshark = { gid = 503; };
    usbmon = { gid = 504; };
  };
}
