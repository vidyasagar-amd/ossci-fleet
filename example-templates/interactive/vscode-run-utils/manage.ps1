# SSH StatefulSet Management Script (PowerShell)
# Usage: .\manage.ps1 [up|down|restart|status|logs|ssh|cleanup]

param(
    [Parameter(Position=0)]
    [string]$Command
)

# FIXME: Update these variables for your environment
$NAMESPACE = "rocm-dev"  # Your Kubernetes namespace
$STATEFULSET = "vscode-statefulset-yourname"  # Must match name in vscode-session.yml
$KUBECONFIG = "--kubeconfig", "C:\Users\YOUR_USERNAME\.kube\configs\your-cluster-config.conf"  # Path to your kubeconfig

function Show-Usage {
    Write-Host "SSH StatefulSet Management" -ForegroundColor Cyan
    Write-Host "==========================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: .\manage.ps1 [command]"
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor Yellow
    Write-Host "  up        - Deploy the StatefulSet and Services"
    Write-Host "  down      - Scale down to 0 replicas (keep services)"
    Write-Host "  restart   - Restart the StatefulSet (down then up)"
    Write-Host "  status    - Show current status"
    Write-Host "  logs      - View pod logs (follow mode)"
    Write-Host "  ssh       - Connect to pod via kubectl exec"
    Write-Host "  cleanup   - Remove all resources (keeps PVC)"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\manage.ps1 up       # Start everything"
    Write-Host "  .\manage.ps1 down     # Stop the pod"
    Write-Host "  .\manage.ps1 status   # Check status"
    Write-Host ""
}

if (-not $Command) {
    Show-Usage
    exit 1
}

$cmd = $Command.ToLower()

if ($cmd -eq "up") {
    Write-Host "Spinning up SSH StatefulSet..." -ForegroundColor Green
    kubectl @KUBECONFIG apply -f vscode-session.yml
    kubectl @KUBECONFIG apply -f vscode-service.yml
    Write-Host "Deployment initiated" -ForegroundColor Green
    Write-Host ""
    Write-Host "Waiting for pod to be ready..." -ForegroundColor Yellow
    kubectl @KUBECONFIG wait --for=condition=ready pod -l app=vscode-session -n $NAMESPACE --timeout=300s
    Write-Host ""
    Write-Host "Getting pod IP address..." -ForegroundColor Cyan
    Start-Sleep -Seconds 2
    kubectl @KUBECONFIG logs "$STATEFULSET-0" -n $NAMESPACE | Select-Object -First 10
    Write-Host ""
    Write-Host "SSH StatefulSet is up and running!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "   1. Run: .\add-ssh-key.ps1 (to inject your SSH key)" -ForegroundColor Yellow
    Write-Host "   2. Run: .\start-ssh-tunnel.ps1 (to start port forwarding)" -ForegroundColor Yellow
    Write-Host "   3. Connect: ssh vscode-pod-tunnel" -ForegroundColor Yellow
}
elseif ($cmd -eq "down") {
    Write-Host "Spinning down SSH StatefulSet..." -ForegroundColor Yellow
    kubectl @KUBECONFIG scale statefulset $STATEFULSET -n $NAMESPACE --replicas=0
    Write-Host "StatefulSet scaled down to 0 replicas" -ForegroundColor Green
    Write-Host "Note: Services are still running. Use 'cleanup' to remove everything." -ForegroundColor Cyan
}
elseif ($cmd -eq "restart") {
    Write-Host "Restarting SSH StatefulSet..." -ForegroundColor Cyan
    Write-Host "Scaling down..." -ForegroundColor Yellow
    kubectl @KUBECONFIG scale statefulset $STATEFULSET -n $NAMESPACE --replicas=0
    Write-Host "Waiting for pod to terminate..." -ForegroundColor Yellow
    kubectl @KUBECONFIG wait --for=delete pod -l app=vscode-session -n $NAMESPACE --timeout=60s 2>$null
    Start-Sleep -Seconds 2
    Write-Host "Scaling up..." -ForegroundColor Green
    kubectl @KUBECONFIG scale statefulset $STATEFULSET -n $NAMESPACE --replicas=1
    Write-Host "Waiting for pod to be ready..." -ForegroundColor Yellow
    kubectl @KUBECONFIG wait --for=condition=ready pod -l app=vscode-session -n $NAMESPACE --timeout=300s
    Write-Host ""
    Write-Host "Getting pod IP address..." -ForegroundColor Cyan
    Start-Sleep -Seconds 2
    kubectl @KUBECONFIG logs "$STATEFULSET-0" -n $NAMESPACE | Select-Object -First 10
    Write-Host ""
    Write-Host "SSH StatefulSet restarted successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Note: Run .\add-ssh-key.ps1 to re-inject your SSH key" -ForegroundColor Yellow
}
elseif ($cmd -eq "status") {
    Write-Host "SSH StatefulSet Status" -ForegroundColor Cyan
    Write-Host "=======================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "StatefulSet:" -ForegroundColor Yellow
    kubectl @KUBECONFIG get statefulset $STATEFULSET -n $NAMESPACE
    Write-Host ""
    Write-Host "Pods:" -ForegroundColor Yellow
    kubectl @KUBECONFIG get pods -l app=vscode-session -n $NAMESPACE
    Write-Host ""
    Write-Host "Services:" -ForegroundColor Yellow
    kubectl @KUBECONFIG get svc -n $NAMESPACE | Select-String "vscode-service"
    Write-Host ""
    Write-Host "PVC:" -ForegroundColor Yellow
    # FIXME: Update PVC name if different
    kubectl @KUBECONFIG get pvc your-pvc-name -n $NAMESPACE 2>$null
    Write-Host ""
    Write-Host "Pod IP Address:" -ForegroundColor Cyan
    kubectl @KUBECONFIG logs "$STATEFULSET-0" -n $NAMESPACE 2>$null | Select-Object -First 10
}
elseif ($cmd -eq "cleanup") {
    Write-Host "Removing all SSH StatefulSet resources..." -ForegroundColor Red
    $response = Read-Host "Are you sure? This will delete the StatefulSet and Services (PVC will be kept). [y/N]"
    if ($response -eq 'y' -or $response -eq 'Y') {
        kubectl @KUBECONFIG delete statefulset $STATEFULSET -n $NAMESPACE 2>$null
        kubectl @KUBECONFIG delete svc vscode-service vscode-service-external -n $NAMESPACE 2>$null
        Write-Host "Resources removed" -ForegroundColor Green
        Write-Host "Note: PVC was NOT deleted (your data is preserved)" -ForegroundColor Cyan
    } else {
        Write-Host "Cleanup cancelled" -ForegroundColor Yellow
    }
}
elseif ($cmd -eq "logs") {
    Write-Host "Viewing SSH StatefulSet logs..." -ForegroundColor Cyan
    kubectl @KUBECONFIG logs "$STATEFULSET-0" -n $NAMESPACE -f
}
elseif ($cmd -eq "ssh") {
    Write-Host "Connecting to SSH pod via kubectl exec..." -ForegroundColor Cyan
    kubectl @KUBECONFIG exec -it "$STATEFULSET-0" -n $NAMESPACE -- /bin/bash
}
else {
    Show-Usage
    exit 1
}
