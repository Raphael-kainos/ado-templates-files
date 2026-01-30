"""
Azure Durable Functions Backend with LangChain
This provides the backend API for the Streamlit frontend.
"""

import logging
import azure.functions as func
import azure.durable_functions as df
import json
import os
from typing import Dict, Any


def orchestrator_function(context: df.DurableOrchestrationContext):
    """
    Main orchestrator for durable function workflows.
    This can chain multiple activities and manage state.
    """
    input_data = context.get_input()

    # Call activity to process with LangChain
    result = yield context.call_activity("ProcessWithLangChain", input_data)

    return result


# Register the orchestrator
main = df.Orchestrator.create(orchestrator_function)
