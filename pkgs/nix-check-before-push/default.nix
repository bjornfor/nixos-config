{ writeShellScriptBin }:

writeShellScriptBin "nix-check-before-push" ''
  # Check for evaluation errors in nixpkgs (and nixos?) git repositories.
  # Run it before git push.
  
  set -x
  nix-env -f . -qa \* --meta --xml --drv-path --show-trace >/dev/null || { echo FAILED; exit 1; }
  nix-build pkgs/top-level/release.nix -A tarball || { echo FAILED; exit 1; }
''
