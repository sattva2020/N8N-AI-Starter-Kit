#!/usr/bin/env bash
# Temporary runner for non-interactive setup
export DOMAIN_NAME="sattva-ai.top"
export ACME_EMAIL="ruslan.griban@gmail.com"
export OPENAI_API_KEY="sk-test-PLACEHOLDER"
export SETUP_MODE="template"

bash ./scripts/setup.sh
