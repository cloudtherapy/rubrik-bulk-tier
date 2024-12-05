<#
.SYNOPSIS
    Set tiering on existing NAS DA Snapshots
.NOTES
    Created: November - 2024
    Author: Derek Blackburn
.LINK
    Rubrik Automation Page: build.rubrik.com
.EXAMPLE
    Example
#>
#Requires -Version 7.0
[cmdletbinding()]
param(
    [string]
    $serviceAccountFile,
    [string]
    $clusterName,
    [string]
    $archivalLocationName,
    [string]
    $nasShareName
)

function Write-Log() {
    param (
        $message,
        [switch]$isError,
        [switch]$isSuccess,
        [switch]$isWarning
    )
    $color = 'Blue'
    if($isError){
        $message = 'ERROR: ' + $message
        $color = 'red'
    } elseif($isSuccess){
        $message = 'SUCCESS: ' + $message
        $color = 'green'
    } elseif($isWarning){
        $message = 'WARNING: ' + $message
        $color = 'yellow'
    }
    $message = "$(get-date) $message"
    Write-Host("$message$($PSStyle.Reset)") -BackgroundColor $color
    $message | out-file Set-TieringExistingSnapshots_log.txt -append
    if($isError){
        exit
    }   
}

function Connect-RSC{

  #The following lines are for brokering the connection to RSC
  #Test the service account json for valid json content
  try {
      Get-Content $serviceAccountFile | ConvertFrom-Json | out-null
  }
  catch {
      Write-Log -message 'Service Account Json is not valid, please redownload from Rubrik Security Cloud' -isError
  }

  #Convert the service account json to a PowerShell object
  $serviceAccountJson = Get-Content $serviceAccountFile | convertfrom-json

  #Create headers for the initial connection to RSC
  $headers = @{
      'Content-Type' = 'application/json';
      'Accept'       = 'application/json';
  }

  #Create payload to send for authentication to RSC
  $payload = @{
      grant_type = "client_credentials";
      client_id = $serviceAccountJson.client_id;
      client_secret = $serviceAccountJson.client_secret
  } 

  #Try to send payload through to RSC to get bearer token
  try {
      $response = Invoke-RestMethod -Method POST -Uri $serviceAccountJson.access_token_uri -Body $($payload | ConvertTo-JSON -Depth 100) -Headers $headers    
  }
  catch {
      Write-Log -message "Failed to authenticate, check the contents of the service account json, and ensure proper permissions are granted" -isError
  }

  #Create connection object for all subsequent calls with bearer token
  $connection = [PSCustomObject]@{
      headers = @{
          'Content-Type'  = 'application/json';
          'Accept'        = 'application/json';
          'Authorization' = $('Bearer ' + $response.access_token);
      }
      endpoint = $serviceAccountJson.access_token_uri.Replace('/api/client_token', '/api/graphql')
  }
  #End brokering to RSC
  Write-Log -message 'Authentication to RSC succeeded'
  $global:connection = $connection
  return $connection
}


$rsc = connect-rsc

function Get-Nasshare([object]$cluster, [string]$sharename) {
    $payload = @{
        query = 'query NasShares($filter: [Filter!]) {
                nasShares(filter: $filter) {
                    nodes {
                    id
                    name
                    effectiveSlaDomain {
                        name
                        id  
                    }
                    }
                }
            }'
        variables = @{
            filter = @(
                @{
                    field = "CLUSTER_ID"
                    texts = $cluster.id
                }
                @{
                    field = "NAME_EXACT_MATCH"
                    texts = $sharename
                }
            )            
        }
    }
    $response = (Invoke-RestMethod -Method POST -Uri $rsc.endpoint -Body $($payload | ConvertTo-JSON -Depth 100) -Headers $rsc.headers).data.nasShares.nodes
    return $response
}

function Get-Nasshares([object]$cluster) {
    $payload = @{
        query = 'query NasShares($filter: [Filter!]) {
                nasShares(filter: $filter) {
                    nodes {
                    id
                    name
                    effectiveSlaDomain {
                        name
                        id
                        
                    }
                    }
                }
            }'
        variables = @{
            filter = @(
                @{
                    field = "CLUSTER_ID"
                    texts = $cluster.id
                }
            )            
        }
    }
    $response = (Invoke-RestMethod -Method POST -Uri $rsc.endpoint -Body $($payload | ConvertTo-JSON -Depth 100) -Headers $rsc.headers).data.nasShares.nodes
    return $response
}

