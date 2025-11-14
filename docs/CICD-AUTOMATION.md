# Complete CI/CD Automation Guide

## Overview

This project now has **fully automated CI/CD** - no manual triggering required!

## 🚀 Automated Workflows

### 1. **Pull Request Validation** (`pr-validation.yml`)
**Triggers:** Automatically on every Pull Request to `main`

**What it does:**
- ✅ Validates Terraform syntax (`terraform fmt`, `terraform validate`)
- ✅ Generates Terraform plan
- ✅ Runs security scan (Trivy)
- ✅ Validates KQL query files
- ✅ Posts plan summary as PR comment
- ✅ Uploads security scan results

**When:** Every time you open/update a PR

**Purpose:** Catch errors before merging

---

### 2. **Automatic Deployment** (`deploy.yml`)
**Triggers:** Automatically when code is merged to `main`

**What it does:**
- ✅ Syncs Terraform state with Azure
- ✅ Plans infrastructure changes
- ✅ Runs security scan
- ✅ Deploys to Azure automatically

**When:** 
- **Automatic:** Every merge to `main` branch
- **Manual:** Can still trigger via Actions tab

**Deployment Flow:**
```
Code Change → Commit → Push to main → Auto Deploy
```

---

### 3. **Drift Detection** (`drift-detection.yml`)
**Triggers:** Automatically every day at 2 AM UTC

**What it does:**
- ✅ Checks for manual changes in Azure Portal
- ✅ Detects configuration drift
- ✅ Creates GitHub Issue if drift found
- ✅ Sends Teams notification (if configured)

**When:** Daily at 2 AM UTC (or manual trigger)

**Purpose:** Alert you to untracked changes

---

### 4. **Infrastructure Destruction** (`destroy.yml`)
**Triggers:** Manual only (requires approval)

**What it does:**
- ✅ Destroys all Azure resources
- ✅ Requires typing "DESTROY" to confirm
- ✅ Requires production environment approval
- ✅ Creates destruction record issue

**When:** Manual trigger only (for cleanup)

**Safety:** Requires confirmation + approval

---

## 📋 Complete Development Workflow

### Normal Development (Fully Automated)

```bash
# 1. Create feature branch
git checkout -b feature/add-new-rule

# 2. Make changes to Terraform or KQL files
# Edit terraform/*.tf or kql-queries/*.kql

# 3. Commit and push
git add .
git commit -m "Add new detection rule"
git push origin feature/add-new-rule

# 4. Create Pull Request on GitHub
# → PR Validation workflow runs automatically
# → Review plan output in PR comments

# 5. Merge PR to main
# → Deployment workflow runs automatically
# → Infrastructure deployed to Azure!
```

**No manual triggering needed!** 🎉

---

### Checking Deployment Status

```bash
# Option 1: GitHub CLI
gh run list --limit 5

# Option 2: Web UI
# Visit: https://github.com/Jessi1012/azure-identity-lab/actions
```

---

## 🔔 Notifications & Monitoring

### GitHub Issues
Automatically created for:
- ⚠️ Configuration drift detection
- 🗑️ Infrastructure destruction records

### Teams Notifications (Optional)
Set secret `TF_VAR_TEAMS_WEBHOOK_URL` for:
- Drift detection alerts
- Deployment notifications

---

## 🔐 Secrets Required

| Secret Name | Description | Required |
|------------|-------------|----------|
| `AZURE_CREDENTIALS` | Service Principal JSON | ✅ Yes |
| `TF_VAR_TEAMS_WEBHOOK_URL` | Teams webhook URL | ❌ Optional |

---

## 🎯 Workflow Triggers Summary

| Workflow | Automatic Trigger | Manual Trigger | Frequency |
|----------|------------------|----------------|-----------|
| PR Validation | ✅ On PR | ✅ Yes | Per PR |
| Deployment | ✅ On merge to main | ✅ Yes | Per merge |
| Drift Detection | ✅ Daily 2 AM UTC | ✅ Yes | Daily |
| Destroy | ❌ No | ✅ Yes | On demand |

---

## 🚦 Branch Protection (Recommended Setup)

### Protect `main` branch:

1. Go to: **Settings** → **Branches** → **Add rule**
2. Branch name pattern: `main`
3. Enable:
   - ✅ Require pull request before merging
   - ✅ Require status checks to pass
     - Select: `Validate Infrastructure Code`
     - Select: `Validate KQL Queries`
   - ✅ Require conversation resolution before merging
4. Save

**Result:** Cannot merge to main until PR validation passes!

---

## 📊 Monitoring & Visibility

### View Deployment History
```bash
# CLI
gh run list --workflow=deploy.yml

# Web
https://github.com/Jessi1012/azure-identity-lab/actions/workflows/deploy.yml
```

### View Drift Detection Results
```bash
# Check for issues with 'drift-detection' label
gh issue list --label drift-detection
```

### View Current Infrastructure
```bash
# Check Azure Portal or run locally
cd terraform
terraform init
terraform state list
```

---

## 🔧 Advanced: Environment-Specific Deployments

### Multi-Environment Setup (Future Enhancement)

1. Create environments in GitHub:
   - Settings → Environments → New environment
   - Add: `development`, `staging`, `production`

2. Update workflow to use environments:
```yaml
jobs:
  deploy:
    environment: ${{ github.event.inputs.environment || 'development' }}
```

3. Configure environment-specific variables:
   - Different resource groups per environment
   - Different Azure subscriptions
   - Approval requirements for production

---

## ⚡ Quick Commands

### Deploy Now (No Code Change)
```bash
# Trigger deployment manually
gh workflow run deploy.yml
```

### Check for Drift Now
```bash
# Trigger drift detection manually
gh workflow run drift-detection.yml
```

### View Latest Deployment
```bash
gh run list --workflow=deploy.yml --limit 1
```

### Follow Live Deployment
```bash
gh run watch
```

---

## 🐛 Troubleshooting

### Deployment Failed
1. Check workflow logs: Actions tab → Click failed run
2. Common fixes:
   - State lock: Wait 5 min and re-run
   - Permission denied: Check service principal roles
   - Resource exists: State sync should handle this

### PR Validation Failed
1. Check PR comments for Terraform plan
2. Fix issues locally:
```bash
terraform fmt -recursive
terraform validate
```

### Drift Detected
1. Check created issue for details
2. Options:
   - Accept drift: Update Terraform code
   - Reject drift: Re-run deployment to fix

---

## 📈 Best Practices

### ✅ DO:
- Create feature branches for changes
- Open PRs and review plans
- Merge to main only after approval
- Monitor drift detection issues
- Keep service principal credentials secure

### ❌ DON'T:
- Push directly to main (use PRs)
- Make manual changes in Azure Portal
- Ignore drift detection alerts
- Skip PR validation checks

---

## 🎓 Learning Resources

### GitHub Actions
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Workflow Syntax](https://docs.github.com/en/actions/reference/workflow-syntax-for-github-actions)

### Terraform
- [Terraform CI/CD Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/part1.html)
- [Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

---

## 🎉 Summary

You now have a **fully automated CI/CD pipeline**!

**Before:**
- Manual deployment via GitHub Actions UI
- Manual state management
- No validation before deployment

**After:**
- ✅ Automatic deployment on merge
- ✅ PR validation before merge
- ✅ Daily drift detection
- ✅ State auto-sync
- ✅ Security scanning
- ✅ Issue tracking

**Just commit and push - CI/CD handles the rest!** 🚀
