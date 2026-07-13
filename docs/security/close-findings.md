# Security Close Findings

This document records every close-finding detected during pentesting phase in the AparCar infrastructure,
with finding, fix applied, and resolved date.

Owner: Pietro (Cloud Infrastructure Lead)
Last reviewed: July 2026

---

### OIDC CD role scope — RESOLVED
**Finding:** CD role trust policy used StringLike wildcard allowing any branch
to assume the CD role.
**Fix applied:** Restricted to `environment:production` sub claim. GitHub
environment created. All CD workflow jobs tagged with `environment: production`.
**Resolved:** July 2026
