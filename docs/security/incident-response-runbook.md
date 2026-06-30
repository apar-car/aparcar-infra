# AparCar Incident Response Runbook

**Owner:** Pietro
**Created:** June 2026
**Last reviewed:** June 2026
**Next review:** December 2026

---

## Severity Levels

| Level | Definition | Response Time |
|---|---|---|
| P1 Critical | Data breach, account compromise, prod down | Immediate |
| P2 High | Security finding in prod, significant degradation | 1 hour |
| P3 Medium | Security finding in dev/staging, minor degradation | 24 hours |
| P4 Low | Informational finding, no immediate risk | 1 week |

---

## Playbook 1 — AWS Account Compromise

**Triggers:**
- GuardDuty finding: UnauthorizedAccess or Recon
- CloudTrail shows API calls from unknown IP
- Billing alert fires unexpectedly

**Steps:**
1. Log into AWS management account immediately
2. Go to IAM Identity Center → Disable Pietro's user session
3. Go to CloudTrail → filter last 24h → identify all actions by compromised principal
4. Revoke all active SSO sessions: IAM Identity Center → Users → Pietro → Active sessions → Revoke all
5. Check all member accounts for new IAM roles, users, or policies created
6. Check for new EC2 instances, Lambda functions, or S3 buckets
7. Check billing for unexpected charges
8. Rotate IAM Identity Center password immediately
9. Review and rotate GitHub PAT
10. Document all findings in `/docs/security/incidents/YYYY-MM-DD-account-compromise.md`
11. Notify Emilio

**Recovery:**
- Re-enable access only after root cause is identified
- Enable MFA step-up for all SSO sessions
- Review and tighten SCPs if needed

---

## Playbook 2 — Terraform State File Compromised

**Triggers:**
- Unexpected CloudTrail S3 GetObject on state bucket from unknown principal
- Terraform plan shows unexpected resource deletions
- DynamoDB lock table shows unexpected lock entries

**Steps:**
1. Immediately revoke S3 bucket policy — remove all cross-account access
2. Check CloudTrail for who accessed the state file and when
3. Check if state file was modified: S3 → bucket → versions → compare timestamps
4. If state was modified: restore previous version from S3 versioning
5. Run `terraform plan` locally to compare state vs real infrastructure
6. If infrastructure was changed outside Terraform: run `terraform apply` to reconcile
7. Re-add cross-account bucket policy only for CI/CD roles
8. Document findings

**Recovery:**
- Rotate `GitHubActions-TerraformCI` and `GitHubActions-TerraformCD` roles
- Review GitHub Actions logs for unauthorized workflow runs

---

## Playbook 3 — Lambda Function Abuse

**Triggers:**
- DLQ has unexpected messages
- CloudWatch shows Lambda invocations from unexpected sources
- GuardDuty finding on Lambda execution role
- Billing spike from unexpected Lambda invocations

**Steps:**
1. Go to Lambda → aparcar-dev-leave-signal-handler → Throttle function (set concurrency to 0)
2. Check CloudWatch logs for the invocation pattern
3. Check AppSync logs for the source of the requests
4. Check if the Lambda execution role was used for anything outside its scope
5. Check DynamoDB for unexpected parking signal entries
6. If abuse confirmed: rotate AppSync API key immediately
7. Review Lambda resource policy for unexpected principals
8. Re-enable Lambda only after root cause is identified

**Recovery:**
- Add rate limiting to AppSync API
- Add input validation checks to Lambda
- Consider adding WAF if not already in place

---

## Playbook 4 — GuardDuty Critical Finding

**Triggers:**
- GuardDuty severity 7.0+ finding in any account
- Slack alert from GuardDuty EventBridge rule

**Steps:**
1. Open GuardDuty console → identify affected resource and finding type
2. Check CloudTrail for the specific API calls that triggered the finding
3. Isolate the affected resource if possible (revoke role, stop function)
4. Determine if finding is a true positive or false positive
5. If true positive: follow relevant playbook above
6. If false positive: suppress the finding with justification documented
7. Document in `/docs/security/incidents/`

---

## Playbook 5 — CI/CD Pipeline Compromise

**Triggers:**
- Unexpected `terraform apply` in Actions logs
- GitHub audit log shows workflow run from unexpected actor
- Infrastructure changed without a corresponding PR

**Steps:**
1. Go to GitHub → Settings → Actions → Disable Actions immediately
2. Check GitHub audit log for unauthorized workflow triggers
3. Check AWS CloudTrail for API calls from `GitHubActions-TerraformCD` role
4. Revoke `GitHubActions-TerraformCD` role in AWS IAM
5. Check all PRs merged in last 24h for suspicious code
6. Review Terraform state for unexpected changes
7. Re-enable Actions only after root cause identified
8. Rotate GitHub PAT

---

## Playbook 6 — CD Pipeline Bootstrap Deadlock

**Triggers:**
- CD role cannot plan because it lacks a permission needed to read its own resources
- Chicken-and-egg: can't apply the fix because can't plan

**Steps:**
1. Identify the missing permission from the AccessDenied error
2. Manually add it via CLI using aparcar-management or aparcar-dev profile
3. Trigger a new CD run — it will now plan successfully
4. CD applies the Terraform code which overwrites the manual change with the correct version
5. Verify the manual change and Terraform code are identical post-apply

**Prevention:**
- When adding new AWS services to the github-oidc module, always add the required
  read permissions (Get*, List*, Describe*) before adding the write permissions
- Test new module changes locally with terraform plan before merging

## Communication Template

For any P1 or P2 incident, notify Emilio within 30 minutes:


Subject: AparCar Security Incident - [P1/P2] - [Short description]

Emilio,

We have a [severity] security incident affecting [component].

What happened: [Brief description]  
Current status: [Contained / Under investigation / Resolved]  
User impact: [None / Potential data exposure / etc]  
Next update: [Time]

Pietro



---

## Post-Incident Documentation Template

Create `/docs/security/incidents/YYYY-MM-DD-[short-name].md`:

```markdown
# Incident: [Short name]
Date: YYYY-MM-DD
Severity: P1/P2/P3/P4
Duration: HH:MM
Affected components: [list]

## Timeline
- HH:MM - [event]
- HH:MM - [event]

## Root cause
[What caused the incident]

## Impact
[What was affected, any data exposure]

## Resolution
[How it was resolved]

## Prevention
[What changes were made to prevent recurrence]
