"""
Simple health check endpoint.
"""

import logging
import azure.functions as func
import json


def main(req: func.HttpRequest) -> func.HttpResponse:
    """
    Health check endpoint.
    """
    logging.info('Health check triggered.')

    return func.HttpResponse(
        json.dumps({
            "status": "healthy",
            "service": "Azure Durable Functions Backend",
            "version": "1.0.0"
        }),
        status_code=200,
        mimetype="application/json"
    )
