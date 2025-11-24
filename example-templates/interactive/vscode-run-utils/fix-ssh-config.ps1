# PowerShell script to fix corrupted SSH config
# This script removes malformed entries from your SSH config file

$sshConfig = "$env:USERPROFILE\.ssh\config"

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Fixing SSH Config" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

if (!(Test-Path $sshConfig)) {
    Write-Host "SSH config file not found at: $sshConfig" -ForegroundColor Red
    exit 1
}

Write-Host "Backing up current SSH config..." -ForegroundColor Yellow
Copy-Item $sshConfig "$sshConfig.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Write-Host "Backup created" -ForegroundColor Green
Write-Host ""

Write-Host "Reading SSH config..." -ForegroundColor Yellow
$content = Get-Content $sshConfig -Raw

Write-Host "Removing corrupted entries..." -ForegroundColor Yellow

# Remove entries with malformed IPs like "$110.233.106.182"
$content = $content -replace '\$\d+\.\d+\.\d+\.\d+', ''

# Remove empty lines
$lines = $content -split "`n" | Where-Object { $_.Trim() -ne "" }

# Clean up any lines with just whitespace or invalid characters
$cleanedLines = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i].TrimEnd()
    
    # Skip obviously malformed lines
    if ($line -match '^\s*$' -or $line -match '\$\d+\.\d+\.\d+\.\d+') {
        continue
    }
    
    # If we find a Host entry, check if the next line is problematic
    if ($line -match '^Host\s+') {
        $cleanedLines += $line
    } elseif ($line -match '^\s+(HostName|User|Port|IdentityFile|StrictHostKeyChecking|UserKnownHostsFile)\s+.+') {
        # Valid SSH config option
        $cleanedLines += $line
    }
}

# Write cleaned config
$cleanedContent = $cleanedLines -join "`n"
Set-Content -Path $sshConfig -Value $cleanedContent

Write-Host "SSH config cleaned!" -ForegroundColor Green
Write-Host ""

Write-Host "Current SSH config:" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan
Get-Content $sshConfig
Write-Host ""

Write-Host "======================================" -ForegroundColor Green
Write-Host "SSH Config Fixed!" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host ""
Write-Host "You can now use SSH commands without errors" -ForegroundColor Green
Write-Host ""
Write-Host "Note: Run .\add-ssh-key.ps1 to regenerate the vscode-pod entry" -ForegroundColor Yellow
Write-Host ""
