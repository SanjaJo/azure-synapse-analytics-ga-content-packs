$InformationPreference = "Continue"

if(Get-Module -Name solliance-synapse-automation){
    Remove-Module solliance-synapse-automation
}
Import-Module "..\solliance-synapse-automation"

#Different approach to run automation in Cloud Shell
$subs = Get-AzSubscription | Select-Object -ExpandProperty Name
if($subs.GetType().IsArray -and $subs.length -gt 1){
    $subOptions = [System.Collections.ArrayList]::new()
    for($subIdx=0; $subIdx -lt $subs.length; $subIdx++){
            $opt = New-Object System.Management.Automation.Host.ChoiceDescription "$($subs[$subIdx])", "Selects the $($subs[$subIdx]) subscription."   
            $subOptions.Add($opt)
    }
    $selectedSubIdx = $host.ui.PromptForChoice('Enter the desired Azure Subscription for this lab','Copy and paste the name of the subscription to make your choice.', $subOptions.ToArray(),0)
    $selectedSubName = $subs[$selectedSubIdx]
    Write-Information "Selecting the $selectedSubName subscription"
    Select-AzSubscription -SubscriptionName $selectedSubName
}

$resourceGroupName = Read-Host "Enter the resource group name";

$userName = ((az ad signed-in-user show) | ConvertFrom-JSON).UserPrincipalName

$artifactsPath = "..\..\"
$reportsPath = "..\reports"
$templatesPath = "..\templates"
$datasetsPath = "..\datasets"
$dataflowsPath = "..\dataflows"
$pipelinesPath = "..\pipelines"
$sqlScriptsPath = "..\sql"


Write-Information "Using $resourceGroupName";

$resourceGroup = Get-AzResourceGroup -Name $resourceGroupName
$uniqueId =  $resourceGroup.Tags["DeploymentId"]
$location = $resourceGroup.Location
$subscriptionId = (Get-AzContext).Subscription.Id
$tenantId = (Get-AzContext).Tenant.Id
$global:logindomain = (Get-AzContext).Tenant.Id;

$workspaceName = "asagaworkspace$($uniqueId)"
$dataLakeAccountName = "asagadatalake$($uniqueId)"
$keyVaultName = "asagakeyvault$($uniqueId)"
$keyVaultSQLUserSecretName = "SQL-USER-ASA"
$sqlPoolName = "SQLPool01"
$integrationRuntimeName = "AutoResolveIntegrationRuntime"
$sparkPoolName = "SparkPool01"
$global:sqlEndpoint = "$($workspaceName).sql.azuresynapse.net"
$global:sqlUser = "asaga.sql.admin"

Write-Information "Creating the SalesTelemetry table"

$kustoCluster = "asagadataexplorer$($uniqueId).$($location)"
$kustoDatabaseName = "ASA-Data-Explorer-DB-01"
$kustoStatement = ".create table SalesTelemetry ( CustomerId:int32, ProductId:int32, Timestamp:datetime, Url:string)"

$token = ((az account get-access-token --resource https://help.kusto.windows.net) | ConvertFrom-Json).accessToken
$body = "{ db: ""$kustoDatabaseName"", csl: ""$kustoStatement"" }"
Invoke-RestMethod -Uri https://$kustoCluster.kusto.windows.net/v1/rest/mgmt -Method POST -Body $body -Headers @{ Authorization="Bearer $token" } -ContentType "application/json"