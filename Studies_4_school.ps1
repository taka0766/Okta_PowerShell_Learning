<#
.SYNOPSIS
    CSVファイルから学籍情報を読み込み、Oktaユーザーアカウントを作成します。
.DESCRIPTION
    このスクリプトは、指定されたCSVファイルから学籍情報を読み込み、Okta APIを使用して、各学生のOktaユーザーアカウントを作成します。
.PARAMETER StudentDataPath
    学籍情報が記載されたCSVファイルのパスを指定します。
.PARAMETER OktaApiUrl
    Okta APIのURLを指定します。
.PARAMETER OktaApiKey
    Okta APIキーを指定します。
.EXAMPLE
    .\Studies_4_school.ps1 -StudentDataPath "C:\StudentData.csv" -OktaApiUrl "https://your-okta-domain.com/api/v1" -OktaApiKey "your-okta-api-key"
.OUTPUTS
    なし
#>
param (
    [string]$StudentDataPath = "C:\StudentData.csv",
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