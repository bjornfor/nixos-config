{ config, lib, pkgs, ... }:

# After rebuilding NixOS with this module you have manually create users.
# Example:
#   sudo -E -u hydra hydra-create-user $USER --password $PASSWORD --role admin

{
  services.hydra = {
    enable = true;
    hydraURL = "http://hydra.bforsman.name";
    minimumDiskFree = 10; # GiB
    minimumDiskFreeEvaluator = 10; # GiB
    notificationSender = "hydra-noreply@bforsman.name";
    #port = 3000; # web server TCP port
    #smtpHost = "localhost";
  };

  nix = {
    useSandbox = true;
    buildCores = lib.mkOverride 90 0;  # 0 is special, it means "use all available CPU cores"
    nrBuildUsers = lib.mkOverride 90 32;
    # Define build slaves (need at least one).
    buildMachines = [
      { hostName = "localhost";
        system = "x86_64-linux";
        supportedFeatures = [ "kvm" "nixos-test" "big-parallel" "benchmark" ];
        maxJobs = "12";
      }
    ];
    extraOptions = ''
      build-timeout = 86400  # 24 hours
    '';
  };

}
