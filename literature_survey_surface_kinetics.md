# 壁面化学反应速率参数 — 文献调研

> 整理日期: 2026-07-16
> 目的: 为 SPARTA GS 反应概率验证提供输入参数

---

## 一、现有文献参数汇总

### 1. Warnatz / Deutschmann / Riedel (1995) — RCG (SiO₂) 表面 ⭐

**论文:** "Modeling of Nitrogen and Oxygen Recombination on Partial Catalytic Surfaces"
*J. Heat Transfer*, 117(2), 495–501. DOI: 10.1115/1.2822549

**Molchanova 2018 论文 Table II 已列出完整参数：**

| 反应类型 | 反应式 | 参数 |
|---------|--------|------|
| AA (吸附) | N + S → N(s) | S₀ = 0.1 |
| AA (吸附) | O + S → O(s) | S₀ = 0.1 |
| DS (脱附) | N(s) → N + S | A = 7.3×10¹¹ s⁻¹, Ea = 3.6×10⁻¹⁹ J (≈ 26080 K) |
| DS (脱附) | O(s) → O + S | A = 5×10¹¹ s⁻¹, Ea = 3.3×10⁻¹⁹ J (≈ 23900 K) |
| DS (脱附) | N₂(s) → N₂ + S | A = 1×10¹² s⁻¹, Ea = 0.17×10⁻¹⁹ J (≈ 1231 K) |
| DS (脱附) | O₂(s) → O₂ + S | A = 1×10¹² s⁻¹, Ea = 0.17×10⁻¹⁹ J (≈ 1231 K) |
| ER | N + N(s) → N₂ + S | A = 0.4×10⁻¹⁶ m³/s, Ea = 0.66×10⁻¹⁹ J (≈ 4780 K) |
| ER | O + O(s) → O₂ + S | A = 1×10⁻¹⁶ m³/s, Ea = 1×10⁻¹⁹ J (≈ 7243 K) |
| LH | N(s) + N(s) → N₂(s) + S | A = 1.16×10⁻¹⁰ m²/s, Ea = 2.16×10⁻¹⁹ J (≈ 15650 K) |
| LH | O(s) + O(s) → O₂(s) + S | A = 33×10⁻¹⁰ m²/s, Ea = 2.66×10⁻¹⁹ J (≈ 19268 K) |

**适用范围:** RCG (Reaction Cured Glass, 94% SiO₂), Tw = 300–2000 K
**覆盖的 GS 类型:** AA, ER

---

### 2. Kovalev / Buchachenko / Krupnov (2015) — α-Al₂O₃ & β-cristobalite ⭐

**论文:** 
- *Acta Astronautica* 113, 142–148 (2015). DOI: 10.1016/j.actaastro.2015.04.001
- *Fluid Dynamics* 50(3), 453–462 (2015). DOI: 10.1134/S001546281503014X

**Molchanova 2018 论文 Table III 列出的 α-Al₂O₃ 参数（仅 O）：**

| 反应类型 | 反应式 | A | b | Ea (J) | Ea (K) |
|---------|--------|---|---|--------|--------|
| AA (吸附) | O + S → O(s) | 6.3×10⁻¹¹ m³/s | ? | 6.2×10⁻²¹ | ≈ 449 K |
| DS (脱附) | O(s) → O + S | 4.8×10¹¹ s⁻¹ | 0 | 2.7×10⁻¹⁹ | ≈ 19560 K |
| ER | O + O(s) → O₂ + S | 5.2×10⁻¹⁸ m³/s | 1/2 | 0.69×10⁻¹⁹ | ≈ 4998 K |
| LH | O(s) + O(s) → O₂ + 2S | 2.7×10⁻⁷ m²/s | 0 | 4.0×10⁻¹⁹ | ≈ 28975 K |

**特点:** 量子力学(DFT)第一性原理计算，无需实验拟合
**覆盖的 GS 类型:** AA, ER
**注意:** N 的参数也存在于原文（论文含完整 N+O 参数表），需获取全文

---

### 3. Swaminathan-Gopalan / Borner / Stephani (2025) — SPARTA SurfChem 框架 ⭐⭐⭐

**论文:** "Development of a detailed surface chemistry framework in DSMC"
*Computers & Fluids*, 292, 106525 (2025)

**这是 SPARTA 代码对应的期刊论文！** 包含碳氧化验证案例，覆盖几乎全部 GS 类型。

**碳氧化系统验证参数（从 SPARTA 示例文件提取）：**

| 类型 | 反应式 | A | b | Ea (K) | n_adsorb |
|------|--------|---|---|--------|----------|
| AA | O(g) → O(s) | 1.0 | 0 | 0 | 1 |
| DA | O₂(g) → 2O(s) | 1.0 | 0 | 0 | 2 |
| DA | O₂(g) → O(s) + O(g) | 0.5 | 0 | 0 | 1 |
| DA | CO₂(g) → C(b) + 2O(g) | 0.5 | 0 | 0 | 1 |
| LH1 | O(g) + O(s) → CO₂(g) | 5.363×10⁷ | 0 | 655.65 | 1 |
| LH3 | O(g) → CO(s) | 157.49 | 0 | 6240 | 1 |
| ER | O(g) → CO(g) | 15.749 | 0 | 6240 | — |
| CI | O(g) + O(s) → O(g) + O(g) | 1×10⁸ | 0 | 0 | — |
| CD | C(g) → C(b) | 0.75 | 0 | 0 | 1 |

**PS 反应：**

