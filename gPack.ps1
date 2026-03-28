<#
.SYNOPSIS
    打包 .in/.out 数据文件和 .cpp 源代码文件为 ZIP 压缩包，支持包含额外文件。
.DESCRIPTION
    基于当前目录递归查找所有 .in/.out 文件，生成扁平结构的 0_Data_日期[_后缀].zip；
    同时打包 std.cpp, gen.cpp, validator.cpp（可选 spj.cpp）到 0_std_日期[_后缀].zip 的 std/ 子目录，
    并将 .in/.out 文件复制到 data/ 子目录（除非使用 -d 参数）。
    新增 -i 参数可额外指定文件或目录（支持通配符），并可选择放入 std/、data/ 或两者。
    新增 -N 参数可自定义 ZIP 文件名后缀（例如 -N "v2" 将生成 0_Data_20241101_v2.zip）。
    所有 ZIP 文件保存在当前目录下的 Zips 文件夹中。
.PARAMETER s
    包含 spj.cpp 文件（默认排除）。
.PARAMETER d
    仅打包 std 目录（即只包含 .cpp 文件，不包含 data 子目录）。
.PARAMETER i
    额外包含的文件或目录，支持通配符。可在路径后附加选项（用空格分隔）：
        无选项：默认放入 std/
        s     ：放入 std/
        d     ：放入 data/
        sd/ds ：同时放入 std/ 和 data/
    例如：-i "docs\*.pdf s" -i "images\logo.png" -i "extra\*.in d" -i "tools\checker.exe sd"
.PARAMETER N
    自定义 ZIP 文件名后缀（字符串），将附加在日期之后，如 "v2"。
.EXAMPLE
    .\gPack.ps1                             # 普通打包
    .\gPack.ps1 -s                          # 包含 spj.cpp
    .\gPack.ps1 -d                          # 仅打包 std 目录
    .\gPack.ps1 -i "README.md" -i "*.txt s" # 额外包含 README.md 到 std，所有 .txt 到 std
    .\gPack.ps1 -i "C:\data\*.ans d" -s     # 包含外部 .ans 文件到 data，并包含 spj.cpp
    .\gPack.ps1 -N "final"                  # 生成带 "_final" 后缀的 ZIP 文件
#>

param(
    [switch]$s,                     # 包含 spj.cpp
    [switch]$d,                     # 仅打包 std 目录（不包含 data）
    [string[]]$i,                   # 额外包含的文件/目录列表，可带选项
    [string]$N                      # ZIP 文件名后缀
)

# 获取当前日期（yyyyMMdd 格式）
$dateFormat = Get-Date -Format 'yyyyMMdd'
# 生成后缀字符串（若指定则带下划线，否则为空）
$suffix = if ($N) { "_$N" } else { "" }

# 输出目录：当前目录下的 Zips
$outputDir = Join-Path $PWD.Path 'Zips'
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

# ---------- 初始化文件列表 ----------
$stdFiles = @()   # 所有需要放入 std/ 的文件（完整路径）
$dataFiles = @()  # 所有需要放入 data/ 和 0_Data_*.zip 的文件（完整路径）

# 1. 收集默认的 .cpp 文件到 std
$cppIncludes = @('std.cpp', 'gen.cpp', 'val.cpp', 'Problem.md')
if ($s) {
    $cppIncludes += 'spj.cpp'
    Write-Host "[INFO] Including spj.cpp"
} else {
    Write-Host "[INFO] Excluding spj.cpp"
}
$cppFiles = Get-ChildItem -Path . -Recurse -Include $cppIncludes -File -ErrorAction SilentlyContinue
if ($cppFiles) {
    $stdFiles += $cppFiles.FullName
    Write-Host "[INFO] Found $($cppFiles.Count) default .cpp files for std/"
}

# 2. 收集默认的 .in/.out 文件到 data
$inOutFiles = Get-ChildItem -Path . -Recurse -Include '*.in', '*.out' -File -ErrorAction SilentlyContinue
if ($inOutFiles) {
    $dataFiles += $inOutFiles.FullName
    Write-Host "[INFO] Found $($inOutFiles.Count) .in/.out files for data/"
}

