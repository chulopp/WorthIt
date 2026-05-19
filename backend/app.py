"""Compatibility entry point.

Use `uvicorn main:app --reload --port 8000` for local development.
This module keeps `uvicorn app:app` working without carrying a separate Flask
sample app that does not belong to the WorthIt backend contract.
"""

from main import app

