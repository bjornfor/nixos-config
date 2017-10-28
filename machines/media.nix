{ config, lib, pkgs, ... }:

{
  imports = [
    ../config/base-medium.nix
  ];

  boot.loader.grub.device =
    "/dev/disk/by-id/ata-Corsair_Force_3_SSD_123479100000148001C8";

  fileSystems."/mnt/backup-disk" =
    { device = "/dev/disk/by-label/backup";
      options = [ "nofail" ];
    };

  networking.hostName = "media";

  system.autoUpgrade = {
    enable = true;
    dates = "04:40";
    channel = "https://nixos.org/channels/nixos-17.09";
  };

  nixpkgs.config = {
    # Disabled because it fails to build.
    # See https://github.com/NixOS/nixpkgs/issues/22333
    #chromium.enableWideVine = true;  # for Netflix, requires full chromium build
  };

  systemd.automounts = [
    { where = "/mnt/maria-pc_seagate_expansion_drive_4tb";
      wantedBy = [ "multi-user.target" ];
    }
  ];

  systemd.mounts = [
    { what = "//maria-pc/seagate_expansion_drive_4tb";
      where = "/mnt/maria-pc_seagate_expansion_drive_4tb";
      type = "cifs";
      options = "ro,credentials=/root/.credentials.maria-pc,uid=bfo,gid=users,iocharset=utf8";
    }
  ];

  environment.systemPackages = with pkgs; [
    google-chrome
    kodi
    spotify
    transmission_gtk
  ];

  services.samba.enable = true; # required for nsswins to work
  services.samba.nsswins = true;

  services.xserver.displayManager.gdm.autoLogin.user = lib.mkForce "media";
  virtualisation.libvirtd.enable = lib.mkForce false;

  users.extraUsers = {
    media = {
      description = "Media user";
      uid = 1001;
      extraGroups = [
        "cdrom"
        "transmission"
        "wheel"
      ];
      isNormalUser = true;
      initialPassword = "media";
    };
  };

  services.borg-backup = rec {
    enable = true;
    repository = "/mnt/backup-disk/backup-maria.borg";
    archiveBaseName = "maria-pc_seagate_expansion_drive_4tb";
    pathsToBackup = [ "/mnt/${archiveBaseName}" ];
    preHook = ''
      # Email notification receivers.
      # Separate multiple addresses with comma and space (", ").
      to_recipients="$(cat /etc/marias-email-address.txt)"
      cc_recipients="bjorn.forsman@gmail.com"

      backup_age_in_days()
      {
          today=$(date +%Y-%m-%d)
          newest_backup_date=$(borg info "$repository"::"$(borg list "$repository" | tail -1 | awk '{print $1}')" | awk '/Time \(start\)/ {print $4}')
          # POSIX sh:
          #n_days_old=$(echo "scale=0; ( $(date -d $today +%s) - $(date -d $newest_backup_date +%s) ) / (24*3600)" | bc)
          # bash(?):
          n_days_old=$(( ( $(date -d $today +%s) - $(date -d $newest_backup_date +%s) ) / (24*3600) ))
          if [ "$n_days_old" -eq "$n_days_old" ] 2>/dev/null
          then
              # $n_days_old is an integer
              echo "$n_days_old"
          else
              echo "-1"
          fi
      }

      maybe_send_failure_notification()
      {
          n_days_old=$(backup_age_in_days)
          echo "Last backup is $n_days_old days old"
          if [ $n_days_old -ge 7 -a $(( $n_days_old % 7 )) = 0 ]; then
              echo "Warning: backup is old ($n_days_old days), sending email"
              send_email $(n_days_old)
          fi
      }

      dieHook() {
          maybe_send_failure_notification
      }

      send_email()
      {
          n_days_old=$1
          test "$n_days_old" -eq "$n_days_old" || { echo "ERROR: Programming error, n_days_old=$n_days_old is not an integer"; exit 1; }
          cat << EOM | sendmail -t
      From: "Mr. Robot" <noreply>
      To: $to_recipients
      Cc: $cc_recipients
      Subject: Obs, sikkerhetskopien din er gammel

      Hei Maria,

      Jeg heter Hal og en robot som Bjørn har laget.
      Hver natt tar jeg sikkerhetskopi av dataene fra den eksterne
      harddisken din og over til stue-PCen. Men nå er det $n_days_old dager siden sist.

      Kan du la PCen stå på en natt slik at jeg får tatt en ny sikkerhetskopi for deg?

      Ha en fin dag!

      Mvh
      Hal 9000 / Bjørn Forsman
      EOM
      }

      # For test
      #send_email $(backup_age_in_days)
      #exit 0

      # access the mountpoint now, to trigger automount (why is this needed?)
      if ! ls -ld /mnt/${archiveBaseName}; then
          die "Failed to mount maria-pc"
      fi
      # Oops! autofs is considered a filesystem, so this check will always pass.
      if ! mountpoint /mnt/${archiveBaseName}; then
          die "exiting"
      fi
      if [ $(ls /mnt/${archiveBaseName} | wc -l) -lt 1 ]; then
          die "/mnt/${archiveBaseName} has no files, assuming mount failure"
      fi
    '';
  };

  users.extraUsers.bfo.openssh.authorizedKeys.keys = with import ../misc/ssh-keys.nix; [
    bfo_at_mini
  ];

  # The NixOS release to be compatible with for stateful data such as databases.
  system.stateVersion = "17.03";
}
