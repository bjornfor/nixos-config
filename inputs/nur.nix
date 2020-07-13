# default to pinned/reproducible branch
{ branch ? "pinned" }:

let
  nurGitUrl = "https://github.com/nix-community/nur";

  pinnedInfo = builtins.fromJSON (builtins.readFile ./nur.json);

  # NUR has no other branches than master
  branches = {
    pinned = builtins.fetchGit {
      inherit (pinnedInfo) url ref rev;
    };
    master = builtins.fetchGit {
      url = nurGitUrl;
      ref = "refs/heads/master";
    };
  };

  badBranchMsg = branch:
    let
      branchNames = builtins.toString (builtins.attrNames branches);
    in
      "unsupported branch \"${branch}\", valid branch names: ${branchNames}";
in
  branches."${branch}" or (throw (badBranchMsg branch))
