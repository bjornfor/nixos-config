# default to pinned/reproducible branch
{ branch ? "pinned" }:

let
  hmGitUrl = "https://github.com/rycee/home-manager";

  pinnedInfo = builtins.fromJSON (builtins.readFile ./home-manager.json);

  branches = {
    pinned = builtins.fetchGit {
      inherit (pinnedInfo) url ref rev;
    };
    release = builtins.fetchGit {
      url = hmGitUrl;
      ref = "refs/heads/release-20.03";
    };
    master = builtins.fetchGit {
      url = hmGitUrl;
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
