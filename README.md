# azure-identity-lab
 # Azure Identity Risk Detection Lab<a></a>
 Automated identity threat detection system built with Terraform, Microsoft Sentinel, and 
## Features<a></a>- ✅ 4 advanced KQL detection rules- ✅ Automated incident remediation via Logic Apps- ✅ Azure Key Vault for secrets management- ✅ Microsoft Defender for Cloud integration- ✅ Azure Policy for compliance automation- ✅ GitHub Actions CI/CD with Trivy security scanning- ✅ Sentinel workbooks for visualization
 ## Technologies<a></a>- Terraform (Infrastructure as Code)- Microsoft Sentinel (SIEM)- Azure Entra ID (Identity Management)- GitHub Actions (CI/CD)- KQL (Threat Detection Queries)- Azure Key Vault (Secrets Management)- Logic Apps (Incident Response Automation

  ## Architecture<a></a>
 Azure AD Logs
 ↓
 Log Analytics Workspace
 ↓
 Microsoft Sentinel
 ↓
 Detection Rules (KQL)
 ↓
 Incidents
 ↓
 Logic App (Auto-remediation)
 
#this is working flow