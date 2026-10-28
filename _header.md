# az-tf-mlz-dns-resolver

Azure DNS Private Resolver for Fortytwo's managed landing zone (MLZ): the resolver in a hub (or Virtual
WAN sidecar) virtual network, its inbound and outbound endpoints, and DNS forwarding rulesets with their
rules and virtual network links. AzAPI only, without telemetry.

- **Inbound endpoints** give on-premises DNS servers, a firewall's DNS proxy or a virtual network's DNS
  settings an address in the hub to send queries to; Azure DNS answers them, with the private DNS zones
  linked to the hub. Without `private_ip_address` Azure assigns the subnet's fifth address (`.4`); set
  it (for example `cidrhost(<subnet prefix>, 4)`) when the address must be known before apply.
- **Outbound endpoints** and **forwarding rulesets** send queries for chosen domains, from the virtual
  networks linked to a ruleset, to other DNS servers such as on-premises ones. The longest matching
  domain wins; other queries go to Azure DNS.

The module creates neither the virtual networks nor the endpoints' subnets: each endpoint needs a
subnet of its own in the resolver's virtual network, /28 to /24, delegated to
`Microsoft.Network/dnsResolvers`.

## Layout

| Path | Resource type | Called |
|---|---|---|
| root | `Microsoft.Network/dnsResolvers` | |
| `modules/inbound_endpoint` | `Microsoft.Network/dnsResolvers/inboundEndpoints` | by the root, per `inbound_endpoints` entry |
| `modules/outbound_endpoint` | `Microsoft.Network/dnsResolvers/outboundEndpoints` | by the root, per `outbound_endpoints` entry |
| `modules/forwarding_ruleset` | `Microsoft.Network/dnsForwardingRulesets` | by the root, per `forwarding_rulesets` entry, or alone |
| `modules/forwarding_rule` | `Microsoft.Network/dnsForwardingRulesets/forwardingRules` | by the ruleset, or alone |
| `modules/virtual_network_link` | `Microsoft.Network/dnsForwardingRulesets/virtualNetworkLinks` | by the ruleset, or alone (a spoke linking itself) |

## Behaviour

- **Replacement:** Azure cannot change a resolver's virtual network, an endpoint's subnet or address, a
  rule's domain name or a link's virtual network; changing one replaces that resource. A ruleset's
  outbound endpoints, a rule's targets, state and metadata, a link's metadata and every tag are updated
  in place.
- **Locks:** the resolver's lock also covers its endpoints, and a ruleset's lock its rules and links; the
  module removes a lock around changes to what it covers. A `ReadOnly` lock still blocks updating the
  locked resource itself: remove it first.
- **Interfaces:** locks, role assignments and diagnostic settings on the resolver and on each ruleset,
  through [`az-tf-mlz-interfaces`](https://github.com/fortytwoservices/az-tf-mlz-interfaces). Neither
  type has log categories, so diagnostic settings take `metrics` (`AllMetrics`) only; Learn marks none of
  their metrics as exportable, so a setting may carry little. DNS query logs come from DNS security
  policies, which this module does not manage. Endpoints, rules and links take no interfaces.
- **Removing an outbound endpoint** takes two applies: first take it out of every ruleset's
  `outbound_endpoints`, then remove it. Azure deletes an outbound endpoint only once no ruleset uses it,
  and Terraform deletes a removed resource before it updates the resources that used it.
  `create_before_destroy` on the ruleset would reverse that order, but Terraform passes it on to the
  endpoints and the resolver: a locked resolver's endpoint would then be deleted after its lock is back
  (`ScopeLocked`), and replacing an endpoint or the resolver would need a new name.
- **Moving an outbound endpoint that a ruleset uses to another subnet** works the same way. A new
  `subnet_id` replaces the endpoint under the same name and ID, and the old one cannot be deleted while a
  ruleset uses it. So add an endpoint under a new key and name, point the rulesets at it, and remove the old
  one in the next apply.
- **Retries:** by default every write retries `AnotherOperationInProgress`, and `CannotDeleteResource`:
  Azure reports endpoints deleted while it still counts them as the resolver's nested resources for a
  short while.
- **Target ports:** Azure accepts only port 53 for a rule's target DNS servers.
- **Metadata on rules and links:** azapi compares only the keys in the body, so removing one entry
  would otherwise plan no change and never reach Azure. The metadata is also sent through
  `sensitive_body`, versioned by a hash of the map: any change, a removed entry included, plans an update
  that writes it, and the plan shows the removed entry in the body.
- **Loops:** do not link a ruleset to the virtual network of an inbound endpoint that one of its rules
  forwards to; the queries would loop.
