# ADR-002: Terraform Remote Backend in Management Account

**Date:** June 2026
**Status:** Accepted
**Author:** Pietro

## Context

Terraform requires a backend to store state files. The default local backend
stores state on disk, which breaks team collaboration and CI/CD pipelines.

## Decision

S3 remote backend in the management account (`022079552075`):
- S3 bucket: `aparcar-terraform-state-022079552075` (eu-west-1)
- DynamoDB lock tables: one per member account (in each account)
- Per-environment state keys: `dev/terraform.tfstate`, `prod/terraform.tfstate`
- Versioning enabled, deletion protection on DynamoDB, SSE-S3 encryption

## Reasons

- Single S3 bucket for all state gives central visibility
- Management account is the most access-controlled account in the org
- Per-environment state keys prevent cross-environment state corruption
- DynamoDB locking prevents concurrent applies corrupting state

## Alternatives Considered

**State bucket per account**
Rejected: Requires managing multiple buckets. Cross-environment state
references become complex. Central visibility into all infrastructure state
is lost.

**Terraform Cloud**
Rejected: Additional cost and external dependency for a two-person team.
S3 backend provides equivalent functionality with no additional cost.

**Local state**
Rejected: Cannot be used in CI/CD. State is lost if the developer's machine
is unavailable. No locking means concurrent applies corrupt state.

## Consequences

- DynamoDB lock tables cannot be shared cross-account (AWS limitation)
- Each member account needs its own lock table
- GitHub Actions role in each account needs cross-account S3 access to the
  management account state bucket
- S3 bucket policy must explicitly allow each member account's CI role
