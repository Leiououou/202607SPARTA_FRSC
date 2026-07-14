# Progress Log

## Session 2026-07-14 (evening): Γ ms_inv Bug 修复 + K_ER 验证 ✅

### K_ER Eq 52 对照验证 (test/20260715_5)
- DSMC tally: 475,137 ER reactions (O+O(s)→O₂)
- N_hits (解析): 4.79×10⁸, ⟨1/Vn⟩ = 1.738×10⁻³ s/m
- K_DSMC = 4.73×10⁻²⁰ vs K_input = 4.74×10⁻²⁰ → **0.1% 偏差** ✓
- 修复前: K_DSMC/K_input ≈ 14% (7× discrepancy)
- HTML 报告: test/20260715_5/K_ER_validation.html
- 更新 face-mode-er-ker-calculation 记忆文件

## Session 2026-07-14 (evening): Γ ms_inv Bug 修复 ✅

### Phase 1-6: 完整修复
- L1324: `ms_inv = factor / max_cover` → `ms_inv = factor`
- 全面搜索: 确认 react_gs_finite_rate() 内所有 ms_inv 引用自动修正
- 编译: make mpi -j16 零错误零警告
- 运行: beam test 结果一致 (41008 reactions, MIN(1.0) clamping)
- 变更日志: change_logs/2026-07-14_gamma_ms_inv_fix.txt
- 记忆文件: gamma-ms-inv-bug.md 标记为 fixed

### 关键发现
- 原始 react() L799 的 ms_inv 不受影响（独立局部变量，用于覆盖度）
- 当前 surf 文件 k_react=1.0 使新旧代码概率均达截断 → 需调整参数才能观测差异

## Session 2026-07-14 (afternoon): tally_only 关键词

### Phase 1-8: 完整实现
- surf_react_adsorb.h: 添加 `int tally_only_flag;`
- 构造函数: tally_only yes/no 解析
- react() + react_gs_finite_rate(): tally_only 跳过逻辑
- gs_model(): 追加 [TALLY-ONLY] 标注
- init(): 启动警告消息
- 编译通过，零错误零警告
- 运行验证: 无tally_only→11反应, 有tally_only→tally=11/Surf reactions=0 ✓

## Session 2026-07-13: schu 有限速率框架搭建

### Phase 1-4: 基础框架实现
- 头文件 surf_react_adsorb.h: 添加 `int schu_flag;` 和 `react_gs_finite_rate()` 声明
- 构造函数: 添加 schu 关键词解析（在 iarg+=5 之后）
- react(): 顶部添加 schu 派发逻辑
- 新建 react_gs_finite_rate(): 复制 react() 全部代码（L1157-1677），去掉派发行
- 编译验证: g++ -std=c++11 -I. -ISTUBS 通过

### 修复的问题
- schu 解析初始放在 iarg+=5 之前，arg[iarg] 实际指向 nsync 而非 schu；修正为 iarg+=5 之后检测

### 输入文件格式
```
surf_react sr adsorb gs data.gs nsync 10 face 300 1.0 schu yes O(s) N(s)
```
- schu 默认 no（不写即走原 react）
- 写 schu yes 则走 react_gs_finite_rate（当前与原逻辑相同）

## Session 2026-07-09

### Phase 1: Planning Files & Code Analysis
- Created task_plan.md, findings.md, progress.md
- Reading: surf_react_adsorb.h (full), surf_react_adsorb.cpp react() (lines 620-1137)
- In progress: Reading PS_chemistry, PS_react, readfile_gs continuation
