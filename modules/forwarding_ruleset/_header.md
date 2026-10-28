# Forwarding ruleset

One DNS forwarding ruleset (`Microsoft.Network/dnsForwardingRulesets`) with its forwarding rules
(`modules/forwarding_rule`) and virtual network links (`modules/virtual_network_link`), a lock, role
assignments and diagnostic settings (metrics only: a ruleset has no log categories). The root module calls it once per ruleset; a separate state can call it alone with the IDs
of one or two outbound endpoints, so a rule change never plans the resolver.

The ruleset's lock covers its rules and links too, so it is removed around changes to them. A spoke that
links itself from its own state calls `modules/virtual_network_link` with the ruleset's ID instead; a
`ReadOnly` lock on the ruleset blocks that.
