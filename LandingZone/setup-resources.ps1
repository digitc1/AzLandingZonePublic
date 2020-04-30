###################################
#                                 #
#  Landing Zone default resources #
#                                 #
###################################

param(
	[Parameter(Mandatory=$true)][string]$name
)

#
# Azure modules
#
Install-Module AzSentinel -Force

#
# Checking if Resource Group for secure Landing Zone already exists
# If it doesn't exist, create it
#
Write-Host "Checking Resource Group for the Secure Landing Zone" -ForegroundColor Yellow
if(!($GetResourceGroup = Get-AzResourceGroup -ResourceGroupName $name*)){
	Write-Host "No Resource Group for Secure Landing Zone found"
	Write-Host "Creating a new Resource Group for the Secure Landing Zone"
	$resourceGroupName = $name + "_rg"
	Write-Host "Select your prefered Azure region"
	Write-Host "`t 0. West Europe"
	Write-Host "`t 1. North Europe"
	Write-Host "`t 2. France Central"
	Write-Host "`t 3. Germany West Central"
	$regionId = Read-Host -Prompt "Enter region code (default West Europe) "
	$AzDCLocation = switch ( $regionId ){
		0 { 'westeurope' }
		1 { 'northeurope' }
		2 { 'francecentral' }
		3 { 'germanywestcentral' }
		default { 'westeurope'}
	}
	$GetResourceGroup = New-AzResourceGroup -Name $resourceGroupName -Location $AzDCLocation
}
else{
	$AzDCLocation = $GetResourceGroup.Location
}
Write-Host "Using Resource Group : "$GetResourceGroup.ResourceGroupName

#
# Checking if Automation account for secure Landing Zone already exists
# If it doesn't exist, create it
#
#Write-Host "Checking Automation account for Landing Zone in the Secure Landing Zone"  -ForegroundColor Yellow
#if(!($GetAutomationAccount = Get-AzAutomationAccount -ResourceGroupName $GetResourceGroup.ResourceGroupName)){
#	Write-Host "No Automation Account found for Secure Landing Zone"
#	Write-Host "Creating new Automation Account for the Landing Zone Logs in the Secure Landing Zone"
#	$automationAccountName = $name + "automation"
#	$GetAutomationAccount = New-AzAutomationAccount $GetResourceGroup.ResourceGroupName -Name $automationAccountName -Location $AzDCLocation
#	$StartTime = (Get-Date).AddDays(7-((Get-Date).DayOfWeek.value__))
#	$EndTime = $StartTime.AddYears(1)
#	New-AzAutomationSchedule -AutomationAccountName $GetAutomationAccount.AutomationAccountName -Name "lzSchedule" -StartTime $StartTime -ExpiryTime $EndTime -DayInterval 7 -ResourceGroupName $GetResourceGroup.ResourceGroupName | Out-Null
#	Write-Host "Add the Landing Zone runbook"
#	Import-AzAutomationRunbook -resourceGroupName $GetResourceGroup.ResourceGroupName -AutomationAccountName $GetAutomationAccount.AutomationAccountName -Name "lzRunbook" -Type "PowerShell" -Path ./setup-automation.ps1 | Out-Null
#	Publish-AzAutomationRunbook -Name "lzRunbook" -resourceGroupName $GetResourceGroup.ResourceGroupName -AutomationAccountName $GetAutomationAccount.AutomationAccountName | Out-Null
#	Write-Host "Add schedule for Landing Zone runbook"
#	Register-AzAutomationScheduledRunbook -RunbookName "lzRunbook" -ScheduleName "lzSchedule" -AutomationAccountName $GetAutomationAccount.AutomationAccountName -resourceGroupName $GetResourceGroup.ResourceGroupName | Out-Null
#}
#Write-Host "Using Automation Account : "$GetAutomationAccount.AutomationAccountName

#
# Checking if Storage account for Landing Zone Logs exists in the secure Landing Zone resource group
# If it doesn't exist, create it
#
Write-Host "Checking Storage Account for Landing Zone Logs in the Secure Landing Zone"  -ForegroundColor Yellow
while(!($GetStorageAccount = Get-AzStorageAccount -ResourceGroupName $GetResourceGroup.ResourceGroupName | Where-Object {$_.StorageAccountName -Like "$name*"})){
	Write-Host "No Storage Account found for Secure Landing Zone"
	Write-Host "Creating new Storage Account for the Landing Zone Logs in the Secure Landing Zone"
	$rand = Get-Random -Minimum 1000000 -Maximum 9999999999
	$storName = $name + $rand + "sa"
	$GetStorageAccount = New-AzStorageAccount -ResourceGroupName $GetResourceGroup.ResourceGroupName -Name $storName -Location $AzDClocation -SkuName Standard_LRS -Kind StorageV2
}
Write-Host "Using Storage Account : "$GetStorageAccount.StorageAccountName

