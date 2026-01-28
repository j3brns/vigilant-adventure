# AgentCore Deployment Guide

This guide provides step-by-step instructions for deploying the AgentCore platform and onboarding tenants.

## Contents

1. [Prerequisites](#prerequisites)
2. [Infrastructure Deployment](#infrastructure-deployment)
3. [Agent Template Setup](#agent-template-setup)
4. [Tenant Onboarding](#tenant-onboarding)
5. [Tenant Agent Development](#tenant-agent-development)
6. [Operations](#operations)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### AWS Account Setup

1. **Bedrock Model Access**

   Enable access to Claude models in the AWS Console:

   ```
   AWS Console → Amazon Bedrock → Model access → Manage model access
   ```

   Enable:
   - Anthropic Claude 4 Sonnet
   - Anthropic Claude 3.5 Sonnet (fallback)
   - Anthropic Claude 3 Haiku (cost-optimised option)

2. **Service Quotas**

   Verify sufficient quotas for:
   - Lambda concurrent executions
   - API Gateway requests per second
   - OpenSearch Serverless OCUs

3. **IAM Permissions**

   The deploying principal requires:

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "bedrock:*",
           "aoss:*",
           "dynamodb:*",
           "lambda:*",
           "apigateway:*",
           "iam:*",
           "logs:*",
           "s3:*"
         ],
         "Resource": "*"
       }
     ]
   }
   ```

   **Note:** Scope these permissions appropriately for production.

### Local Tools

| Tool | Version | Installation |
|------|---------|--------------|
| Terraform | >= 1.5.0 | `brew install terraform` |
| AWS CLI | >= 2.0 | `brew install awscli` |
| Node.js | >= 18 | `brew install node` |
| Python | >= 3.10 | `brew install python@3.11` |
| Git | >= 2.0 | `brew install git` |

### GitLab Requirements

- GitLab instance with CI/CD runners
- Group for AgentCore repositories
- Admin access to create projects and variables

---

## Infrastructure Deployment

### Step 1: Clone and Configure

```bash
# Extract the package
unzip agentcore-complete.zip
cd agentcore-terraform

# Review the structure
tree -L 2
```

### Step 2: Configure Terraform Backend

Create or update `environments/dev/backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "agentcore/dev/terraform.tfstate"
    region         = "eu-west-2"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

### Step 3: Configure Variables

```bash
cd environments/dev
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
# Environment
environment = "dev"
aws_region  = "eu-west-2"

# Naming
project_name = "agentcore"

# Authentication
jwks_uri              = "https://your-idp.com/.well-known/jwks.json"
jwt_issuer            = "https://your-idp.com/"
jwt_audience_prefix   = "arn:aws:bedrock"

# GitLab Integration
gitlab_url          = "https://gitlab.example.com"
gitlab_group_id     = "platform/agentcore"
gitlab_token        = "glpat-xxxxxxxxxxxx"  # Or use environment variable

# Demo Tenants (dev only)
demo_tenants = {
  "demo-tenant-1" = {
    name = "Demo Tenant One"
    tier = "professional"
  }
}
```

### Step 4: Build Authoriser Dependencies

```bash
cd ../../scripts
chmod +x build-authoriser.sh
./build-authoriser.sh
```

This installs Node.js dependencies for the Lambda authoriser.

### Step 5: Initialise Terraform

```bash
cd ../environments/dev
terraform init
```

Expected output:

```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.xx.x...

Terraform has been successfully initialized!
```

### Step 6: Review Plan

```bash
terraform plan -out=tfplan
```

Review the plan carefully. Key resources created:

| Resource | Count | Purpose |
|----------|-------|---------|
| `aws_bedrockagent_agent` | 1 | AgentCore Gateway |
| `aws_opensearchserverless_collection` | 1 | Memory storage |
| `aws_lambda_function` | 1 | JWT authoriser |
| `aws_dynamodb_table` | 2 | Tenant and agent registries |
| `aws_iam_role` | N+2 | Platform roles + per-tenant roles |

### Step 7: Apply

```bash
terraform apply tfplan
```

Wait for completion (typically 5-10 minutes for OpenSearch Serverless).

### Step 8: Capture Outputs

```bash
terraform output -json > outputs.json
```

Key outputs:

| Output | Description |
|--------|-------------|
| `gateway_agent_id` | Use in JWT `aud` claim |
| `gateway_agent_arn` | Gateway ARN for IAM policies |
| `memory_collection_endpoint` | OpenSearch endpoint |
| `api_endpoint` | Base URL for API calls |

---

## Agent Template Setup

### Step 1: Create GitLab Repository

```bash
cd ../../agentcore-agent-template

# Initialise Git
git init
git add .
git commit -m "Initial Strands agent template"

# Create remote repository
git remote add origin https://gitlab.example.com/platform/agentcore-agent-template.git
git push -u origin main
```

### Step 2: Configure as Template

In GitLab:

1. Navigate to **Settings → General**
2. Expand **Visibility, project features, permissions**
3. Enable **Template project**
4. Save changes

### Step 3: Set Group-Level CI/CD Variables

Navigate to **Group → Settings → CI/CD → Variables**:

| Variable | Value | Protected | Masked |
|----------|-------|-----------|--------|
| `AWS_REGION` | `eu-west-2` | No | No |
| `GITLAB_OIDC_TOKEN` | (auto-populated) | No | No |

Tenant-specific variables are set during provisioning.

---

## Tenant Onboarding

### Option A: Via Terraform (Recommended)

Add the tenant to `environments/prod/tenants.tf`:

```hcl
tenants = {
  "acme-corp" = {
    name        = "Acme Corporation"
    tier        = "professional"
    admin_email = "admin@acme.example.com"
    allowed_models = [
      "arn:aws:bedrock:*::foundation-model/anthropic.claude-sonnet-4-*",
      "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-haiku-*"
    ]
  }
  # ... existing tenants
}
```

Apply:

```bash
cd environments/prod
terraform plan -target=module.tenant[\"acme-corp\"]
terraform apply -target=module.tenant[\"acme-corp\"]
```

### Option B: Manual Provisioning

For ad-hoc provisioning without Terraform:

1. **Create IAM Role**

   ```bash
   aws iam create-role \
     --role-name agentcore-tenant-acme-corp \
     --assume-role-policy-document file://trust-policy.json
   ```

2. **Create Registry Entry**

   ```bash
   aws dynamodb put-item \
     --table-name agentcore-tenant-registry-prod \
     --item '{
       "tenant_id": {"S": "acme-corp"},
       "name": {"S": "Acme Corporation"},
       "tier": {"S": "professional"},
       "status": {"S": "active"},
       "execution_role_arn": {"S": "arn:aws:iam::123456789012:role/agentcore-tenant-acme-corp"},
       "created_at": {"S": "2026-01-28T00:00:00Z"}
     }'
   ```

3. **Create GitLab Repository**

   Use GitLab API or UI to create from template.

4. **Set CI/CD Variables**

   ```bash
   curl --request POST \
     --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
     --form "key=TENANT_ID" \
     --form "value=acme-corp" \
     "https://gitlab.example.com/api/v4/projects/${PROJECT_ID}/variables"
   ```

### Post-Onboarding Verification

```bash
# Verify IAM role
aws iam get-role --role-name agentcore-tenant-acme-corp

# Verify registry entry
aws dynamodb get-item \
  --table-name agentcore-tenant-registry-prod \
  --key '{"tenant_id": {"S": "acme-corp"}}'

# Verify GitLab repository
curl --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
  "https://gitlab.example.com/api/v4/projects/platform%2Facme-corp-agent"
```

---

## Tenant Agent Development

### Step 1: Clone Repository

The tenant clones their provisioned repository:

```bash
git clone https://gitlab.example.com/platform/acme-corp-agent.git
cd acme-corp-agent
```

### Step 2: Set Up Development Environment

```bash
# Create virtual environment
python -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt -r requirements-dev.txt
```

### Step 3: Configure AWS Credentials

For local development:

```bash
export AWS_PROFILE=acme-corp-dev
# Or
export AWS_ACCESS_KEY_ID=xxx
export AWS_SECRET_ACCESS_KEY=xxx
```

### Step 4: Customise the Agent

Edit `src/agent.py`:

```python
from strands import Agent, tool
from strands.models import BedrockModel

# Custom tool for Acme's use case
@tool
def search_inventory(product_name: str) -> list[dict]:
    """
    Search Acme's product inventory.
    
    Use this when customers ask about product availability,
    pricing, or specifications.
    
    Args:
        product_name: Name or partial name of product
        
    Returns:
        list: Matching products with stock levels and prices
    """
    # Implement inventory search
    return [{"name": product_name, "stock": 42, "price": 19.99}]

# Configure agent
SYSTEM_PROMPT = """You are Acme Corporation's product assistant.

Help customers:
1. Find products in our catalogue
2. Check availability and pricing
3. Answer product questions

Always be helpful and accurate. If unsure, offer to connect
the customer with a human representative.
"""

def create_agent(session_id=None, actor_id=None):
    return Agent(
        model=BedrockModel(
            model_id="anthropic.claude-sonnet-4-20250514-v1:0",
            region_name="eu-west-2",
        ),
        system_prompt=SYSTEM_PROMPT,
        tools=[search_inventory],
    )
```

### Step 5: Test Locally

```bash
# Run interactive mode
python -u src/agent.py

# Run unit tests
pytest tests/unit/ -v

# Run with coverage
pytest tests/unit/ -v --cov=src --cov-report=html
```

### Step 6: Deploy

```bash
# Push changes
git add .
git commit -m "Implement inventory search tool"
git push origin main
```

The CI/CD pipeline:

1. Validates (lint, type-check)
2. Tests (unit tests)
3. Builds (packages agent)
4. Deploys (manual trigger required)

To deploy:

1. Go to **CI/CD → Pipelines**
2. Find the latest pipeline
3. Click **deploy-dev** (manual job)
4. After validation, click **deploy-prod**

---

## Operations

### Monitoring

**CloudWatch Dashboards:**

Create a dashboard with:

- API Gateway request count and latency
- Lambda invocation count and errors
- Bedrock token consumption
- OpenSearch Serverless OCU usage

**Alarms:**

| Metric | Threshold | Action |
|--------|-----------|--------|
| API 5xx errors | > 1% | Page on-call |
| Lambda errors | > 0 | Slack notification |
| Bedrock throttling | > 0 | Increase quota |

### Log Analysis

```bash
# View authoriser logs
aws logs tail /aws/lambda/agentcore-authoriser-prod --follow

# View tenant agent logs
aws logs tail /agentcore/tenants/acme-corp --follow

# Search for errors
aws logs filter-log-events \
  --log-group-name /agentcore/tenants/acme-corp \
  --filter-pattern "ERROR"
```

### Tenant Suspension

To suspend a tenant (e.g., for non-payment):

```bash
# Update registry
aws dynamodb update-item \
  --table-name agentcore-tenant-registry-prod \
  --key '{"tenant_id": {"S": "acme-corp"}}' \
  --update-expression "SET #s = :status" \
  --expression-attribute-names '{"#s": "status"}' \
  --expression-attribute-values '{":status": {"S": "suspended"}}'

# Update IAM trust policy to deny assume
aws iam update-assume-role-policy \
  --role-name agentcore-tenant-acme-corp \
  --policy-document file://deny-trust-policy.json
```

### Scaling

**Bedrock:**

- Request quota increases via AWS Support
- Consider provisioned throughput for predictable workloads

**OpenSearch Serverless:**

- Automatic scaling based on indexing/search demand
- Monitor OCU consumption for cost management

**Lambda:**

- Configure reserved concurrency per tenant
- Adjust memory allocation based on profiling

---

## Troubleshooting

### Authentication Failures

**Symptom:** 401 Unauthorized responses

**Checks:**

1. Verify JWT is properly formatted:

   ```bash
   # Decode JWT (doesn't verify signature)
   echo $TOKEN | cut -d. -f2 | base64 -d | jq .
   ```

2. Check audience claim matches Gateway ID:

   ```bash
   terraform output gateway_agent_id
   ```

3. Verify JWKS endpoint is accessible:

   ```bash
   curl -s $JWKS_URI | jq .keys[0].kid
   ```

4. Check authoriser logs:

   ```bash
   aws logs tail /aws/lambda/agentcore-authoriser-dev --follow
   ```

### Model Invocation Failures

**Symptom:** AccessDeniedException from Bedrock

**Checks:**

1. Verify model access is enabled in Bedrock console

2. Check tenant IAM policy includes Converse actions:

   ```bash
   aws iam get-role-policy \
     --role-name agentcore-tenant-acme-corp \
     --policy-name tenant-permissions
   ```

3. Verify cross-region inference profile ARNs if using Claude 4:

   ```
   arn:aws:bedrock:*:*:inference-profile/us.anthropic.claude-sonnet-4-*
   ```

### Memory Access Failures

**Symptom:** Agent cannot read/write memory

**Checks:**

1. Verify OpenSearch collection is active:

   ```bash
   aws opensearchserverless batch-get-collection \
     --names agentcore-memory-dev
   ```

2. Check network policy allows access:

   ```bash
   aws opensearchserverless get-security-policy \
     --name agentcore-memory-network-dev \
     --type network
   ```

3. Verify tenant IAM policy has correct index pattern:

   ```
   "aoss:index": "tenant-acme-corp-*"
   ```

### Pipeline Failures

**Symptom:** GitLab CI job fails

**Checks:**

1. Verify CI/CD variables are set:

   - `TENANT_ID`
   - `TENANT_EXECUTION_ROLE_ARN`
   - `ENVIRONMENT`

2. Check OIDC trust relationship:

   ```bash
   aws iam get-role --role-name agentcore-tenant-acme-corp \
     | jq '.Role.AssumeRolePolicyDocument'
   ```

3. Verify GitLab runner has network access to AWS

4. Check job logs for specific error messages

### Common Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| `Token expired` | JWT past expiration | Refresh token |
| `Invalid audience` | Wrong Gateway ID in `aud` | Update token generation |
| `AccessDenied: bedrock:Converse` | Missing IAM permission | Add Converse actions to policy |
| `Collection not found` | OpenSearch not ready | Wait for ACTIVE status |
| `Index pattern denied` | Wrong namespace | Check tenant ID in index pattern |

---

## Appendix: Environment Comparison

| Aspect | Development | Production |
|--------|-------------|------------|
| Gateway model | Claude 4 Sonnet | Claude 4 Sonnet |
| Memory retention | 7 days | 90 days |
| Log retention | 14 days | 365 days |
| Rate limits | Relaxed | Enforced per tier |
| Deployment approval | Optional | Required |
| Backup frequency | None | Daily |

---

*Document version: 1.0*
*Last updated: January 2026*
