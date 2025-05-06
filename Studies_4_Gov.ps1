# --------------------------------------
# メイン処理の引数定義
# .SYNOPSIS
#     CSVファイルから職員情報を読み込み、Oktaグループにユーザーを追加します。
# .DESCRIPTION
#     このスクリプトは、指定されたCSVファイルから職員情報を読み込み、Okta APIを使用して、
#     各職員を職位・部署に対応するOktaグループに追加します。
# .PARAMETER EmployeeDataPath
#     職員情報が記載されたCSVファイルのパスを指定します。
# .PARAMETER OktaApiUrl
#     Okta APIのURLを指定します。
# .PARAMETER OktaApiKey
#     Okta APIキーを指定します。
# .PARAMETER EnableLogging
#     ログ出力を有効にするオプションです。指定した場合のみログが出力されます。
# .EXAMPLE
#     .\Studies_4_Gov.ps1 -EmployeeDataPath ".\EmployeeData.csv" `
#         -OktaApiUrl "https://your-okta-domain.com/api/v1" `
#         -OktaApiKey "your-okta-api-key" `
#         -EnableLogging
# .OUTPUTS
#     なし
# --------------------------------------

param (
    [string]$EmployeeDataPath = ".\EmployeeData.csv",
    [string]$OktaApiUrl = "https://your-okta-domain.com/api/v1",
    [string]$OktaApiKey = "your-okta-api-key",
    [switch]$EnableLogging
)

# --------------------------------------
# ログ出力関数
# .SYNOPSIS
#     ログをファイルに書き出します。
# .DESCRIPTION
#     実行時の情報をログファイルに書き出します。ファイル名にはタイムスタンプが含まれます。
# .PARAMETER message
#     出力するメッセージ
# .PARAMETER logLevel
#     ログレベル（Info、Warning、Error）
# --------------------------------------

function Write-Log {
    param (
        [string]$message,
        [string]$logLevel = "Info"
    )

    if ($EnableLogging) {
        # 実行日時をファイル名に追加（例: Okta_User_Creation_Log_2025-05-06_13-45-00.txt）
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logFileTimestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        
        # 実行時のタイムスタンプをファイル名に付ける
        $logFile = "Okta_User_4_Gov_Creation_Log_$logFileTimestamp.txt"  # ログファイル名を実行時に決定

        # ファイルがまだ作成されていない場合、ファイルを一度だけ開く
        if (-not $global:logFileStream) {
            try {
                # ファイルを新規作成（追記モード）
                $global:logFileStream = [System.IO.StreamWriter]::new($logFile, $false)
                $global:logFileStream.AutoFlush = $true  # 自動でフラッシュして保存する
                Write-Host "ログファイル $logFile を作成しました。"
            } catch {
                Write-Host "ログファイルの作成に失敗しました: $_"
                return
            }
        }

        # ログレベルを含めてログを書き込み
        $logMessage = "[$timestamp] [$logLevel] - $message"
        try {
            $global:logFileStream.WriteLine($logMessage)
        } catch {
            Write-Host "ログ書き込みエラー: $_"
        }
    }
}

# --------------------------------------
# リトライ機能付きのAPI通信関数
# .SYNOPSIS
#     Okta APIへのリクエストを実行し、失敗した場合はリトライを行います。
# .DESCRIPTION
#     通信エラーが発生した場合、指定した回数までリトライを試みます。
# .PARAMETER Uri
#     リクエスト先のAPIのURIを指定します。
# .PARAMETER Method
#     HTTPメソッド（GET、POST、PUT、DELETE）を指定します。
# .PARAMETER Headers
#     APIに送信するヘッダー情報を指定します。
# .PARAMETER Body
#     リクエストボディを指定します。
# .PARAMETER MaxRetries
#     最大リトライ回数を指定します。
# .EXAMPLE
#     $response = Invoke-Retry -Uri "https://your-okta-domain.com/api/v1/groups" `
#         -Method "GET" `
#         -Headers @{Authorization = "SSWS your-okta-api-key"} `
#         -MaxRetries 3
# .OUTPUTS
#     APIのレスポンス
# --------------------------------------

