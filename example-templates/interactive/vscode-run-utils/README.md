# VSCode Remote Development Pod - Complete Setup Guide

This directory contains scripts and configurations to deploy a remote VSCode development environment on Kubernetes with full Git, GitHub CLI, and GPG signing support.

---

## Features

- Secure SSH Access: SSH key-only authentication (passwords disabled)
- Sudo Access: Passwordless sudo for the SSH user
- Persistent Storage: Home directory on persistent volume survives pod restarts
- GPG Commit Signing: Automatically sign all commits
- Development Tools: Git, GitHub CLI (gh), GPG, and more
- GPU Support: Configurable GPU allocation
- Easy Management: PowerShell scripts for common operations

---

## Table of Contents

1. [Files in This Directory](#files-in-this-directory)
2. [Prerequisites](#prerequisites)
3. [Kubectl Configuration](#kubectl-configuration)
4. [Kubectl Authentication (localhost:8000)](#kubectl-authentication-localhost8000)
5. [Personalizing Configuration Files](#personalizing-configuration-files)
6. [Deployment](#deployment)
7. [SSH Access Setup](#ssh-access-setup)
8. [Git and GitHub Configuration](#git-and-github-configuration)
9. [GPG Commit Signing](#gpg-commit-signing)
10. [Common Commands Reference](#common-commands-reference)
11. [Troubleshooting](#troubleshooting)
12. [Security Best Practices](#security-best-practices)

---

## Files in This Directory

### Configuration Files
- **vscode-session.yml** - Main StatefulSet configuration with SSH server, Git, GitHub CLI, GPG
- **vscode-service.yml** - Kubernetes Services (ClusterIP for internal, NodePort for external access)
- **pvc-example.yml** - Example Persistent Volume Claim template

### Management Scripts
- **manage.ps1** - Pod lifecycle management (up, down, restart, status, logs, ssh, cleanup)
- **add-ssh-key.ps1** - Inject SSH public key into the pod
- **start-ssh-tunnel.ps1** - Create port forwarding for SSH access from outside cluster
- **fix-ssh-config.ps1** - Repair corrupted SSH config file

### Development Setup Scripts
- **setup-git-github.ps1** - Configure git user information and GitHub CLI
- **setup-gpg-key.ps1** - Generate GPG key and enable automatic commit signing

---

## Prerequisites

### Required Software

1. **kubectl** - Kubernetes command-line tool
   - Download: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/
   - Verify: `kubectl version --client`

2. **PowerShell 7+** (Recommended for Windows)
   - Download: https://aka.ms/powershell
   - Verify: `pwsh --version`

3. **SSH Client** (Included in Windows 10/11)
   - Verify: `ssh -V`

4. **Git** (Optional, for local work)
   - Download: https://git-scm.com/download/win

### Cluster Access

- Access to a Kubernetes cluster
- Valid kubeconfig file
- Permissions to create StatefulSets, Services, and PVCs in your namespace

---

## Kubectl Configuration

Choose one of these three approaches:

### Option 1: Using Default Kubeconfig

If you only work with one cluster:

```powershell
# Set environment variable (current session)
$env:KUBECONFIG = "C:\Users\YOUR_USERNAME\.kube\config"

# Or permanently (Windows)
[System.Environment]::SetEnvironmentVariable('KUBECONFIG', 'C:\Users\YOUR_USERNAME\.kube\config', 'User')
```

Then update all scripts to use:
```powershell
$KUBECONFIG = @()  # Empty array uses default config
```

### Option 2: Explicit Kubeconfig Path (Recommended)

Keep the default configuration in scripts:
```powershell
$KUBECONFIG = "--kubeconfig", "C:\Users\YOUR_USERNAME\.kube\configs\your-cluster.conf"
```

This allows working with multiple clusters without changing environment variables.

### Option 3: Using Kubeswitch (Advanced)

For managing multiple clusters easily:

**Install:**
```powershell
choco install kubeswitch
# Or download from https://github.com/danielfoehrKn/kubeswitch/releases
```

**Setup:**
```powershell
# Create directory
New-Item -ItemType Directory -Force -Path "$HOME\.kube\switch-config"

# Place kubeconfig files in $HOME\.kube\configs\

# Switch context
switch  # Interactive selector

# Or set alias
Set-Alias -Name kubectx -Value switch
```

**With These Scripts:**
After switching context, update scripts:
```powershell
$KUBECONFIG = @()  # Uses current context
```

---

## Kubectl Authentication (localhost:8000)

Many Kubernetes clusters use OIDC/SSO authentication requiring browser interaction.

### How It Works

1. Running kubectl triggers authentication
2. Message appears: "Please visit the following URL in your browser: http://localhost:8000/"
3. Browser opens automatically (or open manually)
4. Complete authentication flow with your credentials
5. kubectl command proceeds

### If Browser Doesn't Open

1. Look for URL in terminal output
2. Manually open: `http://localhost:8000/`
3. Complete authentication
4. Return to terminal

### Common Issues

**Issue:** "context deadline exceeded"
- Re-run the command
- Complete authentication promptly

**Issue:** "authentication error: authcode-browser error"
- Ensure port 8000 is not blocked
- Check firewall settings

**Issue:** Browser shows error
- Clear browser cache
- Try incognito mode
- Use different browser

### Pre-authenticating

Avoid repeated prompts by authenticating once:

```powershell
kubectl --kubeconfig "path\to\config" get namespaces
```

Complete authentication. Credentials cached until expiration.

---

## Personalizing Configuration Files

**CRITICAL:** All files have `FIXME` comments. You must customize before deployment.

### 1. Determine Your Values

Gather this information:

```
USERNAME: your-username (e.g., jdoe)
NAMESPACE: your-k8s-namespace (e.g., dev-team)
PVC_NAME: your-pvc-name (e.g., jdoe-workspace)
KUBECONFIG_PATH: C:\Users\YOUR_USERNAME\.kube\configs\cluster.conf

Optional:
DOCKER_IMAGE: (use default or specify)
GPU_COUNT: 1 (or 0 if no GPU needed)
STORAGE_SIZE: 500Gi
STORAGE_CLASS: (find with: kubectl get storageclass)
```

### 2. Edit vscode-session.yml

| Line | Original | Change To | Example |
|------|----------|-----------|---------|
| 4 | `name: vscode-statefulset-yourname` | Your username | `vscode-statefulset-jdoe` |
| 6 | `namespace: rocm-dev` | Your namespace | `dev-team` |
| 21 | `claimName: your-pvc-name` | Your PVC name | `jdoe-workspace` |
| 25 | `image: rocm/...` | Your image (optional) | Keep or change |
| 103 | `amd.com/gpu: 1` | GPU count (optional) | `2` or `0` |

### 3. Edit pvc-example.yml (If Creating New PVC)

| Line | Original | Change To | How to Find |
|------|----------|-----------|-------------|
| 7 | `name: your-pvc-name` | PVC name | Must match vscode-session.yml line 21 |
| 9 | `namespace: rocm-dev` | Namespace | Must match vscode-session.yml line 6 |
| 14 | `storageClassName: your-storage-class-name` | Storage class | Run: `kubectl get storageclass` |
| 17 | `storage: 500Gi` | Size needed | e.g., `100Gi`, `1Ti` |

### 4. Edit ALL PowerShell Scripts (.ps1)

**Every script needs these three values updated:**

```powershell
# In manage.ps1 (lines 11-13):
$NAMESPACE = "rocm-dev"  # CHANGE to your namespace
$STATEFULSET = "vscode-statefulset-yourname"  # CHANGE to match vscode-session.yml
$KUBECONFIG = "--kubeconfig", "C:\Users\YOUR_USERNAME\.kube\configs\your-cluster-config.conf"  # CHANGE to your kubeconfig path

# In add-ssh-key.ps1, start-ssh-tunnel.ps1, setup-git-github.ps1, setup-gpg-key.ps1:
# Update the param() section at the top of each file with the same values
```

**Example for all scripts:**
```powershell
$NAMESPACE = "dev-team"
$STATEFULSET = "vscode-statefulset-jdoe"
$KUBECONFIG = "--kubeconfig", "C:\Users\johnd\.kube\configs\production.conf"
```

### 5. Verification Checklist

Before deployment:

- [ ] vscode-session.yml: name, namespace, claimName updated
- [ ] pvc-example.yml: all fields updated (if creating new PVC)
- [ ] manage.ps1: NAMESPACE, STATEFULSET, KUBECONFIG updated
- [ ] add-ssh-key.ps1: Namespace, StatefulSet, KubeConfig updated
- [ ] start-ssh-tunnel.ps1: Namespace, PodName, KubeConfig updated
- [ ] setup-git-github.ps1: Namespace, PodName, KubeConfig updated
- [ ] setup-gpg-key.ps1: Namespace, PodName, KubeConfig updated

---

## Deployment

### Step 1: Create PVC (If Needed)

If you don't have an existing PVC:

```powershell
# First edit pvc-example.yml
kubectl --kubeconfig "C:\path\to\your\config.conf" apply -f pvc-example.yml

# Verify it's bound
kubectl --kubeconfig "C:\path\to\your\config.conf" get pvc -n your-namespace
```

### Step 2: Deploy the StatefulSet

```powershell
cd example-templates\interactive\vscode-run-utils
.\manage.ps1 up
```

**What happens:**
1. Applies vscode-session.yml
2. Applies vscode-service.yml
3. Waits for pod ready (up to 5 minutes)
4. Displays pod IP

**Note:** You may see "Please visit... localhost:8000" - complete the authentication in your browser.

### Step 3: Verify Deployment

```powershell
.\manage.ps1 status
```

Look for:
- StatefulSet: 1/1 READY
- Pods: Running
- PVC: Bound

---

## SSH Access Setup

### Step 1: Inject SSH Key

```powershell
.\add-ssh-key.ps1
```

This will:
1. Generate SSH key if needed
2. Inject public key into pod
3. Update SSH config

**Note:** Authenticate via localhost:8000 if prompted.

### Step 2: Connect to Pod

#### Method A: Port Forwarding (Recommended)

**Terminal 1:**
```powershell
.\start-ssh-tunnel.ps1
# Keep this running
```

**Terminal 2:**
```bash
ssh vscode-pod-tunnel
```

#### Method B: Direct Connection (Internal Network Only)

```bash
ssh vscode-pod
```

---

## Git and GitHub Configuration

### Configure Git

**From Windows:**
```powershell
.\setup-git-github.ps1
```

Prompts for:
- Name (e.g., "John Doe")
- Email (e.g., "john.doe@example.com")  
- GitHub username (optional)

**Or inside pod:**
```bash
git config --global user.name "John Doe"
git config --global user.email "john.doe@example.com"
```

### Authenticate GitHub CLI

Inside the pod:

```bash
gh auth login
```

**Follow prompts:**
1. Select: GitHub.com
2. Select: HTTPS (or SSH)
3. Select: Login with web browser (or paste token)

**For web browser:**
- Note the one-time code shown
- Open URL in your Windows browser
- Enter the code
- Authorize
- Return to pod terminal

**For token:**
1. Create at: https://github.com/settings/tokens
2. Select scopes: repo, workflow
3. Copy token
4. Paste when prompted

**Verify:**
```bash
gh auth status
gh repo list
```

---

## GPG Commit Signing

### Generate GPG Key

**From Windows:**
```powershell
.\setup-gpg-key.ps1
```

Prompts for:
- Name (e.g., "John Doe")
- Email (must match GitHub account)

**Output:**
- GPG public key in ASCII armor format
- Key ID saved to `/workspace/.gpg-key-id`
- Git configured to auto-sign commits

### Add to GitHub

1. Copy GPG key from script output (entire block including BEGIN/END lines)
2. Go to: https://github.com/settings/keys
3. Click "New GPG key"
4. Paste key
5. Click "Add GPG key"

### Verify Signing

Inside pod:

```bash
mkdir test && cd test
git init
echo "test" > file.txt
git add file.txt
git commit -m "Test"
git log --show-signature
```

Should show "Good signature from..."

### Push to GitHub

```bash
gh repo create test --public --source=. --remote=origin
git push -u origin main
```

Check GitHub - commit should have "Verified" badge.

---

## Common Commands Reference

### Pod Management

```powershell
.\manage.ps1 up              # Deploy
.\manage.ps1 down            # Scale to 0
.\manage.ps1 restart         # Restart pod
.\manage.ps1 status          # Check status
.\manage.ps1 logs            # View logs
.\manage.ps1 ssh             # Quick kubectl exec
.\manage.ps1 cleanup         # Delete resources (keeps PVC)
```

### SSH Operations

```powershell
.\add-ssh-key.ps1           # Inject SSH key
.\start-ssh-tunnel.ps1      # Port forward (keep running)
ssh vscode-pod-tunnel        # Connect (new terminal)
.\fix-ssh-config.ps1        # Fix config errors
```

### Development Setup

```powershell
.\setup-git-github.ps1      # Configure git
.\setup-gpg-key.ps1         # Generate GPG key
```

Inside pod:
```bash
gh auth login                # Authenticate GitHub CLI
```

### File Locations in Pod

```
/workspace/                  # Home directory (persistent)
  .ssh/authorized_keys       # Your SSH key
  .ssh/host_keys/            # SSH server keys
  .gitconfig                 # Git config
  .gnupg/                    # GPG keys
  .gpg-key-id                # Key ID reference
  [your-files/]              # Your code
```

---

## Troubleshooting

### Kubectl Authentication

**Problem:** Repeated "Please visit... localhost:8000"

**Solution:**
- Complete browser authentication
- Check firewall not blocking port 8000
- Try incognito mode

**Problem:** "context deadline exceeded"

**Solution:**
- Re-run command
- Complete authentication promptly
- Check network connectivity

### SSH Issues

**Problem:** Connection times out

**Solution:**
- Use `.\start-ssh-tunnel.ps1` (pod IP is internal only)
- Keep tunnel window open

**Problem:** "Permission denied (publickey)"

**Solution:**
- Re-run: `.\add-ssh-key.ps1`
- Verify key: `ls C:\Users\YOUR_USERNAME\.ssh\id_rsa*`

**Problem:** SSH config errors

**Solution:**
```powershell
.\fix-ssh-config.ps1
```

### Pod Issues

**Problem:** Pod not starting

**Solution:**
```powershell
kubectl --kubeconfig "path" describe pod yourpod-0 -n namespace
.\manage.ps1 logs
kubectl --kubeconfig "path" get pvc -n namespace  # Check PVC
```

**Problem:** ImagePullBackOff

**Solution:**
- Verify image name in vscode-session.yml
- Check cluster can access image registry

### Permission Issues

**Problem:** Cannot write to /workspace

**Solution:**
```bash
# Inside pod
sudo chown -R sshuser:sshuser /workspace
sudo chmod 755 /workspace
```

**Problem:** Home directory wrong

**Solution:**
```bash
sudo sed -i 's#/home/sshuser#/workspace#g' /etc/passwd
exit
# Reconnect
```

### Git/GPG Issues

**Problem:** Commits not signed

**Solution:**
```bash
git config --global user.signingkey $(cat /workspace/.gpg-key-id)
git config --global commit.gpgsign true
```

**Problem:** GPG key missing after restart

**Solution:**
- Keys in /workspace/.gnupg/ (persistent)
- Verify: `gpg --list-secret-keys`

---

## Security Best Practices

1. Never commit kubeconfig files to repositories
2. Keep SSH private keys secure
3. Use GPG passphrase on shared machines
4. Rotate GPG keys annually
5. Review GitHub token permissions regularly
6. Don't share SSH private keys between users

---

## Complete Workflow Example

Here's a complete example for user "jdoe":

### 1. Customize Files

```powershell
# Edit vscode-session.yml:
#   Line 4: name: vscode-statefulset-jdoe
#   Line 6: namespace: dev-team
#   Line 21: claimName: jdoe-workspace

# Edit all .ps1 files:
#   $NAMESPACE = "dev-team"
#   $STATEFULSET = "vscode-statefulset-jdoe"
#   $KUBECONFIG = "--kubeconfig", "C:\Users\johnd\.kube\configs\prod.conf"
```

### 2. Deploy

```powershell
.\manage.ps1 up
# Authenticate at localhost:8000 if prompted
```

### 3. Setup SSH

```powershell
.\add-ssh-key.ps1
# Authenticate if prompted
```

### 4. Connect

**Terminal 1:**
```powershell
.\start-ssh-tunnel.ps1
# Keep running
```

**Terminal 2:**
```bash
ssh vscode-pod-tunnel
```

### 5. Configure Git

```powershell
.\setup-git-github.ps1
# Enter: "John Doe"
# Enter: "john.doe@company.com"
```

### 6. Setup GPG

```powershell
.\setup-gpg-key.ps1
# Enter: "John Doe"
# Enter: "john.doe@company.com"
# Copy GPG key from output
```

### 7. Add GPG to GitHub

- Visit: https://github.com/settings/keys
- Click "New GPG key"
- Paste key
- Click "Add GPG key"

### 8. Authenticate GitHub CLI

```bash
# Inside pod
gh auth login
# Follow prompts
```

### 9. Start Developing

```bash
gh repo clone myorg/myrepo
cd myrepo
vim file.txt
git add file.txt
git commit -m "Update"  # Auto-signed
git push
```

---

## Advanced Topics

### Custom Packages

Edit vscode-session.yml line 39:

```yaml
apt-get install -y openssh-server sudo git curl python3 nodejs && \
```

### Multiple Users

Each user needs:
- Own StatefulSet name
- Own PVC
- Own kubeconfig

### Custom SSH Port

```powershell
.\start-ssh-tunnel.ps1 -LocalPort 3333
ssh sshuser@localhost -p 3333
```

---

## What Persists Across Pod Restarts

**Persisted (in /workspace/):**
- SSH keys
- Git configuration
- GPG keys
- Your code and files
- All configurations

**Not Persisted:**
- Installed packages (re-installed each start)
- User account (re-created each start)
- Running processes

---

## Script Parameters

All scripts support parameter overrides:

```powershell
# Override namespace
.\manage.ps1 status -Namespace "other-namespace"

# Override kubeconfig
.\add-ssh-key.ps1 -KubeConfig "C:\path\to\other.conf"

# Override multiple
.\setup-gpg-key.ps1 -Name "Jane Doe" -Email "jane@example.com" -Namespace "dev"
```

---

## Support

For issues or questions, consult your cluster administrator or refer to the main project repository.

## License

See the main project LICENSE file.
