# ADR-005: GitHub Actions OIDC for CI/CD Authentication

**Date:** June 2026
**Status:** Accepted
**Author:** Pietro

## Context

The CI/CD pipeline (GitHub Actions) needs AWS credentials to run
`terraform plan` and eventually `terraform apply`. The naive approach
is to store AWS access keys as GitHub secrets.

## Decision

Use GitHub Actions OIDC (OpenID Connect) to authenticate to AWS without
storing any long-lived credentials:
- AWS IAM OIDC provider: `token.actions.githubusercontent.com`
- IAM role: `GitHubActions-TerraformCI` in each member account
- Trust policy scoped to `apar-car/aparcar-infra` repository only
- Temporary credentials issued per workflow run (max 1 hour)

## Reasons

- No long-lived credentials stored anywhere (no GitHub secrets with AWS keys)
- Credentials expire automatically after each workflow run
- Trust policy scoped to specific repo — other repos cannot assume the role
- Follows AWS and GitHub security best practices
- Credential compromise limited to a single workflow run window

## Alternatives Considered

**AWS access keys stored as GitHub secrets**
Rejected: Long-lived credentials. If GitHub is compromised or secrets are
accidentally logged, credentials remain valid until manually rotated.
Rotation requires manual intervention.

**Self-hosted GitHub Actions runner in AWS**
Rejected: Requires EC2 instance management and additional cost. OIDC
achieves the same security posture with less operational overhead.

## Consequences

- `terraform apply` must run locally (SSO) or via a separate CD workflow
- OIDC provider must be created in each AWS account that CI deploys to
- Role permissions must be explicitly defined (no AdministratorAccess)
- Plan-only permissions for CI reduce blast radius of a compromised workflow
