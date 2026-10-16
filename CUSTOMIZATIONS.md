# Mouser 定制功能与维护

这是 [TomBadash/Mouser](https://github.com/TomBadash/Mouser) 的社区 fork，保留上游 MIT 许可证和版权声明，不代表 Logitech 官方产品。

## 分支与版本

- `main`：保留上游主分支代码，不加入本 fork 的功能改动；上游对应分支名为 `master`。
- `custom`：基于上游 `v3.7.3`，维护定制功能。本地版本标识为 `3.7.3+ctrlclick.3`。
- 不因创建 fork 自动发布二进制 Release。后续发布应使用带有定制标识的版本，明确对应的上游版本。

仓库中的源码修改不会自动替换已安装的程序。上游更新也不会自动合并到 `custom`。

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

## 配置

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

Windows 使用 Python 3.12。`requirements-ctrlclick.txt` 将 Qt 固定到已验证的 PySide6 6.11.1，其余依赖沿用上游要求。

```powershell
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements-ctrlclick.txt
.venv\Scripts\python.exe -m unittest tests.test_ctrl_left_click tests.test_ctrl_click_profiles tests.test_mouse_mapping_haptics tests.test_engine tests.test_key_simulator tests.test_spec_coverage
.venv\Scripts\python.exe -m PyInstaller Mouser.spec --noconfirm
```

输出为 `dist/Mouser/`，运行时必须保留整个目录，不能只复制 EXE。GitHub Actions 中的 **Custom Windows** 流程会在 `custom` 分支上传或手动触发时执行相关检查并生成便携包 Artifact；Artifact 不等于正式 Release。

已在 MX Master 4 蓝牙连接下人工确认 Ctrl＋左键跳转及前进、后退键震动。其余型号、编辑器和权限环境需要分别验证，不能从单一设备的结果推断全部兼容。自动检查使用模拟输入和模拟设备，不会主动点击真实桌面。

## 同步上游

```bash
git remote add upstream https://github.com/TomBadash/Mouser.git
git fetch upstream --tags
git switch main
git merge --ff-only upstream/master
git push origin main
git switch custom
git merge main
```

合并后重新运行测试、打包并进行实体鼠标验证，再发布新的定制版本。优先将通用修复整理为独立提交，便于以后向上游提出 PR。
