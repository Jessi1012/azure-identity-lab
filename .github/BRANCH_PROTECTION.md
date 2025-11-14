# Branch Protection Configuration Guide

## 🔒 Manual Setup Required (GitHub Web UI)

Branch protection rules must be configured via GitHub web interface.

### **Setup Instructions:**

1. Go to: https://github.com/Jessi1012/azure-identity-lab/settings/branches

2. Click **"Add branch protection rule"**

3. Configure for `main` branch:

   **Branch name pattern:** `main`

   **Protect matching branches:**
   - ☑️ Require a pull request before merging
     - ☑️ Require approvals: 1
     - ☑️ Dismiss stale pull request approvals when new commits are pushed
     - ☑️ Require review from Code Owners (optional)
   
   - ☑️ Require status checks to pass before merging
     - ☑️ Require branches to be up to date before merging
     - **Required checks:**
       - `Terraform Security Scan / tfsec`
       - `Terraform Security Scan / checkov`
       - `CodeQL Security Scanning / analyze`
   
   - ☑️ Require conversation resolution before merging
   
   - ☑️ Require signed commits (optional, recommended for security)
   
   - ☑️ Require linear history (keeps Git history clean)
   
   - ☑️ Include administrators (apply rules to repo admins too)
   
   - ☑️ Restrict who can push to matching branches
     - Add yourself: `Jessi1012`
   
   - ☑️ Allow force pushes: **NEVER** (prevents accidental history rewriting)
   
   - ☑️ Allow deletions: **NEVER** (prevents accidental branch deletion)

4. Click **"Create"**

---

## 🎯 Why Branch Protection Matters

### **Without Protection:**
- ❌ Anyone can push directly to `main`
- ❌ No code review required
- ❌ Security scans can be bypassed
- ❌ Secrets can be accidentally committed
- ❌ Breaking changes deployed without testing

### **With Protection:**
- ✅ All changes go through Pull Requests
- ✅ Automated security scans must pass
- ✅ Code review required before merge
- ✅ Commit signing proves identity
- ✅ Linear history makes debugging easier

---

## 📊 Workflow After Branch Protection

### **Current Workflow (No Protection):**
```bash
git commit -m "Add feature"
git push origin main  # ← Directly to main (risky!)
```

### **Protected Workflow:**
```bash
# 1. Create feature branch
git checkout -b feature/add-new-detection

# 2. Make changes and commit
git commit -m "Add brute force detection rule"
git push origin feature/add-new-detection

# 3. Open Pull Request on GitHub
# 4. Wait for automated checks to pass:
#    - tfsec security scan
#    - Checkov compliance scan
#    - CodeQL code analysis
# 5. Request review (if required)
# 6. Merge after approval + green checks
```

---

## 🔐 Security Benefits

| Risk | Without Protection | With Protection |
|------|-------------------|-----------------|
| **Accidental secret commit** | Pushed to main | Blocked by secret scanning |
| **Terraform security issue** | Deployed to production | Caught by tfsec/Checkov |
| **Breaking change** | Breaks main branch | Caught in PR before merge |
| **No code review** | Anyone can merge | Requires approval |
| **Unsigned commits** | Can't verify author | Requires GPG signature |

---

## 📝 Interview Talking Point

> "I implemented branch protection with required status checks including tfsec security scanning, Checkov compliance validation, and CodeQL analysis. All changes must pass automated security checks and code review before merging to main, following industry best practices for secure CI/CD pipelines."

This demonstrates:
- ✅ Understanding of secure development lifecycle
- ✅ Knowledge of defense-in-depth
- ✅ Experience with automated security gates
- ✅ Professional Git workflow practices
