$assignmentIdList = (Get-AzPolicyState | Where-Object {$_.PolicyAssignmentName -Like "SLZ-*" -And $_.ComplianceState -Like "NonCompliant"}).PolicyAssignmentId | Sort-Object | Get-Unique
    foreach ($assignmentId in $assignmentIdList){
            $assignmentName = $assignmentId.split("/") | Select-Object -Last 1
            Start-AzPolicyRemediation -Name "myRemedation_$assignmentName" -PolicyAssignmentId $assignmentId
    }