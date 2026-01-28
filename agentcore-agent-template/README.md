# AgentCore Agent Template (Strands Agents SDK)

This repository contains your tenant's agent implementation for the AgentCore platform, built using the [Strands Agents SDK](https://strandsagents.com/).

## Quick Start

```bash
# Create virtual environment
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt -r requirements-dev.txt

# Run locally (requires AWS credentials)
python -u src/agent.py

# Run tests
pytest tests/unit/ -v
```

## Project Structure

```
├── src/
│   └── agent.py           # Agent implementation with Strands SDK
├── tests/
│   ├── unit/              # Unit tests (mocked)
│   └── integration/       # Integration tests (real services)
├── config/
│   └── agent.yaml         # Agent configuration reference
├── .gitlab-ci.yml         # CI/CD pipeline
├── requirements.txt       # Production dependencies
└── requirements-dev.txt   # Development dependencies
```

## Strands Agents SDK

Strands is a model-driven approach to building AI agents. Instead of defining complex workflows, you:

1. **Define tools** using the `@tool` decorator
2. **Configure the model** and system prompt
3. **Let the LLM** handle reasoning, planning, and tool selection

```python
from strands import Agent, tool

@tool
def my_custom_tool(param: str) -> str:
    """Tool description for the LLM."""
    return f"Result for {param}"

agent = Agent(
    system_prompt="You are a helpful assistant.",
    tools=[my_custom_tool]
)

result = agent("Help me with something")
```

## Customising Your Agent

### 1. Add Custom Tools

Edit `src/agent.py` and add tools using the `@tool` decorator:

```python
@tool
def search_knowledge_base(query: str) -> list[dict]:
    """
    Search the knowledge base for relevant information.
    
    Use this tool when the user asks questions that require
    looking up documentation or stored knowledge.
    
    Args:
        query: The search query
        
    Returns:
        list: Matching documents with relevance scores
    """
    # Your implementation here
    return [{"title": "Doc 1", "content": "..."}]
```

The docstring is crucial - it tells the LLM when and how to use the tool.

### 2. Modify the System Prompt

Update `SYSTEM_PROMPT` in `src/agent.py` to define your agent's persona:

```python
SYSTEM_PROMPT = """You are a customer support agent for {tenant_id}.

Your responsibilities:
1. Answer product questions accurately
2. Help troubleshoot issues
3. Escalate complex cases to human support

Always be empathetic and solution-focused.
"""
```

### 3. Configure AgentCore Memory

Set the `AGENTCORE_MEMORY_ID` environment variable to enable persistent memory:

```bash
export AGENTCORE_MEMORY_ID="your-memory-id"
```

Memory provides:
- **Session summaries**: Conversation context across sessions
- **User preferences**: Remembered user settings
- **Semantic facts**: Extracted and stored knowledge

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `TENANT_ID` | Tenant identifier | `demo-tenant` |
| `ENVIRONMENT` | Environment name | `dev` |
| `AWS_REGION` | AWS region | `eu-west-2` |
| `MODEL_ID` | Bedrock model ID | Claude Sonnet 4 |
| `AGENTCORE_MEMORY_ID` | Memory instance ID | (disabled) |
| `LOG_LEVEL` | Logging level | `INFO` |

## Deployment

Deployments are handled by GitLab CI when you push to main:

1. **Push to main** → Pipeline triggers
2. **Validate** → Lint, type check, security scan
3. **Test** → Unit and integration tests
4. **Build** → Package agent
5. **Deploy** → Manual approval required

### Manual Deployment

1. Go to **CI/CD → Pipelines**
2. Find the latest pipeline on main
3. Click **deploy-dev** (manual trigger)
4. After validation, click **deploy-prod**

## Local Development

### Running the Agent

```bash
# Set AWS credentials
export AWS_PROFILE=your-profile

# Run interactive mode
python -u src/agent.py
```

### Running Tests

```bash
# Unit tests only
pytest tests/unit/ -v

# With coverage
pytest tests/unit/ -v --cov=src --cov-report=html

# Integration tests (requires AWS)
RUN_INTEGRATION_TESTS=1 pytest tests/integration/ -v
```

### Linting

```bash
ruff check src/ tests/
ruff format src/ tests/
mypy src/
```

## Observability

Strands provides built-in observability:

```python
result = agent("Your question")

# Access metrics
print(result.metrics.get_summary())

# Token usage
print(result.metrics.accumulated_usage)

# Latency
print(result.metrics.accumulated_metrics["latencyMs"])
```

For production, enable OpenTelemetry:

```bash
pip install strands-agents[otel]
```

## Resources

- [Strands Agents Documentation](https://strandsagents.com/)
- [Strands GitHub](https://github.com/strands-agents/sdk-python)
- [AgentCore Memory Integration](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/strands-sdk-memory.html)
- [Community Tools](https://github.com/strands-agents/tools)

## Support

For agent implementation issues, contact your development team.

For platform issues, contact the AgentCore platform team.
