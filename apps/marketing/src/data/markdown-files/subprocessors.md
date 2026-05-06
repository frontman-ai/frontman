## Overview

This page lists subprocessors and service providers used by {{company.name}} to provide, secure, analyze, bill, and support Frontman.

Capitalized terms used here have the meanings given in the [Data Processing Agreement](/dpa/).

## Current Subprocessors

### Hetzner

Purpose: hosting, compute, networking, database, storage, and infrastructure services.  
Processing location: European Union.  
Data categories: account data, Customer Content, hosted history, logs, credentials in encrypted form, and service metadata.

### Stripe / Link

Purpose: payments, billing, invoices, receipts, tax handling, fraud prevention, disputes, subscription administration, and transaction-level support, including Stripe Managed Payments where enabled.  
Processing location: global, depending on customer location and Stripe services used.  
Data categories: billing contact data, business information, tax data, transaction data, subscription status, payment metadata, fraud-prevention data, and support data related to transactions.

### Sentry

Purpose: error monitoring, diagnostics, performance monitoring, and service reliability.  
Processing location: global or region configured by provider.  
Data categories: error messages, stack traces, device and browser information, IP address, user identifiers, performance data, and diagnostic metadata. We configure diagnostics to reduce the risk of collecting secrets or Customer Content, but filtering may be imperfect.

### Heap Analytics

Purpose: authenticated product analytics, feature usage analysis, onboarding improvement, and usability analysis.  
Processing location: global or region configured by provider.  
Data categories: account identifiers, product usage events, session metadata, browser and device information, and interaction events inside the authenticated service.

### Google Analytics

Purpose: marketing website analytics after consent where required.  
Processing location: global or region configured by provider.  
Data categories: website usage data, device and browser information, referrers, approximate location, and marketing analytics events.

## Customer-Selected AI Providers

Frontman uses a bring-your-own-key model. Customers choose and connect third-party AI providers such as Anthropic, OpenAI, OpenRouter, or other supported providers using their own credentials or provider-authorized connection.

When a customer selects an AI provider, Frontman transmits prompts, code context, screenshots, logs, tool results, generated output, and other Customer Content to that provider as instructed by the customer.

Customer-selected AI providers are selected and controlled by the customer. Depending on the specific processing role and provider relationship, they may act as independent providers to the customer rather than ordinary subprocessors of {{company.shortName}}. Customers are responsible for reviewing and accepting the terms, privacy notices, and data processing terms of their selected AI providers.

## Changes

We may update this subprocessor list from time to time. For material changes affecting processing under the [Data Processing Agreement](/dpa/), we will provide notice as described in the DPA.

_Last updated: May 5, 2026_
