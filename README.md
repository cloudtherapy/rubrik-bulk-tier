# Rubrik Bulk Tier Management

PowerShell scripts for managing tiering policies across multiple Rubrik snapshots and NAS shares.

## Overview

This repository contains PowerShell scripts designed to automate the process of setting tiering policies on Rubrik snapshots and NAS shares. The scripts help manage storage tiering across multiple objects efficiently.

## Scripts

### Main Scripts
- `Set-TieringOnSnapshots.ps1`: Sets tiering policies on Rubrik snapshots
- `Get-NasShares.ps1`: Retrieves information about NAS shares
- `Set-TieringExistingSnapshots.ps1`: Manages tiering policies on existing snapshots

## Prerequisites

- PowerShell 5.1 or higher
- Rubrik PowerShell Module
- Appropriate permissions on Rubrik cluster

## Usage

1. Import the Rubrik PowerShell Module
2. Connect to your Rubrik cluster
3. Run the desired script with appropriate parameters

## License

This project is licensed under the terms of the LICENSE file.