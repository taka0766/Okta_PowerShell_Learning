# CSVファイルから学籍情報を読み込み、Oktaユーザーアカウントを作成します。
# 
# スクリプトの引数：
# - StudentDataPath：学籍情報CSVファイルのパス
# - OktaApiUrl：Okta API のベースURL（例: https://your-org.okta.com/api/v1）
# - OktaApiKey：Okta APIキー（SSWS トークン）
#
# 使用例：
# .\Studies_4_school.ps1 -StudentDataPath "C:\StudentData.csv" -OktaApiUrl "https://your-okta-domain.com/api/v1" -OktaApiKey "your-okta-api-key"

param (
    [string]$StudentDataPath = ".\StudentData.csv",
    [string]$OktaApiUrl = "https://your-okta-domain.com/api/v1",
    [string]$OktaApiKey = "your-okta-api-key"
)

# CSVファイルから学籍情報を読み込む
$Students = Import-Csv -Path $StudentDataPath

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
    $UserJson = $User | ConvertTo-Json -Depth 10
    $OktaApiUri = "$OktaApiUrl/users"
    $OktaApiResponse = Invoke-RestMethod -Uri $OktaApiUri -Method Post -Headers @{Authorization = "SSWS $OktaApiKey"} -Body $UserJson -ContentType "application/json"

    # 結果を出力
    if ($OktaApiResponse.id) {
        Write-Host "ユーザー $($Student.FirstName) $($Student.LastName) の作成に成功しました。"
    } else {
        Write-Warning "ユーザー $($Student.FirstName) $($Student.LastName) の作成に失敗しました。"
    }
}