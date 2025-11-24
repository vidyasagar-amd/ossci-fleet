# PowerShell script to set up GPG key for GitHub
param(
    # FIXME: Update these parameters for your environment
    [string]$Namespace = "rocm-dev",
    [string]$PodName = "vscode-statefulset-yourname-0",  # Must match vscode-session.yml
    [string]$KubeConfig = "C:\Users\YOUR_USERNAME\.kube\configs\your-cluster-config.conf",
    [string]$Name = "",  # FIXME: Your full name for GPG key
    [string]$Email = ""  # FIXME: Your email (must match GitHub account email)
)

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "GPG Key Setup for GitHub" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Setup kubectl parameters
$kubectlParams = @()
if ($KubeConfig -and (Test-Path $KubeConfig)) {
    $kubectlParams = @("--kubeconfig", $KubeConfig)
}

# Get user input if not provided
if ([string]::IsNullOrWhiteSpace($Name)) {
    $Name = Read-Host "Enter your name for GPG key (e.g., 'John Doe')"
}

if ([string]::IsNullOrWhiteSpace($Email)) {
    $Email = Read-Host "Enter your email for GPG key (must match GitHub email)"
}

Write-Host ""
Write-Host "Installing GPG..." -ForegroundColor Yellow

# Install GPG
kubectl @kubectlParams exec -n $Namespace $PodName -- bash -c "which gpg || apt-get install -y gnupg" 2>&1 | Out-Null

Write-Host "Generating GPG key (this may take a moment)..." -ForegroundColor Yellow
Write-Host ""

# Generate GPG key
$gpgGenCmd = @"
gpg --batch --gen-key <<EOF
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: $Name
Name-Email: $Email
Expire-Date: 0
%no-protection
%commit
EOF
"@

kubectl @kubectlParams exec -n $Namespace $PodName -- su - sshuser -c "$gpgGenCmd" 2>&1 | Out-Null

Write-Host "GPG key generated!" -ForegroundColor Green
Write-Host ""

# Get key ID
$getKeyId = "gpg --list-secret-keys --keyid-format=long | grep sec | awk '{print `$2}' | cut -d'/' -f2 | head -n1"
$keyId = kubectl @kubectlParams exec -n $Namespace $PodName -- su - sshuser -c "$getKeyId"
$keyId = $keyId.Trim()

Write-Host "GPG Key ID: $keyId" -ForegroundColor Cyan
Write-Host ""

# Export public key
Write-Host "======================================" -ForegroundColor Green
Write-Host "GPG Public Key (ASCII Armor)" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host ""
Write-Host "Copy the entire block below (including BEGIN/END lines)" -ForegroundColor Yellow
Write-Host "and add it to GitHub at: https://github.com/settings/keys" -ForegroundColor Yellow
Write-Host ""
Write-Host "========== START COPYING HERE ==========" -ForegroundColor Cyan

$publicKey = kubectl @kubectlParams exec -n $Namespace $PodName -- su - sshuser -c "gpg --armor --export $keyId"
Write-Host $publicKey

Write-Host "=========== STOP COPYING HERE ===========" -ForegroundColor Cyan
Write-Host ""

# Configure git to use GPG key
Write-Host "Configuring git to use GPG key..." -ForegroundColor Yellow

$gitGpgConfig = "git config --global user.signingkey $keyId; git config --global commit.gpgsign true; git config --global tag.gpgsign true; echo '$keyId' > /workspace/.gpg-key-id"

kubectl @kubectlParams exec -n $Namespace $PodName -- su - sshuser -c "$gitGpgConfig" | Out-Null

Write-Host "Git GPG configuration complete!" -ForegroundColor Green
Write-Host ""

Write-Host "======================================" -ForegroundColor Green
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host ""

Write-Host "Configuration saved:" -ForegroundColor Cyan
Write-Host "  - GPG keys stored in: /workspace/.gnupg/ (persistent)" -ForegroundColor White
Write-Host "  - Key ID saved in: /workspace/.gpg-key-id" -ForegroundColor White
Write-Host "  - All commits will be automatically signed" -ForegroundColor White
Write-Host ""

Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Copy the GPG public key from above" -ForegroundColor White
Write-Host "2. Go to https://github.com/settings/keys" -ForegroundColor White
Write-Host "3. Click 'New GPG key'" -ForegroundColor White
Write-Host "4. Paste the entire key block" -ForegroundColor White
Write-Host "5. Click 'Add GPG key'" -ForegroundColor White
Write-Host ""

Write-Host "To export key again later, run in pod:" -ForegroundColor Cyan
Write-Host "  gpg --armor --export `$(cat /workspace/.gpg-key-id)" -ForegroundColor Yellow
Write-Host ""
