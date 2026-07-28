# Progress Log

## 2026-07-28 constant-`gamma` implementation start
- User approved implementation of an independent `surf_react gamma` style and
  requested a detailed plan followed by execution.
- Scope is frozen: no changes to `surf_react_adsorb.cpp/.h`, no PS chemistry,
  no user-visible `nsync`, and no changes to existing GS/PS heat behavior.
- Internal face/surf coverage state will still be synchronized every timestep
  so MPI ranks observe a consistent committed state.
- Added a detailed eight-phase implementation and validation plan to
  `task_plan.md`; phase 1 is in progress.
- Audited style registration, the `SurfReact` virtual API, grid-change
  notifications, adsorb face/surf state synchronization, and Makefile source
  discovery.  No gamma source files have been created yet.
- Captured pre-task SHA-256 hashes for both adsorb source files so the final
  review can prove this task did not alter them.
- Confirmed both Make and CMake glob new source files, and confirmed the
  existing diffuse wrapper can fully accommodate a reaction product at the
  gamma command's `Tw` while `velreset` prevents a second outer resampling.
- Completed the phase-1 architecture decisions: ID-scoped custom attributes,
  mandatory derived tally allocation, strict two-effective-line parsing, and
  a surface-species set derived from command inputs plus reaction reactants.
- Added the first implementation of `src/surf_react_gamma.h/.cpp` and
  registered `gamma` in `src/style_surf_react.h`.
- The implementation currently includes command parsing, strict unordered
  reaction parsing, ID-scoped face/surf state, every-step MPI synchronization,
  adsorption/recombination execution, full diffuse product accommodation,
  tally-only handling, and `reaction_coeff()` heat exposure.  Compilation and
  runtime verification are next; implementation phases remain provisional
  until those checks pass.
- First standalone compile found one missing concrete RNG header
  (`random_mars.h`); the include was added and the retry is pending.
- The retry reached the assembler with no C++ diagnostics; only the chosen
  `../tmp` output path was rejected.  The next compile will use `src` as the
  object-output directory.
- Standalone compilation in `src` now succeeds.  A second compile with
  `-Wall -Wextra -Wshadow` also succeeds; reported shadow warnings originate
  from the established SPARTA constructor naming pattern and inherited
  headers, with no gamma-specific functional warning.
- The first full Windows build command failed before compilation because
  native `mingw32-make` evaluated a Bash conditional through the Windows
  command shell.  The source remains independently compile-clean; the build
  will be retried under MSYS2 Bash.
- MSYS2 Bash itself works and resolves the Unicode workspace; its login PATH
  omitted `mingw32-make`, so the next attempt will use the explicit executable
  path.
- Explicit make reached `Obj_serial` and generated the new gamma dependency
  target, proving source discovery/style generation work.  Its sub-shell PATH
  lacked `g++`; the next build will export the MinGW binary path for children.
- After fixing PATH, the full build reached compilation and stopped only on
  the non-writable MSYS system temp directory.  The next retry will keep all
  compiler temporaries in the workspace build directory.
- Full Windows serial compilation and linking now succeeded; the new
  `Obj_serial/surf_react_gamma.o` and an updated `src/spa_serial.exe` exist.
  Make's final Unix `size` command looked for `spa_serial` rather than
  MinGW's `spa_serial.exe`, so the make process reported a post-link error
  despite producing the executable.
- Located reusable small face and explicit-surface input patterns and species
  data.  New gamma tests will be added in their own `test/20260728_gamma`
  directory so existing test inputs and outputs stay unchanged.

## 2026-07-27 今日讨论归档
- 归档了常复合系数模型的概率分支和无方向反应物匹配约定。
- 归档了 PS `tau` 的生命周期、MTC 竞争算法、延迟状态更新风险，以及 DS 产物出射流程可供后续常复合模型参考的结论。
- 记录了共享 `schu` 对 GS/PS 的最终语义、数密度基准与覆盖率基准的区别，以及 DS/SB 的边界处理。
- 记录了 `init_cover` 已支持 `ps`/`gs/ps`，以及本次已完成的 PS `tally_only` 行为。
- 完成 `test/20260727_2` 的 LH2 理论复核：理论频率 `1.3498848720e7 s^-1`，理论事件数 `13498.85`；模拟 13419 次，对应 `1.3419e7 s^-1`，偏差约 `-0.59%`，在泊松涨落范围内，验证通过。
- 明确 `3.6132e16` 是真实吸附粒子数而非频率，并记录正确的总时间换算为 `dt*nsteps=0.001 s`。
- 保留后续任务：PS 反应热读取/编号/tally 路径，以及常复合系数功能本体，均暂未实施。

