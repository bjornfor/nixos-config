# Mount CIFS share(s) for users at login, as a systemd user services (one per
# share).
#
# Rationale:
# In GNOME one can use gvfs-mount. But in KDE/Plasma there is no equivalent
# tool. And there seems to be no working FUSE implementation for CIFS.
# mount.cifs requires root and/or previously set up entry in /etc/fstab. Hence
# we have to jump through some hoops, which are abstracted by this module.
#
# TODO: Look into pam_mount and pam_cifscreds.

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.cifs-user-mount;

  # A mount.cifs/umount wrapper that checks if the mountpoint is inside user's
  # home directory (it exits with non-zero status if not).
  commonHelper = command: ''
    #!${pkgs.bash}/bin/bash
    set -e

    path_is_subdir_of_home()
    {
        # Use readlink to prevent subverting the check with "../.." appended to the path.
        normalized_path="$(readlink -f "$1")"
        #real_user_home=$(getent passwd $SUDO_USER | cut -d: -f6)
        #real_user_home=$(echo ~$SUDO_USER)
        #real_user_home=~$SUDO_USER
        real_user_home=$PWD  # user services are invoked with PWD=$HOME
        test -d "$real_user_home" || return 1
        # Add trailing slash to prevent user "al" from matching user "alice"
        # home (/home/al is substring of /home/alice).
        echo x"$normalized_path/" | grep -q "^x$real_user_home/"
    }

    # Check all arguments. If any is a path, it must be located within the
    # users home directory, else we abort.
    for arg in "$@"; do
        if [ -d "$arg" ]; then
            if path_is_subdir_of_home "$arg"; then
                echo "Access to $arg is allowed."
            else
                echo "Access to $arg is denied -- not a subdirectory of user home ($real_user_home)"
                exit 1
            fi
        fi
    done

    # Run the command
    echo "${command}"
    ${command}
  '';

  cifsMountHelper = pkgs.writeScript "cifs-mount-helper"
    (commonHelper ''${pkgs.cifs-utils}/bin/mount.cifs "$@"'');

  cifsUmountHelper = pkgs.writeScript "cifs-umount-helper"
    (commonHelper ''${pkgs.utillinux}/bin/umount "$@"'');

  flattenedShareName = share:
    replaceChars [ "$" "/" ] [ "" "" ] share.shareName;

  mkStartScript = share:
    pkgs.writeScript "cifs-user-mount-start" ''
      #!${pkgs.bash}/bin/bash
      mkdir -p "${share.mountpoint}/${flattenedShareName share}" || exit 1
      # Somethimes the network isn't ready yet, so run a loop. (Systemd
      # doesn't support Restart= for oneshot services, see
      # https://github.com/systemd/systemd/issues/2582.)
      for i in $(seq 10); do
          if sudo "${cifsMountHelper}" "//${share.server}/${share.shareName}" "${share.mountpoint}/${flattenedShareName share}" -o "${share.options}"; then
              # Sleep to ensure the last log output gets associated with the service
              # (known system journal race condition).
              sleep 3
              exit 0
          else
              echo "Trying again..."
              sleep 2
          fi
      done

      # Sleep to ensure the last log output gets associated with the service
      # (known system journal race condition).
      sleep 3

      # Failed 
      exit 1
    '';

  mkStopScript = share:
    pkgs.writeScript "cifs-user-mount-stop" ''
      #!${pkgs.bash}/bin/bash
      sudo "${cifsUmountHelper}" "${share.mountpoint}/${flattenedShareName share}"
      ret=$?

      # Sleep to ensure the last log output gets associated with the service
      # (known system journal race condition).
      sleep 3
      exit $ret
    '';

  mkService = share: {
    name = "cifs-user-mount-${flattenedShareName share}";
    value = {
      description = "CIFS user mount for //${share.server}/${share.shareName}";
      wantedBy = [ "default.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      path = with pkgs; [ "/run/wrappers" /* for sudo */ ];
      serviceConfig = {
        ExecStart = mkStartScript share;
        ExecStop = mkStopScript share;
        Type = "oneshot";
        RemainAfterExit = true;
        SyslogIdentifier = "cifs-user-mount-${flattenedShareName share}";
      };
    };
  };

in

{
  options.services.cifs-user-mount = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enable mounting CIFS shares as systemd user services.
      '';
    };

    shares = mkOption {
      type = types.listOf types.attrs;
      default = [ ];
      example = literalExample ''
        [ { server = "server.example";
            shareName = "files";
            mountpoint = "$HOME/mnt/remote/server.example";
            options = "credentials=$HOME/.server.credentials,uid=$(id -u),gid=$(id -g),file_mode=0600,dir_mode=0700,iocharset=utf8,rw";
          }
        ]
      '';
      description = ''
        List of CIFS shares to be mounted somewhere under user $HOME. The
        environment variable $USER can be used in shareName to retrieve
        the user login name, for per-user server shares. $HOME is also available.

        The credentials file has the following format:

          domain=YOUR_DOMAIN
          username=YOUR_USERNAME
          password=YOUR_PASSWORD

        IMPORTANT: Set permissions to 600 on the credentials file to prevent
        group/world readable file.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Give the "users" group access to the custom cifs (u)mount helpers, without
    # being asked for password.
    security.sudo.extraConfig = mkAfter ''
      %users ALL = NOPASSWD: NOSETENV: ${cifsMountHelper}, ${cifsUmountHelper}
    '';

    systemd.user.services = builtins.listToAttrs (map (x: mkService x) cfg.shares);
  };
}
