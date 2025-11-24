# PowerShell script to set up Git and GitHub CLI configuration
param(
    # FIXME: Update these parameters for your environment
    [string]$Namespace = "rocm-dev",
    [string]$PodName = "vscode-statefulset-yourname-0",  # Must match vscode-session.yml
    [string]$KubeConfig = "C:\Users\YOUR_USERNAME\.kube\configs\your-cluster-config.conf",
    [string]$GitUserName = "",  # FIXME: Set your git name or leave blank to be prompted
    [string]$GitUserEmail = "",  # FIXME: Set your git email or leave blank to be prompted
    [string]$GitHubUsername = ""  # Optional GitHub username
)

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Git and GitHub CLI Setup" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Setup kubectl parameters
$kubectlParams = @()
if ($KubeConfig -and (Test-Path $KubeConfig)) {
    $kubectlParams = @("--kubeconfig", $KubeConfig)
}

# Get user input if not provided
if ([string]::IsNullOrWhiteSpace($GitUserName)) {
    $GitUserName = Read-Host "Enter your Git name (e.g., 'John Doe')"
}

if ([string]::IsNullOrWhiteSpace($GitUserEmail)) {
    $GitUserEmail = Read-Host "Enter your Git email (e.g., 'john@example.com')"
}

if ([string]::IsNullOrWhiteSpace($GitHubUsername)) {
    $GitHubUsername = Read-Host "Enter your GitHub username (optional, press Enter to skip)"
}

Write-Host ""
Write-Host "Configuring git in pod..." -ForegroundColor Yellow

# Configure git (use single line to avoid line ending issues)
$gitConfig = "git config --global user.name '$GitUserName'; git config --global user.email '$GitUserEmail'; git config --global init.defaultBranch main; git config --global core.editor vim; echo 'Git configured successfully'"

kubectl @kubectlParams exec -n $Namespace $PodName -- su - sshuser -c "$gitConfig"

Write-Host "Git configuration complete!" -ForegroundColor Green
Write-Host ""

# Display current configuration
Write-Host "Current git configuration:" -ForegroundColor Cyan
kubectl @kubectlParams exec -n $Namespace $PodName -- su - sshuser -c "git config --global --list | grep -E '(user|init)'"

Write-Host ""
Write-Host "======================================" -ForegroundColor Green
Write-Host "GitHub CLI Setup" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host ""

Write-Host "To authenticate with GitHub CLI, SSH into the pod and run:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  gh auth login" -ForegroundColor Yellow
Write-Host ""
Write-Host "Then follow the prompts to:" -ForegroundColor White
Write-Host "  1. Choose GitHub.com"
Write-Host "  2. Choose HTTPS or SSH protocol"
Write-Host "  3. Authenticate via web browser or token"
Write-Host ""

Write-Host "Alternatively, create a GitHub token and run:" -ForegroundColor Cyan
Write-Host "  echo 'YOUR_GITHUB_TOKEN' | gh auth login --with-token" -ForegroundColor Yellow
Write-Host ""

Write-Host "After authentication, you can:" -ForegroundColor Cyan
Write-Host "  - Clone repos: gh repo clone owner/repo" -ForegroundColor White
Write-Host "  - Create repos: gh repo create" -ForegroundColor White
Write-Host "  - View PRs: gh pr list" -ForegroundColor White
Write-Host "  - And more: gh --help" -ForegroundColor White
Write-Host ""

Write-Host "======================================" -ForegroundColor Green
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host ""

Write-Host "Git configuration saved in /workspace/.gitconfig (persistent)" -ForegroundColor Green
Write-Host ""
