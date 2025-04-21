# Telegram-Controlled PowerShell Script

This PowerShell script lets you control your PC through a Telegram bot. It listens for the `/open_notepad` command and launches Notepad when you send it from your Telegram account.

## 🛠 Prerequisites

- Windows 10 or newer
- PowerShell 5 or later (built-in)
- Internet connection
- A Telegram bot token (from [@BotFather](https://t.me/BotFather))
- Your own Telegram user ID (use [@userinfobot](https://t.me/userinfobot))

## 🔒 Enable Script Execution

Before running the script, allow PowerShell to execute local scripts:

## Powershell (Permanent fix)
```
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```
## Powershell (One-time fix for your session)
```
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

