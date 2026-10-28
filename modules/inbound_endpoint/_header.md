# Inbound endpoint

One inbound endpoint of a DNS private resolver (`Microsoft.Network/dnsResolvers/inboundEndpoints`): a
private IP address in the resolver's virtual network that receives DNS queries and answers them with
Azure DNS and the private DNS zones linked to that network. The root module calls it once per endpoint;
it can also be called alone with the resolver's resource ID.

Without `private_ip_address` Azure assigns the subnet's fifth address (`.4` in `10.0.0.0/28`), which
changes only if the endpoint is created again. Azure cannot change an endpoint's subnet or address, so
changing either replaces the endpoint.
