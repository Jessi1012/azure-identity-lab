# Import existing Sentinel solution into Terraform state
# Run this from the repo root directory

Write-Host "Importing existing SecurityInsights solution into Terraform state..." -ForegroundColor Yellow

cd terraform

terraform import azurerm_log_analytics_solution.sentinel "/subscriptions/645a9291-908c-4ee8-b187-9b84d1e25a36/resourceGroups/Identity-Lab-RG/providers/Microsoft.OperationsManagement/solutions/SecurityInsights(identity-lab-logs-workspace01)"

if ($LASTEXITCODE -eq 0) {
    Write-Host "Import successful! You can now run terraform plan/apply." -ForegroundColor Green
} else {
    Write-Host "Import failed. Check the error message above." -ForegroundColor Red
}
