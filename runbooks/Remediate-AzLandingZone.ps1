$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "

    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName

    "Logging in to Azure..."
    $connectionResult =  Connect-AzAccount -Tenant $servicePrincipalConnection.TenantID `
                             -ApplicationId $servicePrincipalConnection.ApplicationID   `
                             -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint `
                             -ServicePrincipal
    "Logged in."
    
    $assignmentIdList = (Get-AzPolicyState | Where-Object {$_.PolicyAssignmentName -Like "SLZ-*" -And $_.ComplianceState -Like "NonCompliant"}).PolicyAssignmentId | Sort-Object | Get-Unique
    foreach ($assignmentId in $assignmentIdList){
        $assignmentName = $assignmentId.split("/") | Select-Object -Last 1
        "Running Remediation for $assignmentName"
        Start-AzPolicyRemediation -Name "myRemedation_$assignmentName" -PolicyAssignmentId $assignmentId | Out-Null
    }
    "Script Completed."
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
