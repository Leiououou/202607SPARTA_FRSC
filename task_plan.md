# Task Plan: 添加 init_cover 关键词 + tally_only 关键词

## Goal
在 `surf_react adsorb` 命令中新增两个可选关键词：
1. `init_cover <species>` — 初始时刻所有表面位点被指定物种占据
2. `tally_only yes/no` — 仅统计反应次数不实际执行（后续实现）

## 输入文件格式
```
surf_react sr adsorb gs data.gs nsync 10 face 300 1.0 \
  schu yes init_cover O(s) tally_only yes O(s) N(s)
```

关键词顺序：`max_cover` → `schu` → `init_cover` → `tally_only` → 物种列表

---

## Phase 1: 头文件 — 新增成员变量
**Status:** pending
**Files:** `src/surf_react_adsorb.h`

在 `int schu_flag;` 之后新增：
```cpp
int init_cover_flag;        // 0=空表面, 1=初始满覆盖
char *init_cover_name;      // 初始覆盖物种名（暂存，init()中解析索引）
int init_cover_index;       // 初始覆盖物种在 species_surf 中的索引
```

---

## Phase 2: 构造函数 — 解析 init_cover 关键词
**Status:** pending
**Files:** `src/surf_react_adsorb.cpp` 构造函数

在 `schu` 解析之后、`species_surf` 之前：
```cpp
// init_cover = species name for initial full surface coverage
init_cover_flag = 0;
init_cover_name = NULL;
init_cover_index = -1;
if (iarg < narg && strcmp(arg[iarg],"init_cover") == 0) {
  iarg++;
  init_cover_flag = 1;
  int n = strlen(arg[iarg]) + 1;
  init_cover_name = new char[n];
  strcpy(init_cover_name, arg[iarg]);
  iarg++;
}
```

注意：此时 `species_surf` 尚未构建，先暂存名字，在 `init()` 中用 `find_surf_species()` 解析索引。

---

## Phase 3: init() — 设置初始表面覆盖度
**Status:** pending
**Files:** `src/surf_react_adsorb.cpp` `SurfReactAdsorb::init()`

在 `init()` 的 one-time operations 块（`if (!firstflag)` 内）末尾：
```cpp
// initial surface coverage: fill all sites with one species
if (init_cover_flag) {
  init_cover_index = find_surf_species(init_cover_name);
  if (init_cover_index < 0)
    error->all(FLERR,"Init_cover species not in surface species list");

  double fnum = update->fnum;
  if (mode == FACE) {
    for (int iface = 0; iface < nface; iface++) {
      long int maxstick = ceil(max_cover * face_area[iface] /
                               (fnum * face_weight[iface]));
      face_species_state[iface][init_cover_index] = maxstick;
      face_total_state[iface] = maxstick;
    }
  } else if (mode == SURF) {
    int nall = surf->nlocal + surf->nghost;
    for (int isurf = 0; isurf < nall; isurf++) {
      long int maxstick = ceil(max_cover * area[isurf] /
                               (fnum * weight[isurf]));
      species_state[isurf][init_cover_index] = maxstick;
      total_state[isurf] = maxstick;
    }
  }
}
```

---

## Phase 4: 编译验证
**Status:** pending
- WSL Ubuntu: `cd src && make mpi -j16`
- 确保无编译错误和警告

---

## Phase 5: 写变更日志
**Status:** pending
- 写入 `change_logs/2026-07-14_init_cover_keyword.txt`

---

## Phase 6: (后续) tally_only 关键词
**Status:** pending
- 另开任务实现
