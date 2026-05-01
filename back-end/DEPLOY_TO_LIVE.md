Deployment options for branch `fix/cves-20260428`

This file provides safe, copy-paste commands to update a live server repository. Replace placeholders (user, live-server, /path/to/repo, ./deploy-script.sh) with real values.

Prechecks (run locally before remote changes):

```bash
# ensure branch is pushed
git fetch origin
git checkout fix/cves-20260428
git status --porcelain
git push origin fix/cves-20260428
mvn -DskipTests package   # confirm build
```

Option A — Checkout branch on server (no merge)

Run from your workstation (SSH to server):

```bash
ssh user@live-server \
  'set -e; cd /path/to/repo || exit 1; git fetch origin; git checkout -f fix/cves-20260428; git reset --hard origin/fix/cves-20260428; ./deploy-script.sh'
```

Notes: This will place the working tree on the branch tip. Useful when you want the server running this branch exactly.

Option B — Merge branch into `main` on the server and deploy

```bash
ssh user@live-server \
  'set -e; cd /path/to/repo || exit 1; git fetch origin; git checkout main; git pull origin main; git merge --no-ff origin/fix/cves-20260428; git push origin main; ./deploy-script.sh'
```

Notes: Use when you want to update `main` on the server and trigger the canonical deploy flow. Ensure reviewers approved the PR before merging.

Option C — Push branch directly to a bare repo on the server (one-time remote add)

Run locally to add the remote (one-time):

```bash
# one-time (local)
git remote add live ssh://user@live-server/~/git/project.git
# push branch to update main on the bare repo
git push live fix/cves-20260428:refs/heads/main
```

Notes: Useful when the server runs a bare repository with hooks to deploy on push. Verify the bare repo's hook behavior first.

Safety and rollback

- Take a quick backup of current production state (DB snapshot or files) before deploy, if applicable.
- If deploy fails, rollback options:
  - Checkout previous commit on server: `git reset --hard <previous-commit>` and restart services
  - If using `main` merge, revert the merge commit: `git revert -m 1 <merge-commit>`

If you want me to run any of these commands from this environment, provide:
- which option (A / B / C),
- `user@host` for SSH, and
- server repo path (e.g., `/var/www/project`), and
- the deploy command/script path to run after update (e.g., `./deploy-script.sh`) or the note that no script is required.

If you prefer to run them yourself, copy the appropriate block above, replace placeholders, and run from your terminal.
