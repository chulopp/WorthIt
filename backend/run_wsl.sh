#!/bin/bash
cd "$(dirname "$0")"
../.venv/bin/python scripts/scrape_missing_july.py
