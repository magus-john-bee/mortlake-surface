# Tailscale — WireGuard mesh VPN (hosted coordination server; headscale is a
# drop-in self-hosted control plane if that's ever wanted). First consumer:
# collie ingress via `tailscale serve` (replaces the public nginx path).
#
# IMPERATIVE (one-time, per fresh machine):
#   sudo tailscale up                                  # login URL → approve
#   sudo tailscale serve --bg --https=8443 http://127.0.0.1:8787
# 8443 because nginx binds 0.0.0.0:443 (its LAN IP is DHCP, so no
# explicit-address binding) — tailscaled cannot take 443 on the tailscale
# interface. Node state persists in /var/lib/tailscale; disable key expiry
# for this node in the admin console (always-on server).
_: {
  flake.nixosModules.tailscale = {
    services.tailscale = {
      enable = true;
      openFirewall = true;
      # Never let tailscaled manage /etc/resolv.conf. With accept-dns on
      # (the `tailscale up` default) a cold boot rewrites the resolver to
      # quad-100, whose forwarding chain ends at this host's own dnsmasq —
      # deadlocking local DNS. The host keeps DHCP DNS from the router;
      # tailnet clients still get split-DNS via the console.
      extraSetFlags = [ "--accept-dns=false" ];
    };

    # Node identity + serve config — without this, every reboot is a
    # re-enrollment.
    preservation.preserveAt."/persistent".directories = [ "/var/lib/tailscale" ];
  };
}