function Get-ArchivalLocations() {
    $payload = @{
        query = 'query Nodes($filter: [TargetFilterInput!]) {
            targets(filter: $filter) {
                nodes {
                id
                name
                }
            }
        }'
        variables = @{

        }
    }
    $response = (Invoke-RestMethod -Method POST -Uri $rsc.endpoint -Body $($payload | ConvertTo-JSON -Depth 100) -Headers $rsc.headers).data.targets.nodes
    return $response
}

function Get-Clusters() {
    $payload = @{
        query = 'query Nodes {
            allClusterConnection {
                nodes {
                name
                id
                }
            }
        }'
    }
    $response = (Invoke-RestMethod -Method POST -Uri $rsc.endpoint -Body $($payload | ConvertTo-JSON -Depth 100) -Headers $rsc.headers).data.allClusterConnection.nodes
    return $response
}

function Set-ObjectTiering([string]$clusterUuid, [string]$archivalLocationId, [string] $objectid) {
    $payload = @{
        query = 'mutation BulkTierExistingSnapshots($input: BulkTierExistingSnapshotsInput!) {
            bulkTierExistingSnapshots(input: $input) {
                endTime
                id
                nodeId
                progress
                startTime
                status
                error {
                message
                }
            }
        }'
        variables = @{
            input = @{
                clusterUuid = $clusterUuid
                objectTierInfo = @{
                    locationId = $archivalLocationId
                    objectIds = @($objectId)
                }
            }
        }
    }
    $response = (Invoke-RestMethod -Method POST -Uri $rsc.endpoint -Body $($payload | ConvertTo-JSON -Depth 100) -Headers $rsc.headers)
    return $response
}

$thisCluster = Get-Clusters | Where-Object name -eq $clusterName
if($null -eq $thisCluster){
    Write-Log -isError ('Could not find cluster, check spelling and permissions')
} else {
    Write-Log ('Found cluster {0} with id {1}' -f $thisCluster.name, $thiscluster.id)
}

if($nasShareName){
    $thisShare = Get-Nasshare -cluster $thisCluster -sharename $nasShareName
    if($null -eq $thisShare){
        Write-Log -isError ('Could not find share, check spelling and permissions')
    } else {
        Write-Log ('Found share {0} with id {1}' -f $thisshare.name, $thisshare.id)
    }
    $thisArchive = Get-ArchivalLocations | Where-Object name -eq $archivalLocationName
    if($null -eq $thisArchive){
        Write-Log -isError ('Could not find Archival location, check spelling and permissions')
    } else {
        Write-Log ('Found Archival Location {0} with id {1}' -f $thisArchive.name, $thisArchive.id)
    }
    Write-Log('Starting tier job of {0}' -f $thisShare.name)
    Set-ObjectTiering -clusterUuid $thisCluster.id -archivalLocationId $thisArchive.id -objectid $thisShare.id
} else {
    $statusSet = [System.Collections.ArrayList]::new()
    Write-Log('No nassharename specified iterating')
    $allNasShares = Get-Nasshares -cluster $thisCluster
    Write-Log('Found {0}' -f $allNasShares.count)
    $confirm = Read-Host('Proceed with tiering of all shares? y/n')
    if($confirm -eq 'y'){
        $Archive = Get-ArchivalLocations | Where-Object name -eq $archivalLocationName
        Write-Log ('Found Archival Location {0} with id {1}' -f $Archive.name, $Archive.id)
        foreach($share in $allNasShares){
            Write-Log ('Found share {0} with id {1}' -f $share.name, $share.id)
            $status = "Started"
            try{
                $operation = Set-ObjectTiering -clusterUuid $thisCluster.id -archivalLocationId $thisArchive.id -objectid $thisShare.id
            } catch {
                $status = "Failed"
            }
            if($operation.errors){
                $status = "Failed"
            }
            if($null -eq $operation.errors){
                Write-Log -isSuccess('{0} tiering started' -f $share.name)
            } else {
                Write-Log -isWarning('{0} tiering failed' -f $share.name)
            }
            $thisObject = [PSCustomObject]@{
                Name = $share.Name
                Id = $share.Id
                TieringStarted = $status
            }
            $statusSet.add($thisObject) | Out-Null
        }
    Write-Host('Statuses:')
    $statusSet
    } else {
        $allNasShares
    }
}