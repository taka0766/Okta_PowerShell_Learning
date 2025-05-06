# CSVファイルから学籍情報を読み込み、Oktaユーザーアカウントを作成します。
# 
# スクリプトの引数：
# - StudentDataPath：学籍情報CSVファイルのパス
# - OktaApiUrl：Okta API のベースURL（例: https://your-org.okta.com/api/v1）
# - OktaApiKey：Okta APIキー（SSWS トークン）
# - EnableLogging：ログ出力を有効にするかどうか（オプション）
#
# ログファイル名の例：
# - 実行時のタイムスタンプをファイル名に追加してログを保存します。
#   例: Okta_User_Creation_Log_2025-05-06_13-45-00.txt
#
# 強制終了について：
# - スクリプト実行中にCtrl+C または Escキーを押すと、処理が強制終了されます。
# - 強制終了時には「スクリプトが強制終了されました。」というメッセージがログに記録されます。
#
# 使用例：
# .\Studies_4_school.ps1 -StudentDataPath ".\StudentData.csv" -OktaApiUrl "https://your-okta-domain.com/api/v1" -OktaApiKey "your-okta-api-key" -EnableLogging

param (
    [string]$StudentDataPath = ".\StudentData.csv",
    [string]$OktaApiUrl = "https://your-okta-domain.com/api/v1",
    [string]$OktaApiKey = "your-okta-api-key",
    [switch]$EnableLogging
)

# ログ出力関数
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
        $logFile = "Okta_User_Creation_Log_$logFileTimestamp.txt"  # ログファイル名を実行時に決定

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

# 学籍情報CSVファイルが存在するか確認
if (-not (Test-Path $StudentDataPath)) {
    Write-Error "指定された学籍情報ファイルが見つかりません: $StudentDataPath"
    Write-Log "指定された学籍情報ファイルが見つかりません: $StudentDataPath" "Error"
    exit
}

# CSVファイルから学籍情報を読み込む
$Students = Import-Csv -Path $StudentDataPath
Write-Log "学籍情報ファイル ($StudentDataPath) を読み込みました。" "Info"

# 強制終了のためのフラグ
$cancelled = $false

# リトライとエラーハンドリングを含む処理
try {
    # 各学生に対して処理を実行
    foreach ($Student in $Students) {
        # 強制終了検知用
        if ($cancelled) { 
            Write-Host "強制終了のため処理を中止します。"
            Write-Log "処理を中止しました。" "Info"
            break
        }

        # ユーザー情報のプロファイルを構築
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
        
        # リトライ機能の設定
        $maxRetries = 3
        $retryCount = 0
        $success = $false

        while ($retryCount -lt $maxRetries -and !$success) {
            try {
                $OktaApiResponse = Invoke-RestMethod -Uri $OktaApiUri -Method Post -Headers @{Authorization = "SSWS $OktaApiKey"} -Body $UserJson -ContentType "application/json"
                
                # 成功した場合
                if ($OktaApiResponse.id) {
                    Write-Host "ユーザー $($Student.FirstName) $($Student.LastName) の作成に成功しました。"
                    Write-Log "ユーザー $($Student.FirstName) $($Student.LastName) の作成に成功。" "Info"
                    $success = $true
                } else {
                    Write-Warning "ユーザー $($Student.FirstName) $($Student.LastName) の作成に失敗しました。"
                    Write-Log "ユーザー $($Student.FirstName) $($Student.LastName) の作成に失敗。" "Warning"
                }
            } catch {
                $retryCount++
                Write-Warning "通信エラーが発生しました。リトライします。試行回数: $retryCount"
                Write-Log "通信エラー: $($_.Exception.Message) リトライ試行回数: $retryCount" "Warning"
                Start-Sleep -Seconds 5
            }
        }

        if (!$success) {
            Write-Error "ユーザー $($Student.FirstName) $($Student.LastName) の作成に失敗しました。最大リトライ回数を超えました。"
            Write-Log "ユーザー $($Student.FirstName) $($Student.LastName) の作成に失敗。最大リトライ回数を超えました。" "Error"
        }
    }
} catch {
    Write-Error "スクリプト実行中にエラーが発生しました: $($_.Exception.Message)"
    Write-Log "スクリプト実行中にエラーが発生しました: $($_.Exception.Message)" "Error"
} finally {
    # 終了処理
    Write-Log "スクリプトが終了しました。" "Info"
    # ファイルストリームが開かれている場合は閉じる
    if ($global:logFileStream) {
        $global:logFileStream.Close()
    }
}

# 強制終了検知用の処理
$host.UI.RawUI.KeyDown += {
    if ($_.VirtualKeyCode -eq 27) {  # Escキーが押された時（Ctrl+Cも含む）
        $cancelled = $true
        Write-Log "スクリプトが強制終了されました。" "Error"
    }
}
