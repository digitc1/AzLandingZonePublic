###################################
#                                 #
#        Setup LZ Policies        #
#                                 #
###################################

param(
        [Parameter(Mandatory=$true)][string]$name
)

Install-Module -Name Az.Security -Force | Out-Null

#
# Create variables needed for this script
#
if(!($GetResourceGroup = Get-AzResourceGroup -ResourceGroupName "*$name*")){
        Write-Host "No Resource Group for Secure Landing Zone found"
        Write-Host "Please run setup script before running the policy script"
        return 1;
}
if(!($GetStorageAccount = Get-AzStorageAccount -ResourceGroupName $GetResourceGroup.ResourceGroupName | Where-Object {$_.StorageAccountName -Like "*$name*"})){
        Write-Host "No Storage Account found for Secure Landing Zone"
        Write-Host "Please run setup script before running the policy script"
        return 1;
}
if(!($GetManagementGroup = Get-AzManagementGroup -GroupName "lz-management-group" -Expand)){
        Write-Host "No Management group found for Secure Landing Zone"
        Write-Host "Please run setup script before running the policy script"
        return 1;
}
$location = $GetResourceGroup.Location
$scope = $GetManagementGroup.Id

#
# Checking if the subscription is registered to use Microsoft.PolicyInsights
# If not, register
#
# Registration can take about few minutes (up to 2 or 3 minutes)
#
Write-Host "Checking registration for Microsoft PolicyInsights" -ForegroundColor Yellow
if(!((Get-AzResourceProvider -ProviderNamespace 'Microsoft.PolicyInsights').RegistrationState[0] -Like "Registered")){
        Write-Host "Your subscription is not registered for Microsoft PolicyInsights"
        Write-Host "Registering for Microsoft PolicyInsights, this can take couple minutes"
        Register-AzResourceProvider -ProviderNamespace 'Microsoft.PolicyInsights'
        while(!((Get-AzResourceProvider -ProviderNamespace 'Microsoft.PolicyInsights').RegistrationState[0] -Like "Registered")){
                Start-Sleep -s 10
        }
}

#
# Creating policy definition
#
if(!(Get-AzPolicyAssignment | Where-Object {$_.Name -Like "ASC_Default"})){
        Write-Host "Enabling first monitoring in Azure Security Center" -ForegroundColor Yellow
        $Policy = Get-AzPolicySetDefinition | Where-Object {$_.Properties.displayName -EQ 'Enable Monitoring in Azure Security Center'}
        New-AzPolicyAssignment -Name "ASC_Default" -DisplayName "Azure Security Center - Default" -PolicySetDefinition $Policy -Scope $scope | Out-Null
}

if(!(Get-AzPolicyAssignment | Where-Object {$_.Name -Like "ASC_CIS"})){
        Write-Host "Enabling second monitoring in Azure Security Center" -ForegroundColor Yellow
        $Policy = Get-AzPolicySetDefinition | Where-Object {$_.Properties.displayName -EQ '[Preview]: Audit CIS Microsoft Azure Foundations Benchmark 1.1.0 recommendations and deploy specific supporting VM Extensions'}
        New-AzPolicyAssignment -Name "ASC_CIS" -DisplayName "Azure Security Center - CIS Compliance" -PolicySetDefinition $Policy -Scope $scope -listOfRegionsWhereNetworkWatcherShouldBeEnabled $location | Out-Null
}

#
# Loop to create all "SLZ-...........DiagnosticToStorageAccount" policies
#
Get-Content -Path ./definitions/definitionList1.txt | ForEAch-Object {
        $policyName = "SLZ-" + $_.Split(',')[0] + "1"
        $policyVersion = $_.Split(',')[1]
        $policyLink = $_.Split(',')[2]

        Write-Host "Checking policy : $policyName" -ForegroundColor Yellow

        $GetDefinition = Get-AzPolicyDefinition | Where-Object {$_.Name -Like $policyName}
        if($GetDefinition)
        {
                if($GetDefinition.Properties.metadata.version -eq $policyVersion){
                        Write-Host "$policyName already exist and is up-to-date"
                }
                else{
                        Write-Host "$policyName requires update"
                        if($objectId = (Get-AzRoleAssignment | where-Object {$_.DisplayName -Like $policyName}).ObjectId){
                                Remove-AzRoleAssignment -ObjectId $objectId -RoleDefinitionName "Contributor" -Scope $scope | Out-Null
                        }
                        Remove-AzPolicyAssignment -Name $policyName -Scope $scope | Out-Null
                        Remove-AzPolicyDefinition -Name $policyName -Force | Out-Null
                        $metadata = '{"version":"'+$policyVersion+'"}'
                        $policyDefinition = New-AzPolicyDefinition -Name $policyName -Policy $policyLink -Parameter ./definitions/parameters1.json -Metadata $metadata -ManagementGroupName "lz-management-group"
                        New-AzPolicyAssignment -name $policyName -PolicyDefinition $policyDefinition -Scope $scope -AssignIdentity -Location $location -region $location -storageAccountId $GetStorageAccount.Id | Out-Null
                        Write-Host "Updated : $policyName"
                }
        }
        else{
                Write-Host "Create the new policy"
                $metadata = '{"version":"'+$policyVersion+'"}'
                $policyDefinition = New-AzPolicyDefinition -Name $policyName -Policy $policyLink -Parameter ./definitions/parameters1.json -Metadata $metadata -ManagementGroupName "lz-management-group"
                New-AzPolicyAssignment -name $policyName -PolicyDefinition $policyDefinition -Scope $scope -AssignIdentity -Location $location -region $location -storageAccountId $GetStorageAccount.Id | Out-Null
                Write-Host "Created : $policyName"
        }
}

