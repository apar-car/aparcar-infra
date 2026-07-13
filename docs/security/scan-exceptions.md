# Security Scan Exceptions

This document records every Checkov and Trivy exception in the AparCar infrastructure,
with justification, risk acceptance, and review date.

All exceptions require explicit approval before renewal.
Owner: Pietro (Cloud Infrastructure Lead)
Last reviewed: June 2026
Next review: December 2026

---

## Checkov Exceptions

### CKV_AWS_144 — S3 Cross-Region Replication
**Resource:** `aparcar-terraform-state-022079552075`
**Reason:** State bucket is in a single region by design. Cross-region replication adds
cost and complexity with no operational benefit at pilot stage. State is protected by
versioning and deletion protection instead.
**Risk:** Low. State loss in a regional outage would require manual recovery but no
user data is stored here.
**Review:** Revisit when operating in multiple regions.

---

### CKV_AWS_18 — S3 Access Logging
**Resource:** `aparcar-terraform-state-022079552075`
**Reason:** Access logging on the state bucket generates additional S3 costs and
log volume. CloudTrail org-level logging already captures all S3 API calls.
**Risk:** Low. CloudTrail provides equivalent audit coverage.
**Review:** December 2026.

---

### CKV_AWS_119 — DynamoDB KMS Customer Managed Key
**Resource:** `aparcar-terraform-locks` (management account)
**Reason:** Terraform lock table contains no sensitive data — only lock metadata.
AWS managed encryption (SSE) is sufficient. CMK adds operational risk: if the key
is deleted or disabled, the lock table becomes inaccessible and Terraform operations
fail across all environments.
**Risk:** Low. Lock table data is ephemeral and non-sensitive.
**Review:** December 2026.

---

### CKV2_AWS_62 — S3 Event Notifications
**Resource:** `aparcar-terraform-state-022079552075`
**Reason:** Event notifications on the state bucket are not required. State changes
are tracked via DynamoDB locking and S3 versioning. No downstream consumer needs
real-time state change events.
**Risk:** None.
**Review:** December 2026.

---

### CKV2_AWS_61 — S3 Lifecycle Configuration
**Resource:** `aparcar-terraform-state-022079552075`
**Reason:** State bucket intentionally retains all versions for full infrastructure
history and rollback capability. A lifecycle policy that expires old versions would
remove the ability to roll back to previous infrastructure states.
**Risk:** Low. Storage costs will grow over time but remain negligible at pilot scale.
**Review:** When state file storage exceeds €5/month.

---

### CKV_AWS_145 — S3 KMS Customer Managed Key
**Resource:** `aparcar-terraform-state-022079552075`
**Reason:** Same reasoning as CKV_AWS_119. AWS managed SSE-S3 (AES256) is enabled.
CMK adds operational risk for state storage — a deleted key makes the entire state
unrecoverable without AWS support intervention.
**Risk:** Low. SSE-S3 provides encryption at rest. Access is controlled via IAM and
bucket policy.
**Review:** December 2026.

---

### CKV_AWS_158 — CloudWatch Log Group KMS Encryption
**Resource:** `module.vpc.aws_cloudwatch_log_group.vpc_flow_logs`
**Reason:** VPC flow logs contain network metadata (IPs, ports, protocols) but no
application-level sensitive data. AWS managed encryption is sufficient. CMK adds
~$1/month per key plus API call costs at pilot stage.
**Risk:** Low. Log data is encrypted at rest with AWS managed keys.
**Review:** When handling PII in log data or when compliance requires CMK.

---

### CKV_AWS_355 — IAM Wildcard Resource for Restrictable Actions
**Resource:** `module.vpc.aws_iam_role_policy.vpc_flow_logs`,
`module.leave_signal_handler.aws_iam_role_policy.lambda`
**Reason:** `ec2:DescribeNetworkInterfaces` is a list operation that AWS does not
support resource-level restrictions on. This is an AWS API limitation, not a
misconfiguration. See AWS documentation:
https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_DescribeNetworkInterfaces.html
**Risk:** Low. The action is read-only and scoped to the Lambda execution role.
**Review:** When AWS adds resource-level support for this action.

---

### CKV_AWS_50 — Lambda X-Ray Tracing
**Resource:** `module.leave_signal_handler.aws_lambda_function.main`
**Reason:** X-Ray adds per-trace costs and operational complexity. CloudWatch
structured JSON logging provides sufficient observability at pilot scale.
CloudWatch Insights can query logs without X-Ray overhead.
**Risk:** Low. Distributed tracing gaps may make debugging harder at scale.
**Review:** When daily active users exceed 1,000 or when cross-service latency
becomes a measurable issue.

