# ADR-001: Multi-Account AWS Organization Structure

**Date:** June 2026
**Status:** Accepted
**Author:** Pietro

## Context

AparCar needs a cloud infrastructure that is secure, cost-controlled, and
professional enough to serve as both a production system and a portfolio
demonstration of DevSecOps practices.

The simplest option is a single AWS account with environment separation via
naming conventions (e.g. `aparcar-dev-*`, `aparcar-prod-*`). This is the
most common pattern in small startups.

## Decision

Use AWS Organizations with a multi-account structure:
- `Apar-car` (management) — org management only, no application resources
- `aparcar-dev` — development environment
- `aparcar-staging` — staging environment
- `aparcar-prod` — production environment

OUs: `Workloads/Dev`, `Workloads/Staging`, `Workloads/Prod`

Access via IAM Identity Center (SSO) only. No IAM users in any account.

## Reasons

- Hard blast-radius isolation: a runaway Lambda in dev cannot affect prod
- Separate billing per environment — cost attribution is exact
- SCPs can be applied per OU (e.g. deny manual deploys to prod)
- IAM Identity Center provides temporary credentials with no long-lived keys
- Matches AWS Well-Architected Framework recommendations
- Demonstrates enterprise-grade security posture for portfolio

## Alternatives Considered

**Single account with naming conventions**
Rejected: No hard isolation between environments. A misconfigured IAM policy
in dev could affect prod resources. Billing attribution requires tagging
discipline which is error-prone.

**Two accounts (dev + prod)**
Rejected: No staging environment for pre-production validation. Staging is
critical for testing the AppSync → Lambda → Redis flow before real users.

## Consequences

- Higher initial setup complexity (SSO, Organizations, cross-account IAM)
- Cross-account S3 access for Terraform state requires explicit bucket policies
- DynamoDB lock tables must exist per account (cannot share cross-account)
- All worth the isolation and security benefits
