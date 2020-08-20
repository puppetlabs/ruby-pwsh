function new-pscredential {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true)]
        [string]
        $user,

        [parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true)]
        [string]
        $password
    )

    $secpasswd = ConvertTo-SecureString $password -AsPlainText -Force
    $credentials = New-Object System.Management.Automation.PSCredential ($user, $secpasswd)
    return $credentials
}

Function ConvertTo-CanonicalResult {
  [CmdletBinding()]
  param(
      [Parameter(Mandatory, Position = 1)]
      [psobject]
      $Result,

      [Parameter(DontShow)]
      [string]
      $PropertyPath,

      [Parameter(DontShow)]
      [int]
      $RecursionLevel = 0
  )

  $MaxDepth = 5
  $CimInstancePropertyFilter = { $_.Definition -match 'CimInstance' -and $_.Name -ne 'PSDscRunAsCredential' }

  # Get the properties which are/aren't Cim instances
  $ResultObject = @{ }
  $ResultPropertyList = $Result | Get-Member -MemberType Property | Where-Object { $_.Name -ne 'PSComputerName' }
  $CimInstanceProperties = $ResultPropertyList | Where-Object -FilterScript $CimInstancePropertyFilter

  foreach ($Property in $ResultPropertyList) {
      $PropertyName = $Property.Name
      if ($Property -notin $CimInstanceProperties) {
          $Value = $Result.$PropertyName
          if ($PropertyName -eq 'Ensure' -and [string]::IsNullOrEmpty($Result.$PropertyName)) {
              # Just set 'Present' since it was found /shrug
              # If the value IS listed as absent, don't update it unless you want flapping
              $Value = 'Present'
          }
          else {
              if ($Value -is [string] -or $value -is [string[]]) {
                  $Value = $Value
              }

              if ($Value.Count -eq 1 -and $Property.Definition -match '\\[\\]') {
                  $Value = @($Value)
              }
          }
      }
      elseif ($null -eq $Result.$PropertyName) {
          if ($Property -match 'InstanceArray') {
              $Value = @()
          }
          else {
              $Value = $null
          }
      }
      else {
          # Looks like a nested CIM instance, recurse if we're not too deep in already.
          $RecursionLevel++

          if ($PropertyPath -eq [string]::Empty) {
              $PropertyPath = $PropertyName
          }
          else {
              $PropertyPath = "$PropertyPath.$PropertyName"
          }

          if ($RecursionLevel -gt $MaxDepth) {
              # Give up recursing more than this
              return $Result.ToString()
          }

          $Value = foreach ($item in $Result.$PropertyName) {
              ConvertTo-CanonicalResult -Result $item -PropertyPath $PropertyPath -RecursionLevel ($RecursionLevel + 1) -WarningAction Continue
          }

          # The cim instance type is the last component of the type Name
          # We need to return this for ruby to compare the result hashes
          # We do NOT need it for the top-level properties as those are defined in the type
          If ($RecursionLevel -gt 1 -and ![string]::IsNullOrEmpty($Value) ) {
              # If there's multiple instances, you need to add the type to each one, but you
              # need to specify only *one* name, otherwise things end up *very* broken.
              if ($Value.GetType().Name -match '\[\]') {
                  $Value | ForEach-Object -Process {
                      $_.cim_instance_type = $Result.$PropertyName.CimClass.CimClassName[0]
                  }
              } else {
                  $Value.cim_instance_type = $Result.$PropertyName.CimClass.CimClassName
                  # Ensure that, if it should be an array, it is
                  if ($Result.$PropertyName.GetType().Name -match '\[\]') {
                      $Value = @($Value)
                  }
              }
          }
      }

      if ($Property.Definition -match 'InstanceArray') {
          if ($Value.Count -lt 2) { $Value = @($Value) }
      }

      $ResultObject.$PropertyName = $Value
  }

  # Output the final result
  $ResultObject
}