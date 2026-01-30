#!/bin/bash
# Startup script for Azure App Service

# Install dependencies
pip install -r requirements.txt

# Run Streamlit
streamlit run app.py --server.port=8000 --server.address=0.0.0.0
