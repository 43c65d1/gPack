# Automatically-bundling-codes-and-data.

I'm just want to do somthing at my coding life.

这其实没什么好看的，只是改了一下AI的代码（不改实在跑不了）

主要是用来方便我出题的（

打包俩ZIP 一个 0\_std\_*DAYTime\_now*.zip , 一个0\_data\_*DAYTime\_now*.zip

0_std_*.zip 会找 std.cpp、gen.cpp、validator.cpp 打包到 std 文件夹里，然后 把所有的 .in/.out 打到 data 文件夹里。

0_data_*.zip 就只包含 *.in/.out 。

结构大概长这个样：

```
├── GP.bat
└── Zips/
    ├── 0_std_20231025.zip
    │   ├── std/
    │   │   ├── std.cpp
    │   │   ├── gen.cpp
    │   │   └── validator.cpp
    │   └── data/
    │       ├── 1.in
    │       └── 1.out
    └── 0_Data_20231025.zip
        ├── test1.in
        └── test1.out
```


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


param(
    [switch]$s,                     # 包含 spj.cpp
    [switch]$d,                     # 仅打包 std 目录（不包含 data）
    [string[]]$i,                   # 额外包含的文件/目录列表，可带选项
    [string]$N                      # ZIP 文件名后缀
)
