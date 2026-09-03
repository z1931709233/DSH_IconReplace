# DeepSeek Harness 图标替换工具（DSH_IconReplace）

## 这套程序是干什么的

它帮助你**一键更换 Windows 程序（.exe）的图标**，分两步完成，全程**不需要联网**即可操作（仅首次需下载一个小工具，见下文）：

1. **`make_icon.ps1`** —— 把一张普通图片（PNG/JPG/BMP）转换成一个**标准的多尺寸 Windows 图标文件 `.ico`**（内置 16/24/32/48/64/128/256 像素，带透明）。
2. **`replace_icon.ps1`** —— 把上面生成的 `.ico` **写进指定的 `.exe`**（替换它内部的图标资源），并自动清理 Windows 图标缓存，让新图标尽快显示。

> 典型用途：`DeepSeek Harness.exe`（Electron 桌面应用）等 Windows 程序的桌面/任务栏图标是打包在 exe 内部的，不能靠配置替换，只能用本工具把图标重新嵌回 exe。

## 目录内容

| 文件 | 作用 |
|------|------|
| `make_icon.ps1` | 脚本 1：图片 → `.ico`（纯 PowerShell，无需联网、无需工具） |
| `replace_icon.ps1` | 脚本 2：`.ico` → 写入 `.exe` + 清理图标缓存 |
| `rcedit.exe` | 脚本 2 依赖的小工具（本机已附带一份） |
| `使用说明.md` | 本文档 |

## 需要下载什么工具

脚本 2（替换 exe 图标）依赖 Electron 官方的小工具 **rcedit**，它不能内置，需要你**下载一次**（之后所有操作都在离线状态下完成）：

1. 打开 https://github.com/electron/rcedit/releases
2. 下载 **`rcedit-x64.exe`**（64 位系统用这个）
3. 把下载的文件**改名为 `rcedit.exe`**，放到**与两个脚本相同的文件夹**（即本目录）。
   - 若你的 exe 是 32 位，就下载 `rcedit-x86.exe` 并同样改名。

> 脚本 1（生成 .ico）不需要任何下载，Windows 自带绘图组件即可完成。

## 脚本放在什么位置

- **四个文件放到同一个文件夹**：`make_icon.ps1`、`replace_icon.ps1`、`rcedit.exe`、`使用说明.md`。建议整个文件夹放在一个不易移动的位置（如 `C:\Tools\DSH_IconReplace` 或本目录）。
- 两个脚本之间没有强绑定，只要 `rcedit.exe` 与 `replace_icon.ps1` 同目录即可。

## 如何执行

### 第一步：生成图标 `.ico`

在资源管理器进入本文件夹，按住 `Shift` 在空白处**右键 → 在此处打开 PowerShell 窗口**，然后输入：

```powershell
powershell -ExecutionPolicy Bypass -File ".\make_icon.ps1"
```

按提示：
1. 把**源图片**直接拖进窗口（或输入完整路径）。
2. 输入**输出 .ico 路径**（直接回车会用图片同目录、同名 `.ico`）。

**源图片要求**（脚本运行时会再次提示）：
- 格式：PNG / JPG / BMP（需要透明背景时请用 PNG）
- 建议**正方形**（非正方形会自动补透明边，不裁切画面）
- 建议分辨率 **≥ 512×512**（最低 256×256），太小放大后会模糊
- 图标主体尽量居中，四周留一点边距

运行结束看到“成功！”即生成了可用的 `.ico`。

### 第二步：替换 exe 图标并清理缓存

仍在同一 PowerShell 窗口执行：

```powershell
powershell -ExecutionPolicy Bypass -File ".\replace_icon.ps1"
```

按提示：
1. 把**目标 exe**（如 `D:\AIWorker\deepseek-harness\DeepSeek Harness.exe`）拖进窗口。
2. 把 **.ico** 拖进窗口（回车用默认的同名 .ico）。
3. 若 exe 正在运行，输入 `Y` 结束进程后继续。
4. 询问是否清理图标缓存，输入 `Y`（会短暂重启资源管理器/任务栏闪烁）。

### 直接带参数执行（自动化/免交互）

```powershell
powershell -ExecutionPolicy Bypass -File ".\make_icon.ps1" -Source "D:\logo.png" -Output "D:\logo.ico"
powershell -ExecutionPolicy Bypass -File ".\replace_icon.ps1" -TargetExe "D:\app.exe" -IconFile "D:\logo.ico"
```

## 常见问题

- **脚本被阻止运行？**
  Windows 默认执行策略可能拦截。统一用上面带 `-ExecutionPolicy Bypass` 的方式即可；或在 PowerShell 里先执行 `Set-ExecutionPolicy -Scope Process Bypass`。

- **替换后桌面/任务栏图标还是旧的？**
  这是 Windows 图标缓存。运行脚本 2 并选择清理即可；仍不行就**删除桌面快捷方式后重新新建**一个指向该 exe 的快捷方式，或注销/重启一次。

- **提示找不到 `rcedit.exe`？**
  说明 rcedit 没放在脚本同目录，按上文“需要下载什么工具”放置后重试。

- **手动清理图标缓存的命令**（可选）：
  ```bat
  taskkill /f /im explorer.exe
  del /f /a "%LocalAppData%\IconCache.db"
  del /f /a "%LocalAppData%\Microsoft\Windows\Explorer\iconcache*"
  del /f /a "%LocalAppData%\Microsoft\Windows\Explorer\thumbcache_*"
  start explorer.exe
  ```

## 重要提醒

- **替换 exe 图标会破坏其数字签名**。之后系统可能提示“未知发布者”。若用于正式分发，应在打包/签名流程中改图标，而不是事后替换。
- 操作前建议**备份原 exe**。
