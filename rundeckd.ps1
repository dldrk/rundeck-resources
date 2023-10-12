param([string]$Mode)


## RUNDECK SERVICE CONFIGS
$InstallMethod = "apache-daemon"
$ApacheDaemonUrl = "https://downloads.apache.org/commons/daemon/binaries/windows/commons-daemon-1.3.4-bin-windows.zip"
$Java = "java" # java,C:\custom\java
$RundeckService = "rundeckd"
$RundeckWar = "rundeck.war"
$WorkingDir = (Get-Location).Path
$KeyStore = "$WorkingDir\etc\keystore"
$KeyPass = "adminadmin"
$Launcher = "-server -Xms2048m -Xmx2048m"
$Launcher = "$Launcher -Dfile.encoding=UTF-8 -Dserver.http.port=4440"
$LauncherArgs = "-d" # --skipinstall


## SERVICE.LOG ROTATION CONFIGS
# IMPORTANT: Windows will lock service.log file while in use by Rundeck. Must be done when service is down.
$Enabled = "true" # true,false
$Verbose = "true" # true,false
$SkipClear = "false" # true,false. Skip clearing service.log for testing
$Every = "start" # start,hour,day,month,size
$MaxCount = 10 # file count limit to rotate
$MaxSize = 10MB # file zize limit to rotate
$LogPath = ".\var\logs"
$LogFile = "service.log"
$ServiceLog = "$LogPath\$LogFile"
$RotationFile = "rotation.log"
$RotationLog = "$LogPath\$RotationFile"


## DEFAULT CONFIGS
$ProgressPreference = "Silent"
$HostName = "$(hostname)"
$HostCert = "$HostName"+".crt"
$DateNow = Get-Date -Format yyyyMMddhhmmss
$ApacheDaemonLauncher = $Launcher.Replace(" ", "#")
$Launcher = "$Launcher -jar $RundeckWar $LauncherArgs"
$ZipLogs = Get-ChildItem -Path $LogPath -Filter "*.zip" -ErrorAction SilentlyContinue
#Write-Output "Zip files found: $(($ZipLogs).Count)"


## RUNDECK INSTALL
Function RundeckInstall {
  if ((Test-Path -Path "etc","server\config","libext","$LogPath") -EQ $False) {
    Invoke-Expression -Command 'CMD /C "$Java $Launcher --installonly"'
    New-Item -Path $WorkingDir -Name "etc" -ItemType Directory -Force
    New-Item -Path $WorkingDir -Name "$LogPath" -ItemType Directory -Force
    Write-Output "$RundeckService base installed"

    if ($InstallMethod -EQ "apache-daemon") {
      $ApacheDaemonInstall = "$ApacheDaemonInstall //IS/$RundeckService"
      $ApacheDaemonInstall = "$ApacheDaemonInstall --DisplayName=""$RundeckService (Rundeck/ProcessAutomation)"""
      $ApacheDaemonInstall = "$ApacheDaemonInstall --LogLevel=Debug"
      $ApacheDaemonInstall = "$ApacheDaemonInstall --LogPath=$WorkingDir"
      $ApacheDaemonInstall = "$ApacheDaemonInstall --ServiceUser=LocalSystem"
      $ApacheDaemonInstall = "$ApacheDaemonInstall --Startup=auto"
      $ApacheDaemonInstall = "$ApacheDaemonInstall --StartMode=java"
      $ApacheDaemonInstall = "$ApacheDaemonInstall --StartPath=$WorkingDir"
      $ApacheDaemonInstall = "$ApacheDaemonInstall --StartParams=-jar#rundeck.war"
      $ApacheDaemonInstall = "$ApacheDaemonInstall --PidFile=rundeckd.pid"
      #$ApacheDaemonInstall = "$ApacheDaemonInstall --JvmMs=2048 --JvmMx=2048"
      $ApacheDaemonInstall = "$ApacheDaemonInstall --StdOutput=$WorkingDir\var\logs\service.log"
      $ApacheDaemonInstall = "$ApacheDaemonInstall --StdError=$WorkingDir\var\logs\service.log"
      $ApacheDaemonInstall = "$ApacheDaemonInstall --JvmOptions9=$ApacheDaemonLauncher"

      Try {
        Invoke-WebRequest -OutFile apache-daemon.zip $ApacheDaemonUrl
      } Catch {
        Write-Error "Apache Daemon binaries cannot be downloaded. Wrong link or old version" -ErrorAction Stop
      }
      Expand-Archive -Path apache-daemon.zip -DestinationPath apache-daemon -Force
      Move-Item -Path apache-daemon\amd64\prunsrv.exe "$RundeckService`.exe" -Force
      Move-Item -Path apache-daemon\prunmgr.exe "$RundeckService`w.exe" -Force
      Remove-Item -Path apache-daemon -Recurse -Force
      Invoke-Expression -Command 'CMD /C "$RundeckService`.exe $ApacheDaemonInstall"'
    }
  }

  # SSL
  if ("$Launcher" -Like "*server.https.port*" -and (Test-Path -Path "$KeyStore") -EQ $False) {
    $Cert = (New-SelfSignedCertificate -DnsName $HostName -CertStoreLocation Cert:\LocalMachine\My)
    Export-PfxCertificate -Cert $Cert -FilePath $KeyStore -Password (ConvertTo-SecureString -String $KeyPass -AsPlainText -Force)
    Export-Certificate -FilePath $HostCert -Cert $Cert -Force
    Copy-Item -Path $KeyStore -Destination "etc\truststore" -Force
    Write-Output "$KeyStore created for $HostName (Cert: $Cert)"
  }
}


