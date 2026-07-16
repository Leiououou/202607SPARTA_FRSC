# Task Plan: 吸附介导反应 n(S) 空位密度修正

## Goal
为 AA、DA、LH1、LH3、CD 五个吸附介导反应统一补上隐式空位 S 的数密度因子 n(S)^n_adsorb，
使用输入文件中已解析但未使用的 coeff[3]（即 surf 行最后一个数字）。

## Current Phase
✅ 全部完成

## 背景
- **文件**: `src/surf_react_adsorb.cpp`
- **函数**: `SurfReactAdsorb::react_gs_finite_rate()`
- **问题**: coeff[3]（n_adsorb）在解析时被正确读入，但在概率计算中完全未使用
  - AA 硬编码了 n(S)¹ → 绕过 coeff[3]=1，恰好正确
  - DA 硬编码了 n(S)² → 绕过 coeff[3]=2，恰好正确
  - LH1/LH3/CD 完全没有 n(S) 因子 → 概率漏乘，偏小
- **方案**: 统一修正块，用 coeff[3] 控制 n(S) 幂次

## Phases

### Phase 1: AA/DA switch-case 简化
- [x] L1351-1362 (AA): 去掉 hardcoded n(S)，去掉 MIN 截断
- [x] L1364-1375 (DA): 同上
- [x] AA 和 DA 改为与 LH1 一致的 `prob_value[i] = 2.0 * r->k_react / Vn;`
- **Status:** complete

### Phase 2: 新增统一 n(S) 修正块
- [x] 在 L1429 的 `for (int j = 1; ...)` 循环之前插入
- [x] 对 AA/DA/LH1/LH3/CD 五种类型乘入 n(S)^coeff[3]
- [x] 使用 `stoich_pow(maxstick - total_state[isurf], n_adsorb) * pow(ms_inv, n_adsorb)`
- **Status:** complete

### Phase 3: MIN 截断条件更新
- [x] L1458-1461: 从排除列表中移除 AA 和 DA
- [x] 改为只排除 D/E/R
- **Status:** complete

### Phase 4: 变更日志 + 记忆文件
- [x] 写 change_logs/20260716_nS_adsorb_fix.txt
- [x] 新建 memory/ns-adsorb-fix.md
- [x] 更新 MEMORY.md 索引
- **Status:** complete

### Phase 5: 编译验证
- [x] WSL 下 `make mpi -j16` — 零错误零警告
- **Status:** complete

## 修改文件清单

| 文件 | 改动行 | 改动内容 |
|------|--------|----------|
| `src/surf_react_adsorb.cpp` | L1351-1359 | AA case 简化 |
| `src/surf_react_adsorb.cpp` | L1361-1369 | DA case 简化 |
| `src/surf_react_adsorb.cpp` | L1429-1437 | 新增 n(S) 统一修正块 |
| `src/surf_react_adsorb.cpp` | L1458-1461 | MIN 条件更新 |

## 一致性验证

| 反应类型 | coeff[3] | 修正后 n(S) 幂次 | 与原逻辑对比 |
|---------|:--------:|:-------------:|:---------:|
| AA | 1 | n(S)¹ | 等价 ✓ |
| DA | 2 | n(S)² | 等价 ✓ |
| LH1 | 1 | n(S)¹ | 补漏 ✓ |
| LH3 | 1 | n(S)¹ | 补漏 ✓ |
| CD | 1 | n(S)¹ | 补漏 ✓ |
| ER | — | 不乘 | 不变 ✓ |

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| 用 stoich_pow(maxstick-total_state) 而非 total_state | 空位 = 总位点 - 占据位点 |
| 放在 for(j=1) 循环之前 | 隐式空位 S 与显式表面共反应物各管各的 |
| 合并 AA/DA 进统一修正 | 消除硬编码，coeff[3] 作为唯一真相源 |
