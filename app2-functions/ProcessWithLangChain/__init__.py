"""
Activity function that processes data using LangChain.
"""

import logging
from langchain.chat_models import AzureChatOpenAI
from langchain.schema import HumanMessage, SystemMessage
import os
import json


def main(input_data: dict) -> dict:
    """
    Process input using LangChain.

    Args:
        input_data: Dictionary containing query and user info

    Returns:
        Processed result from LangChain
    """
    logging.info(f"Processing data with LangChain: {input_data}")

    try:
        query = input_data.get("query", "")
        user = input_data.get("user", "unknown")

        # Initialize LangChain (configure with your Azure OpenAI credentials)
        # These should be set in Function App Configuration
        azure_endpoint = os.getenv("AZURE_OPENAI_ENDPOINT")
        api_key = os.getenv("AZURE_OPENAI_KEY")
        deployment_name = os.getenv("AZURE_OPENAI_DEPLOYMENT", "gpt-4")

        if not azure_endpoint or not api_key:
            logging.warning("Azure OpenAI credentials not configured")
            return {
                "status": "warning",
                "response": "LangChain not configured. Please set Azure OpenAI credentials.",
                "query": query
            }

        # Create LangChain chat model
        llm = AzureChatOpenAI(
            azure_endpoint=azure_endpoint,
            api_key=api_key,
            deployment_name=deployment_name,
            api_version="2024-02-15-preview",
            temperature=0.7
        )

        # Process with LangChain
        messages = [
            SystemMessage(content="You are a helpful AI assistant."),
            HumanMessage(content=query)
        ]

        response = llm(messages)

        return {
            "status": "success",
            "response": response.content,
            "query": query,
            "user": user
        }

    except Exception as e:
        logging.error(f"Error processing with LangChain: {str(e)}")
        return {
            "status": "error",
            "error": str(e),
            "query": input_data.get("query", "")
        }
