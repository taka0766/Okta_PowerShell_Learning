# CSVファイルから職員情報を読み込む
$Employees = Import-Csv -Path "C:\EmployeeData.csv"

# Okta API設定
$OktaApiUrl = "https://your-okta-domain.com/api/v1"
$OktaApiKey = "your-okta-api-key"

# 各職員に対して処理を実行
foreach ($Employee in $Employees) {
  # 職位・部署に対応するOktaグループを取得
  $Group = Get-OktaGroup -GroupName $Employee.Department -OktaApiUrl $OktaApiUrl -OktaApiKey $OktaApiKey

  # ユーザーをグループに追加
  if ($Group) {
    Add-OktaGroupMember -UserId $Employee.UserId -GroupId $Group.id -OktaApiUrl $OktaApiUrl -OktaApiKey $OktaApiKey
    Write-Host "ユーザー $($Employee.UserId) をグループ $($Employee.Department) に追加しました。"
  } else {
    Write-Warning "グループ $($Employee.Department) が見つかりませんでした。"
  }
}

# Oktaグループを取得する関数
function Get-OktaGroup {
  param (
    [string]$GroupName,
    [string]$OktaApiUrl,
    [string]$OktaApiKey
  )

  $OktaApiUri = "$OktaApiUrl/groups?q=$GroupName"
  $OktaApiResponse = Invoke-RestMethod -Uri $OktaApiUri -Method Get -Headers @{Authorization = "SSWS $OktaApiKey"} -ContentType "application/json"

  return $OktaApiResponse | Where-Object {$_.profile.name -eq $GroupName}
}

# Oktaグループにユーザーを追加する関数
function Add-OktaGroupMember {
  param (
    [string]$UserId,
    [string]$GroupId,
    [string]$OktaApiUrl,
    [string]$OktaApiKey
  )

  $OktaApiUri = "$OktaApiUrl/groups/$GroupId/users/$UserId"
  Invoke-RestMethod -Uri $OktaApiUri -Method Put -Headers @{Authorization = "SSWS $OktaApiKey"}
}