# Loop to create all "SLZ-...........DiagnosticToLogAnalytics" policies if log analytics workspace exists
if($GetLogAnalyticsWorkspace = Get-AzureRmOperationalInsightsWorkspace -ResourceGroupName $GetResourceGroup.ResourceGroupName){
        Get-Content -Path ./definitions/definitionList2.txt | ForEAch-Object {
        $policyName = "SLZ-" + $_.Split(',')[0] + "2"
        $policyVersion = $_.Split(',')[1]
        $policyLink = $_.Split(',')[2]

        Write-Host "Checking policy : $policyName" -ForegroundColor Yellow

        $GetDefinition = Get-AzPolicyDefinition | Where-Object {$_.Name -Like $policyName}
        if($GetDefinition)
        {
                if($GetDefinition.Properties.metadata.version -eq $policyVersion){
                        Write-Host "$policyName already exist and is up-to-date"
                }
                else{
                        Write-Host "$policyName requires update"
                        if($objectId = (Get-AzRoleAssignment | where-Object {$_.DisplayName -Like $policyName}).ObjectId){
                                Remove-AzRoleAssignment -ObjectId $objectId -RoleDefinitionName "Contributor" -Scope $scope | Out-Null
                        }
                        Remove-AzPolicyAssignment -Name $policyName -Scope $scope | Out-Null
                        Remove-AzPolicyDefinition -Name $policyName -Force | Out-Null
                        $metadata = '{"version":"'+$policyVersion+'"}'
                        $policyDefinition = New-AzPolicyDefinition -Name $policyName -Policy $policyLink -Parameter ./definitions/parameters2.json -Metadata $metadata -ManagementGroupName "lz-management-group"
                        New-AzPolicyAssignment -name $policyName -PolicyDefinition $policyDefinition -Scope $scope -AssignIdentity -Location $location -region $location -workspaceId $GetLogAnalyticsWorkspace.ResourceId | Out-Null
                        Write-Host "Updated : $policyName"
                }
        }
        else{
                Write-Host "Create the new policy"
                $metadata = '{"version":"'+$policyVersion+'"}'
                $policyDefinition = New-AzPolicyDefinition -Name $policyName -Policy $policyLink -Parameter ./definitions/parameters2.json -Metadata $metadata -ManagementGroupName "lz-management-group"
                New-AzPolicyAssignment -name $policyName -PolicyDefinition $policyDefinition -Scope $scope -AssignIdentity -Location $location -region $location -workspaceId $GetLogAnalyticsWorkspace.ResourceId | Out-Null
                Write-Host "Created : $policyName"
        }
    }
    Remove-Item -Path $HOME/parameters.json
    Remove-Item -Path $HOME/definitionList.txt
}

