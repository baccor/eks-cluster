Natless kubernetes EKS cluster with an ALB(including WAF) and kyverno admission control(cosign + trivy from a gitlab pipeline) in terraform.

What it does:
The pipeline scans any(variable dependent) dockerhub image with trivy, if it passes it's signed with cosign using a KMS key and generates a trivy attestation, then it's pushed to an ECR for further deployment. 
Inside the cluster, Kyverno admissions the image based on the KMS key and an attestation. In this case the image is just a base nginx that gets served by an ALB(with WAF) but it could be anything really.

Here's a simplified graph:

![g](/img/r.png)
