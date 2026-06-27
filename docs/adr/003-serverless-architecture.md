# ADR-003: Serverless Architecture for AparCar Backend

**Date:** June 2026
**Status:** Accepted
**Author:** Pietro

## Context

AparCar needs a backend that handles real-time parking signals between drivers.
The pilot targets 100-500 users in Fuengirola with a budget of €25-30/month.

The frontend was initially built against a Socket.io/Express server (server.js)
running in-memory state. This approach cannot scale and loses all data on restart.

## Decision

Serverless AWS stack:
- **AppSync** — GraphQL API with real-time subscriptions (replaces Socket.io)
- **Lambda** — Python 3.12 functions for business logic
- **EventBridge** — Fan-out of parking signals to multiple consumers
- **DynamoDB** — Persistent parking signal storage with TTL
- **ElastiCache Redis** — GEOSEARCH for radius-based driver matching
- **Pinpoint** — Push notifications to looking drivers

## Reasons

- Cost: near-zero at pilot scale (Lambda free tier covers 1M requests/month)
- No server management: no EC2, no patching, no capacity planning
- AppSync subscriptions provide identical real-time behavior to Socket.io
  but are managed, scalable, and integrate natively with AWS IAM
- EventBridge fan-out allows adding new consumers (analytics, logging)
  without changing the leave-signal Lambda
- DynamoDB TTL automatically expires old parking signals

## Alternatives Considered

**Keep Socket.io on ECS Fargate**
Rejected: Fargate costs ~€15-20/month minimum before a single user.
Blows the pilot budget. Requires container management. In-memory state
means data loss on container restart.

**API Gateway + WebSocket**
Rejected: More complex connection management than AppSync. No native
GraphQL support. AppSync subscriptions are simpler to implement and
maintain for a two-person team.

**EC2 with Express**
Rejected: Fixed cost regardless of traffic. Requires OS patching.
Overkill for pilot scale.

## Consequences

- Frontend must migrate from Socket.io client to AWS Amplify AppSync client
- socketAdapter.js must be rewritten (documented in Emilio's migration guide)
- ElastiCache Redis is the only fixed cost (~€13/month) before pilot launch
- Lambda functions split into VPC (Redis access) and non-VPC (Pinpoint)
  to avoid NAT Gateway cost in dev
