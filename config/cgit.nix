{ config, lib, pkgs, ... }:

let
  myDomain = "bforsman.name";
in
{
  services.lighttpd = {
    enable = true;
    extraConfig = lib.mkAfter ''
      $HTTP["url"] =~ "^/cgit" {
        setenv.add-environment += (
          ${let
              pythonEnv = pkgs.python3.buildEnv.override {
                extraLibs = with pkgs.python3Packages; [ pygments ];
              };
              cgitPath = with pkgs; lib.makeBinPath [ pythonEnv ];
            in ''
            "PATH" => "${cgitPath}:" + env.PATH
          ''}
        )
      }
    '';
    cgit = {
      enable = true;
      configText = ''
        # HTTP endpoint for git clone is enabled by default
        #enable-http-clone=1
  
        # Specify clone URLs using macro expansion
        clone-url=http://${myDomain}/cgit/$CGIT_REPO_URL https://${myDomain}/cgit/$CGIT_REPO_URL git://${myDomain}/$CGIT_REPO_URL git@${myDomain}:$CGIT_REPO_URL
  
        # Show pretty commit graph
        #enable-commit-graph=1
  
        # Show number of affected files per commit on the log pages
        enable-log-filecount=1
  
        # Show number of added/removed lines per commit on the log pages
        enable-log-linecount=1
  
        # Enable 'stats' page and set big upper range
        max-stats=year
  
        # Allow download of archives in the following formats
        snapshots=tar.xz zip
  
        # Enable caching of up to 1000 output entries
        cache-size=1000
  
        # about-formatting.sh is impure (doesn't work)
        #about-filter=${pkgs.cgit}/lib/cgit/filters/about-formatting.sh
        # Add our own filter
        about-filter=${pkgs.writeScript "cgit-about-filter.sh" ''
          #!${pkgs.stdenv.shell}
          # The filename is available as first argument, but the filter
          # should read contents from STDIN (and write to STDOUT).
          filename=$1
          case "$filename" in
              *.asciidoc|*.adoc)
                  exec ${pkgs.asciidoctor}/bin/asciidoctor --safe --no-header-footer - -o -
                  # Dropping --safe with asciidoc because:
                  # asciidoc: ERROR: <stdin>: line 3: unsafe: ifeval invalid
                  #exec ''${pkgs.asciidoc}/bin/asciidoc --no-header-footer -
                  ;;
              *.markdown|*.md)
                  exec ${pkgs.pandoc}/bin/pandoc -f markdown -t html
                  ;;
              *)
                  echo "<pre>"
                  ${pkgs.coreutils}/bin/cat
                  echo "</pre>"
                  ;;
          esac
        ''}
  
        commit-filter=${pkgs.writeScript "cgit-commit-filter.sh" ''
          #!${pkgs.stdenv.shell}
          regex=
          # This expression generates links to commits referenced by their SHA1.
          regex=$regex'
          s|\b([0-9a-fA-F]{7,40})\b|<a href="./?id=\1">\1</a>|g'
  
          # This expression generates links to a bugtracker.
          #regex=$regex'
          #s|#([0-9]+)\b|<a href="http://YOUR_SERVER/?bug=\1">#\1</a>|g'
  
          # Apply the transformation
          sed -re "$regex"
        ''}
  
        source-filter=${pkgs.cgit}/lib/cgit/filters/syntax-highlighting.py
  
        # Search for these files in the root of the default branch of
        # repositories for coming up with the about page:
        readme=:README.asciidoc
        readme=:README.adoc
        readme=:README.markdown
        readme=:README.md
        readme=:README.txt
        readme=:README
  
        # Group repositories on the index page by sub-directory name
        section-from-path=1
  
        # Allow using gitweb.* keys
        enable-git-config=1
  
        # (Can be) maintained by gitolite
        project-list=/srv/git/projects.list
  
        # scan-path must be last so that earlier settings take effect when
        # scanning
        scan-path=/srv/git/repositories
      '';
    };
  };
}
