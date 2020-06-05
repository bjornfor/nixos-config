# Arbitrary shared resources for use across my NixOS machines.

{
  local.resources = {
    hostAddrs = import ../resources/host-addrs.nix;
    sshKeys = import ../resources/ssh-keys.nix;
  };
}
