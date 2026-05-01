<#
deploy_remote.ps1
Usage (example):
$env:REMOTE_USER_HOST='user@live-server'
$env:REMOTE_REPO_PATH='/var/www/project'
$env:BRANCH='fix/cves-20260428'
$env:DEPLOY_CMD='./deploy-script.sh'
.
# Then run (PowerShell):
./deploy_remote.ps1
#
# This script requires OpenSSH `ssh` available in PATH for remote commands.
#>

param()

$remote = $env:REMOTE_USER_HOST
$repo = $env:REMOTE_REPO_PATH
$branch = if ($env:BRANCH) { $env:BRANCH } else { 'fix/cves-20260428' }
$deployCmd = $env:DEPLOY_CMD

if (-not $remote -or -not $repo) {
    Write-Error "REMOTE_USER_HOST and REMOTE_REPO_PATH environment variables must be set."
    exit 2
}

Write-Output "Verifying branch exists on origin..."
$null = git fetch origin $branch
$commit = git rev-parse origin/$branch 2>$null
if (-not $commit) {
    Write-Error "Branch $branch not found on origin. Push it first."
    exit 3
}

$sshCmd = "ssh $remote 'set -e; cd `"$repo`" || exit 1; git fetch origin; git checkout -f $branch; git reset --hard origin/$branch'"
Write-Output "Running remote update: $sshCmd"
Invoke-Expression $sshCmd

if ($deployCmd) {
    $sshDeploy = "ssh $remote 'set -e; cd `"$repo`" || exit 1; $deployCmd'"
    Write-Output "Running remote deploy: $sshDeploy"
    Invoke-Expression $sshDeploy
} else {
    Write-Output "No DEPLOY_CMD provided; updated working tree to $branch on server."
}

Write-Output "Remote update complete."