function Invoke-Retry {
    param (
        [string]$Uri,
        [string]$Method,
        [hashtable]$Headers,
        [string]$Body = $null,
        [int]$MaxRetries = 3
    )

    $retryCount = 0
    $success = $false
    $response = $null

    while ($retryCount -lt $MaxRetries -and -not $success) {
        try {
            if ($Method -eq "GET") {
                $response = Invoke-RestMethod -Uri $Uri -Method Get -Headers $Headers -ContentType "application/json"
            } elseif ($Method -eq "POST") {
                $response = Invoke-RestMethod -Uri $Uri -Method Post -Headers $Headers -Body $Body -ContentType "application/json"
            } elseif ($Method -eq "PUT") {
                $response = Invoke-RestMethod -Uri $Uri -Method Put -Headers $Headers -Body $Body -ContentType "application/json"
            } elseif ($Method -eq "DELETE") {
                $response = Invoke-RestMethod -Uri $Uri -Method Delete -Headers $Headers -ContentType "application/json"
            }

            # 成功した場合、リトライを終了
            $success = $true
        } catch {
            $retryCount++
            Write-Log "通信エラー: $($_.Exception.Message) リトライ試行回数: $retryCount" "Warning"
            Start-Sleep -Seconds 5  # リトライ前に少し待機
        }
    }

    if (-not $success) {
        Write-Log "最大リトライ回数を超えました。通信に失敗しました。" "Error"
    }

    return $response
}

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
#     $Group = Get-OktaGroup -GroupName "Developers" `
#         -OktaApiUrl "https://your-okta-domain.com/api/v1" `
#         -OktaApiKey "your-okta-api-key"
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
    Write-Log "Okta API URI: $OktaApiUri" "Debug"  # デバッグ用ログにAPI URIを出力

    # Okta APIからグループを取得
    $OktaApiResponse = Invoke-Retry -Uri $OktaApiUri -Method "GET" -Headers @{
        Authorization = "SSWS $OktaApiKey"
    }

    # レスポンス内に指定のグループが含まれているかをチェック
    $group = $OktaApiResponse | Where-Object { $_.profile.name -eq $GroupName }
    
    if ($group) {
        Write-Log "グループ '$GroupName' が見つかりました。" "Info"
    } else {
        Write-Log "グループ '$GroupName' は見つかりませんでした。" "Warning"
    }

    return $group
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
#     Add-OktaGroupMember -UserId "00u1a2b3c4d5e6f7g8h9" `
#         -GroupId "00g1a2b3c4d5e6f7g8h9" `
#         -OktaApiUrl "https://your-okta-domain.com/api/v1" `
#         -OktaApiKey "your-okta-api-key"
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
    
    # リトライ付きの通信
    Invoke-Retry -Uri $OktaApiUri -Method "PUT" -Headers @{
        Authorization = "SSWS $OktaApiKey"
    }
}

# --------------------------------------
# メイン処理本体
# --------------------------------------

# CSVファイルから職員情報を読み込む
$Employees = Import-Csv -Path $EmployeeDataPath
Write-Log "職員情報ファイル ($EmployeeDataPath) を読み込みました。" "Info"

# 強制終了のためのフラグ
$cancelled = $false

# リトライ機能の設定
$maxRetries = 3
$retryCount = 0

# 各職員に対して処理を実行
foreach ($Employee in $Employees) {
    # 強制終了検知用
    if ($cancelled) { 
        Write-Host "強制終了のため処理を中止します。"
        Write-Log "処理を中止しました。" "Info"
        break
    }

    # 職位・部署に対応するOktaグループを取得
    $Group = Get-OktaGroup -GroupName $Employee.Department `
        -OktaApiUrl $OktaApiUrl `
        -OktaApiKey $OktaApiKey

    # ユーザーをグループに追加
    if ($Group) {
        $success = $false
        while ($retryCount -lt $maxRetries -and !$success) {
            try {
                Add-OktaGroupMember -UserId $Employee.UserId `
                    -GroupId $Group.id `
                    -OktaApiUrl $OktaApiUrl `
                    -OktaApiKey $OktaApiKey

                Write-Host "ユーザー $($Employee.UserId) をグループ $($Employee.Department) に追加しました。"
                Write-Log "ユーザー $($Employee.UserId) をグループ $($Employee.Department) に追加。" "Info"
                $success = $true
            } catch {
                $retryCount++
                Write-Warning "通信エラーが発生しました。リトライします。試行回数: $retryCount"
                Write-Log "通信エラー: $($_.Exception.Message) リトライ試行回数: $retryCount" "Warning"
                Start-Sleep -Seconds 5
            }
        }

        if (!$success) {
            Write-Error "ユーザー $($Employee.UserId) のグループ追加に失敗しました。最大リトライ回数を超えました。"
            Write-Log "ユーザー $($Employee.UserId) のグループ追加に失敗。最大リトライ回数を超えました。" "Error"
        }
    } else {
        Write-Warning "グループ $($Employee.Department) が見つかりませんでした。"
        Write-Log "グループ $($Employee.Department) が見つかりませんでした。" "Warning"
    }
}

# 強制終了検知用の処理
$host.UI.RawUI.KeyDown += {
    if ($_.VirtualKeyCode -eq 27) {  # Escキーが押された時（Ctrl+Cも含む）
        $cancelled = $true
        Write-Log "スクリプトが強制終了されました。" "Error"
    }
}