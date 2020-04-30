###################################
#                                 #
#     Joining Azure LZ Script     #
#                                 #
###################################

#
# Define a context to run the script and create variables
# If multiple subscription exist under the tenant, user is prompted to choose a subscription
#
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"
Write-Host "Create variables" -ForegroundColor Yellow

$subscription = Get-AzSubscription | where-Object {$_.Name -Like "SecLog*"}
$context = Set-AzContext -SubscriptionId $subscription.Id
Write-Host "Using subscription : " $context.Subscription.Name

$name = "lzslz"
$locations = (Get-AzLocation).Location
$locations += "global"

#
# Creating Landing Zone resources
# Moved to external file for reusability
#
./setup-resources.ps1 $name


#
# Creating policy definition
# Moved to external file for reusability
#
./setup-policy.ps1 $name

#
# Creating Azure Lighthouse delegation
# Moved to external file for reusability
#
./setup-lighthouse.ps1

#
# End of script information
#
Write-Host "Script completed successfully" -ForegroundColor Yellow
$GetResourceGroup = Get-AzResourceGroup -ResourceGroupName $name*
if($GetLogAnalyticsWorkspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $GetResourceGroup.ResourceGroupName){
	Write-Host "Make sure to provide the following information to your SoC team" -ForegroundColor Yellow
	Write-Host "Log Analytics Workspace : " $GetLogAnalyticsWorkspace.CustomerId
}
if($GetEventHub = Get-AzEventHubNameSpace -ResourceGroupName $GetResourceGroup.ResourceGroupName | Where-Object {$_.Name -Like "$name*"}){
	$GetEventHubKey = Get-AzEventHubKey -ResourceGroupName $GetResourceGroup.ResourceGroupName -Namespace $GetEventHub.Name -Name "landingZoneAccessKey"
	$serviceBus = "sb://" + $GetEventHub.ServiceBusEndpoint.Split('/')[2].Split(':')[0]
	Write-Host "Make sure to provide the following information to your SoC team" -ForegroundColor Yellow
	Write-Host "ServiceBusEndpoint : " $serviceBus
	Write-Host "Read Only Primary key : " $GetEventHubKey.PrimaryKey
}