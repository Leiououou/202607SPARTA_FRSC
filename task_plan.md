# Task Plan: 修改 react_gs_finite_rate() 概率公式

## Goal
将 `react_gs_finite_rate()` 中 GS 反应的概率公式替换为 Molchanova 统一公式，对齐 LaTeX 文档。

## 核心原则
1. **只改概率计算，不动反应执行部分**（后处理、粒子命运、surface delta 等保持不变）
2. **遵循 SPARTA 原有的 Γ 因子编码惯例**：site 位点用 `(maxstick - total_state) * ms_inv`，吸附物种用原循环
3. **GS 反应第一反应物（j=0）永远是气相粒子**，表面反应物从 j=1 开始
4. **体相 (b) 物种跳过**，Γ_j = 1
5. **D/E/R 保持常数概率**，CI 保持 SPARTA 原逻辑

---

## Phases

### Phase 1: 添加 Vn 计算 + 数值保护
**Status:** pending
**Files:** `src/surf_react_adsorb.cpp` — `react_gs_finite_rate()`

在 L1200 `double ms_inv = ...` 之后、循环之前，新增：
```cpp
double Vn = fabs(MathExtra::dot3(ip->v, norm));
```

**说明**：
- Vn 用于所有有限速率类型的概率公式
- 后续在 switch 中各类型如需使用，直接引用外层的 Vn
- 数值兜底：Vn < 1e-10 时 P = 1（bypass 统一公式）

---

### Phase 2: 重写 switch 中各类型的 prob_value[i] 计算
**Status:** pending
**Files:** `src/surf_react_adsorb.cpp` — `react_gs_finite_rate()` 中 switch 语句 (L1218-1400)

当前 switch 中的各类型概率计算将被替换。详述如下：

#### Phase 2a: D / E / R — 保持不变
```cpp
case DISSOCIATION:
case EXCHANGE:
case RECOMBINATION:
    prob_value[i] = r->k_react;  // 常数概率，不动
    break;
```

#### Phase 2b: AA — 新公式
**当前代码** (L1240-1264)：`k_react * S_theta`（粘附概率 × 覆盖率函数）

**替换为**：
```cpp
case AA:
{
    if (Vn < 1e-10)
        prob_value[i] = 1.0;
    else {
        // Γ = N_S * FN/Se — 空闲位点数密度
        double Gamma = (maxstick - total_state[isurf]) * ms_inv;
        prob_value[i] = 2.0 * r->k_react / Vn * Gamma;
        prob_value[i] = MIN(1.0, prob_value[i]);
    }
    break;
}
```

**说明**：
- `(maxstick - total_state) * ms_inv` 沿用 ER 原实现中的位点因子编码
- 删除 Kisliuk 逻辑（AA 不再使用 `kisliuk_flag`）
- `r->k_react` 已经是 Arrhenius 形式的 `K(Tw) = A × Tw^b × exp(-Ea_T / Tw)`

#### Phase 2c: DA — 新公式
**当前代码** (L1266-1295)：`k_react * S_theta`

**替换为**：
```cpp
case DA:
{
    if (Vn < 1e-10)
        prob_value[i] = 1.0;
    else {
        // Γ = (N_S * FN/Se)^2 — 空闲位点数密度的平方
        double Gamma = (maxstick - total_state[isurf]) * ms_inv;
        prob_value[i] = 2.0 * r->k_react / Vn * Gamma * Gamma;
        prob_value[i] = MIN(1.0, prob_value[i]);
    }
    break;
}
```

**说明**：删除 Kisliuk 和被注释的第二个吸附系数代码块。

#### Phase 2d: LH1 — 新公式
**当前代码** (L1297-1315)：`k_react * S_theta`

**替换为**：
```cpp
case LH1:
{
    if (Vn < 1e-10)
        prob_value[i] = 1.0;
    else
        prob_value[i] = 2.0 * r->k_react / Vn;
    // 表面共反应物因子 ∏Γ_j 由下方 j>=1 循环补乘
    // min(1, ...) 在循环之后统一截断
    break;
}
```

**说明**：
- 只设置 `2K/Vn` 基础部分
- `Γ = ∏Γ_j` 由 L1402-1416 的 `for (int j = 1; ...)` 循环乘上
- min 截断在此 Phase 最后统一处理

#### Phase 2e: LH3 — 新公式
同上（与 LH1 完全相同）：
```cpp
case LH3:
{
    if (Vn < 1e-10)
        prob_value[i] = 1.0;
    else
        prob_value[i] = 2.0 * r->k_react / Vn;
    break;
}
```

#### Phase 2f: CD — 新公式
同上：
```cpp
case CD:
{
    if (Vn < 1e-10)
        prob_value[i] = 1.0;
    else
        prob_value[i] = 2.0 * r->k_react / Vn;
    break;
}
```

#### Phase 2g: ER — 新公式
**当前代码** (L1357-1370)：硬编码 `dot = 2.0`

