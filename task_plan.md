# Task Plan: Γ ms_inv Bug 修复 — ✅ 已完成

## Goal
修复 `react_gs_finite_rate()` 中 Γ（表面物种数密度）被错误计算为覆盖度的 bug：
`ms_inv = factor / max_cover` → 改为 `ms_inv = factor`（不除 N_site）

## 背景
- **文件**: `src/surf_react_adsorb.cpp`
- **函数**: `SurfReactAdsorb::react_gs_finite_rate()`
- **bug 行**: L1324 `double ms_inv = factor / max_cover;`
- **根因**: `max_cover` 即 N_site（表面位点密度），多除使数密度变成覆盖度

## 完成状态：全部 6 个 Phase 均已完成

| Phase | 内容 | 状态 |
|-------|------|:--:|
| 1 | 代码修复 — ms_inv = factor | ✅ |
| 2 | 全面搜索验证 — 所有引用正确 | ✅ |
| 3 | WSL 编译 — 零错误零警告 | ✅ |
| 4 | 运行验证 — 结果一致（clamping 效应） | ✅ |
| 5 | 变更日志 + 记忆文件更新 | ✅ |
| 6 | surf 文件参数调整指导 | ✅ |

## 修改内容

**单行修改** (`src/surf_react_adsorb.cpp:1324`):
```cpp
// 修复前: double ms_inv = factor / max_cover;
// 修复后: double ms_inv = factor;  // FIXED
```

## 验证结果

| 项目 | 修复前 | 修复后 |
|------|--------|--------|
| ms_inv | factor / N_site | factor |
| Γ (AA) | θ_empty（覆盖度） | N_S·FN/Se（m⁻²）✓ |
| 编译 | — | 零错误零警告 ✓ |
| 运行 (beam test) | 41008 reactions | 41008 reactions (一致，因clamping) ✓ |

## surf 文件参数注意事项

修复后 k_react 有效量纲从 m/s 恢复为 m³/s：
- 方案 A: A_new = A_old / N_site（补偿效应）
- 方案 B: 从论文 K 值反算（推荐）

---

## 后续任务
- PS 反应中 L3449 ms_inv 的评估（是否也需要修复）
- surf 文件参数重新拟合
