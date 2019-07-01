{
  imports = [
    ../../cfg/syncthing.nix
  ];

  networking.firewall.allowedTCPPorts = [
    8384  # syncthing web ui (TODO: auth)
  ];

  services = {
    syncthing.guiAddress = "0.0.0.0:8384";
  };
}