#
# Checking if log container for Landing Zone Logs already exists in the secure Landing Zone resource group
# If it doesn't exist, create it
#
Write-Host "Checking storage container for Landing Zone Logs in the secure Landing Zone" -ForegroundColor Yellow
if(!(Get-AzRmStorageContainer -ResourceGroupName $GetResourceGroup.ResourceGroupName -StorageAccountName $GetStorageAccount.StorageAccountName | Where-Object {$_.Name -Like "landingzonelogs"})){
	Write-Host "No Storage container found for Secure Landing Zone logs"
	Write-Host "Creating new Storage container for the Landing Zone Logs in the Secure Landing Zone"
	New-AzRmStorageContainer -ResourceGroupName $GetResourceGroup.ResourceGroupName -StorageAccountName $GetStorageAccount.StorageAccountName -Name "landingzonelogs" | Out-Null
}

#
# Checking immutability policy for Azure storage account
# If storage is not immutable, set immutability to 185 days
#
Write-Host "Checking immutability policy" -ForegroundColor Yellow
if(((Get-AzRmStorageContainerImmutabilityPolicy -StorageAccountName $GetStorageAccount.StorageAccountName -ResourceGroupName $GetResourceGroup.ResourceGroupName -ContainerName "landingzonelogs").ImmutabilityPeriodSinceCreationInDays) -eq 0){
  Write-Host "No immutability policy found for logs container"
  Write-Host "Creating immutability policy (default 185 days)"
  Set-AzRmStorageContainerImmutabilityPolicy -ResourceGroupName $GetResourceGroup.ResourceGroupName -StorageAccountName $GetStorageAccount.StorageAccountName -ContainerName "landingzonelogs" -ImmutabilityPeriod 185 | Out-Null
}

#
# Checking if Log Analytics workspace already exists in the secure Landing Zone resource group
# If it doesn't exist, create it
#
Write-Host "Checking log analytics workspace in the Secure Landing Zone" -ForegroundColor Yellow
if(!($GetLogAnalyticsWorkspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $GetResourceGroup.ResourceGroupName)){
        Write-Host "Do you want to deploy and configure Azure Log Analytics for this subscription (required for integration with DIGIT-S)"
	$param = read-Host "enter y or n (default No)"
	if($param -Like "y")
	{
		Write-Host "Creating new log analytics workspace in the Secure Landing Zone"
		$rand = Get-Random -Minimum 1000000 -Maximum 9999999999
		$workspaceName = $name +"-workspace"+$rand
		$GetLogAnalyticsWorkspace = New-AzOperationalInsightsWorkspace -Location $AzDCLocation -Name $workspaceName -Sku Standard -ResourceGroupName $GetResourceGroup.ResourceGroupName
		Write-Host "Using log analytics workspace : "$GetLogAnalyticsWorkspace.Name
		Write-Host "Enabling Azure Sentinel for the Landing Zone log analytics workspace"
		Set-AzSentinel -WorkspaceName $workspaceName | Out-Null
		Write-Host "Sentinel is now enabled"
	}
	else{
		Write-Host "No Azure log analytics created"
	}
}
else{
	Write-Host "Using log analytics workspace : "$GetLogAnalyticsWorkspace.Name
}

Write-Host "Checking event-hub namespace in the Secure Landing Zone" -ForegroundColor Yellow
if(!($GetEventHubNamespace = Get-AzEventHubNameSpace -ResourceGroupName $GetResourceGroup.ResourceGroupName | Where-Object {$_.Name -Like "$name*"})){
        Write-Host "Do you want to deploy and configure Azure eventHubNameSpace for this subscription (required for integration with CERT-EU)"
        $param = read-Host "enter y or n (default No)"
        if($param -Like "y")
        {
                Write-Host "Creating new event-hub namespace in the Secure Landing Zone"
                $rand = Get-Random -Minimum 1000000 -Maximum 9999999999
                $eventHubNamespace= $name +"-ehns"+$rand
                $GetEventHubNamespace = New-AzEventHubNamespace -ResourceGroupName $GetResourceGroup.ResourceGroupName -Name $eventHubNamespace -Location $AzDCLocation
                Write-Host "Using event-hub namespace : "$GetEventHubNamespace.Name
        }
        else{
                Write-Host "No event-hub namespace created"
        }
}
else{
        Write-Host "Using event-hub namespace : "$GetEventHubNamespace.Name
}

