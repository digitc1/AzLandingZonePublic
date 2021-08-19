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
    
    $name = Get-AutomationVariable -Name "name"
    $retentionPeriod = Get-AutomationVariable -Name "retentionPeriod"
    if (!( $GetResourceGroup = Get-AzResourceGroup | Where-Object {$_.ResourceGroupName -Like "*$name*"} )) {
        "No Resource Group for Secure Landing Zone found"
        return ;
    }
    if (!( $GetStorageAccount = Get-AzStorageAccount -ResourceGroupName $GetResourceGroup.ResourceGroupName | Where-Object { $_.StorageAccountName -Like "*$name*" } )) {
        "No Storage Account found for Secure Landing Zone"
        return ;
    }

    "Setting context to current storage account"
    $context = New-AzStorageContext -StorageAccountName $GetStorageAccount.StorageAccountName

    "Checking list of storage container for Landing Zone Logs in the secure Landing Zone"
    if(!($containers = Get-AzStorageContainer -Context $context)){
        "No Storage account containers found, exiting script"
        return ;
    }
    
    foreach ($container in $containers) {
        "Checking data for $($container.Name)"
        if((($policy = Get-AzRmStorageContainerImmutabilityPolicy -StorageAccountName $GetStorageAccount.StorageAccountName -ResourceGroupName $GetResourceGroup.ResourceGroupName -ContainerName $container.Name).ImmutabilityPeriodSinceCreationInDays) -eq 0){
            $policy = Set-AzRmStorageContainerImmutabilityPolicy -ResourceGroupName $GetResourceGroup.ResourceGroupName -StorageAccountName $GetStorageAccount.StorageAccountName -ContainerName $container.Name -ImmutabilityPeriod $retentionPeriod
            "Immutability policy created for container $($container.Name)"
        }
        if(((Get-AzRmStorageContainerImmutabilityPolicy -StorageAccountName $GetStorageAccount.StorageAccountName -ResourceGroupName $GetResourceGroup.ResourceGroupName -ContainerName $container.Name).State) -eq "Unlocked"){
            Lock-AzRmStorageContainerImmutabilityPolicy -ResourceGroupName $GetResourceGroup.ResourceGroupName -StorageAccountName $GetStorageAccount.StorageAccountName -ContainerName $container.Name -Etag $policy.Etag -Force | Out-Null
            "Immutability policy locked for container $($container.Name)"
        }
    }
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
