Try {
  $Result = Invoke-DscResource @InvokeParams
} catch {
  $Response.errormessage   = $_.Exception.Message
  return ($Response | ConvertTo-Json -Compress)
}

# keep the switch for when Test passes back changed properties
Switch ($invokeParams.Method) {
  'Test' {
    $Response.indesiredstate = $Result.InDesiredState
    return ($Response | ConvertTo-Json -Compress)
  }
  'Set' {
    $Response.indesiredstate = $true
    $Response.rebootrequired = $Result.RebootRequired
    return ($Response | ConvertTo-Json -Compress)
  }
  'Get' {
    $CanonicalizedResult = ConvertTo-CanonicalResult -Result $Result
    return ($CanonicalizedResult | ConvertTo-Json -Compress -Depth 10)
  }
}
