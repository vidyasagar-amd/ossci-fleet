# Automated PowerShell script to inject SSH key into running VSCode pod
param(
    # FIXME: Update these parameters for your environment
    [string]$Namespace = "rocm-dev",
    [string]$StatefulSet = "vscode-statefulset-yourname",  # Must match vscode-session.yml
    [string]$KubeConfig = "C:\Users\YOUR_USERNAME\.kube\configs\your-cluster-config.conf"
)

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Automated SSH Key Injection for VSCode Pod" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Setup kubectl parameters
$kubectlParams = @()
if ($KubeConfig -and (Test-Path $KubeConfig)) {
    $kubectlParams = @("--kubeconfig", $KubeConfig)
    Write-Host "Using kubeconfig: $KubeConfig" -ForegroundColor Gray
} elseif ($KubeConfig) {
    Write-Host "Warning: Kubeconfig file not found at $KubeConfig, using default config" -ForegroundColor Yellow
}

# Check if kubectl is available
try {
    kubectl @kubectlParams version --client 2>&1 | Out-Null
} catch {
    Write-Host "Error: kubectl is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install kubectl first: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/" -ForegroundColor Yellow
    exit 1
}

# Check SSH key
$sshDir = "$env:USERPROFILE\.ssh"
$privateKey = "$sshDir\id_rsa"
$publicKey = "$sshDir\id_rsa.pub"

# Generate SSH key if it doesn't exist
if (!(Test-Path $publicKey)) {
    Write-Host "No SSH key found. Generating new SSH key pair..." -ForegroundColor Yellow
    
    if (!(Test-Path $sshDir)) {
        New-Item -ItemType Directory -Force -Path $sshDir | Out-Null
    }
    
    # Generate key without passphrase for passwordless access
    ssh-keygen -t rsa -b 4096 -f $privateKey -N '""' -q
    Write-Host "SSH key pair generated successfully!" -ForegroundColor Green
    Write-Host ""
}

# Read public key
$pubKeyContent = Get-Content $publicKey -Raw
$pubKeyContent = $pubKeyContent.Trim()

Write-Host "Your SSH public key:" -ForegroundColor Cyan
Write-Host $pubKeyContent
Write-Host ""

# StatefulSet creates predictable pod names: statefulset-name-ordinal
$podName = "$StatefulSet-0"
Write-Host "Using StatefulSet pod: $podName" -ForegroundColor Cyan

# Check if pod exists and is running
Write-Host "Checking pod status..." -ForegroundColor Yellow
$podStatus = kubectl @kubectlParams get pod $podName -n $Namespace -o jsonpath='{.status.phase}' 2>$null

if ([string]::IsNullOrWhiteSpace($podStatus)) {
    Write-Host "Error: Pod '$podName' not found in namespace '$Namespace'" -ForegroundColor Red
    Write-Host "Please ensure the StatefulSet is deployed using: .\manage.ps1 up" -ForegroundColor Yellow
    exit 1
}

if ($podStatus -ne "Running") {
    Write-Host "Error: Pod '$podName' is not running (status: $podStatus)" -ForegroundColor Red
    Write-Host "Please wait for the pod to be ready or redeploy using: .\manage.ps1 restart" -ForegroundColor Yellow
    exit 1
}

Write-Host "Pod is running" -ForegroundColor Green

# Get pod IP
Write-Host "Getting pod IP address..." -ForegroundColor Yellow
$podIP = kubectl @kubectlParams get pod -n $Namespace $podName -o jsonpath='{.status.podIP}'

if ([string]::IsNullOrWhiteSpace($podIP)) {
    Write-Host "Error: Could not get pod IP address" -ForegroundColor Red
    exit 1
}

Write-Host "Pod IP: $podIP" -ForegroundColor Green
Write-Host ""

# Inject SSH key into pod
Write-Host "Adding SSH key to pod..." -ForegroundColor Yellow

# Escape the public key content for shell
$escapedKey = $pubKeyContent -replace "'", "'\\''"

# Note: Using /workspace as the home directory (configured in vscode-session.yml)
$command = "mkdir -p /workspace/.ssh; echo '$escapedKey' >> /workspace/.ssh/authorized_keys; chown -R sshuser:sshuser /workspace/.ssh; chmod 700 /workspace/.ssh; chmod 600 /workspace/.ssh/authorized_keys; echo 'SSH key added successfully'"

$result = kubectl @kubectlParams exec -n $Namespace $podName -- bash -c "$command" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "SSH key successfully added!" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "Error adding SSH key:" -ForegroundColor Red
    Write-Host $result
    exit 1
}

# Update or create SSH config
$configFile = "$sshDir\config"
$configEntry = @"

Host vscode-pod
    HostName $podIP
    User sshuser
    Port 22
    IdentityFile $privateKey
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
"@

Write-Host "Updating SSH config..." -ForegroundColor Yellow

# Check if config exists and if entry already exists
$updateConfig = $true
if (Test-Path $configFile) {
    $configContent = Get-Content $configFile -Raw
    if ($configContent -match "Host vscode-pod") {
        Write-Host "SSH config entry already exists. Updating IP address..." -ForegroundColor Yellow
        $configContent = $configContent -replace "(Host vscode-pod[\s\S]*?HostName\s+)[\d\.]+", "`$1$podIP"
        Set-Content -Path $configFile -Value $configContent
        $updateConfig = $false
    }
}

if ($updateConfig) {
    Add-Content -Path $configFile -Value $configEntry
    Write-Host "SSH config updated" -ForegroundColor Green
}

Write-Host ""
Write-Host "======================================" -ForegroundColor Green
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host ""
Write-Host "You can now connect using:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Option 1 (using config alias):" -ForegroundColor White
Write-Host "    ssh vscode-pod" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Option 2 (direct connection):" -ForegroundColor White
Write-Host "    ssh sshuser@$podIP" -ForegroundColor Yellow
Write-Host ""
Write-Host "SSH key authentication only (password login disabled)" -ForegroundColor Green
Write-Host ""
Write-Host "Note: For port forwarding from outside the cluster, use .\start-ssh-tunnel.ps1" -ForegroundColor Cyan
Write-Host ""
