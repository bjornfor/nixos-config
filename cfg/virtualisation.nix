{ config, lib, pkgs, ... }:

{
  virtualisation.libvirtd.enable = true;
  virtualisation.lxc.enable = true;
  virtualisation.lxc.usernetConfig = ''
    bfo veth lxcbr0 10
  '';
  virtualisation.docker.enable = true;
  virtualisation.docker.storageDriver = "overlay";

  virtualisation.virtualbox.host.enable = true;
  #virtualisation.virtualbox.host.enableExtensionPack = true;
}
