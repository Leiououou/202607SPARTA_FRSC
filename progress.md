# Progress Log

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
