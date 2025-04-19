# --------------------------------------
# グループ取得関数
# .SYNOPSIS
#     Oktaグループを取得します。
# .DESCRIPTION
#     指定されたグループ名でOktaグループを検索し、グループオブジェクトを返します。
# .PARAMETER GroupName
#     取得するグループの名前を指定します。
# .PARAMETER OktaApiUrl
#     Okta APIのURLを指定します。
# .PARAMETER OktaApiKey
#     Okta APIキーを指定します。
# .EXAMPLE
#     $Group = Get-OktaGroup -GroupName "Developers" -OktaApiUrl "https://your-okta-domain.com/api/v1" -OktaApiKey "your-okta-api-key"
# .OUTPUTS
#     Oktaグループオブジェクト
# --------------------------------------
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

# --------------------------------------
# グループメンバー追加関数
# .SYNOPSIS
#     Oktaグループにユーザーを追加します。
# .DESCRIPTION
#     指定されたユーザーをOktaグループに追加します。
# .PARAMETER UserId
#     追加するユーザーのIDを指定します。
# .PARAMETER GroupId
#     追加先のグループIDを指定します。
# .PARAMETER OktaApiUrl
#     Okta APIのURLを指定します。
# .PARAMETER OktaApiKey
#     Okta APIキーを指定します。
# .EXAMPLE
#     Add-OktaGroupMember -UserId "00u1a2b3c4d5e6f7g8h9" -GroupId "00g1a2b3c4d5e6f7g8h9" -OktaApiUrl "https://your-okta-domain.com/api/v1" -OktaApiKey "your-okta-api-key"
# .OUTPUTS
#     なし
# --------------------------------------
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

# --------------------------------------
# メイン処理
# .SYNOPSIS
#     CSVファイルから職員情報を読み込み、Oktaグループにユーザーを追加します。
# .DESCRIPTION
#     このスクリプトは、指定されたCSVファイルから職員情報を読み込み、Okta APIを使用して、各職員を職位・部署に対応するOktaグループに追加します。
# .PARAMETER EmployeeDataPath
#     職員情報が記載されたCSVファイルのパスを指定します。
# .PARAMETER OktaApiUrl
#     Okta APIのURLを指定します。
# .PARAMETER OktaApiKey
#     Okta APIキーを指定します。
# .EXAMPLE
#     .\Studies_4_Gov.ps1 -EmployeeDataPath "C:\EmployeeData.csv" -OktaApiUrl "https://your-okta-domain.com/api/v1" -OktaApiKey "your-okta-api-key"
# .OUTPUTS
#     なし
# --------------------------------------
param (
    [string]$EmployeeDataPath = "C:\EmployeeData.csv",
    [string]$OktaApiUrl = "https://your-okta-domain.com/api/v1",
    [string]$OktaApiKey = "your-okta-api-key"
)

# CSVファイルから職員情報を読み込む
$Employees = Import-Csv -Path $EmployeeDataPath

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
