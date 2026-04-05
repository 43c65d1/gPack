# gPack - 出题数据与代码自动打包工具

本脚本用于快速打包竞赛题目所需的数据文件（`.in`/`.out`）和源代码（`std.cpp`、`gen.cpp`、`val.cpp`、`Problem.md` 等），生成两个规范命名的 ZIP 压缩包，方便归档或分发。

## 主要功能

- **数据包（`0_Data_yyyyMMdd_HHmmss[_后缀].zip`）**：将当前目录递归收集到的所有 `.in` / `.out` 按**目标相对路径**写入 ZIP 根下（默认每条记录的目标名为**仅文件名**，效果为扁平化；若通过包含规则指定了子路径，则**保留**该相对结构）。
- **结构化包（`0_std_yyyyMMdd_HHmmss[_后缀].zip`）**：
  - 将 `std.cpp`、`gen.cpp`、`val.cpp`、`Problem.md` 放入 `std/` 子目录。
  - 将所有 `.in` / `.out`（及通过 `-id` 等加入 data 的条目）放入 `data/` 子目录，布局与数据包一致（除非使用 `-ExcludeData`）。
  - 可选包含 `spj.cpp`（`-s` / `-spj`）。
- **额外文件**：用 `-i`（std 与 data 各一份）、`-is`（仅 std）、`-id`（仅 data）指定；支持通配符，并用 **`源路径>目标相对路径`** 控制 ZIP 内路径（目标相对于 `std/` 或 `data/`）。**默认不把目录当成“整棵递归打进包”**：遇到目录会跳过，需用通配符显式匹配文件。
- **自定义后缀**：`-n` / `-Name` 在时间戳**之后**追加一段，例如 `_final`。
- **时间戳**：`yyyyMMdd_HHmmss`，同一天多次打包文件名不同；按文件名排序即大致按打包时间先后。
- **压缩**：若环境中有 7-Zip（`7z`），优先用其生成 `.zip`；否则使用 `Compress-Archive`。
- 所有生成的 ZIP 保存在当前目录下的 **`Zips/`** 中。

## 使用方法

```powershell
.\gPack.ps1 [-s] [-ed] [[-i] <路径或模式> ...] [[-is] <路径或模式> ...] [[-id] <路径或模式> ...] [-n <后缀>]
```

长参数名：` -spj`、`-exclude-data`、`-include-all`、`-include-std`、`-include-data`、`-name`。

### 参数说明

| 参数 | 说明 |
|------|------|
| `-s` / `-spj` | 包含 `spj.cpp`（默认不包含） |
| `-ed` / `-exclude-data` | 仅打包 `std/`：生成的 `0_std_*.zip` 中**不包含** `data/` 子目录 |
| `-i` / `-include-all` | 额外包含的文件或模式；每个文件同时加入 `std/` 与 `data/` |
| `-is` / `-include-std` | 额外包含；**仅**加入 `std/` |
| `-id` / `-include-data` | 额外包含；**仅**加入 `data/` |
| `-n` / `-Name` | 自定义文件名后缀，接在时间戳之后，例如 `-n "v2"` → `0_Data_20241101_143052_v2.zip` |

**`源>目标` 规则（可选）**

- 无 `>`：在 `std/` 或 `data/` 根下使用**原文件名**。
- `文件>子路径`：单文件重命名/放到指定相对路径（如 `a.png>img/logo.png`）。
- `文件>目录/` 或 `文件>目录\`**（目标以分隔符结尾）**：表示目录，多文件时每个文件名为 `目录/原名`（如 `*.jpg>imgs/`）。

## 使用示例

```powershell
# 基础打包（不含 spj.cpp，数据包 + 结构化包）
.\gPack.ps1

# 包含 spj.cpp
.\gPack.ps1 -s

# 结构化包中不要 data/ 子目录
.\gPack.ps1 -ed

# README 同时进 std 与 data；所有 .txt 仅进 std；外部 .ans 仅进 data
.\gPack.ps1 -i "README.md" -is "*.txt" -id "C:\data\*.ans"

# 图片放到 std/data 下的 imgs/ 子目录
.\gPack.ps1 -i "a.png>img/logo.png"

# 带后缀，并包含 spj
.\gPack.ps1 -s -n "final"
```

## 输出结构示例

```
当前目录/
├── gPack.ps1
├── std.cpp
├── gen.cpp
├── val.cpp
├── Problem.md
├── spj.cpp（可选）
├── 1.in, 1.out, 2.in, 2.out …
└── Zips/
    ├── 0_Data_20231025_153045.zip
    │   ├── 1.in
    │   ├── 1.out
    │   └── …
    └── 0_std_20231025_153045.zip
        ├── std/
        │   ├── std.cpp
        │   ├── gen.cpp
        │   ├── val.cpp
        │   ├── Problem.md
        │   └── spj.cpp（若使用 -s）
        └── data/
            ├── 1.in
            ├── 1.out
            └── …
```

（同一秒内多次运行仍可能重名；一般按秒区分已足够。）

## 注意事项

1. **同名覆盖**：默认数据在 ZIP 内以目标相对路径写入；若多条记录指向同一目标路径，后写入的会覆盖先前的。请保证目标路径不冲突。
2. **默认收集**：递归扫描当前目录下的 `std.cpp`、`gen.cpp`、`val.cpp`、`Problem.md` 与所有 `.in`/`.out`；`spj.cpp` 仅在使用 `-s` 时加入。
3. **`Zips/`**：不存在时会自动创建。
4. **临时目录**：打包过程使用系统临时目录，需具备写权限。
5. **列表与计数**：脚本在关键处用 `@(...)` 包装集合，减轻 PowerShell 下“单条 `PSCustomObject` 时 `.Count` 异常”的问题。

## 依赖环境

- Windows PowerShell 5.0 或更高版本（`Compress-Archive`）
- **可选**：安装 [7-Zip](https://www.7-zip.org/) 或将 `7z.exe` 加入 PATH；检测到 `7z` 时优先用其打 ZIP，失败则回退到 `Compress-Archive`
- 无需额外 PowerShell 模块

## 更新日志

- **当前版本**：ZIP 名使用 `yyyyMMdd_HHmmss`；`-ed` 排除结构化包中的 `data/`；额外文件拆分为 `-i` / `-is` / `-id`，支持 `源>目标` 与目录尾部分隔符。
- 若存在 7-Zip（`7z` / 常见安装路径），优先用 7z 压缩；否则使用内置 `Compress-Archive`。
- 默认包含 `Problem.md`；校验器文件名为 `val.cpp`。
- 对 `.Count` 与 `foreach` 使用 `@()` 做防御性处理。

---

更多说明见脚本内注释，或运行：`Get-Help .\gPack.ps1 -Detailed`