# Loop to create all "SLZ-...........DiagnosticToEventHub" policies
if($GetEventHubNamespace = Get-AzEventHubNamespace -ResourceGroupName $GetResourceGroup.ResourceGroupName){
    $GetEventHubAuthorizationRuleId = Get-AzEventHubAuthorizationRule -ResourceGroupName $GetResourceGroup.ResourceGroupName -Namespace $GetEventHubNamespace.Name -Name "landingZoneAccessKey"
    Get-Content -Path ./definition/definitionList3.txt | ForEAch-Object {
        $policyName = "SLZ-" + $_.Split(',')[0] + "3"
        $policyVersion = $_.Split(',')[1]
        $policyLink = $_.Split(',')[2]

        Write-Host "Checking policy : $policyName" -ForegroundColor Yellow

        $GetDefinition = Get-AzPolicyDefinition | Where-Object {$_.Name -Like $policyName}
        if($GetDefinition)
        {
                if($GetDefinition.Properties.metadata.version -eq $policyVersion){
                        Write-Host "$policyName already exist and is up-to-date"
                }
                else{
                        Write-Host "$policyName requires update"
                        if($objectId = (Get-AzRoleAssignment | where-Object {$_.DisplayName -Like $policyName}).ObjectId){
                                Remove-AzRoleAssignment -ObjectId $objectId -RoleDefinitionName "Contributor" -Scope $scope | Out-Null
                        }
                        Remove-AzPolicyAssignment -Name $policyName -Scope $scope | Out-Null
                        Remove-AzPolicyDefinition -Name $policyName -Force | Out-Null
                        $metadata = '{"version":"'+$policyVersion+'"}'
                        $policyDefinition = New-AzPolicyDefinition -Name $policyName -Policy $policyLink -Parameter ./definitions/parameters3.json -Metadata $metadata -ManagementGroupName "lz-management-group"
                        New-AzPolicyAssignment -name $policyName -PolicyDefinition $policyDefinition -Scope $scope -AssignIdentity -Location $location -region $location -eventHubRuleId $GetEventHubAuthorizationRuleId.Id | Out-Null
                        Write-Host "Updated : $policyName"
                }
        }
        else{
                Write-Host "Create the new policy"
                $metadata = '{"version":"'+$policyVersion+'"}'
                $policyDefinition = New-AzPolicyDefinition -Name $policyName -Policy $policyLink -Parameter ./definitions/parameters3.json -Metadata $metadata -ManagementGroupName "lz-management-group"
                New-AzPolicyAssignment -name $policyName -PolicyDefinition $policyDefinition -Scope $scope -AssignIdentity -Location $location -region $location -eventHubRuleId $GetEventHubAuthorizationRuleId.Id | Out-Null
                Write-Host "Created : $policyName"
        }
    }
}

Write-Host "Waiting for previous task to complete" -ForegroundColor Yellow
Start-Sleep -Seconds 15

#create role assignment for all policies
Write-Host "Create role assignment for created and updated policies" -ForegroundColor Yellow
$GetPolicyAssignment = Get-AzPolicyAssignment | where-object {$_.Name -like "SLZ-*"}
ForEach ($policyAssignment in $GetPolicyAssignment) {
    if(!(Get-AzRoleAssignment -ObjectId $policyAssignment.Identity.principalId)){
        New-AzRoleAssignment -ObjectId $policyAssignment.Identity.principalId -RoleDefinitionName "Contributor" -Scope $scope | Out-Null
        Write-Host "Created role assignment for: "$policyAssignment.Name
    }
}

#
# Check if the account is registered to use the Azure Security Center
# If not, register
#
Import-Module Az.Security
Write-Host "Checking registration for Microsoft Security" -ForegroundColor Yellow
if(!((Get-AzResourceProvider -ProviderNamespace 'Microsoft.Security').RegistrationState[0] -Like "Registered")){
        Write-Host "Your subscription is not registered for Microsoft Security"
        Write-Host "Registering for Microsoft Security, this can take couple minutes"
        Register-AzResourceProvider -ProviderNamespace 'Microsoft.Security'
        while(!((Get-AzResourceProvider -ProviderNamespace 'Microsoft.Security').RegistrationState[0] -Like "Registered")){
                Start-Sleep -s 10
        }
}
(Get-AzManagementGroup -GroupName "lz-management-group" -Expand).Children | ForEach-Object {
        Set-AzContext -SubscriptionId $_.Name
        Set-AzSecurityPricing -Name "VirtualMachines" -PricingTier "Standard" | Out-Null
        Set-AzSecurityPricing -Name "SqlServers" -PricingTier "Standard" | Out-Null
        Set-AzSecurityPricing -Name "AppServices" -PricingTier "Standard" | Out-Null
        Set-AzSecurityPricing -Name "StorageAccounts" -PricingTier "Standard" | Out-Null
        Set-AzSecurityPricing -Name "KubernetesService" -PricingTier "Standard" | Out-Null
        Set-AzSecurityPricing -Name "SqlServerVirtualMachines" -PricingTier "Standard" | Out-Null
        Set-AzSecurityPricing -Name "ContainerRegistry" -PricingTier "Standard" | Out-Null
        Set-AzSecurityPricing -Name "KeyVaults" -PricingTier "Standard" | Out-Null

        #
        # Set auto-provisionning for Azure Security Center agents
        #
        Write-Host "Checking that security center is enabled and auto-provisioning is working" -ForegroundColor Yellow
        if(!((Get-AzSecurityAutoProvisioningSetting -Name "default").AutoProvision -Like "On")){
                Set-AzSecurityAutoProvisioningSetting -Name "default" -EnableAutoProvision
        }
}
