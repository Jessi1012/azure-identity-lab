# Azure Identity Lab – Beginner Guide

Welcome! This guide explains the project from scratch for someone new to GitHub, Azure, and Terraform. You’ll learn what the project does, the Azure services involved, how the automation works, and how security is enforced.

## What this project does (in plain English)

- Creates a small “Identity Security Lab” in Azure automatically.
- Sets up a Resource Group, a Log Analytics Workspace, and Microsoft Sentinel.
- Adds several security detection rules (KQL) so Sentinel can alert on suspicious activity.
- Uses GitHub Actions (CI/CD) to deploy changes whenever you push code.

Think of it like this: you write down what you want your cloud to look like (Terraform code), push it to GitHub, and a robot (GitHub Actions) builds/updates it in Azure.

## Why this matters

- You get a repeatable, reliable environment to learn modern cloud security.
- Everything is automated—no clicking through portals for each change.
- You learn industry-standard tools: Git, GitHub, Terraform, Azure, and KQL/Sentinel.

## What Azure resources we create (and why)

- Resource Group (RG)
  - A container/folder for all your resources. Easier to manage and delete.
- Log Analytics Workspace (LAW)
  - Central place where logs are stored for analysis.
- Microsoft Sentinel
  - A SIEM that runs on top of the workspace to detect threats.
- Sentinel Scheduled Alert Rules
  - Rules powered by KQL queries to detect:
    - Dormant account reactivation
    - Impossible travel sign-ins
    - Failed-login flood (password spray)
    - Privilege escalation
    - VM deployment activity

KQL files live in `kql-queries/` and are referenced by Terraform when creating the rules.

## What you need before you start (prerequisites)

- Azure subscription where you can create resources.
- Azure Service Principal (an app identity) for automation in CI/CD.
- GitHub repository with secrets configured for the Service Principal.
- Optional for local runs: Git, Azure CLI, Terraform, and VS Code installed.

You don’t need deep knowledge—this project’s automation will guide you.

## How infrastructure is defined (Terraform 101)

- Terraform files live in the `terraform/` folder.
- Key files:
  - `main.tf`: declares resources (RG, workspace, Sentinel onboarding, alert rules)
  - `variables.tf`: input parameters (names, region, retention)
  - `terraform.tfvars`: actual values for the variables
  - `backend.tf`: state configuration (local by default; CI bootstraps imports)

### Dependencies between resources

- Sentinel requires the Log Analytics Workspace.
- Alert rules require Sentinel onboarding to exist first.
- Terraform uses dependency hints (like `depends_on`) and CI imports to get the order right.

### Terraform “state” (important concept)

- Terraform remembers what it created in a state file.
- In CI, we first “import” existing Azure resources into the state so Terraform knows about them and doesn’t try to recreate them.

## What happens after you push code (CI/CD step-by-step)

The automation lives under `.github/workflows/`.

1) Pull Request Validation (`pr-validation.yml`)
- Runs on Pull Requests.
- Checks Terraform format/validation, generates a plan, runs a security scan.
- Adds feedback to the PR so you can fix issues before merging.

2) Deployment (`deploy.yml`)
- Runs when you push to the deployment branch (e.g., `main`).
- High-level flow:
  1. Check out code and log into Azure using the Service Principal (from GitHub Secrets).
  2. Initialize Terraform.
  3. Import any existing Azure resources so Terraform state is in sync:
     - Resource Group
     - Log Analytics Workspace
     - Sentinel onboarding
     - Sentinel scheduled alert rules (we probe each rule by name and import when present)
     - Optional: Key Vault, Logic App, state storage, etc.
  4. Run `terraform plan` to preview.
  5. Run `terraform apply` to create/update Azure resources.

3) Drift Detection (`drift-detection.yml`)
- Runs on a schedule (e.g., nightly).
- Performs a plan to check if someone changed Azure by hand.
- Alerts you in Actions logs so you can reconcile.

## How the Sentinel rules (KQL) are wired in

- Each Terraform rule points to a KQL file, for example:
  - `query = file("../kql-queries/impossible-travel-detection.kql")`
- On apply, Terraform sends that query to Azure Sentinel to configure the rule.
- If a rule already exists in Azure, CI imports it first, then updates it.

## Try it locally (optional)

If you want to run Terraform from your machine:

1. Login to Azure:
   - `az login`
2. Go to `terraform/` and run:
   - `terraform init`
   - `terraform plan`
   - `terraform apply`
3. Clean up (dangerous, removes resources):
   - `terraform destroy`

CI/CD normally handles this for you, so local runs are optional.

## Troubleshooting common issues

- Error: “resource already exists – import into state”
  - Meaning: Azure has the resource, but Terraform’s state doesn’t.
  - Fix: Our workflow imports RG, workspace, Sentinel onboarding, and scheduled alert rules before applying.
- Warning: “plan created with -target; may be incomplete”
  - Meaning: A partial/targeted plan was used. Follow with a full plan/apply to reconcile everything.
- Auth failures in CI
  - Check GitHub Secrets for the correct Service Principal credentials.

## Security – GitHub, the project, and Copilot

### GitHub security

- Secret Scanning + Push Protection
  - Prevents committing secrets; scans both your current changes and history.
- GitHub Secrets and minimal permissions
  - Store SP credentials as GitHub Secrets; grant least-privilege roles in Azure.
- Branch protection (recommended)
  - Require PR reviews and passing checks to merge.
- Optional: Dependabot and code scanning
  - Automated alerts for vulnerable dependencies and code issues.

### Project security (Terraform/Azure)

- Idempotent IaC
  - Declarative code + state means consistent, repeatable deployments.
- Import-first CI
  - Imports existing resources to avoid accidental duplicates and errors.
- Centralized logging
  - LAW + Sentinel gathers and analyzes logs for security alerts.
- Clear scoping
  - Everything under one RG for easier auditing and cleanup.

### Copilot security

- Treat Copilot output like any code—review before merging.
- Don’t paste secrets into prompts.
- Organizations can set Copilot policies for data handling and usage.

## Glossary (quick reference)

- Git: Version control system to track code changes.
- GitHub: Remote platform that hosts your repo and runs workflows.
- CI/CD: Automation that validates and deploys your code.
- Terraform: Tool to define and manage cloud resources with code.
- State file: Terraform’s memory of what exists.
- Azure Resource Group: A container for related resources.
- Log Analytics Workspace: Centralized log store in Azure.
- Microsoft Sentinel: SIEM that runs on top of the workspace.
- KQL: Query language used by Sentinel to analyze logs.

## Next steps

1) Rotate the Service Principal secret and update the GitHub Secret.
2) Confirm Secret Scanning + Push Protection is enabled in the repo settings.
3) Push a small change to trigger deployment and watch the Actions logs.
4) Verify RG, LAW, Sentinel, and alert rules are created in the Azure Portal.

You now have a secure, automated path to build and learn cloud security—end to end.