# ---------- 3. 处理 -i 参数 ----------
if ($i) {
    Write-Host "[INFO] Processing -i include items..."
    foreach ($inc in $i) {
        # 解析选项（末尾的字母组合 s/d/sd 等）
        $pathPart = $inc
        $option = 's'   # 默认放入 std
        # 从末尾查找可能的选项：最后一个空格后的单词如果全是 s/d 则作为选项
        $trimmed = $inc.TrimEnd()
        $lastSpace = $trimmed.LastIndexOf(' ')
        if ($lastSpace -ge 0) {
            $potentialOption = $trimmed.Substring($lastSpace + 1)
            if ($potentialOption -match '^[sd]+$') {
                $option = $potentialOption.ToLower()
                $pathPart = $trimmed.Substring(0, $lastSpace).Trim()
            }
        }
        Write-Host "[INFO]   Include path: '$pathPart' -> option: $option"
        # 解析路径（支持通配符）
        $items = Get-Item $pathPart -ErrorAction SilentlyContinue
        if (-not $items) {
            Write-Warning "      Include path not found: $pathPart"
            continue
        }
        foreach ($item in $items) {
            if ($item.PSIsContainer) {
                # 目录：递归获取其下所有文件（扁平化）
                $files = Get-ChildItem $item.FullName -Recurse -File
                $filePaths = $files.FullName
                Write-Host "[INFO]       Directory '$($item.FullName)' contributes $($filePaths.Count) files"
            } else {
                # 文件
                $filePaths = @($item.FullName)
                Write-Host "[INFO]       File '$($item.FullName)'"
            }
            # 根据选项添加到对应列表
            if ($option -match 's') {
                $stdFiles += $filePaths
            }
            if ($option -match 'd') {
                $dataFiles += $filePaths
            }
        }
    }
}

# 去重（避免同一文件被多次添加）
$stdFiles = $stdFiles | Select-Object -Unique
$dataFiles = $dataFiles | Select-Object -Unique

Write-Host "[INFO] Final file counts: std/ $($stdFiles.Count) files, data/ $($dataFiles.Count) files"

# ---------- 4. 创建 Data ZIP（扁平结构） ----------
$dataZipName = "0_Data_$dateFormat$suffix.zip"
$dataZipPath = Join-Path $outputDir $dataZipName
if ($dataFiles.Count -gt 0) {
    $tempDataDir = Join-Path $env:TEMP "DataTemp_$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDataDir -Force | Out-Null
    try {
        # 将所有文件复制到临时目录根目录（扁平化）
        $dataFiles | Copy-Item -Destination $tempDataDir -Force
        # 压缩
        Compress-Archive -Path (Join-Path $tempDataDir '*') -DestinationPath $dataZipPath -Force
        Write-Host "[OK] Data ZIP created: $dataZipPath"
    } finally {
        Remove-Item -Path $tempDataDir -Recurse -Force -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "[WARN] No files for Data ZIP (0_Data_*.zip not created)"
}

# ---------- 5. 创建 Structured ZIP（含 std/ 和可选的 data/） ----------
$stdZipName = "0_std_$dateFormat$suffix.zip"
$stdZipPath = Join-Path $outputDir $stdZipName
$tempStdDir = Join-Path $env:TEMP "StdTemp_$(Get-Random)"
New-Item -ItemType Directory -Path $tempStdDir -Force | Out-Null
try {
    # 创建 std 子目录
    $stdSubDir = Join-Path $tempStdDir 'std'
    New-Item -ItemType Directory -Path $stdSubDir -Force | Out-Null
    if ($stdFiles.Count -gt 0) {
        $stdFiles | Copy-Item -Destination $stdSubDir -Force
    }
    # 如果不使用 -d，则创建 data 子目录并复制 data 文件
    if (-not $d) {
        $dataSubDir = Join-Path $tempStdDir 'data'
        New-Item -ItemType Directory -Path $dataSubDir -Force | Out-Null
        if ($dataFiles.Count -gt 0) {
            $dataFiles | Copy-Item -Destination $dataSubDir -Force
        }
    } else {
        Write-Host "[INFO] -d specified: ZIP will only contain std/ directory"
    }
    # 检查临时目录下是否有文件
    $allItems = Get-ChildItem $tempStdDir -Recurse
    if ($allItems) {
        Compress-Archive -Path (Join-Path $tempStdDir '*') -DestinationPath $stdZipPath -Force
        Write-Host "[OK] Structured ZIP created: $stdZipPath"
    } else {
        Write-Host "[WARN] No files for Structured ZIP (0_std_*.zip not created)"
    }
} finally {
    Remove-Item -Path $tempStdDir -Recurse -Force -ErrorAction SilentlyContinue
}