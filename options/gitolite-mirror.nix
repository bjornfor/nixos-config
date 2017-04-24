{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.gitolite-mirror;
in
{
  options.services.gitolite-mirror = {

    enable = mkEnableOption "enable configuration of mirrored git repos served under gitolite. Use wild repo configuration in gitolite to match the mirrorPrefix option";

    mirrorPrefix = mkOption {
      type = types.str;
      default = "mirrors/";
      description = ''
        Where under the gitolite repositories directory to keep mirrored
        git repositories.
      '';
    };

    repoUrls = mkOption {
      type = types.listOf types.str;
      default = [];
      example = [ "https://github.com/nixos/nixpkgs" ];
      description = ''
        List of git repository URLs that should be mirrored.
      '';
    };

  };

  config = mkIf cfg.enable {

    assertions = [
      { assertion = config.services.gitolite.enable;
        message = "The gitolite service must be enabled";
      }
    ];

    systemd.services.gitolite-mirror = {
      description = "Maintain Git Mirror Repositories";
      # Run 6 minutes past ever every hour during the day. (Don't update at night
      # during backup.) See systemd.time(7) for details about the format.
      startAt = "*-*-* 7..23:06";
      script = ''
        bare_repo_name_from_url()
        {
            # Normalize by removing optional trailing '.git' and then always
            # appending it.
            echo "$(basename "$1" | sed -e "s/\.git$//").git"
        }

        # $HOME is needed for git to expand ~ in /etc/gitconfig (or else fail)
        export HOME="${config.services.gitolite.dataDir}"

        mkdir -p "${config.services.gitolite.dataDir}/repositories/${cfg.mirrorPrefix}"
        cd "${config.services.gitolite.dataDir}/repositories/${cfg.mirrorPrefix}"

        #inited_one_or_more=0
        for url in ${lib.concatStringsSep " " cfg.repoUrls}; do
            # Init repository.
            # (git clone is fairly atomic in that either the clone completes or
            # not, there is no in-between state if the command is aborted.)
            local_repo=$(bare_repo_name_from_url "$url")
            if [ ! -d "$local_repo" ]; then
                echo "Initializing mirror repo \"$local_repo\" from \"$url\""
                "${pkgs.git}/bin/git" clone --mirror "$url"
                inited_one_or_more=1
            fi

            # Update repo description
            new_repo_description="Mirror of $url"
            old_repo_description=$(cat "$local_repo"/description)
            if [ "$new_repo_description" != "$old_repo_description" ]; then
                echo "Updating repository description in $local_repo"
                echo "$new_repo_description" > "$local_repo"/description
            fi

            # Update existing repos
            echo "Updating repo: $url"
            (cd "$local_repo" && "${pkgs.git}/bin/git" remote update --prune) >/dev/null
        done

        # Is this needed?
        #if [ "$inited_one_or_more" -eq 1 ]; then
        #    # Refresh so that new repositories are shown in cgit
        #    #gitolite setup ...
        #fi
      '';
      serviceConfig.User = config.services.gitolite.user;
      serviceConfig.UMask = "0027";
      serviceConfig.WorkingDirectory = config.services.gitolite.dataDir;
    };

  };

}
