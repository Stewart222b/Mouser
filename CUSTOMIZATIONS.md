# Mouser 功能与维护

本项目独立维护 MX Master 4 的使用体验，当前实机验证范围为 Windows 蓝牙连接。项目定位与来源说明见 [README.md](README.md)，原有 MIT 许可证保持不变。

## 分支与版本

- `main`：日常开发、修复和体验改进的主分支。
- 历史起点：一次完整的 `v3.7.3` 源码导入，之后仅保留本项目的改进提交；不在公开分支中保留原项目开发历史。
- 独立维护版本从 `3.7.4` 开始，包含之前 `3.7.3+ctrlclick.1` 至 `.5` 的改动。后续按本项目节奏递增，不与原项目版本建立对应关系。

程序的 Release、更新清单和下载入口统一使用 `Stewart222b/Mouser`。更新清单身份为 `io.github.stewart222b.mouser`；保留现有配置路径以便升级。部分其他平台的历史系统标识仍保留，以免破坏已有启动集成。

源码提交和 Actions Artifact 不等于正式 Release。只有显式创建发布版本时，才运行正式发布流程。

## 定制功能

### Windows Ctrl＋左键点击

动作列表的 Mouse 分类新增 **Ctrl + Left Click / Ctrl + 左键点击**，内部动作 ID 为 `ctrl_left_click`。

绑定到 MX Master 4 的 Actions Ring 实体键后，把鼠标移到代码符号上，短按并松开实体键即可在鼠标当前位置执行一次 Ctrl＋左键点击。它沿用 Sense Panel 的单击事件，长按不会重复执行。是否跳转定义由编辑器和语言服务决定；聊天文本、终端或普通文本不保证具有跳转行为。

该动作不移动鼠标，不要求先移动编辑光标。用户已经按住 Ctrl 时不会替用户释放它；左键正在按住时跳过动作，以免打断拖拽。发送失败时记录错误并尽力释放本次模拟按下的键。

这项扩展只在 Windows 提供。它可以绑定到其他支持映射的鼠标按键，不限定于 Master 4。Windows 输入注入仍受进程权限约束。

### 按键震动修复

鼠标按键映射此前通过专用的按下／松开路径处理，遗漏了按键震动设置。现在启用按键震动后，前进、后退、中键等鼠标点击映射会在按下时触发一次震动，松开时只释放按键。关闭震动、暂停映射和全局震动开关仍然有效。

修改按键震动开关会刷新事件监听，使原本透传的按键无需重启即可应用设置。设备必须支持震动；这不会为没有震动马达的鼠标增加硬件能力。

`3.7.3+ctrlclick.3` 将普通按键按下时的震动改为立即发送，包括保留原生点击功能的中键。此前这条路径需要等待 HID 监听线程完成最长约 1 秒的读取；现在不再等待该队列，原生点击和松开行为保持不变。手势识别的完成反馈仍在手势确认后触发。

### 中文界面（3.7.5）

补齐简体／繁体中文的震动设置、按键动作、Actions Ring 选项、DPI 档位、默认配置名称和状态提示。语言切换后，已打开的控件和已选中的按键标题会立即更新；Actions Ring 浮层使用当前语言。

只翻译显示文字，不修改动作 ID、配置 ID、用户自定义名称、文件路径和快捷键组合。产品名称与原始诊断信息保留原样。

语言选择由后端统一保存，修复切换语言后保存其他设置可能写回旧语言的问题。自动检查覆盖 QML 词条、动作与按键名称、语言即时切换及配置持久化。

## 配置

### 设置界面（3.8.0）

导航显示文字，按键页在同一屏中提供鼠标预览和动作编辑。应用配置通过上方列表切换，添加、删除、自定义快捷键、手势和 DPI 档位功能继续可用。设备布局覆盖与诊断信息收进「设备诊断」。

震动页按实体键显示开关，按动作设置震动、按压力度与去重规则放进「高级选项」。按键页和震动页读写同一份反馈设置。外观、语言、启动、截图保存位置和更新选项移至「应用设置」。

