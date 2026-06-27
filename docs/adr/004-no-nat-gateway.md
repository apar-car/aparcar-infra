# ADR-004: No NAT Gateway in Any Environment (Pre-Launch)

**Date:** June 2026
**Status:** Accepted
**Author:** Pietro

## Context

Lambda functions inside a VPC need outbound internet access to call AWS
managed services (Pinpoint, AppSync). The standard solution is a NAT Gateway.

A NAT Gateway in eu-west-1 costs ~€32/month plus data transfer fees.
The total pilot budget is €25-30/month. ElastiCache Redis already
consumes ~€13/month of that budget.

## Decision

No NAT Gateway in any environment (dev, staging, prod) until post-launch
traffic data justifies the cost. Instead:
- VPC Gateway Endpoints for DynamoDB and S3 (free, all environments)
- Lambda functions that need Redis run inside the VPC (private subnets)
- Lambda functions that need Pinpoint run outside the VPC (free internet access)
- NAT Gateway added only when a specific technical requirement cannot be
  met without it, with explicit cost approval

## Lambda Split

| Function | VPC | Reason |
|---|---|---|
| leave-signal-handler | Outside VPC | Only needs DynamoDB + EventBridge |
| look-signal-handler | Inside VPC | Needs Redis GEOSEARCH |
| notification-dispatcher | Outside VPC | Only needs Pinpoint |

## Reasons

- NAT Gateway alone exceeds the entire pilot budget
- VPC Gateway Endpoints provide free access to DynamoDB and S3
- Splitting Lambda by dependency avoids forcing all functions into VPC
- Post-launch traffic data should drive the decision to add NAT, not assumptions
- The `enable_nat_gateway` variable in the VPC module allows adding it
  per environment without code changes when needed

## Alternatives Considered

**NAT Gateway in prod only**
Rejected: Prod and dev would have different network architectures, making
it harder to reproduce prod issues in dev. The Lambda split pattern works
equally well in all environments without NAT.

**NAT Gateway in all environments**
Rejected: ~€32/month per environment = ~€96/month across dev, staging, prod
before a single user exists. Unsustainable at pilot stage.

**Pinpoint Interface VPC Endpoint**
Rejected: ~€7-8/month per AZ = €14-16/month for two AZs. More expensive
than a NAT Gateway and still adds fixed cost before launch.

## Consequences

- No outbound internet from private subnets in any environment
- All Lambdas must be explicitly designed for their network context
- Future services that require outbound internet (webhooks, third-party APIs)
  will need either a NAT Gateway or Interface VPC Endpoints
- This decision is revisited when monthly AWS spend has headroom or when
  a specific use case requires outbound internet from private subnets
