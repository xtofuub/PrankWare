# Set your bot token and user ID
$botToken = "7462575551:AAG66o16VhlQu_26sfPaEpIxvhRWKeHBh04"
$userId = "5036966807"
$apiUrl = "https://api.telegram.org/bot$botToken"
$lastUpdateId = 0

while ($true) {
    try {
        # Get updates from Telegram
        $response = Invoke-RestMethod "$apiUrl/getUpdates?offset=$($lastUpdateId + 1)&timeout=10"

        foreach ($update in $response.result) {
            $lastUpdateId = $update.update_id
            $chatId = $update.message.chat.id
            $messageText = $update.message.text

            if ($chatId -eq $userId -and $messageText -eq "/open_notepad") {
                Start-Process notepad.exe

                # Send a confirmation message
                $msg = "Notepad has been opened."
                Invoke-RestMethod "$apiUrl/sendMessage" -Method Post -ContentType "application/json" -Body (@{
                    chat_id = $chatId
                    text = $msg
                } | ConvertTo-Json -Depth 10)
            }
        }

        Start-Sleep -Seconds 2
    } catch {
        Write-Host "Error: $_"
        Start-Sleep -Seconds 5
    }
}
