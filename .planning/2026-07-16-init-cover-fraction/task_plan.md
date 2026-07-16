# Task Plan: init_cover 支持部分覆盖度参数

## Goal
`init_cover` 关键词改为**两个必选参数**：物种名 + 覆盖度 fraction (0~1)。
- `init_cover O 1.0` → 100% 位点被 O 占据
- `init_cover O 0.5` → 50% 位点被 O 占据，其余 50% 空位

## Current Phase
Phase 2: 解析

---

## 背景

### 涉及文件
| 文件 | 作用 |
|------|------|
| `src/surf_react_adsorb.h` | 类声明，新增 `init_cover_fraction` 成员 |
| `src/surf_react_adsorb.cpp` | 构造函数解析 + FACE/SURF 模式执行 |

### 现有解析逻辑 (surf_react_adsorb.cpp:148-160)
```cpp
init_cover O    ← 只读一个参数（物种名），写死 100% 覆盖
```

### 现有执行逻辑
- **FACE** (L592-612): `= maxstick`，全满
- **SURF** (L701-745): local + owned arrays 都 `= maxstick`

### 简化点
用户保证 `init_cover` 后**一定跟两个参数**（物种名 + 数字），无需向后兼容旧格式、无需 isdigit 检测。

---

## Phases

### Phase 1: 头文件 + 构造函数初始化
- [ ] `surf_react_adsorb.h` L54 后新增 `double init_cover_fraction;`
- [ ] `surf_react_adsorb.cpp` L152 初始化 `init_cover_fraction = 1.0;`
- **Status:** pending

### Phase 2: 解析——直接读第二个数字参数
- [ ] L159 `iarg++`（读完物种名）之后，直接 `input->numeric(FLERR, arg[iarg])` 解析 fraction
- [ ] 校验 0 ≤ fraction ≤ 1
- [ ] `iarg++`
- **Status:** pending

### Phase 3: FACE 模式执行 (L598-604)
- [ ] `maxstick` 计算不变
- [ ] `cover_count = (long int) round(maxstick * init_cover_fraction)`
- [ ] `species_state` 和 `total_state` 改为赋 `cover_count`
- [ ] 打印信息：`"Init_cover: %.0f%% sites filled with %s"`
- **Status:** pending

### Phase 4: SURF 模式 — local arrays (L707-712)
- [ ] 同 Phase 3: `maxstick` → `cover_count`
- **Status:** pending

### Phase 5: SURF 模式 — owned arrays (L717-736)
- [ ] distributed / non-distributed 两分支都改
- [ ] 注意 owned 分支重新算 maxstick（area/weight 索引不同）
- **Status:** pending

### Phase 6: 更新现有输入文件
- [ ] 搜索所有 `init_cover` 出现处，改为新格式 `init_cover <species> 1.0`
- **Status:** pending

### Phase 7: 变更日志 + 记忆文件
- [ ] `change_logs/20260716_init_cover_fraction.txt`
- [ ] `memory/init-cover-fraction.md`
- [ ] 更新 `MEMORY.md`
- **Status:** pending

### Phase 8: 编译验证
- [ ] WSL 下 `make mpi -j16`，零错误零警告
- **Status:** pending

---

## 修改文件清单

| 文件 | 区域 | 改动内容 |
|------|------|----------|
| `src/surf_react_adsorb.h` | L54 后 | + `double init_cover_fraction;` |
| `src/surf_react_adsorb.cpp` | L152 | 初始化 `= 1.0` |
| `src/surf_react_adsorb.cpp` | L159-160 | 直接读 fraction，校验 0~1 |
| `src/surf_react_adsorb.cpp` | L598-611 | FACE: maxstick → cover_count |
| `src/surf_react_adsorb.cpp` | L707-712 | SURF local: maxstick → cover_count |
| `src/surf_react_adsorb.cpp` | L722-735 | SURF owned: maxstick → cover_count |
| 现有测试 in 文件 | 各 test 目录 | `init_cover O` → `init_cover O 1.0` |

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| 两个参数都是必选 | 用户确认不会用旧格式，省去 isdigit 检测 |
| `round()` 舍入 | 比 ceil/floor 更公平 |
| `total_state` 赋 cover_count | 空位 = maxstick - total_state 自动正确 |
| owned arrays 同步改 | update_state_surf 从 owned 重建 local，必须一致 |
