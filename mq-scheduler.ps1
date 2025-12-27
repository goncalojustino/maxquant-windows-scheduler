# ==========================================================
# MaxQuant Local Scheduler (v1.2)
# Single-socket, 12-thread machine
# ==========================================================
#Requires -Version 7.0
# Version: 1.4.0

$MAX_THREADS = 12

$MQ_EXE  = "C:\MQ_EXE\bin\MaxQuantCmd.exe"

$BASE    = "C:\MQ"
$QUEUE   = "$BASE\queue"
$RUNNING = "$BASE\running"
$DONE    = "$BASE\done"
$FAILED  = "$BASE\failed"
$LOGS    = "$BASE\logs"

$SUMMARY_LOG = "$LOGS\summary.log"

# pid -> @{ Threads; Xml; Output }
$active = @{}

function FreeThreads {
    $used = ($active.Values | ForEach-Object { $_.Threads } | Measure-Object -Sum).Sum
    if (-not $used) { $used = 0 }
    return $MAX_THREADS - $used
}

Write-Host "MaxQuant scheduler started."

while ($true) {

    # ------------------------------------------------------
    # Reap finished jobs
    # ------------------------------------------------------
    foreach ($procId in @($active.Keys)) {

        $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
        if ($proc) { continue }

        $job     = $active[$procId]
        $xmlPath = $job.Xml
        $outDir  = $job.Output
        $jobName = [IO.Path]::GetFileNameWithoutExtension($xmlPath)

        if (-not $outDir) {
            Add-Content $SUMMARY_LOG "$(Get-Date -Format s) FAILURE $jobName | Missing outputFolder (null)"
            Move-Item $xmlPath "$FAILED\$jobName.xml" -Force
            $active.Remove($procId)
            continue
        }
        # Get exit code (process already gone)
        $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
        if ($proc) {
            $proc.WaitForExit()
            $exitCode = $proc.ExitCode
        }
        else {
            # Process already gone; assume non-zero (defensive)
            $exitCode = 1
        }

        $summaryTxt       = Join-Path $outDir "combined\txt\summary.txt"
        $proteinGroupsTxt = Join-Path $outDir "combined\txt\proteinGroups.txt"

        $success =
            ($exitCode -eq 0) -and
            (Test-Path $outDir) -and
            (Test-Path $summaryTxt) -and
            (Test-Path $proteinGroupsTxt)

        if ($success) {

            Move-Item $xmlPath "$DONE\$jobName.xml" -Force
            Add-Content $SUMMARY_LOG "$(Get-Date -Format s) SUCCESS $jobName"

        } else {

            Move-Item $xmlPath "$FAILED\$jobName.xml" -Force

            $reason = @(
                "ExitCode=$exitCode"
                "OutputExists=$(Test-Path $outDir)"
                "SummaryTxt=$(Test-Path $summaryTxt)"
                "ProteinGroupsTxt=$(Test-Path $proteinGroupsTxt)"
            ) -join "; "

            if (Test-Path $outDir) {
                Set-Content (Join-Path $outDir "FAILED_REASON.txt") $reason
            }

            Add-Content $SUMMARY_LOG "$(Get-Date -Format s) FAILURE $jobName | $reason"
        }

        $active.Remove($procId)
    }

    # ------------------------------------------------------
    # Scan queue and start jobs
    # ------------------------------------------------------
    Get-ChildItem $QUEUE -Filter *.xml | ForEach-Object {

        [xml]$xml = Get-Content $_.FullName
        $threads  = [int]$xml.MaxQuantParams.numThreads

        if ($threads -le 0) {
            Write-Host "Invalid numThreads in $($_.Name), skipping"
            return
        }

        if ($threads -le (FreeThreads)) {

            $jobName = $_.BaseName
            $runXml  = "$RUNNING\$($_.Name)"
            $outDir =
                $xml.MaxQuantParams.outputFolder ??
                $xml.MaxQuantParams.fixedCombinedFolder ??
                $xml.outputFolder ??
                $xml.fixedCombinedFolder

            if (-not $outDir) {
                Write-Host "ERROR: No output folder defined in $($_.Name). Job skipped."
                Move-Item $runXml "$FAILED\$jobName.xml" -Force
                Add-Content $SUMMARY_LOG "$(Get-Date -Format s) FAILURE $jobName | Missing output folder (outputFolder/fixedCombinedFolder)"
                return
            }
            Move-Item $_.FullName $runXml

            Write-Host "Starting $jobName ($threads threads)"

            $p = Start-Process `
                -FilePath $MQ_EXE `
                -ArgumentList "`"$runXml`"" `
                -PassThru `
                -RedirectStandardOutput "$LOGS\$jobName.out" `
                -RedirectStandardError  "$LOGS\$jobName.err"

            # contiguous affinity mask
            $mask = ([int64]1 -shl $threads) - 1
            $p.ProcessorAffinity = [IntPtr][int64]$mask

            $active[$p.Id] = @{
                Threads = $threads
                Xml     = $runXml
                Output  = $outDir
            }
        }
    }

    Start-Sleep 10
}
