<#
.SYNOPSIS
    Creates GitHub releases in current project format.

.DESCRIPTION
    Creates two releases in one run:
    - UNF_Rozn_<version>
    - UT_KA_ERP_<version>

    For each release:
    1) Verifies the tag does not exist (local and origin).
    2) Creates and pushes an annotated tag.
    3) Creates a GitHub Release in current format:
       - title: "<Branch> <version>"
       - notes: "Automated release version <version> for <Branch>"
    4) Uploads files from bin\<Branch>_<version>.

    No simulation and no fallback logic:
    script stops on any error with exit code 1.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Version,

    [ValidateNotNullOrEmpty()]
    [string]$Target = 'main',

    [ValidateNotNullOrEmpty()]
    [string]$UNFBinRoot = 'D:\EDTApps\1c-ai-autofill\worktrees\UNF_Rozn\bin',

    [ValidateNotNullOrEmpty()]
    [string]$UTBinRoot = 'D:\EDTApps\1c-ai-autofill\worktrees\UT_KA_ERP\bin'
)

$ErrorActionPreference = 'Stop'

function Invoke-ExternalCommand {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        [Parameter(Mandatory)]
        [string[]]$Arguments,
        [Parameter(Mandatory)]
        [string]$OperationName
    )

    Write-Host "==> $OperationName"
    Write-Host ("    {0} {1}" -f $FilePath, ($Arguments -join ' '))

    $stdoutPath = [System.IO.Path]::GetTempFileName()
    $stderrPath = [System.IO.Path]::GetTempFileName()
    try {
        $process = Start-Process -FilePath $FilePath -ArgumentList $Arguments -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -NoNewWindow -PassThru
        $process | Wait-Process

        $stdout = Get-Content -LiteralPath $stdoutPath -Raw -ErrorAction SilentlyContinue
        $stderr = Get-Content -LiteralPath $stderrPath -Raw -ErrorAction SilentlyContinue

        if ($stdout) {
            $stdout.TrimEnd("`r", "`n").Split("`n") | ForEach-Object { Write-Host ("    " + $_.TrimEnd("`r")) }
        }
        if ($stderr) {
            $stderr.TrimEnd("`r", "`n").Split("`n") | ForEach-Object { Write-Host ("    " + $_.TrimEnd("`r")) }
        }

        if ($process.ExitCode -ne 0) {
            throw "Operation '$OperationName' failed with exit code $($process.ExitCode)."
        }
    }
    finally {
        Remove-Item -LiteralPath $stdoutPath -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $stderrPath -ErrorAction SilentlyContinue
    }
}

function Assert-TagDoesNotExist {
    param(
        [Parameter(Mandatory)]
        [string]$Tag
    )

    $existingLocalTag = (& git tag --list $Tag 2>$null | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to check local tags for '$Tag'."
    }
    if ($existingLocalTag) {
        throw "Tag '$Tag' already exists locally."
    }

    $existingRemoteTag = (& git ls-remote --tags origin "refs/tags/$Tag" 2>$null | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to check tags in origin for '$Tag'."
    }
    if ($existingRemoteTag) {
        throw "Tag '$Tag' already exists in origin."
    }
}

function Invoke-ReleaseForBranch {
    param(
        [Parameter(Mandatory)]
        [string]$Branch,
        [Parameter(Mandatory)]
        [string]$Version,
        [Parameter(Mandatory)]
        [string]$BinRoot,
        [Parameter(Mandatory)]
        [string]$Target
    )

    if (-not (Test-Path -LiteralPath $BinRoot -PathType Container)) {
        throw "bin directory does not exist: $BinRoot"
    }

    $releaseFolderName = "${Branch}_${Version}"
    $releaseFolderPath = Join-Path $BinRoot $releaseFolderName
    if (-not (Test-Path -LiteralPath $releaseFolderPath -PathType Container)) {
        throw "Artifacts directory does not exist: $releaseFolderPath"
    }

    $files = Get-ChildItem -LiteralPath $releaseFolderPath -File
    if (-not $files -or $files.Count -eq 0) {
        throw "Artifacts directory has no files: $releaseFolderPath"
    }

    $tag = $releaseFolderName
    $title = "$Branch $Version"
    $notes = "Automated release version $Version for $Branch"
    $tagMessage = "Release $tag"

    Assert-TagDoesNotExist -Tag $tag

    Invoke-ExternalCommand -FilePath 'git' -Arguments @('tag', '-a', $tag, '-m', $tagMessage) -OperationName "Create tag $tag"
    Invoke-ExternalCommand -FilePath 'git' -Arguments @('push', 'origin', $tag) -OperationName "Push tag $tag to origin"
    Invoke-ExternalCommand -FilePath 'gh' -Arguments @('release', 'create', $tag, '--target', $Target, '--title', $title, '--notes', $notes) -OperationName "Create GitHub Release $tag"

    foreach ($file in $files) {
        Invoke-ExternalCommand -FilePath 'gh' -Arguments @('release', 'upload', $tag, $file.FullName) -OperationName "Upload $($file.Name) to $tag"
    }

    Write-Host "Done for ${Branch}: release '$tag', files: $($files.Count)."
}

try {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "Command 'git' was not found in PATH."
    }
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw "Command 'gh' was not found in PATH."
    }

    $insideRepo = (& git rev-parse --is-inside-work-tree 2>$null)
    if ($LASTEXITCODE -ne 0 -or $insideRepo.Trim() -ne 'true') {
        throw 'Current directory is not a git repository.'
    }

    $normalizedVersion = $Version.Trim()
    if ($normalizedVersion.StartsWith('v')) {
        $normalizedVersion = $normalizedVersion.Substring(1)
    }
    if ([string]::IsNullOrWhiteSpace($normalizedVersion)) {
        throw 'Version is empty after normalization.'
    }

    Invoke-ReleaseForBranch -Branch 'UNF_Rozn' -Version $normalizedVersion -BinRoot $UNFBinRoot -Target $Target
    Invoke-ReleaseForBranch -Branch 'UT_KA_ERP' -Version $normalizedVersion -BinRoot $UTBinRoot -Target $Target

    Write-Host ''
    Write-Host "All releases created successfully for version $normalizedVersion."
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
