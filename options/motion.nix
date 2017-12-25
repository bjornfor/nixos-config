{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.motion;

  dataDir = "/var/lib/motion";

  # TODO: add uid/gid to NixOS
  motionUser = "motion";
  motionGroup = "motion";
  motionUid = 510;
  motionGid = 510;

  umask = "0027";

  createServiceInstance = name: value:
    { name = "motion-instance-${name}";
      value =
        let
          configFile = pkgs.writeText "motion.conf" (value.configText + ''
            target_dir ${dataDir}/${name}
          '');
        in
          {
            description = "Motion Camera Monitor ${name}";
            wantedBy = [ "motion.target" ];
            partOf = [ "motion.target" ];
            after = [ "motion-setup.service" ];
            requires = [ "motion-setup.service" ];
            serviceConfig.User = motionUser;
            serviceConfig.Group = motionGroup;
            serviceConfig.UMask = umask;
            #serviceConfig.WorkingDirectory = "${dataDir}/${name}";
            serviceConfig.ExecStart = "${pkgs.motion}/bin/motion -n -c ${configFile} ${concatStringsSep " " value.extraOpts}";
          };
    };

  createGarbageCollectScript = name: value:
    ''
      #
      # GC in ${dataDir}/${name} on behalf of motion-instance-${name}.service
      # Delete by time:
      find "${dataDir}/${name}" -ctime +${builtins.toString value.limitDays} -delete
      # Delete by space:
      usage=$(du -sb "${dataDir}/${name}" | cut -d ''$'\t' -f 1)
      limit=$(( ${builtins.toString value.limitMebibytes} * 1024 * 1024))
      if [ $usage -gt $limit ]; then
          find "${dataDir}/${name}" -type f -printf '%T@\t%s\t%p\n' | \
              sort -n | \
              while [ $usage -gt $limit ] && IFS=''$'\t' read timestamp size file; do
                  rm -- "$file" && usage=$(( $usage - $size ))
              done
      fi
    '';
in
{
  options.services.motion = {

    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enable running Motion, the (security) camera monitoring software.
      '';
    };

    instances = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          configText = mkOption {
            type = types.lines;
            default = "";
            description = ''
              The contents of motion.conf for this instance.
              Note that NixOS injects a 'target_dir
              ${dataDir}/INSTANCE_NAME' directive at the end of configText.
            '';
          };
          extraOpts = mkOption {
            type = types.listOf types.str;
            default = [ ];
            example = [ "-d" "7" /* INFO loglevel */ ];
            description = ''
              List of extra command line options to pass to this motion instance.
            '';
          };
          limitDays = mkOption {
            type = types.int;
            default = 14;
            description = ''
              Files older than this will be deleted. Deletion happens every night,
              or on the next boot, if the machine is powered off at midnight.
            '';
          };
          limitMebibytes = mkOption {
            type = types.int;
            default = 10 * 1024;
            description = ''
              If the video/image output directory is bigger than this, old
              files will be deleted until below this size. Deletion happens
              every night, or on the next boot, if the machine is powered off
              at midnight.
            '';
          };
        };
      });
      default = {};
      description = ''
        Definition of motion instances.
      '';
    };

  };

  config = mkIf cfg.enable {
    systemd.services =
      { motion-setup = {
          description = "Setup Motion Camera Monitor";
          wantedBy = [ "multi-user.target" ];
          script = ''
            mkdir -p "${dataDir}"
            chown ${motionUser}:${motionGroup} "${dataDir}"

            # Create /var/lib/motion/NAME directory for each instance (must run as root)
            ${concatMapStrings (x: "mkdir -p \"${dataDir}/${x}\"") (builtins.attrNames cfg.instances)}
            for dir in "${dataDir}/"*; do
                test -d "$dir" || continue
                chown ${motionUser}:${motionGroup} "$dir"
            done
          '';
          # Run as root
          serviceConfig.UMask = umask;
        };

        motion-gc = {
          description = "Garbage Collect Motion Camera Files";
          startAt = "daily";
          script = ''
            ${concatStringsSep "\n\n" (mapAttrsToList createGarbageCollectScript cfg.instances)}
          '';
          serviceConfig.User = motionUser;
          serviceConfig.Group = motionGroup;
          serviceConfig.UMask = umask;
        };
      } // (mapAttrs' createServiceInstance cfg.instances);

    systemd.timers.motion-gc = {
      timerConfig.Persistent = true;
    };

    # Create a target unit to allow easy start stop of all motion instances.
    systemd.targets.motion = {
      description = "Motion Camera Monitor";
      wantedBy = [ "multi-user.target" ];
    };

    users.extraUsers."${motionUser}" = {
      group = motionGroup;
      description = "Motion Camera User";
      uid = motionUid;
      extraGroups = [ "video" ];
    };

    users.extraGroups."${motionGroup}".gid = motionGid;

  };
}
