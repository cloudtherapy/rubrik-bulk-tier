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
    Write-Error('Unable to connect to {0}' -f $rubrikAddress)
}

$shares = Get-content $pathtosharelist

$body = @{
    objectIds = @($shares.id)
    locationId = $archivalLocationId
}
Invoke-RubrikRESTCall -Endpoint 'unmanaged_object/snapshot/bulk_archive_tier' -Method POST -Body $body