<#
.SYNOPSIS
    打包 .in/.out 数据文件和 .cpp 源代码文件为 ZIP 压缩包，支持包含额外文件并指定目标路径。
.DESCRIPTION
    基于当前目录递归查找所有 .in/.out 文件，生成保留目录结构的 0_Data_日期时间[_后缀].zip（日期时间为 yyyyMMdd_HHmmss，按名字排序即时间先后）；
    同时打包 std.cpp, gen.cpp, validator.cpp（可选 spj.cpp）到 0_std_日期时间[_后缀].zip 的 std/ 子目录，
    并将 .in/.out 文件（及通过 -IncludeData 指定的文件）复制到 data/ 子目录（除非使用 -ExcludeData 参数）。
    额外文件可通过 -IncludeAll / -i（同时放入 std/ 和 data/）、
    -IncludeStd / -is（仅放入 std/）或 -IncludeData / -id（仅放入 data/）指定。
    支持通配符和自定义目标路径，使用 "源路径>目标路径" 格式（目标路径相对于 std/ 或 data/ 内部）。
    默认不递归目录（目录被忽略，请使用显式通配符匹配其文件）。

    新增 -Name / -n 参数可自定义 ZIP 文件名后缀（例如 -n "v2" 将生成 0_Data_20241101_143052_v2.zip）。
    若系统 PATH 或 Program Files 下存在 7-Zip（7z.exe），优先用其生成 .zip；否则使用 Compress-Archive。
    所有 ZIP 文件保存在当前目录下的 zips 文件夹中。
.PARAMETER spj
    包含 spj.cpp 文件（默认排除）。短选项 -s，长选项 -spj。
.PARAMETER ExcludeData
    仅打包 std 目录（即只包含 .cpp 文件，不包含 data 子目录）。短选项 -ed，长选项 -exclude-data。
.PARAMETER IncludeAll
    额外包含的文件或目录（支持通配符），同时放入 std/ 和 data/。短选项 -i，长选项 -include-all。
    可使用 "源路径>目标路径" 指定目标位置（相对于 std/ 或 data/ 内部）。
.PARAMETER IncludeStd
    额外包含的文件或目录（支持通配符），仅放入 std/。短选项 -is，长选项 -include-std。
.PARAMETER IncludeData
    额外包含的文件或目录（支持通配符），仅放入 data/。短选项 -id，长选项 -include-data。
.PARAMETER Name
    自定义 ZIP 文件名后缀（字符串），将附加在日期时间戳之后，如 "v2"。短选项 -n，长选项 -name。
.EXAMPLE
    .\gPack.ps1                             # 普通打包
    .\gPack.ps1 -s                          # 包含 spj.cpp
    .\gPack.ps1 -ed                         # 仅打包 std 目录（不包含 data）
    .\gPack.ps1 -i "README.md" -is "*.txt"  # 额外包含 README.md 到 std 和 data，所有 .txt 到 std
    .\gPack.ps1 -id "C:\data\*.ans" -s      # 包含外部 .ans 文件到 data，并包含 spj.cpp
    .\gPack.ps1 -n "final"                  # 生成带 "_final" 后缀的 ZIP 文件
    .\gPack.ps1 -i "a.png>img/logo.png"     # 将 a.png 重命名并放入 std/img/ 和 data/img/
    .\gPack.ps1 -is "*.jpg>imgs/"           # 将所有 jpg 文件放入 std/imgs/ 下
#>

param(
    [Alias('s')]
    [switch]$spj,                       # 包含 spj.cpp

    [Alias('ed', 'exclude-data')]
    [switch]$ExcludeData,               # 仅打包 std 目录（不包含 data）

    [Alias('i', 'include-all')]
    [string[]]$IncludeAll,              # 额外包含的文件/目录，同时放入 std/ 和 data/

    [Alias('is', 'include-std')]
    [string[]]$IncludeStd,              # 额外包含的文件/目录，仅放入 std/

    [Alias('id', 'include-data')]
    [string[]]$IncludeData,             # 额外包含的文件/目录，仅放入 data/

    [Alias('n')]
    [string]$Name                       # ZIP 文件名后缀
)

# ZIP 文件名中的时间戳（yyyyMMdd_HHmmss，字典序与时间序一致；同日多次打包互不覆盖）
$zipStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
# 生成后缀字符串（若指定则带下划线，否则为空）
$suffix = if ($Name) { "_$Name" } else { "" }

