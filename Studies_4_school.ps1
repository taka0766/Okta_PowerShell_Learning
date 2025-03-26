<#
.SYNOPSIS
    CSVファイルから学籍情報を読み込み、Oktaユーザーアカウントを作成します。
.DESCRIPTION
    このスクリプトは、指定されたCSVファイルから学籍情報を読み込み、Okta APIを使用して、各学生のOktaユーザーアカウントを作成します。
.PARAMETER StudentDataPath
    学籍情報が記載されたCSVファイルのパスを指定します。
.PARAMETER OktaDomain
    Oktaドメインを指定します。例: "your-domain.okta.com"
.PARAMETER OktaApiKey
    Okta APIキーを指定します。
.EXAMPLE
    .\Create-OktaStudentAccounts.ps1 -StudentDataPath "C:\StudentData.csv" -OktaDomain "your-domain.okta.com" -OktaApiKey "your-okta-api-key"
.OUTPUTS
    なし
#>
param (
    [string]$StudentDataPath = "C:\StudentData.csv",
    [string]$OktaDomain,
    [string]$OktaApiKey
)

# Okta PowerShell モジュールをインポート
Import-Module Okta.PowerShell

# Oktaコンテキストを設定
Set-OktaContext -Domain $OktaDomain -Token $OktaApiKey

# CSVファイルから学籍情報を読み込む
$Students = Import-Csv -Path $StudentDataPath

# 各学生に対して処理を実行
foreach ($Student in $Students) {
    # Oktaユーザーアカウントの作成
    $User = New-OktaUser -Profile @{
        firstName = $Student.FirstName
        lastName = $Student.LastName
        email = "$($Student.StudentID)@school.example.com"
        login = "$($Student.StudentID)@school.example.com"
    }

    # 結果を出力
    if ($User.Id) {
        Write-Host "ユーザー $($Student.FirstName) $($Student.LastName) の作成に成功しました。"
    } else {
        Write-Warning "ユーザー $($Student.FirstName) $($Student.LastName) の作成に失敗しました。"
    }
}