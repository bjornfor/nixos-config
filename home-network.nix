# Usage examples:
# $ morph deploy ./home-network.nix switch
# $ morph deploy --keep-result --reboot ./home-network.nix boot

{
  network.description = "Home network";
  network.pkgs =
    let
      nixpkgsSrc = import ./inputs/nixpkgs.nix {};
    in
      import nixpkgsSrc {
        # Q: Why is config set but overlays empty?
        # A: As of morph-1.4.0, network.pkgs sets nixpkgs.pkgs, and the latter
        # is documented in "man configuration.nix" to ignore nixpkgs.config but
        # not nixpkgs.overlays. So we get the right overlays from within the
        # nixos configuration, but not the config. Set overlays to empty list
        # to prevent undeclared overlays from sneaking in.
        config = import ./cfg/nixpkgs-config.nix;
        overlays = [];
      };

  "media.local" = import ./machines/media/configuration.nix;
  "mini.local" = import ./machines/mini/configuration.nix;
  "srv1.local" = import ./machines/srv1/configuration.nix;
}