---

### CKV_AWS_272 — Lambda Code Signing
**Resource:** `module.leave_signal_handler.aws_lambda_function.main`
**Reason:** Code signing requires AWS Signer setup and signing profile management.
At pilot stage with a single developer deploying via GitHub Actions OIDC, the
CI/CD pipeline itself provides deployment integrity guarantees.
**Risk:** Low. Code provenance is tracked via Git commits and GitHub Actions logs.
**Review:** When the team grows beyond 3 engineers or when compliance requires it.

---

### CKV2_AWS_73 — SQS KMS Customer Managed Key
**Resource:** `module.leave_signal_handler.aws_sqs_queue.dlq`
**Reason:** DLQ contains failed Lambda invocation payloads for debugging. AWS
managed SQS encryption (SSE-SQS) is enabled. CMK adds cost and the operational
risk that a deleted key makes DLQ messages permanently unrecoverable.
**Risk:** Low. DLQ data is ephemeral debug data, not persistent user data.
**Review:** If DLQ begins storing sensitive PII from Lambda payloads.

---

### CKV_AWS_173 — Lambda Environment Variable KMS Encryption
**Resource:** `module.leave_signal_handler.aws_lambda_function.main`
**Reason:** Lambda environment variables contain only resource names
(`PARKING_TABLE`, `EVENT_BUS_NAME`) — not secrets or sensitive data. All actual
secrets will be stored in AWS Secrets Manager, not environment variables.
**Risk:** None. No sensitive data in environment variables by policy.
**Review:** If any secret or PII is ever added to environment variables (which
is explicitly prohibited by this project's security policy).

### CKV_AWS_288 — IAM Data Exfiltration
**Resource:** `module.github_oidc.aws_iam_role_policy.ci`
**Reason:** Flags s3:GetObject + s3:PutObject as potential data exfiltration. Resource is
scoped to the Terraform state bucket only — not a wildcard. CI role cannot access any
other S3 bucket. False positive.
**Risk:** None. S3 actions are scoped to `aparcar-terraform-state-022079552075` only.
**Review:** December 2026.

---

### CKV_AWS_287 — IAM Credentials Exposure
**Resource:** `module.github_oidc.aws_iam_role_policy.ci` and `.cd`
**Reason:** Flags iam:Get* and iam:List* as potential credential exposure. These are
read-only actions required for terraform plan to read existing IAM resources.
No credential-creating actions (iam:CreateAccessKey, iam:CreateLoginProfile) are included.
**Risk:** Low. Read-only IAM actions cannot expose or create credentials.
**Review:** December 2026.

---

### CKV_AWS_290 — Write Access Without Constraints
**Resource:** `module.github_oidc.aws_iam_role_policy.cd`
**Reason:** CD role requires write access to EC2, CloudWatch, ElastiCache, and AppSync
to manage AparCar infrastructure. Some of these services do not support resource-level
restrictions on all actions (e.g. EC2 Describe* actions). The CD role is scoped to
main branch only via OIDC trust policy and cannot be assumed by PRs or human users.
**Risk:** Accepted. CD role is the minimum required to manage AparCar infrastructure
via Terraform. Mitigated by OIDC trust policy scoping and branch protection on main.
**Review:** December 2026.

### CKV2_AWS_33 — AppSync WAF Protection
**Resource:** `module.appsync.aws_appsync_graphql_api.main`
**Reason:** WAF requires AppSync to be live with real traffic patterns before
rules can be tuned correctly. Adding WAF with misconfigured rules would block
legitimate traffic. WAF will be added pre-launch per the pentest plan.
**Risk:** Accepted for dev environment. WAF is mandatory before prod launch.
**Review:** When AppSync goes to production.

### CKV2_AWS_40 — Full IAM Privileges (CDRoleIAMBootstrap)
**Resource:** `aws_iam_role_policy.cd_iam_bootstrap`
**Reason:** CD role requires iam:* scoped to GitHubActions-TerraformCI and
GitHubActions-TerraformCD roles only. This breaks the bootstrap deadlock where
any new AWS service added to the github-oidc module would require manual
break-glass before CI could plan. Resource scope is two specific role ARNs,
not wildcard. The CD role is already trusted with main branch OIDC — full IAM
on these two roles does not materially increase the attack surface.
**Risk:** Accepted. Mitigated by OIDC trust policy scoping to main branch only.
**Review:** December 2026.

### CKV_AWS_134 — ElastiCache Automatic Backup
**Resource:** `module.elasticache.aws_elasticache_cluster.main`
**Reason:** Redis is used exclusively as a geospatial cache, not a database. All data
is ephemeral — looking driver positions with a 30-minute TTL. If the cluster is lost,
data regenerates automatically as drivers re-register. Backup adds ~€1-2/month with
zero recovery value for a cache workload.
**Risk:** None. Loss of Redis data causes a brief gap in radius matching (seconds to
minutes) until drivers re-register. No user data is lost.
**Review:** December 2026. Reassess if Redis is used to store non-ephemeral data.

### CKV_AWS_31 — ElastiCache AUTH token
**Resource:** `module.elasticache.aws_elasticache_replication_group.main`
**Reason:** Dev environment. Network-level access control via SG restricts Redis
to Lambda SG only. AUTH token deferred to prod where it will be stored in
Secrets Manager. Risk accepted for dev pilot.
**Review:** Before prod launch.

### CKV_AWS_191 — ElastiCache customer-managed KMS key
**Resource:** `module.elasticache.aws_elasticache_replication_group.main`
**Reason:** Redis holds ephemeral geospatial cache data with 30-minute TTL.
AWS-managed encryption at rest provides adequate protection for this data
classification. CMK adds operational complexity (key rotation, access policies)
with no meaningful security improvement for cache data at pilot scale.
**Review:** December 2026.

### CKV2_AWS_50 — ElastiCache Multi-AZ failover
**Resource:** `module.elasticache.aws_elasticache_replication_group.main`
**Reason:** Single-node dev cluster. Multi-AZ requires minimum 2 nodes (~€26/month
additional cost). Redis holds ephemeral cache data — downtime causes a brief gap
in radius matching until drivers re-register. Acceptable for pilot.
**Review:** Before prod launch.

---

## Trivy Exceptions

### AVD-AWS-0132 — S3 KMS Customer Managed Key
**Resource:** `aparcar-terraform-state-022079552075`
**Reason:** Same as CKV_AWS_145 above. Trivy and Checkov flag the same
underlying issue with different identifiers.
**Risk:** Low. See CKV_AWS_145.
**Review:** December 2026.

---

### AVD-AWS-0135 — SQS KMS Customer Managed Key
**Resource:** `module.leave_signal_handler.aws_sqs_queue.dlq`
**Reason:** Same as CKV2_AWS_73 above.
**Risk:** Low. See CKV2_AWS_73.
**Review:** December 2026.

### AVD-AWS-0136 — SNS Topic Not Using Customer Managed Key
**Resource:** `module.cloudwatch_alarms.aws_sns_topic.alarms`
**Reason:** CloudWatch alarm notifications topic. A CMK adds $1/month with
no meaningful security benefit for internal alarm routing. AWS managed key
provides encryption at rest. Will revisit if compliance requires CMK for
all SNS topics.
**Risk:** Low. Topic contains only operational alarm metadata, no PII or
sensitive data.
**Review:** December 2026.

---

## Unresolved Findings

### WAF rate limit evaluation delay
**Resource:** WAF rule `RateLimitPerIP` on `aparcar-dev-web-acl`
**Finding:** WAF rate-based rules evaluate every 30 seconds — burst traffic
can exceed the threshold before blocking kicks in. Tested: 60 sequential
requests all passed; parallel burst of 115 requests all passed.
**Root cause:** AWS WAF rate-based rules have a documented 30-second evaluation
window. Sequential requests (~500ms each) spread across the window and never
trigger the counter. Parallel bursts hit all at once but WAF needs one full
evaluation cycle before blocking starts.
**Risk:** Low for pilot — 50 users, API key not public. Sustained attack
(>50 req over 5 minutes) will be blocked after first 30-second window.
**Prod fix:** Add AppSync built-in throttling as primary control. Lower WAF
threshold to 30 req/5min as secondary. Consider AWS Shield Advanced for
sustained DDoS protection.
**Review:** Before prod launch.
---

## Exception Policy

1. Every exception must be documented here before being added to the skip list.
2. Exceptions are reviewed every 6 months or when the project reaches a new
   scale milestone (pilot launch, 1K users, 10K users).
3. KMS exceptions are reviewed when monthly AWS spend exceeds €50.
4. Any exception covering PII or user data requires explicit re-approval.
5. No exception may be added to silence a check without understanding why
   the check exists.
