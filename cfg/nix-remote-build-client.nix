{
  nix.buildMachines = [
    { hostName = "bforsman.name";
      systems = [ "x86_64-linux" ];
      # TODO: I belive maxJobs = "auto" is documented somewhere, but nix-2.2.2
      # and 2.3 fail with unhelpful "error: stoull".
      maxJobs = 4;
      speedFactor = 10;
      supportedFeatures = [
        "benchmark"
        "big-parallel"
        "kvm"
        "nixos-test"
      ];
      mandatoryFeatures = [ ];
      # The server side user to login with
      sshUser = "nix-remote-build";
      # The client side private key for login as sshUser
      sshKey = "/root/.ssh/id_ed25519_nix_remote_build";
    }
  ];
  nix.distributedBuilds = true;

  # optional, useful when the builder has a faster internet connection than yours
  nix.extraOptions = ''
    builders-use-substitutes = true
  '';
}