#
# Checking if Event Hub 'insights-operational-logs' already exists in the event hub namespace
# If it doesn't exist, create it
#
if($GetEventHubNamespace){
	Write-Host "Checking Event Hub 'insights-operational-logs' in the Secure Landing Zone" -ForegroundColor Yellow
	if(!(Get-AzEventHub -ResourceGroupName $GetResourceGroup.ResourceGroupName -Namespace $GetEventHubNamespace.Name | Where-Object {$_.Name -Like "insights-operational-logs"})){
		Write-Host "No Event Hub for 'insights-operational-logs' found"
		Write-Host "Creating new Event Hub in the Secure Landing Zone"
		New-AzEventHub -ResourceGroupName $GetResourceGroup.ResourceGroupName -NamespaceName $GetEventHubNamespace.Name -Name "insights-operational-logs" | Out-Null
		Write-Host "Created event-hub 'insights-operational-logs'"
	}

	Write-Host "Checking Access Key 'landingZoneAccessKey' in the Secure Landing Zone" -ForegroundColor Yellow
	if(!(Get-AzEventHubAuthorizationRule -ResourceGroupName $GetResourceGroup.ResourceGroupName -Namespace $GetEventHubNamespace.Name | Where-Object {$_.Name -like "landingZoneAccessKey"})){
		Write-Host "No authorization rule called 'landingZoneAccessKey' found"
		Write-Host "Creating new authorization rule in the Secure Landing Zone"
		New-AzEventHubAuthorizationRule -ResourceGroupName $GetResourceGroup.ResourceGroupName -Namespace $GetEventHubNamespace.Name -Name "landingZoneAccessKey" -Rights @("Listen","Send","Manage") | Out-Null
		Write-Host "Created authorization rule 'landingZoneAccessKey'"
	}
}

#
# Checking if the subscription is registered to use Microsoft.Insights
# If not, register
#
# Registration can take about few minutes (up to 2 or 3 minutes)
#
Write-Host "Checking registration for Microsoft Insights" -ForegroundColor Yellow
if(!((Get-AzResourceProvider -ProviderNamespace 'Microsoft.Insights').RegistrationState[0] -Like "Registered")){
	Write-Host "Your subscription is not registered for Microsoft Insights"
	Write-Host "Registering for Microsoft Insights, this can take couple minutes"
	Register-AzResourceProvider -ProviderNamespace 'Microsoft.Insights'
	while(!((Get-AzResourceProvider -ProviderNamespace 'Microsoft.Insights').RegistrationState[0] -Like "Registered")){
		Start-Sleep -s 10
	}
}

#
# Checking if an Activity Log Profile exists for the secure Landing Zone
# If it doesn't exist, create it
#
# The default Log Profile is 90 days retention for all logs
#
Write-Host "Checking for ActivityLogProfile in the Secure Landing Zone" -ForegroundColor Yellow
Write-Host "Log profile is no longer supported and must be setup manually"

#
# Check if resource lock (cannot delete) is correctly set on the resource group
# If not, apply lock
#
Write-Host "Checking 'CannotDelete' lock on the resource-group" -ForegroundColor Yellow
if(!(Get-AzResourceLock | Where-Object {$_.Name -Like "LandingZoneLock"})){
	Write-Host "No lock found on the resource group"
	Write-Host "Applying 'CannotDelete' lock"
	New-AzResourceLock -LockName "LandingZoneLock" -LockLevel CannotDelete -ResourceGroupName $GetResourceGroup.ResourceGroupName -Force | Out-Null
	Write-Host "Created resource lock on the resource group"
}

#
# Check if the management group for the secure Landing Zone already exist
# If not, creates the management group lz-management-group
#
Write-Host "Checking Landing Zone management group" -ForegroundColor Yellow
if(!(Get-AzManagementGroup | Where-Object {$_.Name -Like "lz-management-group"})){
	Write-Host "No management group found"
	Write-Host "Creating the default management group for the Landing Zone"
	New-AzManagementGroup -GroupName "lz-management-group" -DisplayName "Landing Zone management group" | Out-Null
}

$children = (Get-AzManagementGroup -GroupName "lz-management-group" -Expand).Children
Get-AzSubscription | ForEach-Object {
	if ($_.Name -notin $children.DisplayName){
		if($_.Name -Like "SecLog*"){
			New-AzManagementGroupSubscription -GroupName "lz-management-group" -SubscriptionId $_.Id
		}
		else{
			Write-Host "Do you want to onboard the following subscription: " $_.Name
    		$param = read-Host "enter y or n (default No)"
    		if($param -Like "y"){
    			Write-Host "Onboarding the subscription"
        		New-AzManagementGroupSubscription -GroupName "lz-management-group" -SubscriptionId $_.Id
        		Write-Host "The following subscription is now part of the Landing Zone: "$_.Name
			}
		}
	}
}

#
# TODO
# Add owners to the management group in order to avoid loss of control
#