# 输出目录：当前目录下的 zips
$outputDir = Join-Path $PWD.Path 'zips'
# 创建输出目录（如果不存在）
if (-not (Test-Path $outputDir)) {
    try {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        Write-Host "[INFO] Created output directory: $outputDir"
    } catch {
        Write-Host "[ERROR] Failed to create directory: $outputDir"
        exit 1
    }
}

function Get-7ZipExecutablePath {
    $fromPath = Get-Command 7z -ErrorAction SilentlyContinue
    if ($fromPath -and $fromPath.Source -and (Test-Path -LiteralPath $fromPath.Source)) {
        return $fromPath.Source
    }
    foreach ($p in @(
            (Join-Path $env:ProgramFiles '7-Zip\7z.exe'),
            (Join-Path ${env:ProgramFiles(x86)} '7-Zip\7z.exe')
        )) {
        if ($p -and (Test-Path -LiteralPath $p)) { return $p }
    }
    return $null
}

# 将目录下顶层内容打成 ZIP（与 Compress-Archive -Path (Join-Path $dir '*') 布局一致）；有 7z 则优先使用
function New-ZipFromDirectoryContents {
    param(
        [string]$SourceDirectory,
        [string]$ZipFilePath,
        [string]$SevenZipPath
    )
    if (Test-Path -LiteralPath $ZipFilePath) {
        Remove-Item -LiteralPath $ZipFilePath -Force
    }
    if ($SevenZipPath) {
        $argList = @('a', '-tzip', '-mx=9', '-bd', $ZipFilePath, '*', '-r')
        $p = Start-Process -FilePath $SevenZipPath -ArgumentList $argList -Wait -PassThru -NoNewWindow -WorkingDirectory $SourceDirectory
        $code = $p.ExitCode
        $sevenZipOk = (Test-Path -LiteralPath $ZipFilePath) -and ($code -lt 2)
        if (-not $sevenZipOk) {
            if (Test-Path -LiteralPath $ZipFilePath) {
                Remove-Item -LiteralPath $ZipFilePath -Force -ErrorAction SilentlyContinue
            }
            Write-Warning "7-Zip failed or incomplete (exit $code); falling back to Compress-Archive"
            Compress-Archive -Path (Join-Path $SourceDirectory '*') -DestinationPath $ZipFilePath -Force
        }
    } else {
        Compress-Archive -Path (Join-Path $SourceDirectory '*') -DestinationPath $ZipFilePath -Force
    }
}

$sevenZipExe = Get-7ZipExecutablePath
if ($sevenZipExe) {
    Write-Host "[INFO] Using 7-Zip: $sevenZipExe"
} else {
    Write-Host "[INFO] 7-Zip not found; using Compress-Archive"
}

# ---------- 初始化文件列表 ----------
$stdEntries = @()
$dataEntries = @()

# 1. 收集默认的 .cpp 文件到 std（递归）
$cppIncludes = @('std.cpp', 'gen.cpp', 'val.cpp', 'Problem.md')
if ($spj) {
    $cppIncludes += 'spj.cpp'
    Write-Host "[INFO] Including spj.cpp"
} else {
    Write-Host "[INFO] Excluding spj.cpp"
}
$cppFiles = Get-ChildItem -Path . -Recurse -Include $cppIncludes -File -ErrorAction SilentlyContinue
if ($cppFiles) {
    foreach ($file in $cppFiles) {
        $stdEntries += [PSCustomObject]@{ Source = $file.FullName; Dest = $file.Name }
    }
    Write-Host "[INFO] Found $(@($cppFiles).Count) default .cpp files for std/"
}

# 2. 收集默认的 .in/.out 文件到 data（递归）
$inOutFiles = Get-ChildItem -Path . -Recurse -Include '*.in', '*.out' -File -ErrorAction SilentlyContinue
if ($inOutFiles) {
    foreach ($file in $inOutFiles) {
        $dataEntries += [PSCustomObject]@{ Source = $file.FullName; Dest = $file.Name }
    }
    Write-Host "[INFO] Found $(@($inOutFiles).Count) .in/.out files for data/"
}

