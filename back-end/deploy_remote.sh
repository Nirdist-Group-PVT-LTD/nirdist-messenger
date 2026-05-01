#!/usr/bin/env bash
set -euo pipefail

# deploy_remote.sh
# Usage (example):
# REMOTE_USER_HOST=user@live-server REMOTE_REPO_PATH=/var/www/project BRANCH=fix/cves-20260428 DEPLOY_CMD=./deploy-script.sh ./deploy_remote.sh

REMOTE_USER_HOST=${REMOTE_USER_HOST:-}
REMOTE_REPO_PATH=${REMOTE_REPO_PATH:-}
BRANCH=${BRANCH:-fix/cves-20260428}
DEPLOY_CMD=${DEPLOY_CMD:-}

if [ -z "$REMOTE_USER_HOST" ] || [ -z "$REMOTE_REPO_PATH" ]; then
  echo "ERROR: REMOTE_USER_HOST and REMOTE_REPO_PATH must be set as environment variables"
  echo "Example: REMOTE_USER_HOST=user@live-server REMOTE_REPO_PATH=/var/www/project BRANCH=fix/cves-20260428 DEPLOY_CMD=./deploy-script.sh ./deploy_remote.sh"
  exit 2
fi

echo "Pushing and checking remote branch..."
# ensure branch is pushed locally
git fetch origin "$BRANCH"
LOCAL_BRANCH_COMMIT=$(git rev-parse origin/"$BRANCH")
if [ -z "$LOCAL_BRANCH_COMMIT" ]; then
  echo "ERROR: branch $BRANCH not found on origin. Push the branch first." >&2
  exit 3
fi

echo "Running remote update on $REMOTE_USER_HOST:$REMOTE_REPO_PATH"
ssh "$REMOTE_USER_HOST" "set -e; cd '$REMOTE_REPO_PATH' || exit 1; git fetch origin; git checkout -f '$BRANCH'; git reset --hard origin/'$BRANCH'"

if [ -n "$DEPLOY_CMD" ]; then
  echo "Running remote deploy command: $DEPLOY_CMD"
  ssh "$REMOTE_USER_HOST" "set -e; cd '$REMOTE_REPO_PATH' || exit 1; $DEPLOY_CMD"
else
  echo "No DEPLOY_CMD provided; updated working tree to $BRANCH on server."
fi

echo "Remote update complete."
