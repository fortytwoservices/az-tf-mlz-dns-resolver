# Virtual network link

One virtual network link of a DNS forwarding ruleset
(`Microsoft.Network/dnsForwardingRulesets/virtualNetworkLinks`): the linked virtual network's DNS
queries follow the ruleset's rules. `modules/forwarding_ruleset` calls it once per link; a spoke can call
it alone from its own state with the ruleset's resource ID.

Azure cannot point a link at another virtual network, so changing `virtual_network_id` replaces it.

Removing one metadata entry leaves the other keys as they were, and azapi compares only the keys in the
body, so the metadata is also sent through `sensitive_body`, versioned by a hash of the map: any change
is written. A plan that removes an entry shows only that version changing.
