# Task Plan: schu 模型信息打印

## Goal
在运行开始前和结束后，向 screen 和 logfile 打印壁面化学反应使用的模型：
- schu_flag=0 → "SPARTA original"
- schu_flag=1 → "Molchanova finite-rate (schu)"

## 设计思路

SPARTA 的消息打印使用 `fprintf(screen, ...)` 和 `fprintf(logfile, ...)`，
screen 和 logfile 都是 `FILE*`，由 Pointers 基类提供。

**关键发现**:
- `SurfReactAdsorb::init()`（L489）：运行开始时调用，适合打印启动信息
- `Finish::end()`（L47）：运行结束时调用，已有 "Surface reaction tallies:" 段（L324-356），
  遍历 `surf->sr[i]` 打印各反应模型的 style 和 tally
- 需要在 SurfReact 基类增加虚方法 `gs_model()`，默认返回 "SPARTA"，
  SurfReactAdsorb 覆写根据 schu_flag 返回对应字符串
- 这样 Finish 不需要知道具体子类，通过多态即可获取模型名

## Phases

### Phase 1: SurfReact 基类添加 gs_model() 虚方法
**Status:** pending
**Files:** surf_react.h, surf_react.cpp
- surf_react.h: 添加 `virtual const char* gs_model();` 声明
- surf_react.cpp: 添加默认实现返回 "SPARTA"

### Phase 2: SurfReactAdsorb 覆写 gs_model()
**Status:** pending
**Files:** surf_react_adsorb.h, surf_react_adsorb.cpp
- .h: 添加 `const char* gs_model();` 声明
- .cpp: 根据 schu_flag 返回 "SPARTA" 或 "Molchanova finite-rate (schu)"

### Phase 3: init() 中添加启动消息
**Status:** pending
**Files:** surf_react_adsorb.cpp
- 在 init() 末尾（init_reactions 之后）打印模型信息

### Phase 4: Finish::end() 中添加结束消息
**Status:** pending
**Files:** finish.cpp
- 在 "Surface reaction tallies:" 段中 sr->style 行后，打印 gs_model()

### Phase 5: 编译验证
**Status:** pending
- WSL Ubuntu: cd src && make mpi -j16
