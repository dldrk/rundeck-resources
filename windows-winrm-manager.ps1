param([string]$mode, [string]$test)
if ($mode -eq "") { Write-Error "Usage: [script] [enable|disable] [test|] (i.e: [script] enable test)" ; exit 1 }


## CONFIGS
$hostname = $(hostname)
$hostip = (Get-NetIPConfiguration).IPv4Address.IPAddress
$hostcert = "$hostname"+".crt"

#Clear-Host
Write-Output "WINRM PRE-CONFIG REQUIREMENTS:"
Write-Output "`t- Current shell with administrative rights"
Write-Output "`t- Current user within Administrators Domain/LocalGroup"
Write-Output "`t- Current network on Private/Domain mode"
Write-Output "`nCURRENT SCRIPT WILL DO:"
Write-Output "`t- Enable WinRM service on server $hostname - $hostip"
Write-Output "`t- Open ports 5985 (HTTP) - 5986 (HTTPS) for WinRM inbound connections"
Write-Output "`t- Set current network set to Private"
Write-Output "`t- Set WinRM configs to allow client/server unencrypted/encrypted connections"
Write-Output "`t- Export self-signed-certificate to use with HTTPS"

Write-Output "Press any key if all requirements are already satisfied to start configuring. CTRL+C to cancel"
$host.UI.RawUI.ReadKey() > $null


## ENABLE
if ($mode -eq "enable") {
  Write-Output "Enabling WinRM"
  Enable-PSRemoting -Force -SkipNetworkProfileCheck
  New-NetFirewallRule -DisplayName "WinRM-HTTP" -Protocol tcp -Direction in -LocalPort 5985 -Action Allow
  New-NetFirewallRule -DisplayName "WinRM-HTTPS" -Protocol tcp -Direction in -LocalPort 5986 -Action Allow
  Set-NetConnectionProfile -Name (Get-NetConnectionProfile).Name -NetworkCategory Private
  Set-WSManInstance -ResourceURI winrm/config/service/auth -ValueSet @{Basic="true"}
  Set-WSManInstance -ResourceURI winrm/config/service -ValueSet @{AllowUnencrypted="true"}
  Set-WSManInstance -ResourceURI winrm/config/client -ValueSet @{AllowUnencrypted="true"}
  $cert = (New-SelfSignedCertificate -DnsName $hostname -CertStoreLocation Cert:\LocalMachine\My)
  Export-Certificate -FilePath $hostcert -Cert $cert -Force
  New-WSManInstance -ResourceURI winrm/config/listener -SelectorSet @{Address="*";Transport="HTTPS"} `
    -ValueSet @{Hostname="$hostname";CertificateThumbprint=$cert.Thumbprint}
  Add-Content -Force -Path $Env:SystemRoot\System32\drivers\etc\hosts -Value "$hostip $hostname"
  Write-Output "WinRM successfully enabled"
  if ($test -eq "test") {
    Try {
      Write-Output "Testing WinRM connection"
      #Enter-PSSession -ComputerName $hostname -UseSSL -SkipCACheck -Credential (Get-Credential -Username)
      #Invoke-Command -ComputerName $hostname -UseSSL -SkipCACheck -Credential (Get-Credential) -ScriptBlock {WHOAMI}
      $winrmUser = Read-Host -Prompt "User: "
      $winrmPass = Read-Host -Prompt "Password: " -AsSecureString
      $winrmPassSecure = ConvertTo-SecureString -String $winrmPass -AsPlainText -Force
      Invoke-Command -ComputerName $hostname -UseSSL -SkipCACheck -Credential `
        (Get-Credential -Username $winrmUser -Credential $winrmPass) -ScriptBlock { WHOAMI }
    } Catch {
      Write-Error "Cannot test WinRM"
    }
# CHECK THIS set-item wsman:\localhost\client\trustedhosts -Concatenate -value 'hostname'
  }
}


## DISABLE
if ($mode -eq "disable") {
  Write-Output "Disabling WinRM"
  New-NetFirewallRule -DisplayName "WinRM-HTTP" -Protocol tcp -Direction in -LocalPort 5985 -Action Block
  New-NetFirewallRule -DisplayName "WinRM-HTTPS" -Protocol tcp -Direction in -LocalPort 5986 -Action Block
  Disable-PSRemoting -Force
  Write-Output "WinRM successfully disabled"
}

