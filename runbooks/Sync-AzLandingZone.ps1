$connectionName = "AzureRunAsConnection"
try {
    # Get the connection "AzureRunAsConnection "

    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName

    "Logging in to Azure..."
    $connectionResult = Connect-AzAccount -Tenant $servicePrincipalConnection.TenantID `
        -ApplicationId $servicePrincipalConnection.ApplicationID   `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint `
        -ServicePrincipal
    "Logged in."
    
    $assignmentList = (Get-AzPolicyState -ManagementGroupName lz-management-group -Filter "(PolicyDefinitionAction eq 'deployIfNotExists' and ComplianceState eq 'NonCompliant')" | Sort-Object -Unique -Property PolicyDefinitionReferenceId, PolicyDefinitionId)
    foreach ($assignment in $assignmentList) {
        if ($assignment.PolicyDefinitionReferenceId) {
            "Running Remediation for $($assignment.PolicyDefinitionName)"
            Start-AzPolicyRemediation -Name "myRemedation_$($assignment.PolicyDefinitionName)" -PolicyAssignmentId $assignment.PolicyAssignmentId -PolicyDefinitionReferenceId $assignment.PolicyDefinitionReferenceId | Out-Null
        }
        else {
            "Running Remediation for $($assignment.PolicyDefinitionName)"
            Start-AzPolicyRemediation -Name "myRemedation_$($assignment.PolicyDefinitionName)" -PolicyAssignmentId $assignment.PolicyAssignmentId | Out-Null
        }
    }
    "Script Completed."
}
catch {
    if (!$servicePrincipalConnection) {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    }
    else {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
} 
