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
    
    $assignmentList = (Get-AzPolicyState | Where-Object { $_.PolicyAssignmentName -Like "SLZ-*" -And $_.ComplianceState -eq "NonCompliant" -And $_.PolicyDefinitionAction -eq "deployifnotexists" }) | Sort-Object -Unique -Property PolicyDefinitionReferenceId, PolicyDefinitionId
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