## 2026-07-27 PS `tally_only` extension
- 确认 `init_cover` 已对 `ps` 与 `gs/ps` 生效；真正缺失的是 PS 对
  `tally_only_flag` 的执行控制。
- 已确定语义：PS 事件继续抽样、计数并更新对应 `tau`，但不改变表面状态、不生成
  气相产物，也不调用产物碰撞模型。
- 已在 `PS_react()` 的统计与 `tau` 更新之后加入只统计分支，并让 PS-only 模式显示
  `[TALLY-ONLY]` 启动提示。
- PS-only 串行对照：正常模式 50 次反应、50 次粒子移动/逸出；只统计模式 522 次
  假想反应、0 次粒子移动、0 次逸出。
- `gs/ps` 串行共享开关对照通过；只统计模式 44 次假想反应且无粒子生成。
- WSL MPI 单进程复现 `50/522` 对照；双进程只统计测试得到 522 次反应且无粒子移动。
- Windows serial 与 Linux MPI 均重新编译成功；详细哈希与测试记录写入
  `change_logs/2026-07-27_ps_tally_only.txt`。

## 2026-07-27 PS `schu` extension planning
- 用户确定：`surf_react adsorb` 的现有 `schu yes|no` 同时控制 GS 和 PS；在 `gs/ps` 模式下不得分别设置。
- 制定了 PS 扩展的分阶段计划，覆盖公式、兼容性、DS/LH/SB 边界、模式矩阵、文档、编译和回归测试。
- 已完成 `PS_react()` 修改：`schu yes` 使用数密度因子，`schu no` 保留覆盖率因子；SB 空位覆盖率保持不变。
- 定量测试：二阶同种 LH 在 10 s 内 `no=121`、`yes=12223`，分别符合理论均值 122.5 和 12250。
- 一阶 DS 在相同随机种子下 `yes/no` 均为 23 次；`gs/ps` 共享开关解析和运行通过。
- `surf_react_adsorb.cpp` 增量编译成功，并成功链接、运行 Windows serial `src/spa_serial.exe`。
- 受限上下文最初未枚举出 WSL；切换到系统权限后确认 Ubuntu-20.04 与 `/usr/bin/mpic++` 可用。
- 在 WSL 中执行 `make clean-mpi && make mpi -j4`，成功重新生成 Linux MPI `src/spa_mpi`。
- 新版 `spa_mpi` SHA-256：`6CEB3203A1B0D6C47A987BA8A7822DECADA6AFBC807CE4C3BACA9397F607BB4D`；PS 脱附聚焦测试通过并得到 23 次反应。
- 未修改 PS 反应文件的反应热格式或统计路径。

## 2026-07-22
- 追踪 `schu` 分支、`surf_react adsorb` 反应后处理、产物碰撞模型与 `compute surf` 能量统计。
- 确认当前 adsorb/schu 没有显式反应热输入或释放能分配；`reaction_coeff()` 固定为 0，壁面 `etot` 仅反映粒子平动/内能的净变化。
- 复核 Molchanova 2018 PDF 第 107105-4 和 107105-7 页；确认该文对 LH/ER 复合采用完全化学能适应，将全部复合能计入壁面热流，而产物按壁温漫反射。
- 按用户要求仅审查了 adsorb GS 反应第二行解析、反应数据结构、反应编号和 `compute surf` 能量统计路径；未修改求解器源码，等待用户批准实施计划。