# ---------- 3. 处理额外包含的文件（支持 > 分隔符，默认不递归） ----------
function Add-FilesFromPatterns {
    param(
        [string[]]$Patterns,
        [ref]$StdEntriesRef,
        [ref]$DataEntriesRef,
        [string]$Target   # "std", "data", "both"
    )
    if (-not $Patterns) { return }
    Write-Host "[INFO] Processing $Target include patterns..."
    foreach ($pattern in $Patterns) {
        $sourcePattern = $pattern
        $destPath = $null
        if ($pattern -match '>') {
            $parts = $pattern -split '\s*>\s*', 2
            $sourcePattern = $parts[0].Trim()
            $destPath = $parts[1].Trim()
            # 统一目标路径中的分隔符为 Windows 反斜杠（内部处理方便 Join-Path）
            $destPath = $destPath -replace '/', '\'
            if ($destPath -eq '\') { $destPath = '' }
        }
        
        $items = Get-Item $sourcePattern -ErrorAction SilentlyContinue
        if (-not $items) {
            Write-Warning "      Include pattern not found: $sourcePattern"
            continue
        }
        
        $matchedFiles = @()
        foreach ($item in $items) {
            if ($item.PSIsContainer) {
                Write-Host "[INFO]       Skipping directory: $($item.FullName) (use explicit pattern to include its files)"
                continue
            }
            $matchedFiles += $item
        }
        
        if (@($matchedFiles).Count -eq 0) {
            Write-Warning "      No files matched (directories ignored): $sourcePattern"
            continue
        }
        
        $isMultiple = @($matchedFiles).Count -gt 1
        if ($destPath) {
            $endsWithSlash = $destPath -match '\\$'
            if ($isMultiple -and -not $endsWithSlash) {
                Write-Warning "      Multiple files but destination '$destPath' does not end with '\', treating as directory."
                $destPath = $destPath + '\'
                $endsWithSlash = $true
            }
            if ($endsWithSlash -or ($isMultiple -and -not $endsWithSlash)) {
                foreach ($file in $matchedFiles) {
                    $relativeDest = if ($destPath) { Join-Path $destPath $file.Name } else { $file.Name }
                    $relativeDest = $relativeDest -replace '\\', '/'   # ZIP 内使用正斜杠
                    Write-Host "[INFO]       File: $($file.FullName) -> $relativeDest"
                    if ($Target -eq 'std' -or $Target -eq 'both') {
                        $StdEntriesRef.Value += [PSCustomObject]@{ Source = $file.FullName; Dest = $relativeDest }
                    }
                    if ($Target -eq 'data' -or $Target -eq 'both') {
                        $DataEntriesRef.Value += [PSCustomObject]@{ Source = $file.FullName; Dest = $relativeDest }
                    }
                }
            } else {
                # 单个文件且目标不以反斜杠结尾：目标应为文件路径
                if (@($matchedFiles).Count -eq 1) {
                    $file = $matchedFiles[0]
                    $relativeDest = $destPath -replace '\\', '/'
                    Write-Host "[INFO]       File: $($file.FullName) -> $relativeDest"
                    if ($Target -eq 'std' -or $Target -eq 'both') {
                        $StdEntriesRef.Value += [PSCustomObject]@{ Source = $file.FullName; Dest = $relativeDest }
                    }
                    if ($Target -eq 'data' -or $Target -eq 'both') {
                        $DataEntriesRef.Value += [PSCustomObject]@{ Source = $file.FullName; Dest = $relativeDest }
                    }
                } else {
                    Write-Warning "      Multiple files but destination '$destPath' does not end with '\', treating as directory."
                    foreach ($file in $matchedFiles) {
                        $relativeDest = (Join-Path $destPath $file.Name) -replace '\\', '/'
                        Write-Host "[INFO]       File: $($file.FullName) -> $relativeDest"
                        if ($Target -eq 'std' -or $Target -eq 'both') {
                            $StdEntriesRef.Value += [PSCustomObject]@{ Source = $file.FullName; Dest = $relativeDest }
                        }
                        if ($Target -eq 'data' -or $Target -eq 'both') {
                            $DataEntriesRef.Value += [PSCustomObject]@{ Source = $file.FullName; Dest = $relativeDest }
                        }
                    }
                }
            }
        } else {
            foreach ($file in $matchedFiles) {
                Write-Host "[INFO]       File: $($file.FullName) -> $($file.Name)"
                if ($Target -eq 'std' -or $Target -eq 'both') {
                    $StdEntriesRef.Value += [PSCustomObject]@{ Source = $file.FullName; Dest = $file.Name }
                }
                if ($Target -eq 'data' -or $Target -eq 'both') {
                    $DataEntriesRef.Value += [PSCustomObject]@{ Source = $file.FullName; Dest = $file.Name }
                }
            }
        }
    }
}

Add-FilesFromPatterns -Patterns $IncludeAll -StdEntriesRef ([ref]$stdEntries) -DataEntriesRef ([ref]$dataEntries) -Target 'both'
Add-FilesFromPatterns -Patterns $IncludeStd -StdEntriesRef ([ref]$stdEntries) -DataEntriesRef ([ref]$dataEntries) -Target 'std'
Add-FilesFromPatterns -Patterns $IncludeData -StdEntriesRef ([ref]$stdEntries) -DataEntriesRef ([ref]$dataEntries) -Target 'data'

# 去重（按 Source 和 Dest 组合）；@() 保证结果为数组，避免单条时 .Count 失效
$stdEntries = @($stdEntries | Sort-Object -Property Source, Dest -Unique)
$dataEntries = @($dataEntries | Sort-Object -Property Source, Dest -Unique)

Write-Host "[INFO] Final entries: std/ $(@($stdEntries).Count) items, data/ $(@($dataEntries).Count) items"

# ---------- 4. 创建 Data ZIP（保留目录结构，与 std zip 中的 data/ 一致） ----------
$dataZipName = "0_Data_$zipStamp$suffix.zip"
$dataZipPath = Join-Path $outputDir $dataZipName
if (@($dataEntries).Count -gt 0) {
    $tempDataDir = Join-Path $env:TEMP "DataTemp_$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDataDir -Force | Out-Null
    try {
        foreach ($entry in @($dataEntries)) {
            $relPath = $entry.Dest -replace '/', '\'   # 转为 Windows 路径
            $targetPath = Join-Path $tempDataDir $relPath
            $targetDir = Split-Path $targetPath -Parent
            if (-not (Test-Path $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }
            Copy-Item -Path $entry.Source -Destination $targetPath -Force
        }
        New-ZipFromDirectoryContents -SourceDirectory $tempDataDir -ZipFilePath $dataZipPath -SevenZipPath $sevenZipExe
        Write-Host "[OK] Data ZIP created: $dataZipPath"
    } finally {
        Remove-Item -Path $tempDataDir -Recurse -Force -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "[WARN] No files for Data ZIP (0_Data_*.zip not created)"
}

# ---------- 5. 创建 Structured ZIP（std/ 和可选的 data/） ----------
$stdZipName = "0_std_$zipStamp$suffix.zip"
$stdZipPath = Join-Path $outputDir $stdZipName
$tempStdDir = Join-Path $env:TEMP "StdTemp_$(Get-Random)"
New-Item -ItemType Directory -Path $tempStdDir -Force | Out-Null
try {
    # std 子目录
    $stdSubDir = Join-Path $tempStdDir 'std'
    New-Item -ItemType Directory -Path $stdSubDir -Force | Out-Null
    foreach ($entry in @($stdEntries)) {
        $targetPath = Join-Path $stdSubDir ($entry.Dest -replace '/', '\')
        $targetDir = Split-Path $targetPath -Parent
        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }
        Copy-Item -Path $entry.Source -Destination $targetPath -Force
    }
    
    # data 子目录（与 Data ZIP 内容完全一致）
    if (-not $ExcludeData) {
        $dataSubDir = Join-Path $tempStdDir 'data'
        New-Item -ItemType Directory -Path $dataSubDir -Force | Out-Null
        foreach ($entry in @($dataEntries)) {
            $targetPath = Join-Path $dataSubDir ($entry.Dest -replace '/', '\')
            $targetDir = Split-Path $targetPath -Parent
            if (-not (Test-Path $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }
            Copy-Item -Path $entry.Source -Destination $targetPath -Force
        }
    } else {
        Write-Host "[INFO] -ExcludeData specified: Structured ZIP will only contain std/ directory"
    }
    
    $allItems = @(Get-ChildItem $tempStdDir -Recurse -ErrorAction SilentlyContinue)
    if (@($allItems).Count -gt 0) {
        New-ZipFromDirectoryContents -SourceDirectory $tempStdDir -ZipFilePath $stdZipPath -SevenZipPath $sevenZipExe
        Write-Host "[OK] Structured ZIP created: $stdZipPath"
    } else {
        Write-Host "[WARN] No files for Structured ZIP (0_std_*.zip not created)"
    }
} finally {
    Remove-Item -Path $tempStdDir -Recurse -Force -ErrorAction SilentlyContinue
}
