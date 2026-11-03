# Connect to the Microsoft Graph with the required scopes
Connect-MgGraph -Scope "AccessReview.Read.All"
 
# Get all access review defintions
Write-Host "Getting access review definitions"
$Definitions = Get-MgIdentityGovernanceAccessReviewDefinition -All -Verbose
 
# Filter to only those we care about
# $Definitions = $Definitions | Where-Object {$_.Scope.AdditionalProperties.query -like "*accessPackageAssignments*"}
$Definitions = $Definitions | Where-Object { $_.DisplayName -like "*LOBApp_PRD61*" }
 
# For each definition, get the latest completed instance
$Report = foreach ($Definition in $Definitions) {
    # Use to step through: $Definition = $Definitions | get-random -count 1
    Write-Host "Processing $($Definition.Status) AR: $($Definition.DisplayName) ($($Definition.Id))"
    $Instances = Get-MgIdentityGovernanceAccessReviewDefinitionInstance -AccessReviewScheduleDefinitionId $Definition.id -All
    $Instance = $Instances | Where-Object Status -in @("Completed","Applied") | Sort-object EndDateTime -Descending | Select-Object -First 1
 
    if (!$Instance) {
        Write-Warning "No active or completed instances found for $($Definition.DisplayName) ($($Definition.Id))    "
    }
    else {
        # Get all decisions for the instance
        $Decisions = Get-MgIdentityGovernanceAccessReviewDefinitionInstanceDecision -AccessReviewInstanceId $Instance.Id -AccessReviewScheduleDefinitionId $Definition.id -All
 
        # Process each decision, outputting a custom object for each
        foreach ($Decision in $Decisions) {
            # Use to step through: $Decision = $Decisions | get-random -count 1
            [PSCustomObject] @{
                Definition_DisplayName                = $Definition.DisplayName
                Definition_Status                     = $Definition.Status
                Decision_Principal_DisplayName        = $Decision.Principal.DisplayName
                Decision_Decision                     = $Decision.Decision
                Decision_Resource_DisplayName         = $Decision.Resource.DisplayName
                Decision_Resource_Id                  = $Decision.Resource.Id
                Instance_Id                           = $Instance.Id
                Instance_StartDateTime                = $Instance.StartDateTime
                Instance_EndDateTime                  = $Instance.EndDateTime
                Decision_ApplyResult                  = $Decision.ApplyResult
            }
        }
    }
}
 
# To use Export-Excel, run this first: Install-Module ImportExcel -Scope CurrentUser
$Report | Export-Csv -Path ".\AccessReviewReport.Csv" 