## 2026-07-21
- 启动“常复合系数 gamma 计算与 SPARTA 接入设计”。
- 恢复并阅读历史规划资料；确认已有 schu 有限速率框架、数密度修复和 ER 验证基础。
- 正在检查源码入口、输入语法和现有测试。
- 阅读本地 `aas0505004.pdf`，提取 Zuppardi 2018 年 DS2V 表面催化设置。
- 检索 Zuppardi 其他相关论文、DS2V 用户手册及 2017 年飞行器研究，确认其常概率模型的事件级含义。
- 未修改任何源代码或算例。
- 逐页渲染并视觉核查本地 DS2V Version 3.8 手册的表面反应相关页（25、26、35），确认手册未公开竞争反应的抽样算法。
- 检索竞争性常 gamma DSMC 文献；确认纯常 gamma 多用于物种独立复合，公开且严谨的多通道竞争处理主要出现在有限速率表面化学框架中。
## 2026-07-22 adsorb GS reaction energy implementation
- Added mandatory per-reaction energy after GS kinetic coefficients.
- Sign convention: positive exothermic, negative endothermic; J per real event.
- Connected the value to `compute surf` ECHEM/ETOT through `reaction_coeff()`.
- Fixed ECHEM column advancement for non-reacting surface collisions.
- Updated one representative reaction file and the GS format documentation.
- Targeted modified translation units compile successfully with MinGW g++.
- Full serial build is blocked by pre-existing POSIX-only memory.cpp calls on MinGW.

## 2026-07-22 compute boundary reaction heat
- Confirmed `Domain::surf_react[iface]` identifies the reaction model assigned to each box face.
- Confirmed `Update` passes the per-collision reaction number into `ComputeBoundary::boundary_tally()`.
- Planned new `echem` tally and inclusion of the same term in `etot`; implementation in progress.
- First validation pass used `tally_only yes`; it confirmed candidate-only reactions do not reach boundary heat tallies. Switched the controlled test to executed adsorption reactions.
- Single-rank positive/negative/zero tests passed exactly. Initial two-rank attempt failed because the test had only one grid cell; changed the test grid to two cells before retrying.
- The two-cell retry still lacked a clumped partition; added `balance_grid rcb cell` before the final MPI retry.
- Final single-rank comparison at step 10 (950 reactions): positive `echem=570`, zero `echem=0`, negative `echem=-570`; `etot` shifted by exactly the same amounts.
- Final two-rank run passed with 9,998 executed reactions; step-10 `echem=561` for 935 reactions, matching the analytical normalization.
- Rebuilt Linux ELF `src/spa_mpi`; SHA-256 `61a242340a1b36733ff72a46ce290986c9c8c27c1f44bd246c84fb6597c5f4c1`.
- Added detailed persistent modification log: `change_logs/2026-07-22_adsorb_reaction_heat_compute_surf_boundary.txt`.
## 2026-07-28 gamma runtime validation

- Located deterministic particle-creation syntax and confirmed the `air`
  mixture ID used by the compact O/O2 fixture.
- Chosen per-case outputs:
  - `stats_style` reports `np`, `nsreact`, and `sr_ID[1..4]`.
  - `compute boundary` plus `fix ave/time ... c_ID[*]` records energy terms.
  - particle dumps record the post-impact species/type and sampled energies.
- Preparing isolated one-step inputs so each expected event is unambiguous.
- Rebuilt the serial executable after exposing the full per-reaction stats
  vector; MinGW again linked `spa_serial.exe` successfully and only its
  suffix-blind `size` post-step failed.
- Empty-surface deterministic case passed:
  - one incoming O was removed (`np: 1 -> 0`);
  - no file-defined reaction was counted (`nsreact=0`, all `sr_grxn=0`);
  - `compute boundary` reported `echem=0` and positive `etot=6.625e-20 J`
    for the zlo impact, exactly the incident O translational energy.
- Full-coverage deterministic recombination passed:
  - the gas particle remained and changed from O (`type 1`) to O2 (`type 2`);
  - `np=1`, `nsreact=1`, and aggregate/per-reaction step and cumulative
    counters were all one;
  - its outward velocity was diffusely sampled at `Tw`;
  - boundary `echem` equals the input `h` after SPARTA's face-area/time flux
    normalization, and `etot` equals incident minus emitted particle energy
    plus that chemical term.
- The compact test intentionally has no gas collision model, so SPARTA's
  standard `Particle::erot/evib` samplers return zero even for O2. The gamma
  code does invoke those samplers through `SurfCollideDiffuse`; production
  cases with rotational/vibrational collision styles active receive the same
  internal-energy sampling behavior as an ordinary diffuse wall.
- `tally_only yes` deterministic case passed: the candidate was recorded in
  `sr_grxn` while `nsreact=0`; the particle remained O and underwent the
  ordinary configured diffuse wall collision. Consequently `echem=0`; the
  normal nonreactive particle/wall energy exchange remains visible in `etot`,
  consistent with existing adsorb tally-only behavior.
