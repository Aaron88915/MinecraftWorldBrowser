# Minecraft Java 世界浏览器 · Linux v3.3.2

Linux 版与当前 Windows 版使用同一版本号 `3.3.2`，采用 Qt Widgets 桌面界面，保留 Telegram 风格的亮色／暗色主题。

## 一键安装（Kali / Debian / Ubuntu）

下载 [Linux x86_64 一键安装包](https://github.com/Aaron88915/MinecraftWorldBrowser/releases/download/v3.3.2/MinecraftWorldBrowser-v3.3.2-linux-x86_64-install.run)，在下载目录执行一条命令：

```sh
sh MinecraftWorldBrowser-v3.3.2-linux-x86_64-install.run
```

安装器会自动验证并解压程序，补齐缺少的 Qt 系统依赖，安装到当前用户的固定目录，然后创建桌面图标与应用菜单入口。安装依赖需要网络；有缺少的软件包时会请求输入 sudo 密码。用普通用户执行上面的命令，不需要在前面加 sudo。

安装位置为 `~/.local/share/minecraft-world-browser/app/`；设置了 `XDG_DATA_HOME` 时使用该目录。安装完成后，可以删除下载的 `.run` 文件或解压目录，通过桌面上的「Minecraft Java 世界浏览器」图标启动。重复安装会更新程序，配置、世界标签和备份记录保留在程序目录之外。

也可以下载下面的 `.tar.gz` 启动包，解压后双击 **一键安装.desktop**，或者在解压目录执行 `sh install.sh`。桌面环境若询问是否允许执行安装入口，请选择允许；安装器会打开终端显示进度与密码提示。

桌面位置通过 `xdg-user-dir DESKTOP` 识别，支持“桌面”等本地化目录名。创建的图标带可执行权限，并按 Xfce 的方式设置启动校验元数据。若桌面环境仍要求“允许启动”，确认一次即可。

管理员已提前安装系统依赖时，可添加 `--skip-dependencies`；需要指定桌面位置时可添加 `--desktop-dir /绝对路径`。

## 直接启动

`MinecraftWorldBrowser-v3.3.2-linux-x86_64.tar.gz` 包含 Linux x86_64 的 Python、Qt 和中文字体，无需另外安装 Python 或通过 pip 下载依赖。

在 Linux 图形桌面的终端中运行：

```sh
tar -xzf MinecraftWorldBrowser-v3.3.2-linux-x86_64.tar.gz
cd MinecraftWorldBrowser-v3.3.2-linux-x86_64
./launch.sh
```

启动包面向使用 glibc 的 x86_64 桌面发行版，例如 Kali Linux、Ubuntu 22.04/24.04、Debian 12 及更新版本；不适用于 ARM64 或 Alpine/musl。Qt 库要求 glibc 2.28 或更高版本，并使用系统的图形桌面库。首次使用时，Kali / Debian / Ubuntu 可安装：

```sh
sudo apt update
sudo apt install libgl1 libegl1 libxkbcommon0 libxkbcommon-x11-0 \
  libxcb-cursor0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 \
  libxcb-render-util0 libxcb-xinerama0
```

如果提示 `Could not load the Qt platform plugin "xcb"`、`libxcb-cursor0 is needed`，或终端显示 `IOT instruction`，通常是 Qt 的 X11 系统依赖没有补齐。安装上面的软件包后，在程序目录重新执行 `./launch.sh`。无需换成 Ubuntu，也无需重新安装 Python。

启动时会在创建窗口前检查 X11 插件的动态库，缺少库时打印具体原因和 Kali 可用的安装命令。也可手动执行 `./launch.sh --check-dependencies`。这项检查只验证库能否加载，不连接桌面。

可选：运行 `sh install-desktop.sh`，为当前程序目录添加桌面和应用菜单快捷图标。此方式保留当前位置，程序目录需要保留；完整安装请使用上面的一键安装器。

## 功能

- 自动发现 `~/.minecraft`、Prism Launcher、MultiMC、Modrinth、ATLauncher、GDLauncher 以及常见 Flatpak 数据目录。
- 扫描 `.minecraft/saves`、版本隔离目录、启动器实例和直接添加的世界目录；可拖放或手动添加目录。
- “全盘扫描”发现用户主目录及 `/mnt`、`/media`、`/run/media` 中可读取的存档，跳过系统目录、缓存和符号链接。
- 读取 `level.dat` 的名称、版本、模式、难度、种子、最后游玩时间等信息，显示加载器、大小与存档状态。
- 搜索、版本／模式筛选、收藏、表头排序、调整列宽、详情、标签、备注、备份历史、复制路径和打开文件管理器。
- ZIP 备份与恢复、自动备份、配置导入导出；后台任务支持取消。
- 检测 Linux 上 Minecraft Java 的 `session.lock` 文件锁，阻止备份或覆盖正在使用的存档。恢复先验证并解压到临时目录，提交失败时恢复原存档。

ZIP 备份清单和 `.mwconfig` 配置格式与 Windows 版兼容。导入 Windows 配置时，Linux 上不存在的盘符路径会跳过并显示数量；收藏、标签和备注仍会保留在配置中。迁移世界后需要重新添加 Linux 的实际目录，并按新路径设置其元数据。恢复 Windows 备份时可选择 Linux 目标目录。

## 本地数据

配置、元数据和备份历史默认保存在：

```text
~/.local/share/minecraft-world-browser/settings.json
~/.local/share/minecraft-world-browser/AutomaticBackups/
```

设置了 `XDG_DATA_HOME` 时使用该目录下的 `minecraft-world-browser/`。也可通过 `./launch.sh --data-dir /自定义目录` 指定配置目录。

启用自动备份后，程序每五分钟重新检查存档，只备份发生变化且未被游戏占用的世界；程序需要保持运行。

## 从源码运行

源码启动包为 `MinecraftWorldBrowser-v3.3.2-linux-source.tar.gz`。固定的 Qt 版本需要 Python 3.10 至 3.13，以及兼容的 Linux 环境。

```sh
tar -xzf MinecraftWorldBrowser-v3.3.2-linux-source.tar.gz
cd MinecraftWorldBrowser-v3.3.2-linux
sh setup.sh
sh launch.sh
```

Ubuntu/Debian 上若未安装 Python，可先安装 `python3 python3-venv`。源码版通过 `requirements.txt` 安装固定的 `PySide6-Essentials==6.8.3`，中文字体与字体许可证已经包含在包内。

## 检查与构建

```sh
./launch.sh --version
./launch.sh --self-test
QT_QPA_PLATFORM=offscreen ./launch.sh --ui-test
QT_QPA_PLATFORM=offscreen ./launch.sh --render-preview main-light.png
QT_QPA_PLATFORM=offscreen ./launch.sh --render-preview main-dark.png --dark
```

功能检查覆盖 NBT 解析、实例识别、配置持久化、备份恢复、恶意 ZIP 路径、取消和提交回滚。界面检查覆盖明暗主题、按钮按下／释放、目录滚动条、横向分隔线、筛选排序、后台线程、详情编辑和最小窗口尺寸。预览使用独立示例数据，不读取或修改真实配置与存档。

仓库的 `.github/workflows/linux.yml` 在 Ubuntu 22.04/24.04 上运行上述检查，生成 Qt 截图，并验证打包后的 Linux 运行库。工作流仅上传构建产物，不自动发布 Release。

维护者可在仓库根目录运行：

```sh
python3 linux/tools/fetch_runtime.py
python3 -m pip download --platform manylinux_2_28_x86_64 --implementation cp \
  --python-version 312 --abi cp312 --abi abi3 --only-binary=:all: \
  --dest build/linux-wheels -r linux/requirements.txt
python3 linux/tools/package_portable.py
python3 linux/tools/package_source.py
python3 linux/tools/package_installer.py
python3 linux/tools/verify_installer.py
```

打包工具验证官方 Python 发行文件的 SHA-256、Qt wheel 的 RECORD 和 ELF 架构，并保留 Linux 可执行权限与运行库符号链接。`BUILD-INFO.json` 记录依赖版本、来源和哈希。该过程可在 Windows 上组装已编译的 Linux 库，实际 Linux 启动仍需通过 Linux 检查。

两个启动包都附带 `.sha256` 校验文件，可在下载目录执行 `sha256sum -c MinecraftWorldBrowser-v3.3.2-linux-x86_64.tar.gz.sha256` 检查完整性。包结构检查使用 `python3 linux/tools/verify_package.py`。

单文件 `.run` 安装器也附带 SHA-256 校验文件，嵌入的启动包在解压前再次验证。安装功能检查涵盖桌面与菜单入口、特殊字符路径、中文桌面目录、缺失依赖、重复安装和失败回滚。Linux 工作流额外实际运行安装器并检查安装后的运行库与桌面文件。

也可在 Linux 上运行 `sh build-linux.sh`，用 PyInstaller 生成独立可执行文件目录包。此方式需要在目标操作系统上构建。

检查分为跨平台功能自检、Qt 界面检查和 Linux 原生检查。Linux 文件锁、符号链接、运行库及安装器由 Ubuntu 22.04/24.04 工作流验证；Kali 桌面仍需实机确认。

第三方运行库和字体许可见 `THIRD_PARTY_NOTICES.md`，字体许可证位于 `assets/NotoSansSC-OFL.txt`。
