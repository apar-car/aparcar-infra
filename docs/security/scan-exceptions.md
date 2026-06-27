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

---

## Exception Policy

1. Every exception must be documented here before being added to the skip list.
2. Exceptions are reviewed every 6 months or when the project reaches a new
   scale milestone (pilot launch, 1K users, 10K users).
3. KMS exceptions are reviewed when monthly AWS spend exceeds €50.
4. Any exception covering PII or user data requires explicit re-approval.
5. No exception may be added to silence a check without understanding why
   the check exists.
