"""
Streamlit Front-end Application
This app demonstrates integration with Azure App Service and Easy Auth.
It calls the backend Azure Function (App 2) using function keys.
"""

import streamlit as st
import requests
import os
import json

# Configuration
BACKEND_FUNCTION_URL = os.getenv(
    "BACKEND_FUNCTION_URL", "https://your-function-app.azurewebsites.net/api")
FUNCTION_KEY = os.getenv("FUNCTION_KEY", "")

st.set_page_config(
    page_title="Streamlit Frontend",
    page_icon="🚀",
    layout="wide"
)


def get_user_info():
    """
    Extract user information from Easy Auth headers.
    When deployed to Azure App Service with Easy Auth enabled,
    user claims are available in request headers.
    """
    # In local development, these won't be available
    user_principal = st.session_state.get('user_principal', 'Local User')
    user_name = st.session_state.get('user_name', 'Development Mode')

    # In Azure, these would come from headers injected by Easy Auth
    # X-MS-CLIENT-PRINCIPAL-NAME, X-MS-CLIENT-PRINCIPAL-ID, etc.

    return {
        'principal': user_principal,
        'name': user_name
    }


def call_backend_function(endpoint: str, data: dict = None):
    """
    Call the backend Azure Function with function key authentication.

    Args:
        endpoint: The function endpoint (e.g., 'ProcessData')
        data: Optional JSON data to send

    Returns:
        Response from the function
    """
    url = f"{BACKEND_FUNCTION_URL}/{endpoint}"
    headers = {
        "x-functions-key": FUNCTION_KEY,
        "Content-Type": "application/json"
    }

    try:
        if data:
            response = requests.post(
                url, headers=headers, json=data, timeout=30)
        else:
            response = requests.get(url, headers=headers, timeout=30)

        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        st.error(f"Error calling backend: {str(e)}")
        return None


def main():
    """Main application"""

    # Header
    st.title("🚀 Streamlit Frontend Application")
    st.markdown("---")

    # User Information (from Easy Auth)
    user_info = get_user_info()
    with st.sidebar:
        st.header("User Information")
        st.write(f"**Name:** {user_info['name']}")
        st.write(f"**Principal:** {user_info['principal']}")
        st.markdown("---")
        st.info("Authenticated via Azure Easy Auth (Entra ID)")

    # Main content
    col1, col2 = st.columns(2)

    with col1:
        st.header("📊 Dashboard")
        st.write("Welcome to the application frontend!")

        # Example: Call backend function
        if st.button("Call Backend Health Check"):
            with st.spinner("Calling backend..."):
                result = call_backend_function("health")
                if result:
                    st.success("Backend is healthy!")
                    st.json(result)

    with col2:
        st.header("⚙️ Configuration")
        st.write(f"**Backend URL:** {BACKEND_FUNCTION_URL}")
        st.write(
            f"**Function Key:** {'*' * 10 if FUNCTION_KEY else 'Not Set'}")

    # Example: LangChain interaction through backend
    st.markdown("---")
    st.header("💬 LangChain Query")

    user_query = st.text_area(
        "Enter your query:",
        placeholder="Ask a question to be processed by the LangChain backend..."
    )

    if st.button("Submit Query"):
        if user_query:
            with st.spinner("Processing query..."):
                result = call_backend_function("ProcessQuery", {
                    "query": user_query,
                    "user": user_info['principal']
                })

                if result:
                    st.success("Query processed successfully!")
                    st.write("**Response:**")
                    st.write(result.get('response', 'No response'))
        else:
            st.warning("Please enter a query")


if __name__ == "__main__":
    main()