| 类型 | 反应式 | A | b | Ea (K) |
|------|--------|---|---|--------|
| DS | O(s) → O(g) | 0.050457 | 2 | 3177.17 |
| DS | CO(s) → CO(g) | 1×10³ | 0 | 0 |
| LH2 | 2O(s) + C(b) → CO₂(g) | 1×10¹⁴ | 0 | 0 |
| LH4 | O(s) + C(b) → CO(s) | 1×10² | 0 | 0 |
| SB | C(b) → C(g) | 1×10² | 0 | 0 |

⚠️ **注意:** 这些是 SPARTA 框架验证用的示意参数（A 数量级为 1 的占位值），不是物理实验数据。

---

### 4. Poovathingal / Schwartzentruber et al. (2016–2021) — 碳烧蚀表面化学 ⭐⭐

**关键论文:**
- Poovathingal PhD Thesis (2016): "Predictive Finite Rate Model for Oxygen-Carbon Interactions at High Temperature"
- AIAA 2021-0925: "Air-Carbon Ablation Model for Hypersonic Flight from Molecular Beam Data"

**含 20+ 个基元反应，Arrhenius 参数来自分子束实验拟合。**

| # | 反应 | 速率常数形式 |
|---|------|-------------|
| 1 | O + (s) → O(s) | (P₀/B) × 0.3 |
| 2 | O(s) → O + (s) | TST 公式, Ea ≈ 44277 K |
| 3 | O + O(s) + C(b) → CO + O + (s) | (P₀/B) × 100·exp(−4000/T) |
| 4 | O + O(s) + C(b) → CO₂ + (s) | (P₀/B) × 0.7 |
| 5 | O + (s) → O*(s) | (P₀/B) × 1000·exp(−4000/T) |
| 16 | O₂ + 2(s) → 2O(s) | (F_O₂/B²) × exp(−8000/T) |
| 17 | O₂ + O(s) + C(b) → CO + O₂ + (s) | (F_O₂/B) × 100·exp(−4000/T) |
| 18 | O₂ + O(s) + C(b) → CO₂ + O + (s) | (F_O₂/B) × exp(−500/T) |

**覆盖的 GS 类型:** AA, DA, LH1, LH3, ER（含 C(b) 体相）

---

### 5. NASA TPS 催化数据库 — 复合概率 γ(T)

**来源:** Stewart et al., NASA TP 系列

**RCG 的复合概率 γ (Arrhenius 分段拟合):**

| 物种 | 温度范围 | γ(T) |
|------|---------|------|
| N | Tw < 465 K | γ_N = 5.0×10⁻⁴ |
| N | 465–905 K | γ_N = 2.0×10⁻⁵·exp(1500/Tw) |
| N | 905–1575 K | γ_N = 10·exp(−10360/Tw) |
| N | > 1575 K | γ_N = 6.2×10⁻⁶·exp(12100/Tw) |
| O | Tw < 685 K | γ_O = 2.9×10⁻⁴·exp(264/Tw) |
| O | 685–1324 K | γ_O = 10·exp(−6900/Tw) |
| O | > 1617 K | γ_O = 3.9×10⁻⁸·exp(21410/Tw) |

⚠️ 这些是宏观复合概率 γ，不是基元反应速率常数，不能直接用作 SPARTA 的 K(T) 输入
（需要反推为基元反应参数，或直接用 Molchanova 框架的 Eq. 35 公式）

---

## 二、各 GS 反应类型的文献覆盖情况

| GS 类型 | 文献支持 | 可用数据源 |
|---------|:-------:|-----------|
| **D (Dissociation)** | ⚠️ 很少 | 气体解离通常用 TCE 模型在气相处理，表面解离缺乏独立参数 |
| **E (Exchange)** | ❌ 几乎没有 | 表面交换反应文献极少，可能需从 MD/DFT 获取 |
| **R (Recombination)** | ⚠️ | 常数概率型，NASA γ 数据可参考 |
| **AA (Adsorption)** | ✅✅✅ | Warnatz, Kovalev, Poovathingal 均有 |
| **DA (Dissociative Adsorption)** | ✅✅ | Poovathingal (O₂→2O(s)), SPARTA 示例 |
| **LH1 (Desorption-like)** | ✅ | Poovathingal, SPARTA 碳氧化示例 |
| **LH3** | ✅ | Poovathingal, SPARTA 碳氧化示例 |
| **CD (Condensation)** | ⚠️ | SPARTA 碳氧化示例（C→C(b)），体相沉积参数少 |
| **ER (Eley-Rideal)** | ✅✅✅ | Warnatz, Kovalev, Poovathingal 均有 |
| **CI (Collision-Induced)** | ❌ 很少 | SPARTA 示例有示意值，物理参数极缺 |

---

## 三、推荐的验证策略

### 可完整验证的反应类型（有文献参数）：
1. **AA + ER**: Warnatz RCG 参数 (O + S, N + S, O + O(s), N + N(s))
2. **AA + ER + DA**: Poovathingal 碳氧化参数
3. **LH1 + LH3 + CD**: SPARTA 碳氧化系统（C(b) 参与）

### 需要自行构造或简化的反应类型：
4. **D, E, R**: 常数概率型，可任意设定 P = 0.1~0.5 做自洽性验证
5. **CI**: 极度缺乏实验参数，可参考 SPARTA 示例的示意值做代码正确性验证

### 关键文献获取优先级：
1. ⭐ **Molchanova 2018** (已有 PDF) — Table II & III 直接可用
2. ⭐ **SPARTA 示例文件** (已有) — 覆盖全部 GS 类型，但是示意参数
3. ⭐ **Poovathingal PhD 2016** — 完整碳氧化 20+ 反应参数
4. **Acta Astronautica 113 (2015)** — α-Al₂O₃ 完整参数（需获取全文）
