# Tailnet split-DNS resolver. The Tailscale console routes otwell.dev to
# jehoel's tailscale IP (100.102.3.8); this module is what answers there.
# dnsmasq serves *.otwell.dev authoritatively (all names -> this host, where
# nginx binds 0.0.0.0:443 with valid ACME certs) and forwards everything
# else to public resolvers. Bound to lo + tailscale0 only — the LAN keeps
# using the router, and the public zone is untouched for the outside world.
_: {
  flake.nixosModules.tailnet-dns = {
    services.dnsmasq = {
      enable = true;
      settings = {
        # Authoritative answer for the split-DNS domain (dnsmasq covers the
        # bare domain and all subdomains).
        address = "/otwell.dev/100.102.3.8";
        # Never read /etc/resolv.conf — it points at quad-100, whose
        # otwell.dev route leads back here (forwarding loop otherwise).
        no-resolv = true;
        server = [
          "1.1.1.1"
          "9.9.9.9"
        ];
        interface = [
          "lo"
          "tailscale0"
        ];
        bind-interfaces = true;
        # No DHCP, no hosts-file service — DNS answering only.
        no-hosts = true;
        port = 53;
      };
    };

    # Tailnet clients' quad-100 forwarders reach this over tailscale0.
    networking.firewall.interfaces.tailscale0 = {
      allowedUDPPorts = [ 53 ];
      allowedTCPPorts = [ 53 ];
    };
  };
}
