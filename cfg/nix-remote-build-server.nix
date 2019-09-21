# TODO: There is a nix.sshServe NixOS option, but it doesn't (yet) allow the
# configuration of the nix-store --write flag.

let
  user = "nix-remote-build";
in
{
  # must be trusted to be allowed to build derivations
  nix.trustedUsers = [ user ];

  users.users.nix-remote-build = {
    group = user;
    isSystemUser = true;
    useDefaultShell = true;
    openssh.authorizedKeys.keys = with import ../misc/ssh-keys.nix; [
      (''command="nix-store --serve --write",restrict '' + media.root.nix_remote_build)
      (''command="nix-store --serve --write",restrict '' + mini.root.nix_remote_build)
      (''command="nix-store --serve --write",restrict '' + whitetip.root.nix_remote_build)
    ];
  };

  users.groups."${user}" = { };
}
