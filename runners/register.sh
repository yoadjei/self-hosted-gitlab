#!/bin/bash
set -e

GITLAB_URL="${GITLAB_URL:-http://gitlab}"
RUNNER_NAME="${RUNNER_NAME:-runner}"
RUNNER_TAG="${RUNNER_TAG:-default}"
RUNNER_IMAGE="${RUNNER_IMAGE:-alpine:latest}"

echo "==> Waiting for GitLab at ${GITLAB_URL} to become ready..."

until curl --silent --output /dev/null --write-out "%{http_code}" "${GITLAB_URL}" | grep -qE "^(200|302)$"; do
  echo "    GitLab not ready yet — retrying in 10s..."
  sleep 10
done

echo "==> GitLab is up. Registering runner '${RUNNER_NAME}'..."

gitlab-runner register \
  --non-interactive \
  --url "${GITLAB_URL}" \
  --token "${RUNNER_TOKEN}" \
  --name "${RUNNER_NAME}" \
  --executor "docker" \
  --docker-image "${RUNNER_IMAGE}" \
  --docker-volumes "/var/run/docker.sock:/var/run/docker.sock"

echo "==> Runner '${RUNNER_NAME}' registered. Starting runner process..."

exec gitlab-runner run --user=gitlab-runner --working-directory=/home/gitlab-runner
