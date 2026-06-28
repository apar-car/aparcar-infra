# ADR-006: Terraform Module Versioning Strategy

**Date:** June 2026
**Status:** Accepted
**Author:** Pietro

## Context

AparCar infrastructure uses reusable Terraform modules (`modules/vpc`,
`modules/lambda`). Without versioning, any change to a module instantly
affects all environments that reference it. This creates risk when fixing
a bug in dev accidentally breaks prod.

## Decision

All module references use Git tags via the GitHub source syntax:

```hcl
module "vpc" {
  source = "git::https://github.com/apar-car/aparcar-infra.git//modules/vpc?ref=COMMIT_HASH"
}
```

### Versioning Convention

Semantic versioning (SemVer): `vMAJOR.MINOR.PATCH`

- **PATCH** (`v1.0.1`): Bug fixes, security patches, no interface changes
- **MINOR** (`v1.1.0`): New optional variables, backward-compatible changes
- **MAJOR** (`v2.0.0`): Breaking changes — new required variables, removed outputs

### Release Process

1. Make changes to module on a feature branch
2. PR passes CI (Checkov + Trivy + terraform plan)
3. Merge to main
4. Create annotated tag: `git tag -a v1.1.0 -m "description"`
5. Push tag: `git push origin v1.1.0`
6. Update environment references to new tag in a separate PR
7. Apply per environment: dev first, staging, then prod

### Environment Version Pinning

| Environment | Update Policy |
|---|---|
| dev | Can use latest tag immediately after release |
| staging | Update after dev has run for 48 hours without issues |
| prod | Update after staging has run for 1 week without issues |

## Reasons

- Hard isolation: a module change in dev cannot accidentally affect prod
- Rollback: if a module update causes issues, revert the tag reference
- Audit trail: Git tags give a clear history of what changed and when
- Professional pattern used by all enterprise Terraform teams

## Alternatives Considered

**Local path references (`../../modules/vpc`)**
Rejected: No version isolation between environments. A module bug fix
immediately affects all environments simultaneously.

**Terraform Registry**
Rejected: Requires publishing modules publicly or using Terraform Cloud
private registry. Git tags achieve the same result with no additional cost
or infrastructure.

## Consequences

- Every module change requires a new Git tag before environments can use it
- `terraform init` requires GitHub authentication (handled via OIDC in CI
  and SSO token locally)
- Module development workflow has one extra step (tagging after merge)
- `source_dir` for Lambda code still uses local path — Lambda source code
  is environment-specific and not versioned via module tags
