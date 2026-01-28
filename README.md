# AgentCore Multi-Tenant Platform

A production-ready infrastructure scaffold for deploying multi-tenant AI agents on AWS using [Strands Agents SDK](https://strandsagents.com/) and [Amazon Bedrock AgentCore](https://docs.aws.amazon.com/bedrock-agentcore/).

## Overview

This project implements a **two-track release model** separating infrastructure concerns from application deployment:

| Track | Repository | Owner | Cadence |
|-------|------------|-------|---------|
| **Infrastructure** | `agentcore-terraform` | Platform team | Weekly/monthly |
| **Application** | `agentcore-agent-template` | Tenant teams | As needed |

Platform teams provision tenant resources via Terraform. Tenant teams deploy their agents independently via GitLab CI without platform involvement.

## Quick Start

```bash
# Extract the package
unzip agentcore-complete.zip
cd agentcore-terraform

# 1. Configure backend and variables
cd environments/dev
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# 2. Build authoriser dependencies
cd ../../scripts
./build-authoriser.sh
cd ../environments/dev

# 3. Deploy infrastructure
terraform init
terraform plan
terraform apply
```

## Repository Structure

```
agentcore-complete/
├── agentcore-terraform/           # Infrastructure as Code
│   ├── modules/
│   │   ├── agentcore-platform/    # Shared platform resources
│   │   ├── tenant/                # Per-tenant resources
│   │   └── authoriser/            # JWT validation Lambda
│   ├── environments/
│   │   ├── dev/                   # Development environment
│   │   └── prod/                  # Production environment
│   └── scripts/
│       └── build-authoriser.sh    # Lambda dependency builder
│
├── agentcore-agent-template/      # Tenant agent template
│   ├── src/
│   │   └── agent.py               # Strands agent implementation
│   ├── tests/                     # Unit and integration tests
│   ├── config/                    # Agent configuration
│   └── .gitlab-ci.yml             # CI/CD pipeline
│
├── README.md                      # This file
├── ARCHITECTURE.md                # System architecture
└── DEPLOYMENT.md                  # Deployment guide
```

## Key Features

### Multi-Tenant Isolation

- **IAM role per tenant** with scoped permissions
- **Namespace isolation** in AgentCore Memory
- **Separate CloudWatch log groups** per tenant
- **Rate limiting** enforced at the Gateway

### Strands Agents SDK Integration

- Model-driven agent development
- Built-in tool use with `@tool` decorator
- AgentCore Memory integration for persistence
- OpenTelemetry observability

### Self-Service Tenant Onboarding

- Terraform provisions tenant resources
- GitLab repository created from template
- CI/CD variables automatically configured
- Tenants deploy independently

## Technology Stack

| Component | Technology |
|-----------|------------|
| Infrastructure | Terraform, AWS |
| Agent Framework | Strands Agents SDK |
| LLM | Amazon Bedrock (Claude 4 Sonnet) |
| Memory | AgentCore Memory / OpenSearch Serverless |
| Authentication | JWT with Lambda authoriser |
| CI/CD | GitLab CI with OIDC |
| Observability | CloudWatch, OpenTelemetry |

## Documentation

- **[ARCHITECTURE.md](./ARCHITECTURE.md)** — System design, components, data flow
- **[DEPLOYMENT.md](./DEPLOYMENT.md)** — Step-by-step deployment instructions
- **[agentcore-terraform/README.md](./agentcore-terraform/README.md)** — Terraform module documentation
- **[agentcore-agent-template/README.md](./agentcore-agent-template/README.md)** — Agent development guide

## Prerequisites

- AWS account with Bedrock access enabled
- Terraform >= 1.5.0
- Node.js >= 18 (for authoriser Lambda)
- Python >= 3.10 (for agent development)
- GitLab instance with CI/CD runners

## Licence

Internal use only. Contact platform team for licensing enquiries.
