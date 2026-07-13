# AparCar — Closed Security Findings

Findings that have been fully remediated. Each entry documents the original
finding, the fix applied, and the date resolved.

---

### CI role had write access to Terraform state bucket
**Resource:** `arn:aws:s3:::aparcar-terraform-state-022079552075`
**Finding:** GitHubActions-TerraformCI role had s3:PutObject and s3:DeleteObject
on the state bucket. CI only needs to read state for planning — write access
could allow a compromised CI pipeline to corrupt Terraform state.
**Fix applied:** Removed s3:PutObject and s3:DeleteObject from CI role policy.
CI role now has s3:GetObject and s3:ListBucket only.
**Resolved:** July 2026

---

### CD OIDC scope too broad
**Resource:** `arn:aws:iam::945475931696:role/GitHubActions-TerraformCD`
**Finding:** CD role trust policy used StringLike wildcard
`repo:apar-car/aparcar-infra:*` allowing any branch or PR to assume the CD role.
A compromised feature branch could trigger infrastructure changes.
**Fix applied:** Restricted to `environment:production` sub claim using
StringEquals condition. GitHub `production` environment created. All CD workflow
jobs tagged with `environment: production`. Trust policy updated manually to
avoid bootstrap deadlock.
**Resolved:** July 2026

---

### verify=False on DynamoDB and Lambda boto3 clients
**Resource:** `src/look-signal-handler/handler.py`, `src/radius-matcher/handler.py`
**Finding:** boto3 clients used verify=False disabling TLS certificate verification
for VPC Interface Endpoint connections. Traffic was encrypted but not verified,
leaving a theoretical MITM attack surface within the VPC.
**Fix applied:** Amazon Root CA 1 bundle (AmazonRootCA1.pem) downloaded from
https://www.amazontrust.com/repository/ and bundled into both Lambda deployment
packages. boto3 now uses verify="/var/task/AmazonRootCA1.pem" for DynamoDB
Interface Endpoint (look-signal-handler) and Lambda Interface Endpoint
(radius-matcher).
**Resolved:** July 2026