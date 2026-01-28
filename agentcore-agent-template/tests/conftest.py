"""
Pytest configuration and shared fixtures for Strands agent tests.
"""

import os
import pytest
import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

# Add src to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))

# Set test environment variables
os.environ.setdefault("TENANT_ID", "test-tenant")
os.environ.setdefault("ENVIRONMENT", "test")
os.environ.setdefault("AWS_REGION", "eu-west-2")


@pytest.fixture
def sample_event():
    """Provide a sample Lambda event."""
    return {
        "message": "Hello, how can you help me?",
        "sessionId": "test-session-123",
        "userId": "test-user-456",
        "metadata": {},
    }


@pytest.fixture
def mock_bedrock_model():
    """Mock the Bedrock model for testing without AWS credentials."""
    with patch("strands.models.BedrockModel") as mock:
        mock_instance = MagicMock()
        mock.return_value = mock_instance
        yield mock_instance


@pytest.fixture
def mock_agent():
    """Mock the Strands Agent for testing."""
    with patch("strands.Agent") as mock:
        mock_instance = MagicMock()
        
        # Mock the result
        mock_result = MagicMock()
        mock_result.message = {
            "content": [{"text": "Hello! I'm here to help you."}]
        }
        mock_result.metrics = MagicMock()
        mock_result.metrics.accumulated_usage = {
            "inputTokens": 10,
            "outputTokens": 20,
        }
        mock_result.metrics.accumulated_metrics = {
            "latencyMs": 500,
        }
        
        mock_instance.return_value = mock_result
        mock.return_value = mock_instance
        
        yield mock_instance


@pytest.fixture
def mock_memory_client():
    """Mock AgentCore Memory client."""
    with patch("bedrock_agentcore.memory.MemoryClient") as mock:
        mock_instance = MagicMock()
        mock_instance.create_memory.return_value = {"id": "test-memory-id"}
        mock.return_value = mock_instance
        yield mock_instance
