Param
(
  [Parameter (Mandatory= $true)]
  [String] $sid
)

$connectionName = Get-AutomationVariable -name "RunAsConnectionName"
$managementGroupName = Get-AutomationVariable -name "managementGroupName"
$name = Get-AutomationVariable -Name "name"
$seclogSubscriptionId = Get-AutomationVariable -Name "seclogSubscriptionId"

try
{
    $connection=Get-AutomationConnection -Name $connectionName         

    "Logging in to Azure..."
    Connect-AzAccount `
        -ServicePrincipal `
        -TenantId $connection.TenantId `
        -ApplicationId $connection.ApplicationId `
        -CertificateThumbprint $connection.CertificateThumbprint `

    "Logged in"

	
	Set-AzContext -SubscriptionId $sid
	$guid = New-Guid
	$startTime = Get-Date -Format o
	New-AzRoleAssignmentScheduleRequest -Name $guid -Scope "/subscriptions/$sid" -ExpirationDuration PT4H -RoleDefinitionId "/subscriptions/$sid/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c" -PrincipalId "6bc6f785-40a9-4e25-83cc-cd10260ed1bb" -RequestType "AdminAssign" -ScheduleInfoStartDateTime $startTime -ExpirationType "AfterDuration" -Justification "Allow CSIRC Investigation"
}
catch {
    if (!$connection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}