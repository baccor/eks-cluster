this part is responsible for the "i'd do it the other way but *something*".

1# ALB

Originally i wanted to(and should) use tls but for that i'd need to buy a domain. yes, they're cheap, but it's a pointless expense and not something i'd use for anything other than a screenshot proving that it works.
The policy is the default one so i could technically scope it down a little as it's too broad.

2# Cluster public CIDRs

For the sake of simplicity i haven't used a bastion. if i ever expand the project i'll surely add it to make the cluster fully private but for now it's enough.

3# Kyverno

First and foremost i didn't want to increase the node number due to free tier limitations and i wanted to keep it relatively cheap.
With that in mind i pretty much maxed out my pods and had to keep kyverno in the minimal availability mode(or whatever the name was) thus 2 controllers are disabled.

The policy has Tlog and SCT ignored, similarly to 2# if i were to expand on this i'd just put in the pubkeys so that it doesn't fetch infinitely and doesn't need to be ignored.
KMS pubkey is hardcoded because of the additional endpoint cost, it works either way but this is just more cost efficient.
Validation scope is just the loadbalancer namespace but it'd be a better idea to exclude the necessary system pods and validate any other pod across the whole cluster(Not really needed for the current state of the project).


4# No monitoring

I could add it but there's no real traffic and i already did a monitoring project.

5# Issues(kinda)

LB and Kyverno stall on destroy so i need to destroy them with a script. Despite troubleshooting there's no logs or any logical links that point to the core of it, just a forever stuck finalizer.


6# Could (or wanted to) add:

- Cilium (added this at the very beginning but i'd either hit a pod limit or would need to replace the already existing cni so i just got rid of it)
- Argo/Flux
- Monitoring
- A custom operator 
