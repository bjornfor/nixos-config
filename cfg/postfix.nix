{
  services = {
    postfix = {
      enable = true;
      # Possibly set "domain" in machine specific configs.
      # The default "From:" address is
      #   user@${config.networking.hostName}.localdomain
      #domain = "server1.example";
      rootAlias = "bjorn.forsman@gmail.com";
      extraConfig = ''
        inet_interfaces = loopback-only

        # Postfix (or my system) seems to prefer ipv6 now, but that breaks on
        # my network:
        #
        #   connect to gmail-smtp-in.l.google.com[2a00:1450:4010:c09::1b]:25: Network is unreachable
        #
        # So let's force ipv4.
        smtp_address_preference = ipv4
      '';
    };
  };
}
