# Task Plan: SPARTA schu 有限速率框架搭建

## Goal
搭建 Molchanova 有限速率壁面催化模型的基础框架：新增 `react_gs_finite_rate()` 函数 + `schu` 关键词开关，概率公式暂不修改。

## Phases

### Phase 1: 头文件修改 (surf_react_adsorb.h)
**Status:** complete
**Steps:**
- [x] L48: 在 `int gsflag,psflag;` 后添加 `int schu_flag;`
- [x] L33: 在 `int react(...)` 声明后添加 `int react_gs_finite_rate(...)` 声明

### Phase 2: 构造函数添加 schu 关键词解析 (surf_react_adsorb.cpp)
**Status:** complete
**Steps:**
- [x] `iarg += 5` 之后插入 schu 关键词解析代码块（修正了位置逻辑 bug）
- [x] 包含 `schu_flag = 0;` 默认初始化

### Phase 3: react() 顶部添加派发逻辑 (surf_react_adsorb.cpp)
**Status:** complete
**Steps:**
- [x] 在 `if (!gsflag) return 0;` 之前添加 `if (schu_flag && gsflag) return react_gs_finite_rate(...);`

### Phase 4: 创建 react_gs_finite_rate() 函数 (surf_react_adsorb.cpp)
**Status:** complete
**Steps:**
- [x] 在 react() 闭合花括号后插入新函数（1157 行）
- [x] 复制 react() 全部代码，改名，去掉派发行

### Phase 5: 编译验证
**Status:** complete
**Steps:**
- [x] g++ -std=c++11 -I. -ISTUBS 编译通过，无错误

## Next Phase: 修改有限速率概率公式
修改 `react_gs_finite_rate()` 中的概率计算：
- D/E/R: 不变
- AA/DA/ER: P = min(1, 2K(Tw)·Γ/Vn)，单因子 Γ
- LH1/LH3/CD: P = min(1, 2K(Tw)·Γ/Vn)，∏Γ_j
- CI: 保留 SPARTA 原逻辑

## Decisions (已确认)
- D/E/R 保持 P = k_react 常数概率
- AA/DA/LH1/LH3/CD/ER 使用统一公式 P = min(1, 2K·Γ/Vn)
- CI 保留 SPARTA 原逻辑（含 energy 选项）
- FN/Se 不额外乘 W_s
- schu 默认 no（向后兼容）

## Files Modified
- [surf_react_adsorb.h](src/surf_react_adsorb.h) — L34, L49: 新增 schu_flag 和 react_gs_finite_rate 声明
- [surf_react_adsorb.cpp](src/surf_react_adsorb.cpp) — 构造函数 schu 解析、react() 派发、react_gs_finite_rate() 函数（L1157-1677）

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| schu 解析位置错误：在 iarg+=5 之前检测 | 1 | 将 schu 检测移至 iarg+=5 之后，确保检查正确位置 |
| mingw32-make 无 mpic++ | 2 | 改用 g++ -ISTUBS 直接编译验证语法 |
