$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

    "Logging in to Azure..."
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

#
# External resource required
#
$definitionListv1URI = "https://raw.githubusercontent.com/digitc1/AzLandingZonePublic/master/definitions/definitionList1.txt"
$definitionParametersv1URI = "https://raw.githubusercontent.com/digitc1/AzLandingZonePublic/master/definitions/parameters1.json"
$definitionListv2URI = "https://raw.githubusercontent.com/digitc1/AzLandingZonePublic/master/definitions/definitionList2.txt"
$definitionParametersv2URI = "https://raw.githubusercontent.com/digitc1/AzLandingZonePublic/master/definitions/parameters2.json"
$definitionListv3URI = "https://raw.githubusercontent.com/digitc1/AzLandingZonePublic/master/definitions/definitionList3.txt"
$definitionParametersv3URI = "https://raw.githubusercontent.com/digitc1/AZLandingZonePublic/master/definitions/parameters3.json"
$definitionSecurityCenterCoverage = "https://raw.githubusercontent.com/digitc1/AzLandingZonePublic/master/definitions/securityCenter/definition-securityCenterCoverage.json"
$definitionSecurityCenterAutoProvisioning = "https://raw.githubusercontent.com/digitc1/AzLandingZonePublic/master/definitions/securityCenter/definition-securityCenterAutoProvisioning.json"

#
# Create variables needed for this script
#
$name = Get-AutomationVariable -Name "name"
$name
$managementGroupName = Get-AutomationVariable -Name "managementGroup"
$managementGroupName
if (!( $GetResourceGroup = Get-AzureRmResourceGroup | Where-Object {$_.ResourceGroupName -Like "*$name*"} )) {
    "No Resource Group for Secure Landing Zone found"
    return 1;
}
if (!( $GetStorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $GetResourceGroup.ResourceGroupName | Where-Object { $_.StorageAccountName -Like "*$name*" } )) {
    "No Storage Account found for Secure Landing Zone"
    return 1;
}
if (!($GetManagementGroup = Get-AzureRmManagementGroup -Expand -GroupName $managementGroupName )) {
    Write-Host "No Management group found for Secure Landing Zone"
    return 1;
}
$location = $GetResourceGroup.Location
$scope = ($GetManagementGroup).Id

#
# Creating policy definition related to Azure Security Center
#
"Checking registration for Azure Security Center CIS Benchmark"
if (!( Get-AzureRmPolicyAssignment -Scope $scope -Name "ASC_Default" )) {
    "Enabling first monitoring in Azure Security Center"
    $Policy = Get-AzureRmPolicySetDefinition | Where-Object { $_.Properties.displayName -EQ 'Enable Monitoring in Azure Security Center' }
    New-AzureRmPolicyAssignment -Name "ASC_Default" -DisplayName "Azure Security Center - Default" -PolicySetDefinition $Policy -Scope $scope | Out-Null
}
"Checking registration for extended Azure Security Center CIS Benchmark"
if (!( Get-AzureRmPolicyAssignment -Scope $scope -Name "ASC_CIS" )) {
    "Enabling second monitoring in Azure Security Center"
    $Policy = Get-AzureRmPolicySetDefinition | Where-Object { $_.Properties.displayName -EQ 'CIS Microsoft Azure Foundations Benchmark 1.1.0' }
    New-AzureRmPolicyAssignment -Name "ASC_CIS" -DisplayName "Azure Security Center - CIS Compliance" -PolicySetDefinition $Policy -Scope $scope -listOfRegionsWhereNetworkWatcherShouldBeEnabled $location | Out-Null
}
"Checking policy for Azure Security Center coverage"
if (!(Get-AzureRmPolicyAssignment -Scope $scope -Name "SLZ-SCCoverage" )) {
    "Enabling Azure Security Center coverage"
    Invoke-WebRequest -Uri $definitionSecurityCenterCoverage -OutFile $HOME/rule.json
    $policyDefinition = New-AzureRmPolicyDefinition -Name "SLZ-SCCoverage" -Policy $HOME/rule.json -ManagementGroupName $GetManagementGroup.Name
    New-AzureRmPolicyAssignment -name "SLZ-SCCoverage" -PolicyDefinition $policyDefinition -Scope $scope -AssignIdentity -Location $location | Out-Null
    Remove-Item -Path $HOME/rule.json
}
"Checking policy for Azure Security Center Auto-provisioning agents"
if (!(Get-AzureRmPolicyAssignment -Scope $scope -Name "SLZ-SCAutoProvisioning" )) {
    "Enabling Azure Security Center auto-provisioning"
    Invoke-WebRequest -Uri $definitionSecurityCenterAutoProvisioning -OutFile $HOME/rule.json
    $policyDefinition = New-AzureRmPolicyDefinition -Name "SLZ-SCAutoProvisioning" -Policy $HOME/rule.json -ManagementGroupName $GetManagementGroup.Name
    New-AzureRmPolicyAssignment -name "SLZ-SCAutoProvisioning" -PolicyDefinition $policyDefinition -Scope $scope -AssignIdentity -Location $location | Out-Null
    Remove-Item -Path $HOME/rule.json
}

