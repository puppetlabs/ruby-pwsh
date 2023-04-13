Get-ChildItem WSMan:\localhost\Listener\ -OutVariable Listeners | Format-List * -Force
$HTTPListener = $Listeners | Where-Object -FilterScript { $_.Keys.Contains('Transport=HTTP') }
If ($HTTPListener.Count -eq 0) {
  winrm create winrm/config/Listener?Address=*+Transport=HTTP
  winrm e winrm/config/listener
}
