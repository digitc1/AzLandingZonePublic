###################################
#                                 #
#       Setup LZ delegation       #
#                                 #
###################################

Write-Host "Checking status of delegated access" -ForegroundColor Yellow

#
# Get the list of children for the management group
#
(Get-AzManagementGroup -GroupName "lz-management-group" -Expand).Children | ForEach-Object {
        Set-AzContext -SubscriptionId $_.Name | Out-Null

        #
        # Set contact email address
        #
        Write-Host "Checking that security center notification is set to DIGIT_VIRTUAL_TASK_FORCE@ec.europa.eu" -ForegroundColor Yellow
        if(!(Get-AzSecurityContact | Where-Object {$_.Email -Like "DIGIT-VIRTUAL-TASK-FORCE@ec.europa.eu"})){
                $count = (Get-AzSecurityContact).Count
                Set-AzSecurityContact -Name "default$($count+1)" -Email "DIGIT-CLOUD-VIRTUAL-TASK-FORCE@ec.europa.eu" -AlertAdmin -NotifyOnAlert | Out-Null
        }
        Write-Host "Checking that security center notification is set to EC-DIGIT-CSIRC@ec.europa.eu" -ForegroundColor Yellow
        if(!(Get-AzSecurityContact | Where-Object {$_.Email -Like "EC-DIGIT-CSIRC@ec.europa.eu"})){
                $param = read-Host "No contact for EC-DIGIT-CSIRC@ec.europa.eu found. Would you like to add it (y/n)"
    		if($param -Like "y"){
                        $count = (Get-AzSecurityContact).Count
                        Set-AzSecurityContact -Name "default$($count+1)" -Email "EC-DIGIT-CSIRC@ec.europa.eu" -AlertAdmin -NotifyOnAlert | Out-Null
                }
        }
        Write-Host "Checking that security center notification is set to EC-DIGIT-CLOUDSEC@ec.europa.eu" -ForegroundColor Yellow
        if(!(Get-AzSecurityContact | Where-Object {$_.Email -Like "EC-DIGIT-CLOUDSEC@ec.europa.eu"})){
                $param = read-Host "No contact for EC-DIGIT-CLOUDSEC@ec.europa.eu found. Would you like to add it (y/n)"
    		if($param -Like "y"){
                        $count = (Get-AzSecurityContact).Count
                        Set-AzSecurityContact -Name "default$($count+1)" -Email "EC-DIGIT-CLOUDSEC@ec.europa.eu" -AlertAdmin -NotifyOnAlert | Out-Null
                }
        }
        $param = read-Host "Would you like to setup additional contacts for security alerts (y/n)"
        while($param -Like "y"){
                $param -Like "n"
                $tmp = Read-Host "Enter the email address for new contact"
                $count = (Get-AzSecurityContact).Count
                Set-AzSecurityContact -Name "default$($count+1)" -Email $tmp -AlertAdmin -NotifyOnAlert | Out-Null
                $param = Read-Host "Successfully added security contact. Add another (y/n) ?"
        }
#
# Following values have been hard-coded in the parameters file:
# Security Reader (read access to the security center) and Log analytics reader (Read access to Azure Log Analytics workspace and all logs) to DIGIT-S1
# Security Reader (read access to the security center) and Log analytics reader (Read access to Azure Log Analytics workspace and all logs) to DIGIT-S2
#
        if(!(Get-AzManagedServicesDefinition | Where-Object {$_.Properties.ManagedByTenantId -Like "3a8968a8-fbcf-4414-8b5c-77255f50f37b"})){
                Write-Host "No delegated access for DIGIT S found. Setup delegated access for DIGIT S ?"
                $param = read-Host "enter y or n (default No)"
                if($param -Like "y"){
                        New-AzDeployment -Name LightHouse -Location westeurope -TemplateFile ./templates/delegatedResourceManagement.json -TemplateParameterFile ./templates/delegatedResourceManagement.parameters.json | Out-Null
                        Write-Host "Delegation created for DIGIT S"
                }
        }
        else{
                Write-Host "Delegated access is already configured." -ForegroundColor "Yellow"
        }
}