# Loop to create all "SLZ-...........DiagnosticToStorageAccount" policies
Invoke-WebRequest -Uri "$definitionParametersv1URI" -OutFile $HOME/parameters.json
Invoke-WebRequest -Uri "$definitionListv1URI" -OutFile $HOME/definitionList.txt
$definitionList = @()

Get-Content -Path $HOME/definitionList.txt | ForEAch-Object {
    $policyName = "SLZ-" + $_.Split(',')[0] + "1"
    $policyVersion = $_.Split(',')[1]
    $policyLink = $_.Split(',')[2]

    "Checking policy : $policyName"

    if ($GetPolicyInitiative = Get-AzureRmPolicySetDefinition -ManagementGroupName $GetManagementGroup.Name -Name "SLZ-policyGroup1" ) {
        if ($tmp = $GetPolicyInitiative.Properties.PolicyDefinitions.Where( { $_.PolicyDefinitionId -Like "*$policyName" }, 'SkipUntil', 1)) {
            $effect = $tmp.parameters.effect.value
        }
        else {
            $effect = "DeployIfNotExists"
        }
    }
    else {
        $effect = "DeployIfNotExists"
    }
    $param = @{ storageAccountId = @{value = $GetStorageAccount.Id }; region = @{value = $GetResourceGroup.Location }; effect = @{value = $effect } }

    $policyDefinition = Get-AzureRmPolicyDefinition -ManagementGroupName $GetManagementGroup.Name | Where-Object { $_.Name -like $policyName }
    if ($policyDefinition) {
        if (!($policyDefinition.Properties.metadata.version -eq $policyVersion)) {
            Invoke-WebRequest -Uri $policyLink -OutFile $HOME/$policyName.json
            $metadata = '{"version":"' + $policyVersion + '"}'
            $policyDefinition = Set-AzureRmPolicyDefinition -Id $policyDefinition.ResourceId -Policy $HOME/$policyName.json -Metadata $metadata
            Remove-Item -Path $HOME/$policyName.json
            "Updated policy: $policyName"
        }
    }
    else {
        Invoke-WebRequest -Uri $policyLink -OutFile $HOME/$policyName.json
        $metadata = '{"version":"' + $policyVersion + '"}'
        $policyDefinition = New-AzureRmPolicyDefinition -Name $policyName -Policy $HOME/$policyName.json -Parameter $HOME/parameters.json -Metadata $metadata -ManagementGroupName $GetManagementGroup.Name
        Remove-Item -Path $HOME/$policyName.json
        "Created policy: $policyName"
    }
    $definitionList += @{policyDefinitionId = $policyDefinition.ResourceId; parameters = $param }
}
Set-AzureRmPolicySetDefinition -ManagementGroupName $GetManagementGroup.Name -Name $GetPolicyInitiative.Name -PolicyDefinition ($definitionList | ConvertTo-Json -Depth 5) | Out-Null
Remove-Item -Path $HOME/parameters.json
Remove-Item -Path $HOME/definitionList.txt

# Loop to create all "SLZ-...........DiagnosticToLogAnalytics" policies if log analytics workspace exists
if ($GetLogAnalyticsWorkspace = Get-AzureRmOperationalInsightsWorkspace -ResourceGroupName $GetResourceGroup.ResourceGroupName) {
    Invoke-WebRequest -Uri $definitionParametersv2URI -OutFile $HOME/parameters.json
    Invoke-WebRequest -Uri $definitionListv2URI -OutFile $HOME/definitionList.txt
    $definitionList = @()

    Get-Content -Path $HOME/definitionList.txt | ForEAch-Object {
        $policyName = "SLZ-" + $_.Split(',')[0] + "2"
        $policyVersion = $_.Split(',')[1]
        $policyLink = $_.Split(',')[2]

        "Checking policy : $policyName"
        if ( $GetPolicyInitiative = Get-AzureRmPolicySetDefinition -ManagementGroupName $GetManagementGroup.Name -Name "SLZ-policyGroup2" ) {
            if ($tmp = $GetPolicyInitiative.Properties.PolicyDefinitions.Where( { $_.PolicyDefinitionId -Like "*$policyName" }, 'SkipUntil', 1)) {
                $effect = $tmp.parameters.effect.value
            }
            else {
                $effect = "DeployIfNotExists"
            }
        }
        else {
            $effect = "DeployIfNotExists"
        }
        $param = @{ workspaceId = @{value = $GetLogAnalyticsWorkspace.ResourceId }; region = @{value = $GetResourceGroup.Location }; effect = @{value = $effect } }

        $policyDefinition = Get-AzureRmPolicyDefinition -ManagementGroupName $GetManagementGroup.Name -Name $policyName -ErrorAction Continue
        if ($policyDefinition) {
            if (!($policyDefinition.Properties.metadata.version -eq $policyVersion)) {
                Invoke-WebRequest -Uri $policyLink -OutFile $HOME/$policyName.json
                $metadata = '{"version":"' + $policyVersion + '"}'
                $policyDefinition = Set-AzureRmPolicyDefinition -Id $policyDefinition.ResourceId -Policy $HOME/$policyName.json -Metadata $metadata
                Remove-Item -Path $HOME/$policyName.json
                "Updated : $policyName"
            }
        }
        else {
            Invoke-WebRequest -Uri $policyLink -OutFile $HOME/$policyName.json
            $metadata = '{"version":"' + $policyVersion + '"}'
            $policyDefinition = New-AzureRmPolicyDefinition -Name $policyName -Policy $HOME/$policyName.json -Parameter $HOME/parameters.json -Metadata $metadata -ManagementGroupName $GetManagementGroup.Name
            Remove-Item -Path $HOME/$policyName.json
            "Created : $policyName"
        }
        $definitionList += @{policyDefinitionId = $policyDefinition.ResourceId; parameters = $param }
    }
    Set-AzureRmPolicySetDefinition -ManagementGroupName $GetManagementGroup.Name -Name $GetPolicyInitiative.Name -PolicyDefinition ($definitionList | ConvertTo-Json -Depth 5) | Out-Null
    Remove-Item -Path $HOME/parameters.json
    Remove-Item -Path $HOME/definitionList.txt
}

