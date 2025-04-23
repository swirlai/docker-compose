#!/usr/bin/env python3

import requests

try:
    headers = {
        "Content-Type": "application/json",
        "Host": "localhost"
    }
    response = requests.get("http://localhost:8000/swirl/health/celery/", headers=headers)
    response.raise_for_status()  # Raise an exception for HTTP errors
    print("Health check passed")
except requests.exceptions.RequestException as e:
    print(f"Health check failed: {e}")
    exit(1)