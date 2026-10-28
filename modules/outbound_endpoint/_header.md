# Outbound endpoint

One outbound endpoint of a DNS private resolver (`Microsoft.Network/dnsResolvers/outboundEndpoints`):
where queries that match a forwarding ruleset's rules leave the resolver's virtual network for their
target DNS servers. The root module calls it once per endpoint; it can also be called alone with the
resolver's resource ID.

Azure cannot move an endpoint to another subnet, so changing `subnet_id` replaces it. Azure deletes an
outbound endpoint only once no ruleset uses it: take it out of the rulesets in one apply and delete it in
the next.
