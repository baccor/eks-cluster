waf responses: 

![waf](/img/w.png)

![waf2](/img/a.png)

for kyverno i did a dry run with both signed/attested nginx and an unsigned one.
![kyvernosigned](/img/k.png)
![kyvernounisgned](/img/u.png)


as for the pipeline, it exits if any high/critical gets discovered:
(exit code's in the yaml so it exits right after)
![p](/img/p.png)

otherwise you get:
![s](/img/s.png)

and this gets pushed to the ecr: 
![ecr](/img/e.png)
