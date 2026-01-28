# AgentCore Infrastructure

Terraform scaffold for multi-tenant AWS AgentCore deployment.

## Architecture

This repository provisions the **infrastructure track** of the two-track release model. Agent code deployment is handled separately via GitLab CI.

```
┌─────────────────────────────────────────────────────────────────┐
│                     Infrastructure Track                        │
│                        (This Repo)                              │
├─────────────────────────────────────────────────────────────────┤
│  modules/                                                       │
│  ├── agentcore-platform/   Core AgentCore resources             │
│  ├── tenant/               Per-tenant provisioning              │
│  └── authoriser/           Lambda authoriser                    │
│                                                                 │
│  environments/                                                  │
│  ├── dev/                  Development environment              │
│  └── prod/                 Production environment               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Application Track                           │
│                    (Tenant GitLab Repos)                        │
├─────────────────────────────────────────────────────────────────┤
│  gitlab.internal/tenants/                                       │
│  ├── acme-corp-agent/      Tenant deploys agent code            │
│  ├── globex-agent/         via GitLab CI to existing            │
│  └── initech-agent/        AgentCore Runtime                    │
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

- Terraform >= 1.5
- AWS CLI configured with appropriate credentials
- Control Tower account structure in place
- S3 backend bucket and DynamoDB lock table

## Quick Start

```bash
# Initialise dev environment
cd environments/dev
terraform init

# Plan changes
terraform plan -out=tfplan

# Apply
terraform apply tfplan
```

## Module Structure

### agentcore-platform

Provisions the shared platform resources:
- AgentCore Gateway
- AgentCore Runtime
- AgentCore Memory
- DynamoDB tenant registry
- IAM roles for platform operations

### tenant

Provisions per-tenant resources:
- Tenant IAM role (for agent execution)
- Memory namespace
- Agent configuration in Runtime
- DynamoDB tenant record
- GitLab repository (from template)

### authoriser

Provisions the Lambda authoriser:
- Lambda function
- IAM execution role
- API Gateway integration
- CloudWatch logging

## State Management

Currently using a single state file per environment. Future improvement: split into layered states (platform, tenants) using `terraform_remote_state` data sources.

## Adding a Tenant

```hcl
module "tenant_acme" {
  source = "../../modules/tenant"

  tenant_id   = "acme-corp"
  tenant_name = "Acme Corporation"
  tier        = "professional"
  
  # Passed from platform module
  runtime_id     = module.platform.runtime_id
  memory_id      = module.platform.memory_id
  gateway_id     = module.platform.gateway_id
}
```
