"""
AgentCore Tenant Agent - Strands Agents SDK Implementation

This module implements a tenant agent using the Strands Agents SDK with
AgentCore Memory integration. Strands provides model-driven agent development
where the LLM handles reasoning, planning, and tool selection.

Customise this file to implement your agent's behaviour by:
1. Modifying the system prompt
2. Adding custom tools with the @tool decorator
3. Configuring memory strategies
"""

import logging
import os
from datetime import datetime
from typing import Any

from strands import Agent, tool
from strands.models import BedrockModel

# Optional: AgentCore Memory integration
try:
    from bedrock_agentcore.memory import MemoryClient
    from bedrock_agentcore.memory.integrations.strands.config import (
        AgentCoreMemoryConfig,
        RetrievalConfig,
    )
    from bedrock_agentcore.memory.integrations.strands.session_manager import (
        AgentCoreMemorySessionManager,
    )
    AGENTCORE_MEMORY_AVAILABLE = True
except ImportError:
    AGENTCORE_MEMORY_AVAILABLE = False

# Configure logging
logging.basicConfig(
    level=getattr(logging, os.getenv("LOG_LEVEL", "INFO")),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)


# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

# Environment variables set by AgentCore Runtime or GitLab CI
TENANT_ID = os.getenv("TENANT_ID", "demo-tenant")
ENVIRONMENT = os.getenv("ENVIRONMENT", "dev")
AWS_REGION = os.getenv("AWS_REGION", "eu-west-2")

# AgentCore Memory configuration (optional)
MEMORY_ID = os.getenv("AGENTCORE_MEMORY_ID")

# Model configuration
MODEL_ID = os.getenv(
    "MODEL_ID",
    "anthropic.claude-sonnet-4-20250514-v1:0"
)

# System prompt defining agent behaviour
SYSTEM_PROMPT = """You are a helpful assistant for {tenant_id}.

Your role is to:
1. Answer questions clearly and accurately
2. Help users accomplish their tasks efficiently  
3. Use available tools when they would help answer the question
4. Remember important context from the conversation

Always be polite, professional, and helpful. If you're unsure about
something, acknowledge the uncertainty rather than guessing.

Current environment: {environment}
""".format(tenant_id=TENANT_ID, environment=ENVIRONMENT)


# -----------------------------------------------------------------------------
# Custom Tools
# -----------------------------------------------------------------------------
# Define tools using the @tool decorator. The docstring is used by the LLM
# to understand when and how to use the tool.

@tool
def get_tenant_info() -> dict[str, Any]:
    """
    Get information about the current tenant.
    
    Use this tool when the user asks about their account, tenant, or
    organisation details.
    
    Returns:
        dict: Tenant information including ID, environment, and capabilities
    """
    return {
        "tenant_id": TENANT_ID,
        "environment": ENVIRONMENT,
        "region": AWS_REGION,
        "capabilities": ["chat", "memory", "tools"],
        "tier": os.getenv("TENANT_TIER", "professional"),
    }


@tool
def store_user_preference(preference_type: str, preference_value: str) -> str:
    """
    Store a user preference for future reference.
    
    Use this tool when the user explicitly states a preference they want
    remembered, such as communication style, topics of interest, or
    formatting preferences.
    
    Args:
        preference_type: Category of preference (e.g., "communication_style", 
                        "topic_interest", "format_preference")
        preference_value: The preference value to store
        
    Returns:
        str: Confirmation message
    """
    logger.info(f"Storing preference: {preference_type}={preference_value}")
    # In production, this would persist to AgentCore Memory
    return f"Noted: I'll remember your {preference_type} preference."


@tool  
def get_current_time() -> str:
    """
    Get the current date and time.
    
    Use this tool when the user asks about the current time, date, or
    needs time-based context.
    
    Returns:
        str: Current timestamp in ISO format
    """
    return datetime.now().isoformat()


# Collect all custom tools
CUSTOM_TOOLS = [
    get_tenant_info,
    store_user_preference,
    get_current_time,
]