# Loop to create all "SLZ-...........DiagnosticToEventHub" policies
if ($GetEventHubNamespace = Get-AzureRmEventHubNamespace -ResourceGroupName $GetResourceGroup.ResourceGroupName) {
    $GetEventHubAuthorizationRuleId = Get-AzureRmEventHubAuthorizationRule -ResourceGroupName $GetResourceGroup.ResourceGroupName -Namespace $GetEventHubNamespace.Name -Name "landingZoneAccessKey"
    Invoke-WebRequest -Uri $definitionParametersv3URI -OutFile $HOME/parameters.json
    Invoke-WebRequest -Uri $definitionListv3URI -OutFile $HOME/definitionList.txt
    $definitionList = @()

    Get-Content -Path $HOME/definitionList.txt | ForEAch-Object {
        $policyName = "SLZ-" + $_.Split(',')[0] + "3"
        $policyVersion = $_.Split(',')[1]
        $policyLink = $_.Split(',')[2]

        "Checking policy : $policyName"
        if ($GetPolicyInitiative = Get-AzureRmPolicySetDefinition -ManagementGroupName $GetManagementGroup.Name -Name "SLZ-policyGroup3" ) {
            if ($tmp = $GetPolicyInitiative.Properties.PolicyDefinitions.Where( { $_.PolicyDefinitionId -Like "*$policyName" }, 'SkipUntil', 1)) {
                $effect = $tmp.parameters.effect.value
            }
            else {
                $effect = "DeployIfNotExists"
            }
        }
        else {
            $effect = "DeployIfNotExists"
        }
        $param = @{ eventHubRuleId = @{value = $GetEventHubAuthorizationRuleId.Id }; region = @{value = $GetResourceGroup.Location }; effect = @{value = $effect }; eventHubName = @{value = "insights-operational-logs" } }

        $policyDefinition = Get-AzureRmPolicyDefinition -ManagementGroupName $GetManagementGroup.Name -Name $policyName -ErrorAction Continue
        if ($policyDefinition) {
            if (!($policyDefinition.Properties.metadata.version -eq $policyVersion)) {
                Invoke-WebRequest -Uri $policyLink -OutFile $HOME/$policyName.json
                $metadata = '{"version":"' + $policyVersion + '"}'
                $policyDefinition = Set-AzureRmPolicyDefinition -Id $policyDefinition.ResourceId -Policy $HOME/$policyName.json -Metadata $metadata
                Remove-Item -Path $HOME/$policyName.json
                "Updated : $policyName"
            }
        }
        else {
            Invoke-WebRequest -Uri $policyLink -OutFile $HOME/$policyName.json
            $metadata = '{"version":"' + $policyVersion + '"}'
            $policyDefinition = New-AzureRmPolicyDefinition -Name $policyName -Policy $HOME/$policyName.json -Parameter $HOME/parameters.json -Metadata $metadata -ManagementGroupName $GetManagementGroup.Name
            Remove-Item -Path $HOME/$policyName.json
            "Created : $policyName"
        }
        $definitionList += @{policyDefinitionId = $policyDefinition.ResourceId; parameters = $param }
    }
    Set-AzureRmPolicySetDefinition -ManagementGroupName $GetManagementGroup.Name -Name $GetPolicyInitiative.Name -PolicyDefinition ($definitionList | ConvertTo-Json -Depth 5) | Out-Null
    Remove-Item -Path $HOME/parameters.json
    Remove-Item -Path $HOME/definitionList.txt
}
