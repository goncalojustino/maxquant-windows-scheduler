# maxquant-windows-scheduler
A lightweight PowerShell 7 scheduler for running multiple MaxQuant jobs in parallel on Windows, using a queue-based submission model, CPU affinity, and robust success/failure classification.

## Overview

This repository provides a **minimal local scheduler** for MaxQuant on Windows systems.  
It is designed for labs and individual users who:

- must run MaxQuant on **Windows**
- want to run **multiple jobs in parallel** safely
- need **explicit resource control** (CPU threads / affinity)
- want **deterministic success/failure detection**
- do **not** need a full HPC or cluster scheduler

The scheduler runs continuously, watches a queue directory for MaxQuant XML files, and launches jobs when sufficient CPU resources are available.

## Key features

- Queue-based job submission (drop XML files into a directory)
- Parallel execution with CPU thread accounting
- CPU affinity enforcement (no oversubscription)
- Supports both `<outputFolder>` and `<fixedCombinedFolder>` XML layouts
- Robust success/failure classification based on MaxQuant outputs
- Persistent audit trail (`summary.log`)
- Explicit failure diagnostics (`FAILED_REASON.txt`)
- PowerShell 7–native (no deprecated cmdlets)

## Requirements
- **Windows** (Windows 10/11 or Windows Server)
- **PowerShell 7 or newer**  
  (`pwsh`, not Windows PowerShell 5.1)
- **MaxQuant** installed locally
> This script **will not run** under Windows PowerShell 5.1.

---

## Directory layout
The scheduler expects the following directory structure:

```
C:\MQ\
 ├─ queue\        # submit XML files here
 ├─ running\      # XML files currently running
 ├─ done\         # successfully completed jobs
 ├─ failed\       # failed jobs
 └─ logs\         # scheduler logs and job stdout/stderr
```

Additional directories are user-defined in the XML files:
- MaxQuant executable directory (e.g. `C:\MQ_EXE`)
- Andromeda index directory (e.g. `C:\MQ_INDEX`)
- RAW data directories
- Output directories

## Installation

1. Clone the repository:
   ```powershell
   git clone https://github.com/<your-username>/maxquant-windows-scheduler.git
   ```
2. Ensure PowerShell 7 is available:
   ```powershell
   pwsh --version
   ```
3. Edit `mq-scheduler.ps1` and set:
   - path to `MaxQuantCmd.exe`
   - maximum number of threads (`$MAX_THREADS`)
   - base scheduler directory (default: `C:\MQ`)

## Running the scheduler
From **PowerShell 7**:
```powershell
pwsh -ExecutionPolicy Bypass -File mq-scheduler.ps1
```
The scheduler will start and run continuously.

## Submitting jobs

To submit a MaxQuant job:
1. Prepare a valid MaxQuant XML file
2. Ensure it contains:
   - `<numThreads>`
   - either `<outputFolder>` **or** `<fixedCombinedFolder>`
3. Copy or move the XML file into:
```
C:\MQ\queue\
```
That is the only submission step.

## Output folder resolution

The scheduler determines the output directory using the following precedence:
1. `<outputFolder>` under `<MaxQuantParams>`
2. `<fixedCombinedFolder>` under `<MaxQuantParams>`
3. `<outputFolder>` at top level
4. `<fixedCombinedFolder>` at top level
If no output folder can be resolved, the job is rejected and marked as failed.

## Success and failure criteria
A job is classified as **SUCCESS** if **all** of the following are true:
- MaxQuant exits with code `0`
- Output directory exists
- `combined/txt/summary.txt` exists
- `combined/txt/proteinGroups.txt` exists
Otherwise, the job is classified as **FAILURE**.

## Failure diagnostics
For failed jobs:
- The XML file is moved to `C:\MQ\failed`
- A `FAILED_REASON.txt` file is written to the output directory (if available)
- A detailed entry is added to `logs/summary.log`
Example failure reason:
```
ExitCode=0; OutputExists=True; SummaryTxt=True; ProteinGroupsTxt=False
```
This indicates that MaxQuant ran and produced output, but protein inference did not complete successfully.
## Logs
- Scheduler audit log:
  ```
  C:\MQ\logs\summary.log
  ```
- Per-job stdout:
  ```
  C:\MQ\logs\<jobname>.out
  ```
- Per-job stderr:
  ```
  C:\MQ\logs\<jobname>.err
  ```
## Limitations

This tool is intentionally minimal:
- Not a cluster or HPC scheduler
- No retries or job migration
- No MaxQuant parameter validation
- No cloud or container support
- Single-machine only

It is designed for **local, deterministic execution**, not for distributed workloads.

## License

This project is licensed under the MIT License.

## Citation
If you use this scheduler in published work, please cite the repository:

```
G. Justino, maxquant-windows-scheduler, GitHub (2025)
```

This tool was developed to support reproducible, unattended MaxQuant analysis workflows on Windows-based proteomics systems.
