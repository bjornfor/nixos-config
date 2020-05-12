{ config, lib, pkgs, ... }:

{
  services.locate = {
    enable = true;
    # "findutils" is the default package (as per NixOS 17.03), but "mlocate"
    # has benefits:
    # 1. It (supposedly) updates its database faster.
    # 2. Its 'locate' command checks user permissions so that
    #    (a) users only see files they have access to on the filesystem and
    #    (b) indexing can run as root (without leaking file listings to
    #    unprivileged users).
    locate = pkgs.mlocate;
    localuser = null;  # needed so mlocate can run as root (TODO: improve NixOS module)
    interval = "02:15";
  };
}
