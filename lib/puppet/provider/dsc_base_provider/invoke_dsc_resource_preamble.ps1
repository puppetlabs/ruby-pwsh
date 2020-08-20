$script:ErrorActionPreference = 'Stop'
$script:WarningPreference = 'SilentlyContinue'

$response = @{
    indesiredstate = $false
    rebootrequired = $false
    errormessage   = ''
}