## RUNDECK START
Function RundeckStart {
  Stop-Service -Name $RundeckService -Force
  Start-Service -Name $RundeckService
}


## ROTATION SERVICE
Function RotateLog($Log) {
  Try {
    $MessageSuccess = "$DateNow - ROTATION SUCCESSFUL [$Every] : $ServiceLog-$DateNow.zip"
    $MessageFailed = "$DateNow - ROTATION FAILED [$Every] : $Log is being used or not found"
    Compress-Archive -Path "$Log" -DestinationPath "$ServiceLog-$DateNow.zip" -CompressionLevel Optimal -Force
    if ($SkipClear.ToLower() -EQ "false") { Clear-Content -Path $ServiceLog -Force }
    Add-Content -Value $MessageSuccess -Path $RotationLog -Encoding Utf8 -Force
    if ($Verbose.ToLower() -EQ "true") { Write-Output "$MessageSuccess" }
  } Catch {
    Add-Content -Value $MessageFailed -Path $RotationLog -Encoding Utf8 -Force
    if ($Verbose.ToLower() -EQ "true") { Write-Output "$MessageFailed" }
  }
}

Function RotateByTime($Time) {
  ForEach ($Log in $ZipLogs) {
    if ($Log.Name.Contains((Get-Date -Format "$Time"))) {
      Expand-Archive -Path "$LogPath\$Log" -DestinationPath "$ENV:TEMP\$LogFile-temp" -Force
      Add-Content -Value (Get-Content -Path "$ENV:TEMP\$LogFile-temp\$LogFile") -Path "$ENV:TEMP\$LogFile" -Force
      Remove-Item -Path "$ENV:TEMP\$LogFile-temp" -Recurse -Force 
      Remove-Item -Path "$LogPath\$Log" -Force
    }
  }
  if ((Test-Path -Path "$ENV:TEMP\$LogFile") -EQ $true) {
    RotateLog("$ENV:TEMP\$LogFile")
    Remove-Item -Path "$ENV:TEMP\$LogFile" -Force
  } else { RotateLog("$ServiceLog") }
}

Function RotateBySize {
  if (((Get-ChildItem -Path "$ServiceLog").Length / 1MB) -GT ($MaxSize / 1MB)) {
    RotateLog("$ServiceLog")
  }
}

Function DoRotation {
  if ($Enabled -EQ "false") { Exit 0 }
  if ($Every.ToLower() -EQ "start") { if (($ZipLogs).Count -LT $MaxCount) { RotateLog("$ServiceLog") } }
  if ($Every.ToLower() -EQ "hour") { RotateByTime("yyyyMMddhh") }
  if ($Every.ToLower() -EQ "day") { RotateByTime("yyyyMMdd") }
  if ($Every.ToLower() -EQ "month") { RotateByTime("yyyyMM") }
  if ($Every.ToLower() -EQ "size") { RotateBySize }
}


## MANAGE
if ($Mode -eq "") { Write-Error "Usage: [script] -Mode [RundeckInstall|RundeckStart|DoRotation]" ; exit 1 }
if ($Mode -eq "RundeckInstall") { RundeckInstall }
if ($Mode -eq "RundeckStart") { RundeckStart }
if ($Mode -eq "DoRotation") { DoRotation }

