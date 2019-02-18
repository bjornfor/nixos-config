{ config, pkgs, lib, ... }:

let
  miniciGcRootDir = "/nix/var/nix/gcroots/mini-ci";

  mini-ci = pkgs.my.mini-ci.override {
    repositories = "${config.services.gitolite.dataDir}/repositories";
    miniciGcRootDir = miniciGcRootDir;
  };

  # Make a VREF script that takes one optional argument. Usage:
  #   - VREF/$name                  = @all   # run on all branches/refs
  #   - VREF/$name/master           = @all   # run only on master branch
  #   - VREF/$name/refs/tags/[0-9]  = @all   # run only on these tag patterns
  mkVrefScript = name: text:
    pkgs.writeScript name ''
      #!${pkgs.bash}/bin/bash
      # Description of VREFs arguments is here:
      # http://gitolite.com/gitolite/vref.html#what-arguments-are-passed-to-the-vref-maker
      ref=$1
      oldsha=$2
      newsha=$3
      oldtree=$4
      newtree=$5
      access_flag=$6
      refex=$7  # full refex, e.g. VREF/COUNT/3/NEWFILES
      # Arg 8...N is the refex split by '/', just as a convenience

      selfname="${name}"
      # Get the (expanded) ref, like gitolite does. Basically, refs must be
      # fully qualified. If not, they are treated as branch names.
      vref_ref_arg=$(echo "$refex" | sed -e "s|VREF/$selfname.\?||")
      case "$vref_ref_arg" in
           refs/heads/*|refs/tags/*)
               true  # nop
               ;;
           *)
               vref_ref_arg="refs/heads/$vref_ref_arg"
               ;;
      esac

      # We stop only if $vref_ref_arg is non-empty AND not matching the ref
      # that is about to be pushed. Matches are only pinned to start of word
      # (regex '^'), like in gitolite.
      if [ "x$vref_ref_arg" != x ] && ! echo "$ref" | grep -q "^$vref_ref_arg"; then
          exit 0  # silently stop
      fi

      # Business logic
      ${text}
    '';

    # Custom gitolite VREFs (virtual refs scripts), that can be enabled in
    # gitolite-admin.git.
    vref = {
      # Run nix-build at git push time and cache the result. Branches and tags
      # are "cached" indefinitely, so it is also an automatic artifact server.
      # Build failures aborts the push. Take care to place this as the last
      # VREF (if more than one).
      mini-ci = mkVrefScript "mini-ci" ''
        ${mini-ci}/bin/mini-ci hook --repo="$GL_REPO" --oldrev="$oldsha" --newrev="$newsha" --ref="$ref"
      '';
    };
in
{
  services.gitolite = {
    enable = true;
    dataDir = "/srv/git";
    # Initial admin key (ssh)
    adminPubkey = with import ../misc/ssh-keys.nix; mini.bf.default;
    user = "git";
    group = "git";
    extraGitoliteRc =
      let
        generatedLocalCode = pkgs.runCommand "gitolite-local-code" {} ''
          mkdir -p "$out/VREF"
          ln -s "${vref.mini-ci}" "$out"/VREF/mini-ci
        '';
      in
        ''
          # Make dirs/files group readable, needed for webserver/cgit. (Default
          # setting is 0077.)
          $RC{UMASK} = 0027;

          $RC{GIT_CONFIG_KEYS} = '.*';

          $RC{LOCAL_CODE} = '${generatedLocalCode}';

          # Allow creators of "wild repos" to delete their own repos.
          push( @{$RC{ENABLE}}, 'D' );
        '';
  };

  # Creating /srv requires root privileges. The gitolite-init service itself
  # runs as unprivileged user. Use this helper service to create the needed
  # directories.
  systemd.services.gitolite-init-setup-srv = {
    description = "Create /srv Directory For Gitolite";
    requiredBy = [ "gitolite-init.service" ];
    before = [ "gitolite-init.service" ];
    script = ''
      mkdir -p /srv
      chmod a+rx /srv
    '';
    serviceConfig.Type = "oneshot";
  };

  # For convenience / testing
  environment.systemPackages = [ mini-ci ];

  systemd.tmpfiles.rules =
    let
      user = config.services.gitolite.user;
      group = config.services.gitolite.group;
    in
      [ #Type Path                      Mode UID     GID      Age Argument
        "d    ${miniciGcRootDir}        0755 ${user} ${group} -   -"
      ];

  systemd.services.mini-ci-gc = {
    description = "Mini-CI Garbage Collection";
    startAt = "daily";
    script = ''
      ${mini-ci}/bin/mini-ci gc
    '';
    serviceConfig.User = config.services.gitolite.user;
    serviceConfig.Group = config.services.gitolite.group;
    unitConfig.Documentation = "file://${mini-ci}/bin/mini-ci";
  };
}