**替换为**（使用真实 Vn）：
```cpp
case ER:
{
    // ER = 气相粒子撞击吸附态(s)，永远 2 个反应物，如 CO(g)+O(s)→CO2(g)+(s)
    // Γ = N_AS * FN/Se 由下方循环补乘，ER 自己的 case 只设基础值
    if (Vn < 1e-10)
        prob_value[i] = 1.0;
    else
        prob_value[i] = 2.0 * r->k_react / Vn;
    break;
}
```

#### Phase 2h: CI — 保持 SPARTA 原逻辑（不动）
```cpp
case CI:
{
    prob_value[i] = r->k_react;
    if (r->energy_flag) {
        double *v = ip->v;
        double dot = MathExtra::dot3(v, norm);
        double vmag_sq = MathExtra::lensq3(v);
        double E_i = 0.5 * species[ip->ispecies].mass * vmag_sq;
        double cos_theta = abs(dot) / sqrt(vmag_sq);
        prob_value[i] *= pow(E_i, r->energy_coeff[0]) *
                        pow(cos_theta, r->energy_coeff[1]);
    }
    break;
}
```

---

### Phase 3: 修改表面反应物 Γ_j 循环
**Status:** pending
**Files:** `src/surf_react_adsorb.cpp` L1402-1416

**当前代码**只检查 `state[0] == 's'`，**需要增加**：
- 体相 `(b)` 跳过（`continue`），Γ_j = 1
- 其余逻辑不变

**新代码**：
```cpp
for (int j = 1; j < r->nreactant; j++) {
    // 体相物种不参与 Γ 计算，数密度 = 1（常数）
    if (r->state_reactants[j][0] == 'b') continue;

    if (r->state_reactants[j][0] == 's') {
        if (r->part_reactants[j] == 0) {
            prob_value[i] *=
                stoich_pow(total_state[isurf],
                           r->stoich_reactants[j]) *
                pow(ms_inv, r->stoich_reactants[j]);
        } else {
            prob_value[i] *=
                stoich_pow(species_state[isurf][r->reactants_ad_index[j]],
                           r->stoich_reactants[j]) *
                pow(ms_inv, r->stoich_reactants[j]);
        }
    }
}
```

---

### Phase 4: 统一 min(1, ...) 截断
**Status:** pending
**Files:** `src/surf_react_adsorb.cpp` — 在 L1402 循环之后、L1418 `sum_prob += ...` 之前

对 LH1/LH3/CD/CI/ER(nreactant>1) 类型的 prob_value[i] 做截断：
```cpp
// 有限速率统一公式：P = min(1, 2K·Γ/Vn)
// AA/DA/ER(nreactant==1) 已在各自的 case 中 min 过了
if (r->type == LH1 || r->type == LH3 || r->type == CD ||
    r->type == CI ||
    (r->type == ER && r->nreactant > 1)) {
    prob_value[i] = MIN(1.0, prob_value[i]);
}
```

**说明**：也可以用 flag 方式，但当类型少时显式列出更清晰。或者用 switch 排除 D/E/R/AA/DA：
```cpp
// 有限速率类型（除 AA/DA 已在内部截断外）统一截断
if (r->type != DISSOCIATION && r->type != EXCHANGE &&
    r->type != RECOMBINATION && r->type != AA && r->type != DA) {
    prob_value[i] = MIN(1.0, prob_value[i]);
}
```

**更简洁方案**（推荐）：给 AA/DA/ER(nr==1) 在 case 内 min；给其他有限速率类型（LH1/LH3/CD/CI）在循环后统一 min。

---

### Phase 5: 编译验证
**Status:** pending
- WSL Ubuntu: `cd src && make mpi -j16`
- 确保无编译错误和警告

---

### Phase 6: 更新 LaTeX 文档（如需）
**Status:** pending
- 如有细微调整，同步更新 `schu_2018/gs_probabilities.tex` 并重新编译 PDF

---

## 各类型概率公式对比总表

| 类型 | 原公式 | 新公式 | Γ 因子 |
|------|--------|--------|--------|
| D | k_react | k_react（不变） | — |
| E | k_react | k_react（不变） | — |
| R | k_react | k_react（不变） | — |
| AA | k_react × S_θ | min(1, 2K/Vn × Γ) | (maxstick-N_tot)×ms_inv |
| DA | k_react × S_θ | min(1, 2K/Vn × Γ²) | (maxstick-N_tot)×ms_inv |
| LH1 | k_react × S_θ | min(1, 2K/Vn × ∏Γ_j) | 原循环 |
| LH3 | k_react × S_θ | min(1, 2K/Vn × ∏Γ_j) | 原循环 |
| CD | k_react × S_θ | min(1, 2K/Vn × ∏Γ_j) | 原循环 |
| ER | 2×k_r/dot=2 | min(1, 2K/Vn × ∏Γ_j) | 原循环（j=1: 吸附态(s)） |
| CI | k_react (× energy) | k_react (× energy)（不变） | 原循环 |

---

## 不影响的部分
- 概率归一化 `correction` 逻辑（L1429-1430）
- 蒙特卡洛抽选流程（L1437-1451）
- 反应执行：species_delta 更新、粒子命运处理（L1460-1677）
- PS 反应 `react()` 原函数
- `SurfReactAdsorb` 其他成员函数
