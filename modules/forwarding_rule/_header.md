# Forwarding rule

One forwarding rule in a DNS forwarding ruleset (`Microsoft.Network/dnsForwardingRulesets/forwardingRules`):
queries for `domain_name`, from the virtual networks linked to the ruleset, go to `target_dns_servers`
through the ruleset's outbound endpoints. `modules/forwarding_ruleset` calls it once per rule; it can also
be called alone with the ruleset's resource ID.

Azure cannot change a rule's domain name, so changing it replaces the rule; targets, state and metadata
are updated in place. Azure accepts only port 53 for the targets.

Removing one metadata entry leaves the other keys as they were, and azapi compares only the keys in the
body, so the metadata is also sent through `sensitive_body`, versioned by a hash of the map: any change
is written. A plan that removes an entry shows only that version changing.
