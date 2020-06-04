# Arbitrary shared resources for use across my NixOS machines.

{
  local.resources = {
    sshKeys = import ../resources/ssh-keys.nix;
  };
}