- Omitted-gamma deterministic case passed: initialized O coverage did not
  react with incoming O, all reaction counters stayed zero, and the particle
  remained in the gas. This confirms the required default `gamma=0`.
- Heteronuclear order-symmetry cases both passed for the single file entry
  `N + O --> NO`: incoming N over O(s) and incoming O over N(s) each counted
  exactly one reaction and emitted the sole gas product NO (`type 3`).
- Statistical `gamma=0.5` fixed-state test passed: 1,557 candidates were
  counted among 3,174 wall impacts, a measured fraction of 0.4905. This is
  consistent with a constant 0.5 Bernoulli gate (about 1.1 standard
  deviations from the expected count).
- Positive, zero, and negative reaction-heat cases passed. With identical
  incident/product random streams, `echem` shifted from `+2.5e-16` through
  zero to `-2.5e-16` in the boundary flux output, while `etot` shifted by the
  same amount around the unchanged particle-energy difference. The factor
  relative to the per-event `h` is SPARTA's expected face-area/timestep tally
  normalization.
- Explicit `surf` mode passed on the 10,000-line cylinder fixture. Starting
  from 1,000 O atoms and full O(s) coverage, 992 reactions produced exactly
  992 O2 molecules while total gas count stayed 1,000; the remaining 8 O had
  not yet impacted by step 100. Per-model cumulative tally was also 992.
  This exercises custom per-surface state, collate/spread, and diffuse product
  emission independently of the `face` arrays.
- Rebuilt `src/spa_mpi` under WSL with the gamma translation unit and real MPI.
- A first two-rank fixed-state face run reproduced the serial totals exactly
  (1,557 candidates / 3,174 impacts), confirming global reaction tally
  reduction. Its one-cell grid was owned by one rank, so a split-grid face
  case is still required for meaningful state-delta traffic.
- Two-rank replicated explicit-surface run passed with particle migration:
  990 O-to-O2 events gave exactly 990 O2 and cumulative reaction count 990.
  A separate `explicit/distributed` fixture is now prepared to exercise owned
  surface attributes and rendezvous/collate behavior.
- Two-rank distributed explicit-surface run passed: each rank owned 5,001
  surface records and held 4,999 ghosts; 991 reactions produced exactly 991
  O2 with matching cumulative tally and no state-bound errors.
- Split-grid two-rank `face` fixed-state run passed with both ranks owning a
  cell and migrating particles. It counted 1,514 candidates among 3,134 wall
  impacts (0.4831), statistically consistent with gamma 0.5. A mutating
  face-state conservation run is prepared next.
- Split-grid two-rank mutating `face` run passed: 3,120 reactions produced
  exactly 3,120 O2 while total gas count remained 10,000, with particles
  distributed and migrating across both ranks. No replicated-state bounds
  error occurred during per-timestep `MPI_Allreduce` synchronization.
- Parser tests passed:
  - blank/full-line/inline comments and two effective lines parsed correctly;
  - reversed duplicate unordered reactants were rejected;
  - a missing heat line was rejected;
  - a formula with more than one product was rejected.
- Existing combined GS/PS adsorb tally-only input completed successfully with
  the rebuilt executable, confirming style registration did not disturb the
  prior command.
- Added user documentation, focused-test documentation, and a dated change
  log covering syntax, state transitions, heat equations, tally-only behavior,
  MPI synchronization, and current CPU/MPI scope.
- Strict warning syntax check completed. Reported warnings are existing SPARTA
  shadow/unused-parameter patterns plus bounded `strlen`-to-int conversions
  for the 1024-byte parser buffers; no functional warning was found.
- Final Windows serial and WSL MPI executables were rebuilt from the finished
  source. The Windows build again linked successfully before only the known
  `.exe`-suffix-blind `size` reporting step failed; the Linux MPI build and
  its `size` step both returned success.
- Final smoke tests passed with logging disabled:
  - serial parser/registration run completed;
  - two-rank mutating face run reproduced 3,120 reactions and exactly 3,120
    O2 products.
- Cleanup removed only generated test logs/data and disposable standalone
  objects. All source fixtures, inputs, documentation, and final executables
  remain.
- Baseline SHA-256 hashes for `surf_react_adsorb.cpp` and `.h` are unchanged:
  `4489C124...25AB7` and `E823E17B...2B8`, respectively.
