# 🔐 Security Best Practices for AIRA Project

## ✅ Current Security Status

- ✅ Service Principal credentials rotated (Nov 11, 2025)
- ✅ GitHub Secrets updated with new credentials
- ✅ `.gitignore` enhanced to prevent future secret leaks
- ✅ Old credentials invalidated and no longer work

---

## 🚨 NEVER Commit These to Git

### **Sensitive Files (Already Protected in .gitignore)**
```
sp-credentials.json         # Service Principal credentials
*.tfstate                   # Terraform state (contains secrets)
*.tfvars                    # Terraform variables (may contain secrets)
*.log                       # Log files (may contain output)
*.backup                    # Backup files
.env*                       # Environment variables
**/secrets/                 # Any secrets directory
**/*secret*                 # Any file with "secret" in name
**/*password*               # Any file with "password" in name
**/*credential*             # Any file with "credential" in name
```

---

## 🔑 Where Secrets Are Stored

### **1. GitHub Secrets (For CI/CD)**
Location: `https://github.com/Jessi1012/azure-identity-lab/settings/secrets/actions`

Stored secrets:
- `AZURE_CREDENTIALS` - Service Principal JSON (clientId, clientSecret, subscriptionId, tenantId)
- `TF_VAR_TEAMS_WEBHOOK_URL` - Teams webhook for alerts
- `AZURE_SUBSCRIPTION_ID` - Your Azure subscription ID
- `AZURE_TENANT_ID` - Your Azure AD tenant ID
- `TF_BACKEND_SUFFIX` - Storage account suffix for Terraform backend

**Security:** Encrypted at rest, masked in logs, access controlled by GitHub

### **2. Azure Key Vault (For Runtime Secrets)**
Location: Azure Portal → Key Vault: `kv-identity-5n7ekf`

Stored secrets:
- `teams-webhook-url` - Used by Logic App for Teams notifications

**Security:** RBAC-controlled, audit logs enabled, soft-delete protection

### **3. Local Machine (Development Only)**
Location: `c:\Users\chait\Documents\azure-identity-lab\sp-credentials.json`

⚠️ **WARNING:** This file is NOT in Git (protected by .gitignore)
- Only use for local development
- Never share or commit
- Rotate credentials if exposed

---

## 🔄 How to Rotate Secrets (If Exposed)

### **Step 1: Generate New Service Principal Password**
```powershell
az ad sp credential reset --id <your-sp-id> --display-name "github-actions-NEW-2025" --years 1
```

### **Step 2: Update GitHub Secrets**
1. Go to: https://github.com/Jessi1012/azure-identity-lab/settings/secrets/actions
2. Click `AZURE_CREDENTIALS` → Update
3. Paste new JSON with updated `clientSecret`
4. Click "Update secret"

### **Step 3: Test Deployment**
```bash
git commit --allow-empty -m "Test new credentials"
git push origin feature/test-deployment
```
Check GitHub Actions: https://github.com/Jessi1012/azure-identity-lab/actions

---

## 🛡️ Additional Security Measures

### **Enable GitHub Secret Scanning**
1. Go to: https://github.com/Jessi1012/azure-identity-lab/settings/security_analysis
2. Enable "Secret scanning"
3. GitHub will alert you if secrets are accidentally committed

### **Enable Dependabot**
1. Go to: https://github.com/Jessi1012/azure-identity-lab/settings/security_analysis
2. Enable "Dependabot alerts"
3. Automatically get notified of vulnerable dependencies

### **Use Branch Protection**
1. Go to: https://github.com/Jessi1012/azure-identity-lab/settings/branches
2. Add rule for `main` branch
3. Require pull request reviews before merging
4. Require status checks to pass

---

## 📝 What's Safe to Share Publicly

### ✅ Safe (Non-Sensitive)
- Resource names (Log Analytics Workspace, Key Vault names)
- Azure region (eastus)
- KQL queries
- Terraform configuration files
- Architecture diagrams

### ⚠️ Be Careful (Semi-Sensitive)
- Subscription ID (not secret, but reveals your Azure account structure)
- Tenant ID (public information, but avoid broadcasting)
- Email addresses (privacy concern, not security risk)

### 🚨 NEVER Share (Highly Sensitive)
- Service Principal `clientSecret` (password)
- Teams webhook URLs (allows posting to your Teams)
- Access tokens
- SSH keys
- API keys

---

## 🎯 Interview Talking Points

When discussing this project in interviews, you can say:

> "I implemented defense-in-depth secret management:
> - CI/CD credentials stored in GitHub Secrets (encrypted, masked in logs)
> - Runtime secrets in Azure Key Vault (RBAC-controlled, audited)
> - Git ignore patterns prevent accidental commits
> - Credential rotation process documented for incident response
> - Separation of bootstrap secrets (GitHub) vs. runtime secrets (Key Vault)"

This shows you understand **real-world security practices**, not just "hide passwords."

---

## 📚 Additional Resources

- [GitHub Secrets Documentation](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Azure Key Vault Best Practices](https://learn.microsoft.com/en-us/azure/key-vault/general/best-practices)
- [Terraform Sensitive Data Management](https://developer.hashicorp.com/terraform/language/values/variables#suppressing-values-in-cli-output)
- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)

---

## 🔍 How to Check for Exposed Secrets

### **Scan Git History for Secrets**
```bash
# Install gitleaks (secret scanner)
# Option 1: Using Chocolatey
choco install gitleaks

# Option 2: Download from https://github.com/gitleaks/gitleaks/releases

# Scan repository
gitleaks detect --source . --report-format json --report-path gitleaks-report.json
```

### **Check GitHub for Leaked Secrets**
```bash
# Use GitHub's secret scanning (if repo is public)
# Or use TruffleHog
docker run --rm -v "$(pwd):/repo" trufflesecurity/trufflehog:latest filesystem /repo
```

---

## ✅ Security Checklist

Before pushing code to GitHub:
- [ ] No passwords in code
- [ ] No API keys in code
- [ ] `.gitignore` includes all secret file patterns
- [ ] Sensitive values use variables (not hardcoded)
- [ ] GitHub Secrets are up to date
- [ ] Test deployment works with secrets from GitHub

Before sharing repository publicly:
- [ ] Run `gitleaks detect` to scan for secrets
- [ ] Review Git history for accidentally committed secrets
- [ ] Enable GitHub secret scanning
- [ ] Update README to remove any sensitive examples

---

**Last Updated:** November 11, 2025  
**Security Posture:** ✅ Good (Secrets properly managed, no known exposures)
