# Secret Rotation Policy

**Owner:** Pietro (Cloud Infrastructure Lead)
**Created:** June 2026
**Next full review:** December 2026

---

## Policy Statement

No long-lived credentials may exist in AparCar infrastructure without a
documented rotation schedule. All credentials are rotated before expiry,
not after. Rotation is tracked in this document.

---

## Credential Inventory

### AWS Root Account — Management (022079552075)
**Type:** Password + MFA
**Owner:** Pietro
**Storage:** Password manager (never written down, never shared)
**MFA:** Authenticator app
**Rotation schedule:** Yearly or immediately on suspected compromise
**Last rotated:** June 2026
**Next rotation:** June 2027
**Notes:** Root is never used for day-to-day operations. Only used for
initial org setup. MFA required for all root actions.

---

### IAM Identity Center — Pietro (pietro-admin)
**Type:** SSO password + MFA
**Owner:** Pietro
**Storage:** Password manager
**MFA:** Authenticator app (registered June 2026)
**Rotation schedule:** 90 days or immediately on suspected compromise
**Last rotated:** June 2026
**Next rotation:** September 2026
**Notes:** This is the primary access method for all AWS accounts.
Temporary credentials issued per session (max 1 hour). No long-lived
access keys exist.

---

### GitHub PAT — wazuh-server CLI access
**Type:** Personal Access Token
**Owner:** Pietro (CyberBass051)
**Storage:** GitHub CLI credential store on wazuh-server
**Scopes:** `repo`, `read:org`, `workflow` (minimum required)
**Expiry:** 90 days from creation
**Created:** June 24 2026
**Expires:** September 22 2026
**Rotation schedule:** Every 90 days, before expiry
**Notes:** Used for `gh` CLI operations on wazuh-server. Must be renewed
before September 22 2026 — this coincides with the Atlantic crossing.
Set a calendar reminder for September 15 2026.
**CRITICAL:** Previous token (created June 24 2026, expires July 24 2026)
was over-privileged with admin and delete scopes. Revoked June 2026 and
replaced with minimum required scopes.

---

### Namecheap — Domain Registrar (apar-car.com)
**Type:** Account password + 2FA
**Owner:** Pietro
**Storage:** Password manager
**2FA:** Enabled
**Rotation schedule:** Yearly
**Last rotated:** 2026 (registration)
**Next rotation:** June 2027
**Notes:** Domain auto-renewal must be enabled. Verify renewal settings
before any extended period without internet access (ship crossings).
Expiry of apar-car.com would break the entire product.

---

### AppSync API Key (not yet created)
**Type:** API Key
**Owner:** Pietro
**Storage:** AWS Secrets Manager (when created)
**Rotation schedule:** Every 365 days (AWS enforced maximum)
**Notes:** Will be created when AppSync is deployed. Key must be stored
in Secrets Manager, never in code or environment variables. Emilio's
frontend will retrieve it via Amplify configuration, not hardcoded.

---

### Pinpoint Credentials (not yet created)
**Type:** IAM role-based (no static credentials)
**Owner:** Pietro
**Notes:** Pinpoint will be accessed via Lambda execution role, not
static credentials. No rotation required — temporary credentials only.

---

## Rotation Procedures

### Rotating a GitHub PAT
1. Create new token at https://github.com/settings/tokens/new
2. Scopes: `repo`, `read:org`, `workflow` only
3. Expiration: 90 days
4. Update on wazuh-server: `gh auth login --with-token`
5. Verify CI pipeline still works: trigger a test PR
6. Revoke old token immediately after verification
7. Update this document with new expiry date

### Rotating AWS SSO Password
1. Log into SSO portal
2. Go to profile → Change password
3. Update password manager
4. Update this document

### Rotating Namecheap Password
1. Log into Namecheap
2. Go to Profile → Change password
3. Verify 2FA still works after rotation
4. Update password manager
5. Update this document

---

## Compromise Response

If any credential is suspected compromised:
1. Revoke immediately — do not wait to investigate first
2. Check CloudTrail for unauthorized API calls in the last 30 days
3. Check GitHub audit log for unauthorized repo actions
4. Rotate all credentials that share the same access scope
5. Document the incident in `/docs/security/incidents/`
6. Notify Emilio if any customer data may have been exposed

---

## Upcoming Rotation Calendar

| Credential | Rotation Due | Risk if Missed |
|---|---|---|
| GitHub PAT (wazuh-server) | September 22 2026 | CI/CD breaks |
| IAM Identity Center | September 2026 | AWS console access |
| AWS Root password | June 2027 | Emergency access only |
| Namecheap password | June 2027 | Domain management |

---

## Policy Rules

1. No credential may have broader scope than required for its function
2. All credentials must be stored in a password manager or AWS Secrets Manager
3. No credentials in code, environment variables, or chat messages
4. All credentials must have MFA or expiry — no indefinite static credentials
5. Rotation must be completed before expiry, not after
6. Any credential with `delete` or `admin` scope requires explicit justification