视觉组织参考 [Windows 设置页规范](https://learn.microsoft.com/en-us/windows/apps/design/app-settings/guidelines-for-app-settings)，采用相关设置分组、按需展开和即时生效的方式。实现继续使用现有 Qt Quick；不增加界面框架依赖，也不改变已有配置格式或硬件输入处理。

### 界面统一（3.8.1）

指针与滚轮、Actions Ring 和应用设置页采用与按键页一致的设置行、字体、控件和间距。DPI 支持滑杆与精确数值输入；滚轮模式、方向、启动、语言、截图路径和更新操作继续使用原有配置及后端接口。

Actions Ring 使用上、右、下、左的四向预览，与实际浮层的方向顺序和简短动作名称一致；右侧显示完整动作。支持全局及按应用配置、自定义快捷键和按住延迟。简繁中文界面保留 Actions Ring 名称，仅翻译周围的操作说明，不改写用户自定义名称。

鼠标热点使用更大的浅色实心点和深色描边，点击范围扩大至 44 个逻辑像素，选中态使用静态蓝色轮廓。

### 跨屏震动（Windows）

`3.7.3+ctrlclick.4` 在「震动反馈」页增加「跨屏震动」开关。启用后，光标从一块显示器进入另一块时发送一次短震动，沿用当前全局震动强度；在同一块屏幕内移动不触发。它不依赖当前应用或按键映射，Mouser 隐藏到系统通知区后仍会运行。

功能默认关闭，配置键为 `settings.screen_switch_haptic`。关闭此开关、关闭全局震动或断开鼠标会停止跨屏检测；暂停 Mouser 时不触发反馈，恢复后重新建立基准。

`3.7.3+ctrlclick.5` 为跨屏反馈单独使用 `SUBTLE_COLLISION`（波形 `0x04`），替换 `.4` 版复用的按键状态切换波形。每次跨屏仍只提交一条立即发送命令，强度沿用全局设置。波形名称参考 [Solaar 的 HID++ 定义](https://github.com/pwr-Solaar/Solaar/blob/master/lib/logitech_receiver/hidpp20_constants.py)；实际手感需要在设备上确认。

实现使用 Qt 的 `QCursor.pos()` 和 `QGuiApplication.screenAt()`，每 25 ms 采样一次，统一使用 Qt 逻辑坐标处理缩放与负坐标。只对实际观察到的屏幕变化触发反馈，250 ms 内的快速往返最多触发一次，不补发被抑制的震动。首次采样、显示器连接／移除或布局变化只建立基准；落在没有屏幕的坐标区域时重建基准，避免误震。极快跨越后在两次采样之间返回原屏幕的移动可能不会被检测到。

当前仅提供 Windows 开关，需要支持震动的已连接鼠标和至少两块扩展桌面的显示器；镜像显示不构成两个可切换的光标区域。此功能按桌面光标位置判断，不区分此次移动来自哪一个物理输入设备。Qt 接口参考：[screenAt](https://doc.qt.io/qt-6/qguiapplication.html#screenAt)、[高 DPI 坐标](https://doc.qt.io/qt-6/highdpi.html)。不新增依赖，不保存光标轨迹。

### Ctrl＋左键应用配置

新增动作默认不绑定任何应用，也不会修改默认配置、DPI、滚轮方向或其他个人偏好。可以直接在 Mouser 中选择应用配置，再为对应按键选择新动作。

`examples/ide-apps.json` 是可选的通用模板，仅包含程序文件名和显示名称，不是个人配置快照。编辑器内的 coding agent 扩展随宿主编辑器匹配；独立桌面应用需要单独建立配置。应删去没有安装或不希望修改的条目。`ChatGPT.exe` 是部分 Codex 桌面发行版使用的进程名，也可能与其他桌面应用重名，应先核对实际进程。

辅助脚本默认只预览；只有显式传入 `--apply` 才会修改文件，并先生成本地配置备份。运行前完全退出 Mouser，防止两个进程同时保存配置。

```powershell
# 在仓库根目录的 Python 环境中执行；先查看预览。
python scripts/configure_ctrl_click.py --config "$env:APPDATA\Mouser\config.json" --apps examples/ide-apps.json

# 确认后应用，再重新启动 Mouser。
python scripts/configure_ctrl_click.py --config "$env:APPDATA\Mouser\config.json" --apps examples/ide-apps.json --apply
```

脚本从默认配置复制新的应用条目，保留全局设置和配置版本。已有匹配条目时只替换 Actions Ring 映射；如果一个条目关联多个应用，修改会影响该条目关联的应用，应先在界面中拆分配置。

真实配置和备份只留在本机，不提交到仓库。示例模板也不会在程序启动时自动运行。

## 构建与检查

Windows 使用 Python 3.12。`requirements-master4.txt` 将 Qt 固定到已验证的 PySide6 6.11.1，其余依赖使用 `requirements.txt`。旧的 `requirements-ctrlclick.txt` 作为兼容入口保留。

```powershell
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements-master4.txt
.venv\Scripts\python.exe -m unittest tests.test_ctrl_left_click tests.test_ctrl_click_profiles tests.test_mouse_mapping_haptics tests.test_screen_haptics tests.test_engine tests.test_key_simulator tests.test_spec_coverage tests.test_updater tests.test_update_installer tests.test_locale_manager tests.test_localization
.venv\Scripts\python.exe -m PyInstaller Mouser.spec --noconfirm
```

输出为 `dist/Mouser/`，运行时必须保留整个目录，不能只复制 EXE。GitHub Actions 中的 **Master4 Windows** 流程会在 `main` 分支上传或手动触发时执行相关检查并生成便携包 Artifact；Artifact 不等于正式 Release。

已在 Windows 的 MX Master 4 蓝牙连接下人工确认 Cursor 中 Ctrl＋左键跳转、前进／后退键震动、中键按下立即震动，以及跨屏单下轻碰。其余型号、编辑器和权限环境需要分别验证，不能从单一设备的结果推断全部兼容。自动检查使用模拟输入和模拟设备，不会主动点击真实桌面。

## 独立维护与可选的外部修复

不自动合并原项目更新，也不要求定期追齐其版本。优先解决 MX Master 4 的具体体验问题。

脱离 GitHub fork 关系不影响 Git 获取其他公开仓库的提交。将来确有需要时，可临时添加原项目 remote、获取提交，再通过 `git cherry-pick` 引入经过审查的修复；处理依赖和冲突后，重新检查并进行设备验证。此操作按需进行，不作为默认更新流程。

个人配置、运行日志、设备发现快照、凭据和本机构建产物不提交到公开仓库。公开示例只保留通用应用名称和可复现的设置方法。

历史整理只改变提交关系和相应说明，保留完整源码、原许可证与来源致谢。原始开发历史已单独备份，不作为公开分支维护。
