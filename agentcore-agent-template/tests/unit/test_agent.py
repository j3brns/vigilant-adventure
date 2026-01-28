"""
Unit tests for the Strands-based tenant agent.
"""

import os
import pytest
from unittest.mock import MagicMock, patch


class TestTools:
    """Tests for custom tool functions."""
    
    def test_get_tenant_info(self):
        """Test get_tenant_info returns correct structure."""
        from agent import get_tenant_info
        
        result = get_tenant_info()
        
        assert "tenant_id" in result
        assert "environment" in result
        assert "region" in result
        assert "capabilities" in result
        assert isinstance(result["capabilities"], list)
    
    def test_get_current_time(self):
        """Test get_current_time returns ISO format."""
        from agent import get_current_time
        
        result = get_current_time()
        
        # Should be ISO format
        assert "T" in result
        assert "-" in result
    
    def test_store_user_preference(self):
        """Test store_user_preference returns confirmation."""
        from agent import store_user_preference
        
        result = store_user_preference(
            preference_type="communication_style",
            preference_value="concise"
        )
        
        assert "communication_style" in result.lower()
        assert "remember" in result.lower()


class TestAgentFactory:
    """Tests for agent creation."""
    
    @patch("agent.BedrockModel")
    @patch("agent.Agent")
    def test_create_agent_basic(self, mock_agent_class, mock_model_class):
        """Test basic agent creation without memory."""
        from agent import create_agent
        
        agent = create_agent()
        
        # Model should be configured
        mock_model_class.assert_called_once()
        model_kwargs = mock_model_class.call_args.kwargs
        assert "model_id" in model_kwargs
        assert "region_name" in model_kwargs
        
        # Agent should be created
        mock_agent_class.assert_called_once()
        agent_kwargs = mock_agent_class.call_args.kwargs
        assert "model" in agent_kwargs
        assert "system_prompt" in agent_kwargs
        assert "tools" in agent_kwargs
    
    @patch("agent.BedrockModel")
    @patch("agent.Agent")
    def test_create_agent_with_session(self, mock_agent_class, mock_model_class):
        """Test agent creation with session ID."""
        from agent import create_agent
        
        agent = create_agent(
            session_id="custom-session",
            actor_id="custom-actor"
        )
        
        mock_agent_class.assert_called_once()


class TestHandler:
    """Tests for the Lambda handler."""
    
    @patch("agent.create_agent")
    def test_handler_success(self, mock_create_agent, sample_event):
        """Test successful handler invocation."""
        from agent import handler
        
        # Mock agent response
        mock_agent = MagicMock()
        mock_result = MagicMock()
        mock_result.message = {"content": [{"text": "Test response"}]}
        mock_result.metrics = MagicMock()
        mock_result.metrics.accumulated_usage = {"inputTokens": 10, "outputTokens": 20}
        mock_result.metrics.accumulated_metrics = {"latencyMs": 500}
        mock_agent.return_value = mock_result
        mock_create_agent.return_value = mock_agent
        
        result = handler(sample_event, None)
        
        assert result["statusCode"] == 200
        assert "response" in result["body"]
        assert "metrics" in result["body"]
    
    @patch("agent.create_agent")
    def test_handler_empty_message(self, mock_create_agent):
        """Test handler with empty message."""
        from agent import handler
        
        event = {"message": ""}
        result = handler(event, None)
        
        assert result["statusCode"] == 400
        assert "error" in result["body"]
    
    @patch("agent.create_agent")
    def test_handler_no_message(self, mock_create_agent):
        """Test handler with missing message."""
        from agent import handler
        
        event = {}
        result = handler(event, None)
        
        assert result["statusCode"] == 400
    
    @patch("agent.create_agent")
    def test_handler_exception(self, mock_create_agent, sample_event):
        """Test handler error handling."""
        from agent import handler
        
        mock_create_agent.side_effect = Exception("Test error")
        
        result = handler(sample_event, None)
        
        assert result["statusCode"] == 500
        assert "error" in result["body"]


class TestConfiguration:
    """Tests for configuration handling."""
    
    def test_environment_variables(self):
        """Test environment variable defaults."""
        from agent import TENANT_ID, ENVIRONMENT, AWS_REGION
        
        # Should have values (either from env or defaults)
        assert TENANT_ID is not None
        assert ENVIRONMENT is not None
        assert AWS_REGION is not None
    
    def test_system_prompt_formatting(self):
        """Test system prompt contains tenant info."""
        from agent import SYSTEM_PROMPT, TENANT_ID, ENVIRONMENT
        
        assert TENANT_ID in SYSTEM_PROMPT or "{tenant_id}" not in SYSTEM_PROMPT
        assert ENVIRONMENT in SYSTEM_PROMPT or "{environment}" not in SYSTEM_PROMPT
    
    def test_custom_tools_list(self):
        """Test custom tools are defined."""
        from agent import CUSTOM_TOOLS
        
        assert isinstance(CUSTOM_TOOLS, list)
        assert len(CUSTOM_TOOLS) >= 1
