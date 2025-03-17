# CSVファイルから学籍情報を読み込む
$Students = Import-Csv -Path "C:\StudentData.csv"

# Okta API設定
$OktaApiUrl = "https://your-okta-domain.com/api/v1"
$OktaApiKey = "your-okta-api-key"

# 各学生に対して処理を実行
foreach ($Student in $Students) {
  # Oktaユーザーアカウントの作成
  $User = @{
    profile = @{
      firstName = $Student.FirstName
      lastName = $Student.LastName
      email = "$($Student.StudentID)@school.example.com"
      login = "$($Student.StudentID)@school.example.com"
    }
  }

  # Okta APIを呼び出してユーザーを作成
  $UserJson = $User | ConvertTo-Json
  $OktaApiUri = "$OktaApiUrl/users"
  $OktaApiResponse = Invoke-RestMethod -Uri $OktaApiUri -Method Post -Headers @{Authorization = "SSWS $OktaApiKey"} -Body $UserJson -ContentType "application/json"

  # 結果を出力
  if ($OktaApiResponse.id) {
    Write-Host "ユーザー $($Student.FirstName) $($Student.LastName) の作成に成功しました。"
  } else {
    Write-Warning "ユーザー $($Student.FirstName) $($Student.LastName) の作成に失敗しました。"
  }
}