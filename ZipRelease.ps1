param (
    [string]$newVersion = "0.0"
)

$tempDirectory = "temp"

$programmableTrainStopDir = "$tempDirectory/programmable-train-stop"
Copy-Item "./programmable-train-stop" $programmableTrainStopDir -Recurse -Force
Remove-Item "$programmableTrainStopDir/.vscode" -Recurse

$outputFile = "./Releases/programmable-train-stop-${newVersion}.zip"
Compress-Archive -Path $programmableTrainStopDir -DestinationPath $outputFile

Remove-Item $tempDirectory -Force -Recurse