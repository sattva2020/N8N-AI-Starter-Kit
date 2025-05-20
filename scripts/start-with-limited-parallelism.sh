#!/bin/bash

# Stop all running containers
docker-compose down

# Prune networks
docker network prune -f

# Fix Supabase environment variables
if [ -f ./scripts/fix-env-vars.sh ]; then
  echo "Fixing Supabase environment variables..."
  bash ./scripts/fix-env-vars.sh
else
  echo "Script fix-env-vars.sh not found. Skipping this step."
  
  # Manual fix for environment variables
  if [ -f .env ]; then
    if grep -q "SUPABASE_ANON_KEY" .env && ! grep -q "^ANON_KEY=" .env; then
      ANON_KEY_VALUE=$(grep -E "^SUPABASE_ANON_KEY=" .env | cut -d '=' -f2)
      echo "ANON_KEY=$ANON_KEY_VALUE" >> .env
      echo "✅ Added ANON_KEY variable"
    fi
    
    if grep -q "SUPABASE_SERVICE_ROLE_KEY" .env && ! grep -q "^SERVICE_ROLE_KEY=" .env; then
      SERVICE_KEY_VALUE=$(grep -E "^SUPABASE_SERVICE_ROLE_KEY=" .env | cut -d '=' -f2)
      echo "SERVICE_ROLE_KEY=$SERVICE_KEY_VALUE" >> .env
      echo "✅ Added SERVICE_ROLE_KEY variable"
    fi
  fi
fi

# Limit parallelism by setting the COMPOSE_PARALLEL_LIMIT
export COMPOSE_PARALLEL_LIMIT=1

# Start the system with the CPU profile
docker-compose --profile cpu up -d

# Check the status
docker-compose ps
