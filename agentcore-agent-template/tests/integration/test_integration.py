"""
Integration tests for the Strands agent.

These tests verify the agent works correctly with real AWS services.
They require appropriate AWS credentials and are run in CI/CD.
"""

import os
import pytest


# Skip all integration tests if not enabled
pytestmark = pytest.mark.skipif(
    not os.getenv("RUN_INTEGRATION_TESTS"),
    reason="Integration tests disabled. Set RUN_INTEGRATION_TESTS=1 to enable."
)


class TestBedrockIntegration:
    """Tests for Bedrock model integration."""
    
    def test_create_agent_with_bedrock(self):
        """Test creating agent with real Bedrock model."""
        from agent import create_agent
        
        agent = create_agent()
        
        assert agent is not None
        assert agent.model is not None
    
    @pytest.mark.timeout(60)
    def test_agent_invocation(self):
        """Test actual agent invocation."""
        from agent import create_agent
        
        agent = create_agent()
        result = agent("What is 2 + 2?")
        
        assert result is not None
        assert result.message is not None


class TestAgentCoreMemoryIntegration:
    """Tests for AgentCore Memory integration."""
    
    @pytest.mark.skipif(
        not os.getenv("AGENTCORE_MEMORY_ID"),
        reason="AGENTCORE_MEMORY_ID not set"
    )
    def test_agent_with_memory(self):
        """Test agent creation with AgentCore Memory."""
        from agent import create_agent
        
        agent = create_agent(
            session_id="integration-test-session",
            actor_id="integration-test-actor"
        )
        
        assert agent is not None


class TestLambdaHandler:
    """End-to-end tests for the Lambda handler."""
    
    @pytest.mark.timeout(120)
    def test_handler_end_to_end(self, sample_event):
        """Test full handler flow."""
        from agent import handler
        
        result = handler(sample_event, None)
        
        assert result["statusCode"] == 200
        assert "response" in result["body"]
        assert len(result["body"]["response"]) > 0
