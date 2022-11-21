function Build-CSPList {
	<#
		.SYNOPSIS
			Find available configuration service providers

		.DESCRIPTION
			Connects to the Microsoft Docs and retrieve the list of currently documented CSP's

		.EXAMPLE
			Find-CSP -CSP policy-csp-abovelock

			Retrieve the policy-csp-abovelock policy

		.NOTES
			Internal function which returns all CSP's found
	#>
	[CmdletBinding(DefaultParameterSetName = 'Default')]
	[OutputType('System.String')]
	param()

	try {
		$urlList = [ordered]@{}
		$ret = Invoke-WebRequest -Uri 'https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-configuration-service-provider'
		$foundLinks = ($ret.Links.href -split '#' | Where-Object { ($_ -like 'policy-csp*') } )

		$counter = 0
		foreach ($link in $foundLinks ) {
			if ($link -match 'policy-') {
				if (-NOT($urlList.Contains($link))) {
					$urlList.Add($link, "https://learn.microsoft.com/en-us/windows/client-management/mdm/$link")
					$counter++
				}
			}
		}

		Write-Verbose "Removing old CSP List: $env:Temp\policiesFound.json"
		if (Test-Path -Path "$env:Temp\policiesFound.json") { Remove-Item -Path "$env:Temp\policiesFound.json" -Force -ErrorAction Stop }
		Write-Verbose "Saving CSP List: $env:Temp\policiesFound.json"
		$urlList | ConvertTo-Json | Out-File -FilePath "$env:Temp\policiesFound.json" -Append -ErrorAction Stop
	}
	catch {
		"Error: $_"
	}
}

function Find-CSP {
	<#
	.SYNOPSIS
		Find CPS's

	.DESCRIPTION
		Find and current CSP's on Microsoft Docs for Windows version supportability

	.PARAMETER CSP
		CSP to search for

	.PARAMETER CSP
		Name of CSP to retrieve from Microsoft Docs

	.PARAMETER DisplayCSPs
		Show the list of available CSP's

	.EXAMPLE
		Find-CSP -CSP policy-csp-abovelock

		Retrieve the policy-csp-abovelock policy

	.EXAMPLE
		Find-CSP -CSP windows <ctrl + space>

		This will use dynamic tab completion and search all available csp's that contain the word 'windows'

	.NOTES
		None
	#>

	[CmdletBinding(DefaultParameterSetName = 'Default')]
	[OutputType('System.Collections.Hashtable')]
	param(
		[string]
		$CSP,

		[switch]
		$DisplayCSPs
	)

	begin {
		Build-CSPList
		Write-Verbose "Starting"
		$parameters = $PSBoundParameters
		[System.Collections.ArrayList]$cspList = @{}
	}

	process {
		try {
			if ($parameters.ContainsKey('DisplayCSPs')) {
				Get-Content -Path "$env:Temp\policiesFound.json" | ConvertFrom-Json -AsHashtable #| Select-Object -ExpandProperty Keys
				return
			}

			Write-Verbose "Retrieving new CSP list from: $env:Temp\policiesFound.json"
			Write-Verbose "Processing $CSP - https://learn.microsoft.com/en-us/windows/client-management/mdm/$CSP"
			$uri = "https://learn.microsoft.com/en-us/windows/client-management/mdm/$CSP"
			$request = Invoke-WebRequest -Uri $uri -ErrorAction Stop

			# Format policies
			$policies = ($request.RawContent -split '\s') | Where-Object { $_ -ne '' }
			$foundPolicies = ((($policies | Select-String -Pattern 'self-bookmark' -Context 0, 1 )) -replace '> data-linktype="self-bookmark">|</a>|</dd>|> ', '' | Where-Object { $_ -ne '' }) -replace '\s', ''

			# Format table
			$lines = ((($request.RawContent -split '\s' | Where-Object { $_ -match '<th>|</th>|<tr>|</tr>|<td>|</td>|<tbody>|</tbody>|<table>|</table>' }) -replace '<th>|</th>|<tr>|</tr>|<td>|</td>|<tbody>|</tbody>|<table>|</table>', '').trim() -ne '') -join ' '
			$null = $lines -match '(\w+).(\w+\s+\d+).(\w+\s+\d+).(\w+).(\w+).(\w+).(\w+).(\w+).(\w+).(\w+).(\w+).(\w+).(\w+).(\w+).(\w+).(\w+).(\w+).(\w+).(\w+).(\w+).(\w+).(\w+)'
			$lines = ($lines -replace 'Edition|Windows|10|11|, ', '' ) -split ' ' | Where-Object { $_ -ne '' }
			$policyCounter = 0

			Write-Verbose "Formatting CSP"
			for ($counter = 0 ; $counter -lt $lines.count; $counter += 3) {
				$cspItem = [PSCustomObject]@{
					'Policy'     = if (($foundPolicies -is [System.String]) -and ($foundPolicies)) { $foundPolicies }
					elseif (-NOT($foundPolicies)) { 'No Policies' }
					elseif ($foundPolicies -is [System.Array]) { $foundPolicies[$policyCounter] }
					'Edition'    = if ( $lines[$counter] -eq 'SE' ) { "Windows SE" } else { $lines[$counter] }
					'Windows 10' = if ( $lines[$counter + 1] -match 'Yes1607' ) { $lines[$counter + 1] -replace 'Yes1607', 'Yes, starting in Windows 10 build 1607' } else { $lines[$counter + 1] }
					'Windows 11' = $lines[$counter + 2]
				}
				$null = $cspList.add($cspItem)
				if ($lines[$counter] -eq 'Education') { $policyCounter ++ }
			}

			# Display list
			$cspList
		}
		catch {
			$statusCode = $_.Exception.Response.StatusCode.value__
			Write-Output "ERROR: $statusCode Web page not found -> $uri"
		}
	}

	end {
		Write-Output "Finished!"
	}
}

# Activate `TAB` completion for the 'Find-CSP' function and parameter 'CSP'. Pressing `TAB` returns what is defined in the action of the scriptblock
Register-ArgumentCompleter -CommandName Find-CSP, Get-Date -ParameterName CSP -ScriptBlock {
	param($commandName, $parameterName, $filter)
	Get-Content -Path "$env:Temp\policiesFound.json" |
	ConvertFrom-Json -AsHashtable |
	Select-Object -ExpandProperty Keys |
	Where-Object { $_ -like "*$filter*" } |
	ForEach-Object { New-Object -Type System.Management.Automation.CompletionResult -ArgumentList $_, $_, "ParameterValue", "https://learn.microsoft.com/en-us/windows/client-management/mdm/$_" }
}
