# Jerry’s Challenge

可爱像素风的双人合作横版解谜游戏。

- 游戏工程标识：`jerrys-challenge`
- 技术选型：Godot 4.x 稳定版、GDScript、Compatibility 渲染器。
- [游戏设计文档](../../docs/games/jerrys-challenge/游戏概述.md)
- [第一关设计](../../docs/games/jerrys-challenge/第一关设计-一起去野餐.md)

当前版本：**0.4.3 可玩 demo**，Godot **4.7.2 stable**。

新增两个独立冒险，标题页选择后仍可选六种角色：

- **数字天平桥**：5、10、20 以内三档。天平一端放目标数，两侧共六张随机数字牌和加减号，保证有解。像拿苹果一样拿牌，放入三个凹槽拼成等于目标的算式，自动平衡开桥；两人一起走到最右侧刷新下一题。空手互动可拿回槽中的牌，持牌离开凹槽再互动可放回地面。不用点确认或拉杆。
- **数字天平桥**：5、10、20 以内三档。天平一端放目标数，两侧共六张随机数字牌和加减号，保证有解。像拿苹果一样拿牌，放入三个凹槽拼成等于目标的算式，自动平衡开桥；两人一起走到最右侧刷新下一题。空手互动可拿回槽中的牌，持牌离开凹槽再互动可放回地面。不用点确认或拉杆。

全程无订单倒计时、效率评分或顾客离场。小店当前只有固定配方，随机的是后续顾客外观；付款找零使用 1 元金币。钱包累计可能超过 10 元，单笔购买、支付和找零练习都在十以内。材料商要求付正好，材料商找零、多配方和限时挑战尚未实现。

新冒险在互动后保存准确状态，包括零钱盘、手持物与库存；暂停可保存回标题继续。小店重试会明确重置整次经营；天平桥重试保留本题，将所有牌放回原位。野餐仍使用独立的原有检查点存档。

已实现标题页、双人六角色选人、脚印教学、收集三个苹果、桥梁接力、各自点灯和野餐结尾。新增供家庭试玩的 Tom 小猫和 Jerry 小老鼠，默认分别预选这两个外观。支持暂停、提示、静音、当前小关重试、伙伴集合及按小关存档继续。主线无死亡与倒计时。

## 运行

优先双击仓库根目录 `builds/jerrys-challenge/0.4.3/JerrysChallenge.exe`，或运行根目录 `启动游戏.ps1`。发布包与引擎工具保留本地，不提交 Git。

开发时，用 Godot 4.7.2 导入本目录 `project.godot` 后按 F6/F5 运行，或使用根目录 `启动游戏.ps1`。无需安装 .NET。

| 玩家 | 移动 | 跳跃 | 拾取 / 放下 / 使用机关 |
| --- | --- | --- | --- |
| Tom P1 | A / D | W | E |
| Jerry P2 | ← / → | ↑ | ↓ |

选人页：左右切换，互动键准备；双方准备后，再按任一互动键出发。也可用鼠标操作选人按钮。允许两人选择同一个外观，用 P1/P2、名字和不同标记区分。

Esc 暂停，F1 显示/隐藏提示。水果门和野餐灯的双拉杆需要两人同时按住 E 与 ↓，保持 1.8 秒，直到总开关锁定。任一人提前松手、离开拉杆或跳起，拉杆就会回弹，总开关进度清零。花朵桥仍采用按一次的接力规则。退出后“继续上次的冒险”会从当前小关起点恢复，不保留关内临时状态。

## 验证与构建

```powershell
# 在仓库根目录执行
& .tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path games/jerrys-challenge --script tests/smoke.gd
& .tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path games/jerrys-challenge --script tests/learning_smoke.gd
& .tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path games/jerrys-challenge --script tests/shop_journey.gd
& .tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path games/jerrys-challenge --script tests/balance_smoke.gd
& .tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path games/jerrys-challenge --export-release 'Windows Desktop'
```

导出依赖 `.tools/godot/templates/windows_release_x86_64.exe`，与编辑器保持同版。其他开发者可以改为本机对应模板路径。

## 当前边界

- 已加入 Tom 与 Jerry 的家庭试玩同人外观。家庭成员定制外观、女孩角色、可编辑键位及截图按钮尚未实现。
- 背景以现有角色和地形为风格基准，按 3 倍像素网格绘制简洁天空、云、树木和远景；UI 使用像素木框、铜边按钮和像素字体。角色、地形和水果来自 CC0 Pixel Adventure 1。0.2.0 的高细节生成插画已停用，并排除出新版导出包。
- 自动检查能验证逻辑和模拟双人输入，实际键盘是否存在同时按键冲突仍需你们在本机体验。
- 字体使用系统字体回退；Windows 优先 Microsoft YaHei，不分发微软字体文件。

素材来源和引擎许可保存在 [licenses](licenses/)。
