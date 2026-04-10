#!/bin/bash
# Hits the GitLab API to create runner auth tokens and writes them to .env.
# Run this after GitLab is up, before starting the runner containers.

set -e

ENV_FILE="$(dirname "$0")/../.env"

if [ ! -f "${ENV_FILE}" ]; then
  echo "ERROR: .env file not found. Copy .env.example to .env and fill in GITLAB_ROOT_PASSWORD."
  exit 1
fi

# Load .env
set -a
source "${ENV_FILE}"
set +a

GITLAB_URL="${GITLAB_URL:-http://localhost}"
GITLAB_CONTAINER="${GITLAB_CONTAINER:-gitlab}"

echo "==> Waiting for GitLab at ${GITLAB_URL}..."

until curl -s -o /dev/null -w "%{http_code}" "${GITLAB_URL}" | grep -qE "^(200|302)$"; do
  echo "    Not ready yet, retrying in 10s..."
  sleep 10
done

echo "==> GitLab is up. Creating a temporary API token..."

# Use gitlab-rails inside the container to create a short-lived personal access token.
# This avoids needing a pre-existing token — we generate one from root credentials.
PAT=$(docker exec "${GITLAB_CONTAINER}" gitlab-rails runner "
  user = User.find_by_username('root')
  token = user.personal_access_tokens.create!(
    name: 'bootstrap-token',
    scopes: ['api'],
    expires_at: 1.day.from_now
  )
  puts token.token
" 2>/dev/null | tail -1)

if [ -z "${PAT}" ]; then
  echo "ERROR: Failed to create a personal access token. Is the gitlab container running?"
  exit 1
fi

echo "==> Got API token. Creating runner registrations..."

# Create the python runner via the Runners API.
# runner_type=instance_type means it is available to all projects on the instance.
PYTHON_TOKEN=$(curl -s --request POST "${GITLAB_URL}/api/v4/user/runners" \
  --header "PRIVATE-TOKEN: ${PAT}" \
  --form "runner_type=instance_type" \
  --form "description=runner-python" \
  --form "tag_list=python" \
  | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

NODE_TOKEN=$(curl -s --request POST "${GITLAB_URL}/api/v4/user/runners" \
  --header "PRIVATE-TOKEN: ${PAT}" \
  --form "runner_type=instance_type" \
  --form "description=runner-node" \
  --form "tag_list=node" \
  | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "${PYTHON_TOKEN}" ] || [ -z "${NODE_TOKEN}" ]; then
  echo "ERROR: Failed to create one or both runner tokens. Check your GitLab API access."
  exit 1
fi

echo "==> Writing tokens to .env..."

# Remove any existing token lines, then append the new ones.
grep -v "PYTHON_RUNNER_TOKEN\|NODE_RUNNER_TOKEN" "${ENV_FILE}" > "${ENV_FILE}.tmp"
echo "PYTHON_RUNNER_TOKEN=${PYTHON_TOKEN}" >> "${ENV_FILE}.tmp"
echo "NODE_RUNNER_TOKEN=${NODE_TOKEN}" >> "${ENV_FILE}.tmp"
mv "${ENV_FILE}.tmp" "${ENV_FILE}"

echo ""
echo "Done. Tokens written to .env:"
echo "  PYTHON_RUNNER_TOKEN=${PYTHON_TOKEN}"
echo "  NODE_RUNNER_TOKEN=${NODE_TOKEN}"
echo ""
echo "Now run: docker compose up -d runner-python runner-node"
