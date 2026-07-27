# Progress Log

## 2026-07-22
- 追踪 `schu` 分支、`surf_react adsorb` 反应后处理、产物碰撞模型与 `compute surf` 能量统计。
- 确认当前 adsorb/schu 没有显式反应热输入或释放能分配；`reaction_coeff()` 固定为 0，壁面 `etot` 仅反映粒子平动/内能的净变化。
- 复核 Molchanova 2018 PDF 第 107105-4 和 107105-7 页；确认该文对 LH/ER 复合采用完全化学能适应，将全部复合能计入壁面热流，而产物按壁温漫反射。
- 按用户要求仅审查了 adsorb GS 反应第二行解析、反应数据结构、反应编号和 `compute surf` 能量统计路径；未修改求解器源码，等待用户批准实施计划。

## 2026-07-21
- 启动“常复合系数 gamma 计算与 SPARTA 接入设计”。
- 恢复并阅读历史规划资料；确认已有 schu 有限速率框架、数密度修复和 ER 验证基础。
- 正在检查源码入口、输入语法和现有测试。
- 阅读本地 `aas0505004.pdf`，提取 Zuppardi 2018 年 DS2V 表面催化设置。
- 检索 Zuppardi 其他相关论文、DS2V 用户手册及 2017 年飞行器研究，确认其常概率模型的事件级含义。
- 未修改任何源代码或算例。
- 逐页渲染并视觉核查本地 DS2V Version 3.8 手册的表面反应相关页（25、26、35），确认手册未公开竞争反应的抽样算法。
- 检索竞争性常 gamma DSMC 文献；确认纯常 gamma 多用于物种独立复合，公开且严谨的多通道竞争处理主要出现在有限速率表面化学框架中。
## 2026-07-22 adsorb GS reaction energy implementation
- Added mandatory per-reaction energy after GS kinetic coefficients.
- Sign convention: positive exothermic, negative endothermic; J per real event.
- Connected the value to `compute surf` ECHEM/ETOT through `reaction_coeff()`.
- Fixed ECHEM column advancement for non-reacting surface collisions.
- Updated one representative reaction file and the GS format documentation.
- Targeted modified translation units compile successfully with MinGW g++.
- Full serial build is blocked by pre-existing POSIX-only memory.cpp calls on MinGW.

## 2026-07-22 compute boundary reaction heat
- Confirmed `Domain::surf_react[iface]` identifies the reaction model assigned to each box face.
- Confirmed `Update` passes the per-collision reaction number into `ComputeBoundary::boundary_tally()`.
- Planned new `echem` tally and inclusion of the same term in `etot`; implementation in progress.
- First validation pass used `tally_only yes`; it confirmed candidate-only reactions do not reach boundary heat tallies. Switched the controlled test to executed adsorption reactions.
- Single-rank positive/negative/zero tests passed exactly. Initial two-rank attempt failed because the test had only one grid cell; changed the test grid to two cells before retrying.
- The two-cell retry still lacked a clumped partition; added `balance_grid rcb cell` before the final MPI retry.
- Final single-rank comparison at step 10 (950 reactions): positive `echem=570`, zero `echem=0`, negative `echem=-570`; `etot` shifted by exactly the same amounts.
- Final two-rank run passed with 9,998 executed reactions; step-10 `echem=561` for 935 reactions, matching the analytical normalization.
- Rebuilt Linux ELF `src/spa_mpi`; SHA-256 `61a242340a1b36733ff72a46ce290986c9c8c27c1f44bd246c84fb6597c5f4c1`.
- Added detailed persistent modification log: `change_logs/2026-07-22_adsorb_reaction_heat_compute_surf_boundary.txt`.
