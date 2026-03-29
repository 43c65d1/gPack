# gPack - 出题数据与代码自动打包工具

本脚本用于快速打包竞赛题目所需的数据文件（`.in`/`.out`）和源代码（`std.cpp`、`gen.cpp`、`validator.cpp` 等），生成两个规范命名的 ZIP 压缩包，方便归档或分发。

## 主要功能

- **数据包（`0_Data_日期.zip`）**：递归收集当前目录下所有 `.in` / `.out` 文件，**扁平化**（不保留子目录结构）打包成一个 ZIP。
- **代码包（`0_std_日期.zip`）**：
  - 将 `std.cpp`、`gen.cpp`、`val.cpp`、`Problem.md` 放入 `std/` 子目录。
  - 将所有 `.in` / `.out` 文件放入 `data/` 子目录（可通过 `-d` 参数跳过数据文件）。
  - 可选包含 `spj.cpp`（需加 `-s` 开关）。
- **额外文件支持**：通过 `-i` 参数可添加任意文件或目录（支持通配符），并灵活指定放入 `std/`、`data/` 或两者。
- **自定义后缀**：使用 `-N` 参数为 ZIP 文件名添加自定义后缀（如 `_final`）。
- 所有生成的 ZIP 文件保存在当前目录下的 **`Zips/`** 文件夹中。

## 使用方法

```powershell
.\gPack.ps1 [-s] [-d] [-i "路径 [选项]"] [-N "后缀"]
```

### 参数说明

| 参数 | 说明 |
|------|------|
| `-s` | 包含 `spj.cpp`（默认不包含） |
| `-d` | 仅打包 `std/` 目录，生成的 `0_std_*.zip` 中**不包含** `data/` 子目录 |
| `-i` | 额外包含的文件或目录（支持通配符）。可在路径后附加选项（空格分隔）：<br> • 无选项 或 `s` → 放入 `std/`<br> • `d` → 放入 `data/`<br> • `sd` 或 `ds` → 同时放入 `std/` 和 `data/`<br>示例：`-i "docs\*.pdf s" -i "extra\*.in d"` |
| `-N` | 自定义文件名后缀，附加在日期之后，如 `-N "v2"` 生成 `0_Data_20241101_v2.zip` |

## 使用示例

```powershell
# 基础打包（不含 spj.cpp，同时生成数据包和代码包）
.\gPack.ps1

# 包含 spj.cpp
.\gPack.ps1 -s

# 只生成代码包（不含 data/ 子目录）
.\gPack.ps1 -d

# 额外包含 README.md 到 std/，所有 .txt 到 std/，以及外部 .ans 文件到 data/
.\gPack.ps1 -i "README.md" -i "*.txt s" -i "C:\data\*.ans d"

# 同时包含 spj.cpp，并为 ZIP 文件添加后缀 "final"
.\gPack.ps1 -s -N "final"
```

## 输出结构示例

```
当前目录/
├── gPack.ps1
├── std.cpp
├── gen.cpp
├── val.cpp
├── Problem.md
├── spj.cpp (可选)
├── 1.in, 1.out, 2.in, 2.out ...
└── Zips/
    ├── 0_Data_20231025.zip
    │   ├── 1.in
    │   ├── 1.out
    │   ├── 2.in
    │   └── 2.out
    └── 0_std_20231025.zip
        ├── std/
        │   ├── std.cpp
        │   ├── gen.cpp
        │   ├── val.cpp
        │   ├── Problem.md
        │   └── spj.cpp (如果使用 -s)
        └── data/
            ├── 1.in
            ├── 1.out
            ├── 2.in
            └── 2.out
```

## 注意事项

1. **文件名冲突**：由于数据文件会被**扁平化**（所有文件直接放入 ZIP 根目录或 `data/` 目录），如果不同子目录中存在同名文件，后复制的文件会覆盖先前的文件。请确保数据文件名称唯一。
2. **默认包含的文件**：
   - 源代码：`std.cpp`, `gen.cpp`, `val.cpp`, `Problem.md`（以及可选的 `spj.cpp`）
   - 数据文件：所有 `.in` / `.out` 文件（递归查找）
3. **输出目录**：`Zips/` 文件夹会自动创建，若已存在则直接使用。
4. **权限要求**：脚本会在系统临时目录中创建临时文件夹用于打包，需要写入权限。

## 依赖环境

- Windows PowerShell 5.0 或更高版本（内置 `Compress-Archive` cmdlet）
- 无需额外安装模块

## 更新日志

- **重构版本**：新增 `-i` 和 `-N` 参数，支持灵活添加外部文件，文件名可自定义后缀。
- 默认包含 `Problem.md`。
- 修复了旧版中的若干路径处理问题。

---

如需更多帮助，请运行 `Get-Help .\gPack.ps1 -Detailed`。