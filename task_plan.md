# Task Plan: 常复合系数 gamma 计算与 SPARTA 接入设计

## Goal
基于当前 SPARTA 分支，确定常复合系数 gamma 的定义、计算输入输出、代码落点、验证方法，并形成可实施方案。

## Phases
- [complete] 1. 盘点现有表面反应、schu、输入文件与测试结构
- [complete] 2. 明确 Zuppardi/DS2V 中 gamma 与事件概率的关系
- [pending] 3. 设计独立计算模块及 SPARTA 输入接口
- [pending] 4. 设计验证算例、守恒检查与实施顺序
- [pending] 5. 经用户批准后，为 adsorb GS 反应文件增加必填的逐反应化学能（J/真实反应，吸热为正），并接入 `compute surf echem/etot`

## Scope
本轮以架构分析和实施建议为主，不修改求解器行为。

## Errors
- 无
## Adsorb reaction-energy implementation (2026-07-22)
- [completed] Parse a mandatory GS reaction energy after kinetic coefficients.
- [completed] Use positive-exothermic/negative-endothermic convention in `compute surf echem/etot`.
- [completed] Compile the modified translation units and validate representative input syntax.
- [blocked] Full MinGW serial link: existing `memory.cpp` requires POSIX allocation APIs unavailable in this toolchain.

## Compute boundary adsorb reaction heat (2026-07-22)
- [completed] 1. Add an `echem` value to `compute boundary`.
- [completed] 2. Resolve the face reaction model and read the current GS reaction energy.
- [completed] 3. Add reaction heat to `echem` and `etot` with positive-exothermic convention.
- [completed] 4. Verify zero/no-reaction behavior and output-column indexing.
- [completed] 5. Run positive, negative, and zero reaction-energy face tests.
- [completed] 6. Rebuild and validate Linux MPI `spa_mpi` under Ubuntu 20.04.

### Scope
- Only boundary heat tallies for already-read GS reaction energy.
- No changes to reaction probability, coverage evolution, product energy allocation, or PS chemistry.

### Errors
- Two-rank test with a one-cell grid: `Run command before grid ghost cells are defined`; corrected the test to use two grid cells.
- Two cells with the default partition still produced no usable ghost layout; added RCB balancing for a clumped two-rank partition.
