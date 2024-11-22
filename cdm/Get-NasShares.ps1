[cmdletbinding()]
param(
    [string]$rubrikAddress,
    [string]$rubrikToken,
    [string]$archivalLocationId,
    [string]$pathtosharelist
)

Import-module rubrik

try {
    Connect-Rubrik -server $rubrikAddress -token $rubrikToken
} catch {
    Write-Error('Unabble to connect to {0}' -f $rubrikAddress)
}

$allShares = Get-RubrikNASShare

$allShares | select-object name,id | convertto-csv | out-file 'allshares.csv'

$allArchivalLocations = Get-RubrikArchive  | select-object name,id | convertto-csv | out-file 'allArchivalLocations.csv'

$allArchivalLocations