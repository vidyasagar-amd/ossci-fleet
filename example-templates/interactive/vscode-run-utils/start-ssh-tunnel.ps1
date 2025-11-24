# PowerShell script to start SSH tunnel to VSCode pod
param(
    # FIXME: Update these parameters for your environment
    [string]$LocalPort = "2222",
    [string]$Namespace = "rocm-dev",
    [string]$PodName = "vscode-statefulset-yourname-0",  # Must match vscode-session.yml
    [string]$KubeConfig = "C:\Users\YOUR_USERNAME\.kube\configs\your-cluster-config.conf"
)

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Starting SSH Tunnel to VSCode Pod" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Setup kubectl parameters
$kubectlParams = @()
if ($KubeConfig -and (Test-Path $KubeConfig)) {
    $kubectlParams = @("--kubeconfig", $KubeConfig)
    Write-Host "Using kubeconfig: $KubeConfig" -ForegroundColor Gray
}

# Check if pod exists
Write-Host "Checking pod status..." -ForegroundColor Yellow
$podStatus = kubectl @kubectlParams get pod $PodName -n $Namespace -o jsonpath='{.status.phase}' 2>$null

if ([string]::IsNullOrWhiteSpace($podStatus)) {
    Write-Host "Error: Pod '$PodName' not found in namespace '$Namespace'" -ForegroundColor Red
    exit 1
}

if ($podStatus -ne "Running") {
    Write-Host "Error: Pod '$PodName' is not running (status: $podStatus)" -ForegroundColor Red
    exit 1
}

Write-Host "Pod is running" -ForegroundColor Green
Write-Host ""

# Update SSH config to use localhost
$sshDir = "$env:USERPROFILE\.ssh"
$configFile = "$sshDir\config"
$privateKey = "$sshDir\id_rsa"

$configEntry = @"

Host vscode-pod-tunnel
    HostName localhost
    Port $LocalPort
    User sshuser
    IdentityFile $privateKey
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
"@

# Check if config exists and update/add entry
if (Test-Path $configFile) {
    $configContent = Get-Content $configFile -Raw
    if ($configContent -notmatch "Host vscode-pod-tunnel") {
        Add-Content -Path $configFile -Value $configEntry
        Write-Host "SSH config updated with tunnel entry" -ForegroundColor Green
    }
} else {
    Set-Content -Path $configFile -Value $configEntry
    Write-Host "SSH config created with tunnel entry" -ForegroundColor Green
}

Write-Host ""
Write-Host "Starting port forwarding..." -ForegroundColor Yellow
Write-Host "This window must stay open for the SSH connection to work!" -ForegroundColor Red
Write-Host ""
Write-Host "======================================" -ForegroundColor Green
Write-Host "In a NEW terminal window, connect using:" -ForegroundColor Green
Write-Host ""
Write-Host "    ssh vscode-pod-tunnel" -ForegroundColor Yellow
Write-Host ""
Write-Host "Or directly:" -ForegroundColor White
Write-Host "    ssh sshuser@localhost -p $LocalPort" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press Ctrl+C to stop the tunnel" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Green
Write-Host ""

# Start port forwarding
kubectl @kubectlParams port-forward -n $Namespace $PodName ${LocalPort}:22
