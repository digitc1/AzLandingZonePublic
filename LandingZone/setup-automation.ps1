###################################
#                                 #
#       Setup LZ Automation       #
#                                 #
###################################

#
# script parameters
#
param(
	[Parameter(Mandatory=$true)][string]$name
)

#
# Additional modules
#

#
# External resource required
#
$automationRunAsURI = ""
$automationRunbookURI = ""


#
# Checking variables and requirements
#
if(!($GetResourceGroup = Get-AzResourceGroup -ResourceGroupName "*$name*")){
    Write-Host "No Resource Group for Secure Landing Zone found"
    Write-Host "Please run setup script before"
    return 1;
}
if(!($GetManagementGroup = Get-AzManagementGroup -GroupName "lzslz-management-group")){
    Write-Host "No Management Group for Secure Landing Zone found"
    Write-Host "Please run setup script before"
    return 1;
}
$automationAccountName = $name + "Automation"
#TODO#
# Add Subscription Id #
$subscriptionId = ""

#
# Checking Azure automation account for Azure Landing Zone
# If it doesn't exist, create it
#
Write-Host "Checking automation account in the Secure Landing Zone" -ForegroundColor Yellow
if(!($GetAutomationAccount = Get-AzAutomationAccount -Name $automationAccountName -ResourceGroupName $GetResourceGroup.ResourceGroupName)){
    Write-Host "No automation account found"
    Write-Host "Creating automation account"
    $GetAutomationAccount = New-AzAutomationAccount -Name $automationAccountName -ResourceGroupName $GetResourceGroup.ResourceGroupName -Location $GetResourceGroup.Location
}
Write-Host "Using Automation Account : "$GetAutomationAccount.AutomationAccountName

#
# Checking Azure Run As account for Landing Zone automation account
# If it doesn't exist, create it
#
Write-Host "Checking automation runAs account in the Secure Landing Zone" -ForegroundColor Yellow
if(!($automationServicePrincipal = Get-AzAdServicePrincipal | Where-Object {$_.DisplayName -Like "*$automationAccountName*"})){
    Write-Host "No automation RunAs account found"
    Write-Host "Creating RunAs account"
    # TODO #
    # generate password #
    $randomPassword = ""
    # TODO #
    # review Invoke-WebRequest cmdlet #
    Invoke-WebRequest -Uri "$automationRunAsURI" -Authentication OAuth -Token $secureToken -OutFile $HOME/setup-runAs.ps1
    ./setup-runAs.ps1 -ResourceGroup $GetResourceGroup.ResourceGroupName -AutomationAccountName $automationAccountName -ApplicationDisplayName $automationAccountName -subscriptionId $subscriptionId -createClassicRunAsAccount $false -selfSignedCertPlainPassword $randomPassword | Out-Null
    Remove-Item -Path "$HOME/setup-runAs.ps1"
    $automationServicePrincipal = Get-AzAdServicePrincipal -DisplayName $automationAccountName
}
Write-Host "Using automation account service principal : "$automationServicePrincipal.DisplayName

# TODO #
# Assign contributor at management group level #

#
# Checking Azure key vault for the Azure Landing Zone
# If it doesn't exist, create it
#
Write-Host "Checking key vault in the Secure Landing Zone" -ForegroundColor Yellow
if(!($GetKeyVault = Get-AzKeyVault | Where-Object {$_.VaultName -Like "*$name*"})){
    Write-Host "No key vault found"
    Write-Host "Creating Azure key vault"
    $rand = Get-Random -Minimum 1000000 -Maximum 9999999999
    $keyVaultName = $name + "kv" + $rand
    $GetKeyVault = New-AzKeyVault -VaultName $keyVaultName -ResourceGroupName $GetResourceGroup.ResourceGroupName -Location $GetResourceGroup.Location
}
Write-Host "Using automation account service principal : "$GetKeyVault.VaultName

#
# Checking the existence of "LandingZonePassword" secret in the Azure keyvault
# If it doesn't exist, create it
#
Write-Host "Checking Azure key vault secrets" -ForegroundColor Yellow
if(!(Get-AzKeyVaultSecret -VaultName $GetKeyVault.VaultName -SecretName "landingZonePassword")){
    Write-Host "No Landing Zone credentials found"
    Write-Host "Generating Landing Zone credentials and store in key vault"
    # TODO #
    # Generate landingZonePassword and push to key vault #
}

#
# Checking access policy for Azure landing zone key vault
#
Write-Host "Checking key vault access for Azure landing zone automation account" -ForegroundColor Yellow
Set-AzRmKeyVaultAccessPolicy -VaultName $GetKeyVault.VaultName -PermissionsToSecret get -ServicePrincipalName $automationServicePrincipal.DisplayName | Out-Null

#
# Checking Azure automation schedule
# If it doesn't exist, create it (default schedule runs once a week)
#
Write-Host "Checking Azure automation schedule" -ForegroundColor Yellow
if(!($GetAutomationAccountSchedule = Get-AzAutomationSchedule -ResourceGroupName $GetResourceGroup.ResourceGroupName -AutomationAccountName $GetAutomationAccount.AutomationAccountName)){
    Write-Host "No automation account schedule found"
    Write-Host "Creating automation account schedule"
    $StartTime = (Get-Date).AddDays(7-((Get-Date).DayOfWeek.value__))
    $EndTime = $StartTime.AddYears(1)
    $GetAutomationAccountSchedule = New-AzAutomationSchedule -AutomationAccountName $GetAutomationAccount.AutomationAccountName -Name "lzSchedule" -StartTime $StartTime -ExpiryTime $EndTime -DayInterval 7 -ResourceGroupName $GetResourceGroup.ResourceGroupName
}

#
# Checking Azure automation runbook for Azure landing zone
# if it doesn't exist, create it
#
Write-Host "Checking Azure automation runbook for Azure landing zone" -ForegroundColor Yellow
if(!(Get-AzAutomationRunbook -ResourceGroupName $GetResourceGroup.ResourceGroupName -AutomationAccountName $GetAutomationAccount.AutomationAccountName | Where-Object {$_.Name "*$name*"})){
    # TODO #
    # review Invoke-WebRequest cmdlet #
    # review automation runbook code, include key vault #
    $runbookName = $name + "runbook"
    Invoke-WebRequest -Uri "$automationRunbookURI" -Authentication OAuth -Token $secureToken -OutFile $HOME/automationRunbook.ps1
    Import-AzAutomationRunbook -resourceGroupName $GetResourceGroup.ResourceGroupName -AutomationAccountName $GetAutomationAccount.AutomationAccountName -Name $runbookName -Type "PowerShell" -Path ./automationRunbook.ps1 | Out-Null
    Publish-AzAutomationRunbook -Name $runbookName -resourceGroupName $GetResourceGroup.ResourceGroupName -AutomationAccountName $GetAutomationAccount.AutomationAccountName | Out-Null
    Register-AzAutomationScheduledRunbook -RunbookName $runbookName -ScheduleName $GetAutomationAccountSchedule.Name -AutomationAccountName $GetAutomationAccount.AutomationAccountName -resourceGroupName $GetResourceGroup.ResourceGroupName | Out-Null
    Remove-Item -Path "$HOME/automationRunbook.ps1"
}