# Default example

A resource group, a hub virtual network with a delegated subnet for each endpoint, and a spoke
virtual network. Then a DNS private resolver in the hub with an inbound endpoint at a static address
(the subnet's fifth, known before apply) and an outbound endpoint, and a forwarding ruleset that sends
queries for `onprem.example.com.` to two on-premises DNS servers, linked to the spoke. The resolver and
the ruleset send their metrics to a Log Analytics workspace.

Run it with `scripts/e2e.sh examples/default`: apply, a second plan that must be empty, destroy.