# -----------------------------------------------------------------------------
# Agent Factory
# -----------------------------------------------------------------------------

def create_agent(
    session_id: str | None = None,
    actor_id: str | None = None,
) -> Agent:
    """
    Create a configured Strands agent instance.
    
    Args:
        session_id: Optional session identifier for memory continuity
        actor_id: Optional actor/user identifier for memory isolation
        
    Returns:
        Agent: Configured Strands agent ready for invocation
    """
    # Configure the Bedrock model
    model = BedrockModel(
        model_id=MODEL_ID,
        region_name=AWS_REGION,
        temperature=0.7,
        max_tokens=2048,
    )
    
    # Configure session manager with AgentCore Memory if available
    session_manager = None
    
    if AGENTCORE_MEMORY_AVAILABLE and MEMORY_ID:
        logger.info(f"Configuring AgentCore Memory: {MEMORY_ID}")
        
        memory_config = AgentCoreMemoryConfig(
            memory_id=MEMORY_ID,
            session_id=session_id or f"session-{datetime.now().strftime('%Y%m%d%H%M%S')}",
            actor_id=actor_id or f"actor-{TENANT_ID}",
        )
        
        session_manager = AgentCoreMemorySessionManager(
            agentcore_memory_config=memory_config,
            region_name=AWS_REGION,
        )
    
    # Create the agent
    agent = Agent(
        model=model,
        system_prompt=SYSTEM_PROMPT,
        tools=CUSTOM_TOOLS,
        session_manager=session_manager,
    )
    
    logger.info(f"Agent created for tenant {TENANT_ID} with {len(CUSTOM_TOOLS)} tools")
    return agent


# -----------------------------------------------------------------------------
# Lambda Handler
# -----------------------------------------------------------------------------

def handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    """
    AWS Lambda handler for AgentCore Runtime invocations.
    
    Args:
        event: Lambda event containing:
            - message: User's input message
            - sessionId: Session identifier
            - userId: User identifier
            - metadata: Additional request metadata
        context: Lambda context object
        
    Returns:
        dict: Response containing agent's reply and metadata
    """
    logger.info(f"Handler invoked for tenant {TENANT_ID}")
    
    try:
        # Extract request parameters
        message = event.get("message", "")
        session_id = event.get("sessionId")
        user_id = event.get("userId")
        
        if not message:
            return {
                "statusCode": 400,
                "body": {"error": "No message provided"},
            }
        
        # Create agent with session context
        agent = create_agent(
            session_id=session_id,
            actor_id=user_id,
        )
        
        # Invoke the agent
        result = agent(message)
        
        # Extract response
        response_text = result.message.get("content", [{}])[0].get("text", "")
        
        return {
            "statusCode": 200,
            "body": {
                "response": response_text,
                "sessionId": session_id,
                "metrics": {
                    "inputTokens": result.metrics.accumulated_usage.get("inputTokens", 0),
                    "outputTokens": result.metrics.accumulated_usage.get("outputTokens", 0),
                    "latencyMs": result.metrics.accumulated_metrics.get("latencyMs", 0),
                },
            },
        }
        
    except Exception as e:
        logger.error(f"Handler error: {e}", exc_info=True)
        return {
            "statusCode": 500,
            "body": {"error": str(e)},
        }


# -----------------------------------------------------------------------------
# Local Development
# -----------------------------------------------------------------------------

if __name__ == "__main__":
    # Simple REPL for local testing
    print(f"AgentCore Tenant Agent - {TENANT_ID}")
    print(f"Environment: {ENVIRONMENT}")
    print(f"Model: {MODEL_ID}")
    print("-" * 50)
    print("Type 'quit' to exit\n")
    
    agent = create_agent()
    
    while True:
        try:
            user_input = input("You: ").strip()
            if user_input.lower() in ("quit", "exit", "q"):
                break
            if not user_input:
                continue
                
            result = agent(user_input)
            print(f"\nAgent: {result.message}\n")
            
        except KeyboardInterrupt:
            break
        except Exception as e:
            print(f"Error: {e}\n")
    
    print("Goodbye!")
