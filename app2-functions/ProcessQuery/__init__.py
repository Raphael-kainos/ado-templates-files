"""
HTTP Trigger to start the durable orchestration and process queries.
"""

import logging
import azure.functions as func
import azure.durable_functions as df
import json


async def main(req: func.HttpRequest, starter: str) -> func.HttpResponse:
    """
    HTTP trigger to start durable orchestration.
    """
    logging.info('ProcessQuery HTTP trigger function processed a request.')

    client = df.DurableOrchestrationClient(starter)

    try:
        req_body = req.get_json()
        query = req_body.get('query')
        user = req_body.get('user', 'anonymous')

        if not query:
            return func.HttpResponse(
                json.dumps({"error": "Query is required"}),
                status_code=400,
                mimetype="application/json"
            )

        # Start the orchestration
        instance_id = await client.start_new(
            "DurableOrchestrator",
            None,
            {"query": query, "user": user}
        )

        logging.info(f"Started orchestration with ID = '{instance_id}'.")

        # Wait for completion (or return instance_id for async processing)
        timeout = 30
        result = await client.wait_for_completion_or_create_check_status_response(
            req,
            instance_id,
            timeout_in_milliseconds=timeout * 1000
        )

        return result

    except ValueError:
        return func.HttpResponse(
            json.dumps({"error": "Invalid JSON in request body"}),
            status_code=400,
            mimetype="application/json"
        )
    except Exception as e:
        logging.error(f"Error: {str(e)}")
        return func.HttpResponse(
            json.dumps({"error": str(e)}),
            status_code=500,
            mimetype="application/json"
        )
