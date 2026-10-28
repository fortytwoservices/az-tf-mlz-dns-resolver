# Forwarding rule

One forwarding rule in a DNS forwarding ruleset (`Microsoft.Network/dnsForwardingRulesets/forwardingRules`):
queries for `domain_name`, from the virtual networks linked to the ruleset, go to `target_dns_servers`
through the ruleset's outbound endpoints. `modules/forwarding_ruleset` calls it once per rule; it can also
be called alone with the ruleset's resource ID.

Azure cannot change a rule's domain name, so changing it replaces the rule; targets, state and metadata
are updated in place. Azure accepts only port 53 for the targets.
