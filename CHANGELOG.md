# Changelog

All notable changes to this project are documented in this file.

The format follows a pragmatic, release-oriented approach suitable for small scientific tools.

---

## v1.4.0 — Initial public release (2025-12-27)

### Added
- Queue-based submission model for MaxQuant XML files
- Parallel job execution with global thread accounting
- CPU affinity enforcement to avoid oversubscription
- Support for both `<outputFolder>` and `<fixedCombinedFolder>` in MaxQuant XML files
- Robust success classification based on:
  - process exit code
  - existence of output directory
  - presence of `combined/txt/summary.txt`
  - presence of `combined/txt/proteinGroups.txt`
- Explicit failure diagnostics via `FAILED_REASON.txt`
- Persistent audit trail via `logs/summary.log`
- Per-job stdout and stderr logging
- PowerShell 7–native implementation

### Changed
- Scheduler explicitly requires PowerShell 7 or newer
- Failure states are surfaced deterministically instead of silently

### Removed
- Deprecated `Get-WmiObject` usage (not supported in PowerShell 7)

### Fixed
- Correct handling of MaxQuant XML schema variants
- Prevention of scheduler crashes due to missing metadata
- Robust handling of partial or early-failing MaxQuant runs

---

## Pre-release development notes

Prior to v1.4.0, the scheduler existed as an internal lab script and underwent iterative hardening, including:
- XML schema validation
- Process lifecycle management
- Defensive error handling
- Compatibility testing with long-running MaxQuant jobs

These changes are consolidated into the initial public release.
