$FileProps = ".\server\config\rundeck-config.properties"
$RdUrl = "http://localhost:4440"
$RdToken = ""

$Props = Get-Content -Path $FileProps -Force | Where-Object { "$_" -NotContains "" -And "$_" -NotLike "#*" -And "$_" -NotLike "dataSource*" }
ForEach ($Prop in ($Props)) {
  $PropKey = $Prop.Split("=")[0].Trim()
  $PropValue = $Prop.Split("=")[1].Trim()
  $PropJson = "[{ ""key"":""$PropKey"", ""value"":""$PropValue"", ""strata"":""default"" }]"
  Write-Output "Uploading $PropJson"
  (Invoke-WebRequest -UseBasicParsing -Method POST -Uri "$RdUrl/api/40/config/save" -Body "$PropJson" -Headers @{ "Accept"="application/json"; "Content-Type"="application/json"; "X-Rundeck-Auth-Token"="$RdToken" }).Content
}

