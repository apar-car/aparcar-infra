# AparCar — Closed Security Findings

Findings that have been fully remediated. Each entry documents the original
finding, the fix applied, and the date resolved.

---

## Phase 1 — Infrastructure Review

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

---

## Phase 2 — AppSync Application Testing

### Attack 1 — Unauthenticated access
**Finding:** AppSync API potentially accessible without authentication.
**Result:** PASS — AppSync returns UnauthorizedException for all unauthenticated
requests. WAF + AppSync API key auth working correctly.
**Tested:** July 2026

---

### Attack 2 — Authorization bypass
**Finding:** Business logic authorization could be bypassed by manipulating
exchangeId or userId parameters.
**Vectors tested:**

| Attack | Result |
|---|---|
| Unauthorized user confirms exchange | Blocked — `Not authorized to confirm this exchange` |
| Driver2 uses driver1 cancel reason | Blocked — `Invalid reason for driver2` |
| Driver1 confirms own exchange | Blocked — `Not authorized to confirm this exchange` |
| Rate unconfirmed exchange | Blocked — `Can only rate completed exchanges` |
| Driver1 requests own signal | Blocked — `Spot no longer available` |

**Result:** PASS — All five attack vectors blocked. Business logic authorization
enforced correctly at Lambda level. No bypass found.
**Tested:** July 2026

---

### Attack 3 — Input validation and injection
**Finding:** Input fields could accept malicious payloads including SQLi and XSS.
**Vectors tested:**

| Attack | Result | Verdict |
|---|---|---|
| SQLi in userId (`admin'--`) | Initially accepted — fixed | ✅ Closed |
| XSS in carDetails (`<script>alert(1)</script>`) | 403 WAFForbiddenException | ✅ WAF blocked |
| Extreme coordinates (lat: 999.99) | `Invalid coordinates` | ✅ |
| Negative radius (-500) | `radius_meters must be between 50 and 5000` | ✅ |
| Oversized radius (999999) | `radius_meters must be between 50 and 5000` | ✅ |
| Zero timer (0 minutes) | `Timer debe estar entre 1 y 30 minutos` | ✅ |
| Empty userId | `Missing required fields` | ✅ |

**SQLi finding fix:** Regex validation added to all handlers:
`re.match(r'^[a-zA-Z0-9_-]{1,64}$', user_id)`
Returns `Invalid userId format` for non-conforming inputs.
Re-tested post-fix — `admin'--` now returns `Invalid userId format`.
**Result:** PASS — All vectors blocked after fix applied.
**Resolved:** July 2026

---

### GraphQL introspection enabled — RESOLVED
**Resource:** AppSync API `ta7iib5itbarbpjuh5extujzlu`
**Finding:** Introspection queries returned full schema to authenticated API
key holders. An attacker with a valid API key could enumerate all mutations,
types, and field names via `__schema` and `__type` queries.
**Previous mitigation attempted:** WAF body inspection rule added but ineffective
— AppSync processes request body after WAF evaluation layer using wrong syntax
(`fields_to_match`, `text_transformations` instead of `field_to_match`,
`text_transformation`).
**Fix applied:** WAF rule `BlockGraphQLIntrospection` at priority 3 added with
correct Terraform syntax. Rule blocks requests containing `__schema` or `__type`
in the request body using `LOWERCASE` text transformation and `CONTAINS`
positional constraint with `oversize_handling = "MATCH"`.
**Verified:** Re-tested post-fix:
- `{ __schema { types { name } } }` → `403 WAFForbiddenException` ✅
- `{ __type(name: "Mutation") { fields { name } } }` → `403 WAFForbiddenException` ✅
- Normal mutations unaffected ✅
**Resolved:** July 2026

### Attack 5 — Information disclosure
**Finding:** API error responses could expose internal implementation details,
stack traces, or sensitive data.
**Vectors tested:**
- Non-existent mutation → GraphQL validation error (no internals exposed)
- Invalid exchangeId → `Exchange not found` (clean, no DynamoDB details)
- Null injection → GraphQL type validation error (no stack trace)

**Result:** PASS — No stack traces, AWS ARNs, table names, or internal paths
exposed. Minor: GraphQL validation errors reveal field existence but introspection
block mitigates schema enumeration risk.
**Tested:** July 2026