# default to pinned/reproducible branch
{ branch ? "pinned" }:

let
  nixpkgsGitUrl = "https://github.com/NixOS/nixpkgs.git";

  pinnedInfo = builtins.fromJSON (builtins.readFile ./nixpkgs.json);

  branches = {
    # a snapshot of stable
    pinned = builtins.fetchGit {
      inherit (pinnedInfo) url ref rev;
    };
    release = builtins.fetchGit {
      url = nixpkgsGitUrl;
      ref = "refs/heads/release-20.03";
    };
    master = builtins.fetchGit {
      url = nixpkgsGitUrl;
      ref = "refs/heads/master";
    };
    # TODO: channels include programs.sqlite (for shell command-not-found
    # functionality), but command-not-found.pl hardcodes that path (no
    # $NIX_PATH lookup).
    stable-channel = builtins.fetchTarball {
      url = "https://nixos.org/channels/nixos-20.03/nixexprs.tar.xz";
    };
    unstable-channel = builtins.fetchTarball {
      url = "https://nixos.org/channels/nixpkgs-unstable/nixexprs.tar.xz";
    };
  };

  badBranchMsg = branch:
    let
      branchNames = builtins.toString (builtins.attrNames branches);
    in
      "unsupported branch \"${branch}\", valid branch names: ${branchNames}";
in
  branches."${branch}" or (throw (badBranchMsg branch))
