[
  (self: super:
    (import ../pkgs/default.nix { pkgs = super; })
  )

  (self: super: {
    nur =
      let
        nurSrc = import ../inputs/nur.nix { };
      in
        import nurSrc { nurpkgs = super; pkgs = super; };
  })
]
