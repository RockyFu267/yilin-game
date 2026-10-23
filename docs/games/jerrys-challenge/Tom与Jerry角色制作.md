# Tom 与 Jerry · 家庭试玩角色

版本：0.3.0，日期：2026-10-23。

应用户要求，为孩子的家庭试玩加入 Tom 小猫与 Jerry 小老鼠。这是角色同人像素版本，不是 Pixel Adventure 素材，也不将原角色设计声明为本项目原创或 CC0。

## 游戏内结果

- 保留原有四个伙伴，新增 Jerry Mouse（索引 4）与 Tom Cat（索引 5），共六个可选外观。
- 默认 P1 预选 Tom 小猫，P2 预选 Jerry 小老鼠；双方可自由换选，也可选择相同角色。
- 两套角色均有待机、跑步、上升跳跃与下落图条，统一为 32×32 帧。
- 人物外观不改变碰撞体、速度、跳跃或机关能力。存档支持恢复两个新外观。

## 文件与制作过程

- 工具：内置 imagegen，参考原有 Ninja Frog 的待机图条匹配像素画风。
- 原始生成表：`games/jerrys-challenge/art-source/tom-jerry-sheet.png`；原文件保留，不放入导出包。
- 游戏资源：`games/jerrys-challenge/assets/characters/Jerry Mouse/` 与 `Tom Cat/`。
- 导入脚本：`games/jerrys-challenge/tests/import_character_sheet.gd`。
- 使用 Godot 原生图像导入流程，按八列四行切片；清理低透明度边缘和相邻格的零碎残留，再用每个角色共用的边界及最近邻缩放整理成 32×32 图条。保证各动作采用相同裁切标准。
- Jerry：待机 4 帧、跑步 8 帧、跳跃 2 帧、下落 2 帧。Tom 同样配置。

### 最终生成提示词

```text
Create a production game SPRITE SHEET, a transparent PNG, width 2048 height 1024, EXACTLY 8 equal columns by 4 equal rows (32 cells, each 256x256). Reference image is STYLE ONLY: a small chunky Pixel Adventure platformer sprite, crisp square pixels, thick dark outlines, simple limited color clusters and cute oversized head. Match that simplicity, NOT detailed painting. Every character must look like a tiny approximately 24x28 logical-pixel sprite enlarged nearest-neighbor, consistent feet baseline and scale. In every cell, subject faces RIGHT in 3/4 side platformer view, entire body and tail contained in cell with ample transparent padding, same center and feet baseline at 82% of cell. No ground, no scenery, no text, no grid lines, no shadows outside sprite. Transparent background. Subjects: Jerry the lovable brown mouse from Tom and Jerry, big round pink-inner ears, tan muzzle and belly, tiny black nose, cheerful face, no clothing; Tom the grey-blue cartoon cat from Tom and Jerry, triangular pink-inner ears, white muzzle/belly/paws, yellow-green eyes, long tail, friendly playful expression, no clothing. Both cute chibi bipedal playable heroes of SAME sprite height suitable for a child-friendly cooperative pixel platformer. Cohesive palette and blackish navy outlines, flat pixel shading with only 2 shades per color. Anatomically clean, exactly two arms and two legs. Layout strict: ROW 1 = JERRY, first 4 cells subtle IDLE breathing cycle, cells 5-6 JUMP ascent pose feet tucked, cells 7-8 FALL descent pose arms open. ROW 2 = JERRY eight consecutive RUN cycle frames with changing leg stride and arm swing, feet baseline consistent. ROW 3 = TOM, first 4 cells subtle IDLE breathing cycle, cells 5-6 JUMP ascent pose feet tucked, cells 7-8 FALL descent pose arms open. ROW 4 = TOM eight consecutive RUN cycle frames with changing leg stride and arm swing. Keep all Jerry frames same character silhouette/head proportions and all Tom frames same character proportions. Strictly equal cell spacing, no overlaps across cells. Do not add more rows or columns, do not omit cells. Pixel art game asset, no smooth vector curves, no high-detail fur or illustration style.
```
