## Overview

This document summarizes the technical and organizational measures used by {{company.name}} to protect personal data processed through Frontman.

These measures are designed for a small B2B SaaS startup and may evolve as Frontman grows.

## Access Control

- Access to production systems is limited to authorized personnel with a business need.
- Administrative access is restricted and reviewed when personnel or responsibilities change.
- Authentication is required for administrative systems.
- Access to decrypted API keys and sensitive credentials is limited to authorized personnel and systems where necessary to provide, secure, maintain, troubleshoot, or support the service.

## System and Infrastructure Security

- Hosted Frontman infrastructure runs in the European Union using Hetzner.
- Network access is limited to required services and administrative paths.
- Security updates are applied as part of regular maintenance.
- Service components are monitored for availability, errors, and abnormal behavior.

## Encryption

- Data is encrypted in transit using TLS where supported.
- Sensitive provider credentials and API keys are encrypted server-side using application-level encryption.
- Secrets are not intended to be stored in plaintext in source code or logs.

## Logging and Monitoring

- Logs and diagnostics are used to operate, secure, troubleshoot, and improve the service.
- Sentry is used for error monitoring and diagnostics.
- Diagnostic filtering is configured to reduce the risk of collecting secrets, API keys, or Customer Content in error payloads.
- Because filtering can be imperfect, logs and diagnostics are handled as potentially sensitive.

## Backup and Recovery

- Backups are maintained to support recovery from operational incidents.
- Deleted Customer Content is removed from active systems when deleted by the user.
- Backup copies may retain deleted data for up to 3 months before automatic backup expiry.

## Data Minimization and Retention

- Frontman processes Customer Content as needed to provide the hosted service and user-requested agentic workflows.
- Conversation and task history is retained until user deletion.
- Billing, tax, security, and support records may be retained for legal, operational, or dispute-resolution purposes.

## Development and Change Management

- Changes are developed and reviewed through normal source-control workflows.
- Production changes are deployed through controlled operational processes.
- Frontman is designed for development workflows and does not deploy customer code to production.

## Incident Response

- Security and privacy incidents are investigated when detected or reported.
- We assess incident scope, affected data, and required mitigation.
- Where legally required, we notify affected customers, authorities, or data subjects within applicable deadlines.

## Personnel and Confidentiality

- Personnel with access to production systems or personal data are required to keep customer and service data confidential.
- Access is granted based on operational need.
- Personnel are expected to follow internal security and data handling practices.

## Subprocessor Management

- Subprocessors are selected based on service need, security posture, and legal suitability.
- Current subprocessors are listed at [Subprocessors](/subprocessors/).
- Material subprocessor changes are handled under the [Data Processing Agreement](/dpa/).

## Customer Responsibilities

Customers remain responsible for:

- deciding what Customer Content to process through Frontman;
- reviewing and testing generated code changes;
- managing provider credentials and provider-side permissions;
- configuring AI provider accounts and data processing settings;
- maintaining backups and source-control practices for their own projects;
- ensuring their own use of Frontman complies with applicable law.

_Last updated: May 5, 2026_
