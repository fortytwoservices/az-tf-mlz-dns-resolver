# Virtual network link

One virtual network link of a DNS forwarding ruleset
(`Microsoft.Network/dnsForwardingRulesets/virtualNetworkLinks`): the linked virtual network's DNS
queries follow the ruleset's rules. `modules/forwarding_ruleset` calls it once per link; a spoke can call
it alone from its own state with the ruleset's resource ID.

Azure cannot point a link at another virtual network, so changing `virtual_network_id` replaces it.
