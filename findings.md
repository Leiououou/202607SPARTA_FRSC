# Findings: 常复合系数 gamma

## 2026-07-28 已冻结的 `surf_react gamma` 设计
- 命令为 `surf_react ID gamma file surf|face Tw n_site ...`，无用户侧
  `nsync`；未列出的物种 `gamma=0`。
- 可重复使用 `init_cover species fraction`，并支持
  `tally_only yes|no`。
- 文件中每条反应严格为两个有效行：`A + B --> C` 和逐真实事件反应热
  `h`；`A+B` 无方向，产物固定为一个气相粒子。
- 入射 `A` 先通过 `gamma_A` 门控，再按空位/吸附物覆盖率抽样。空位导致
  吸附；命中 `B(s)` 且存在通道则生成一个漫反射气相产物；无通道则散射。
- `tally_only` 固定表面状态，仅统计文件中定义的复合候选，不执行吸附或
  复合，不贡献物理热流。
- 吸附热流只有入射粒子能量项；复合热流为
  `E_incident-E_product+h`，其中 `echem=h`。
- 无 PS 调度并不等于无需并行状态同步：`face` 和分布式 `surf` 的覆盖变化
  仍须在每个时间步结束时汇总。该同步为内部固定行为，不暴露 `nsync`。
- 实现采用独立 `SurfReactGamma` 文件，不修改 adsorb 源文件或头文件。

## 2026-07-28 SPARTA 接口审计（阶段 1）
- `Surf::add_react()` 通过 `style_surf_react.h` 中的
  `SurfReactStyle(key,Class)` 注册风格；新头文件需要加入该聚合头。
- `src/Makefile` 使用 `$(wildcard *.cpp)` 和 `$(wildcard *.h)`，新增源文件会
  自动进入传统 Make 构建；仍需复核 CMake 的源文件收集方式。
- `SurfReact` 已提供所需虚接口：`react()`、`reactionID()`、
  `reaction_coeff()`、`match_reactant/product()`、`tally_update()` 和空实现
  `grid_changed()`，无需修改基类。
- `Grid::notify_changed()` 会对所有 surface reaction model 调用
  `grid_changed()`，新风格可独立处理分布式显式表面的重分配。
- 已记录本任务开始前 adsorb 文件 SHA-256：
  - `surf_react_adsorb.cpp`:
    `4489C124B6125CEF9679F5F8796EA1DEB2C6C8886CEDDB659FE0C6D305025AB7`
  - `surf_react_adsorb.h`:
    `E823E17BC475B5E643B89CEB0696C838916FD653FC46011B3FF9238ED805B2B8`
- 现有 adsorb 的 SURF custom 名称是全局通用的 `nstick_total`、
  `nstick_species`、`area`、`weight`；新风格应改用含 reaction ID 的名称，
  避免多个 gamma/adsorb 实例之间发生所有权和析构冲突。
- `SurfReactAdsorb::tally_update()` 证明即使只有 GS、没有 PS，覆盖状态仍需
  同步；gamma 风格将固定每步调用 face Allreduce 或 surf collate/spread。
- adsorb 的 SURF 同步模板可复用：按发生事件的 surface ID 收集本地
  `species_delta`，`collate_array()` 到 owned surface，再
  `spread_custom()` 回 local+ghost。
- 传统 Make 和 CMake 都通过 glob 收集 `src` 下的新 `.cpp/.h`，因此新增
  gamma 文件不需要手工维护源文件列表；style 注册聚合头仍需显式加入 include。
- `SurfCollideDiffuse::wrapper()` 正好支持外部 reaction style 传入两个系数
  `[Tw, accommodation]`，并同时重采样平动、转动和振动能。gamma 可创建一个
  diffuse 实例并用 `[Tw,1.0]` 完全适应产物，无需复制速度采样公式。
- 外层 `SurfCollideDiffuse::collide()` 仅在 `velreset==0` 时再次漫反射，因此
  gamma 成功复合后必须置 `velreset=1`；吸附删除 `ip` 后无需速度处理。
- 当前 adsorb 的覆盖计数统一采用 `ceil(n_site*area/(fnum*weight))`；其
  area/weight custom 初始化、spread 和 grid-change 流程是 gamma 的直接风格
  参考。
- `SurfReact` 基类析构总会释放四个 tally 指针，但基类构造函数不负责分配，
  因此 gamma 构造函数必须像现有 styles 一样始终创建四个 tally 数组。
- `Surf::remove_custom()` 会压缩同类型 custom 数据数组并修正其余
  `ewhich`；gamma 析构时应按 ID-scoped 名称重新 `find_custom()` 后逐个删除，
  不依赖构造时缓存的索引顺序。
- 现有 `readone()` 只跳过第一有效行之前的空行/注释，随后直接把下一物理行
  当第二行。gamma 文件规范强调“两个有效行”，因此新解析器会对两行分别跳过
  空行和整行注释，同时仍保持 SPARTA 的 `#` 注释和 MPI root-read/broadcast
  风格。
- Surface species 集合将由三类物种的并集构造：显式 gamma 配对物种、
  `init_cover` 物种、所有反应物。这样未参与反应但 gamma 非零的物种仍可吸附，
  反应物即使 gamma 为零也可作为初始化或另一方向的表面伙伴。
- 第一版代码采用二维 species-pair reaction map，并对 `[A][B]` 与 `[B][A]`
  写入同一 reaction index；文件顺序不会参与运行期通道抽样。
- 空位吸附返回 reaction number 0 但把 `ip` 置空，因此标准粒子能量 tally
  仍能看到“有入射、无出射”的能量差，而 reaction tally/echem 不会把隐式吸附
  当成文件反应。
- 复合事件复用 `ip` 记录为唯一气相产物、内部 diffuse 后置
  `velreset=1`，返回文件 reaction index；标准 `compute surf/boundary`
  因而能同时统计粒子前后能量差和 `reaction_coeff()` 给出的 `h`。
- 新 translation unit 已在 MinGW g++ C++11 下独立编译通过；严格 warning
  编译只报告 SPARTA 现有构造函数参数名的 shadow 风格，没有发现 gamma
  数据流、类型转换或未使用变量警告。
- Windows serial full link produced a new `spa_serial.exe`; the Makefile's
  trailing `size` command is the only failed post-step because MinGW appends
  `.exe`.
- Existing focused test assets provide reusable species files and boundary/
  explicit-surface setups under `test/20260722_*` and `test/20260727_*`.
  Gamma tests will be isolated in a new dated directory rather than altering
  those regression cases.

## 2026-07-22: adsorb/schu 反应后能量处理
- `schu yes` 只在 `SurfReactAdsorb::react()` 入口分流到 `react_gs_finite_rate()`，改变 GS 微观概率的计算；反应成功后的物种更新、粒子创建/删除和碰撞模型处理与原 `adsorb` 路径相同。
- `SurfReactAdsorb::reaction_coeff(int)` 在头文件中固定返回 `0.0`，且 GS/PS 反应文件解析没有反应热/化学能输入字段。`energy` 可选项只用于 CI 反应概率的入射能量依赖，不是反应热。
- 显式表面的 `compute surf ... echem` 通过 `reaction_coeff()` 取化学能，因而 adsorb 风格的 `echem` 始终为 0。`etot` 中的化学项也为 0，只剩入射与出射粒子的平动+转动+振动能差。
- 反应产物的能量不由反应焓保守分配：若反应文件指定产物碰撞模型，该模型直接重置产物速度/内能；否则返回外层 `surf_collide` 模型重置。例如 diffuse 按壁温抽样平动速度、转动能和振动能。
- 隐式表面 `compute isurf/grid ... etot` 只统计粒子显式能量差，没有 `echem` 补偿项。

## 2026-07-22: Molchanova et al. (Phys. Fluids 30, 107105, 2018) 反应热处理
- 原文第 107105-4 页明确规定：LH 复合产物若留在表面，复合能 `E_recomb` 全部被表面适应并计入壁面热流；若产物进入气相，本文仍采用完全能量适应，产物所有能量模态按壁温的漫反射分布采样，全部 `E_recomb` 单独计入壁面。
- 原文承认可扩展为不完全适应：一部分复合能进壁面，余下部分加入反射产物，并可用 Larsen-Borgnakke 在平动/转动/振动间分配；但本文未实施该扩展。
- ER 复合使用与 LH 相同的完全适应假设：气相产物按壁温漫反射，复合能全部进入壁面热流。
- 解离吸附所需的断键能计入壁面热流，但作为负的热能通量贡献。
- 因完全适应假设，作者明确说明所得表面加热率是给定有限速率机理的“最大可能值”。

## 已知项目背景
- 当前分支已有 `SurfReactAdsorb::react_gs_finite_rate()` 和 `schu yes` 分派入口。
- 已修复有限速率路径中表面物种数密度换算错误：`ms_inv = factor`。
- 已发现/记录 ER 路径曾存在法向速度被常数覆盖的问题。
- 本轮需判断常 gamma 应复用 adsorb 反应框架，还是新增更轻量的表面反应 style。

## 待确认
- gamma 的目标定义（原子复合概率、原子损失概率或分子生成系数）。
- gamma 是外部模型计算后的定值，还是需要 SPARTA 根据壁温/状态预计算。
- 是否需要能量与动量分配模型，以及产物是返回气相还是仅统计通量。

## Zuppardi / DS2V 常概率壁面催化模型（2026-07-21 文献核查）
- 核心论文：G. Zuppardi, *Effects of chemistry in Mars entry and Earth re-entry*, AAS 5(5), 2018, DOI 10.12989/aas.2018.5.5.581。
- 该文采用 DS2V-4.5 64bits；定义五条表面复合：O+O->O2、N+N->N2、N+O->NO、CO+O->CO2、C+O->CO，并为每个事件给出放热能。
- 论文只计算两个极限：非催化时每条表面反应概率设为 0；完全催化时设为 1。未使用表面覆盖度、吸附态或随时间演化的位点模型。
- Zuppardi 与 Vangone (2017) 的 NACA 0010/襟翼研究同样用 DS2V，将 O+O->O2 和 N+N->N2 的概率均设为 1 来实现完全催化壁。
- DS2V 用户手册说明：表面反应先定义入射物种、反射产物和单事件传给表面的反应能；随后按表面区间输入每条反应概率。概率在一个反应物撞壁时判定；若反应需要第二个反应物，第二个粒子稍后从模拟中移除。
- 因而在该类 DS2V 计算中，常 gamma 本质上是撞壁事件的 Bernoulli 概率/原子消耗比例，而不是由 Arrhenius 速率、覆盖度或壁面微观状态在线求得。
- 对双原子同核复合，事件同时消耗两个原子、生成一个分子；实现时必须处理第二原子的统计删除/配对，否则直接把每个成功撞壁原子都变成一个分子会破坏原子守恒。
- 反应放热作为每个表面反应事件的能量输入表面，进入壁面热流核算；论文列出 O2 8.20e-19 J、N2 1.56e-18 J、NO 1.04e-18 J、CO2 7.25e-19 J、CO 1.78e-18 J。
- 对部分催化 0<gamma<1，DS2V 接口允许直接赋常概率；但所核查的 Zuppardi 飞行器论文主要使用 gamma=0/1 两个极限，没有展示材料相关的中间 gamma 标定。

## DS2V User's Guide 本地原件复核（2026-07-21）
- 文件：`D:\博一\气固相互作用\DS2V用户手册.pdf`，Version 3.8 (October 2006)，47 页。
- 手册印刷页 25：每条表面反应分别输入 first incident molecule、second incident molecule、最多六个 reflected molecule 和单事件输入表面的反应能。
- 手册印刷页 26：复合反应有一个反射产物；各种表面反应概率在指定表面属性时设置。
- 手册印刷页 35：一个界面同时列出最多 18 条反应的独立概率；文字仅称该值是“one of the incident molecules strikes the surface”时的概率，若需要两个反应物则另一个稍后移除。
- 全手册没有说明：多个候选反应的遍历顺序、是否共用一个随机数、概率是否累计、总和是否必须 <=1、第二反应物如何选择/排队、缺少第二反应物时如何处理。
- 因此不能仅凭该手册判定 O 撞壁时 O+O 和 C+O 的竞争算法，也不能证明“第一列物种是唯一触发物种”。需要 DS2V 源码或黑箱算例。

## 竞争性常 gamma DSMC 文献检索（2026-07-21）
- 严格同时满足“DSMC + 常 gamma + 多通道共享同一反应物 + 明确竞争算法”的公开文献很少；多数常 gamma 工作只做 O->O2、N->N2 两个按入射物种分离的通道。
- Ko & Jun, HiSST 2024：SPARTA 中按每个原子物种拆为 `A->NULL` 和 `A->A2`，各 gamma/2；O、N通道彼此独立，不处理 O 同时生成 O2/NO/CO 的分支竞争。
- Zuppardi 2018：DS2V 同时列 O2、N2、NO、CO2、CO 五条常概率反应，但论文和 DS2V 用户手册均未公开候选通道归一化/顺序算法。
- Swaminathan-Gopalan, Borner & Stephani 2017/2019 的 DSMC surface chemistry framework 明确研究共享 O(s) 的 O2/CO2 竞争。它证明顺序执行会偏向排在前面的反应，并提出：GS通道按概率总和归一化；PS通道按各频率占总频率的比例随机选反应。该工作是有限速率/覆盖度模型，不是纯常 gamma，但竞争抽样算法可直接借鉴。
- Mars surface-catalysis 研究明确指出 Mitcheltree CO2 再生模型忽略竞争通道 O+O->O2，说明单一 CO2 超催化/常概率模型不能自动代表竞争选择性。
- 对真正的常 gamma 竞争，单个总复合系数 gamma_O 只规定 O 的总损失比例，不能唯一确定 O2/CO/CO2 分支；还必须额外给分支系数 b_r，满足 `sum b_r=1`，并令 `P_r=gamma_O*b_r`（随后再处理各通道化学计量）。
## 2026-07-27：今日讨论与已确认结论

### 常复合系数模型的约定
- 每种入射物种定义一个复合系数 `gamma`。粒子撞壁后，先以 `1-gamma` 的概率直接散射；进入反应分支后，再按壁面各物种覆盖率和空位覆盖率选择事件。
- 命中空位时，入射粒子被吸附；命中某个已吸附物种且反应文件定义了相应通道时发生复合；若该通道没有定义，则该概率分支转为直接散射。
- 常概率反应文件不区分哪个反应物是入射气相、哪个是吸附态。定义 `N+O=NO` 时，同时允许入射 `N+O(s)` 和入射 `O+N(s)`，即反应物对是无方向、对称匹配。
- 未来实现常复合系数反应后的气相产物出射时，可参考 `PS_react()` 中 DS 分支的随机表面位置、粒子创建、剩余时间和碰撞模型调用流程。

### PS 的 `tau`、MTC 与状态更新
- `tau[isurf][i]` 是每个表面单元、每条有效 PS 反应各自独立的可反应时间累计量；反应物满足时每个同步周期增加 `dt*nsync`。
- 当前 SPARTA adsorb PS 使用 MTC：以 `nu_i*tau_i` 为候选事件权重抽取通道；事件发生后，仅从被选通道的 `tau_i` 中减去指数等待时间 `-log(U)/nu_i`。
- FACE 模式单独创建并清零 `face_tau`；SURF 模式把 `tau` 保存为 surface custom double array，并通过 `spread_custom()` 在分布式/局部表面表示之间传播。
- 原码通过 `species_delta` 延迟更新表面状态；同一同步周期内多次 PS 事件仍读取旧的 `species_state/total_state`，可能产生过度消耗，后续修改 PS 时需要单独核查。

### PS 频率公式与 `schu`
- Molchanova 2018 和 SPARTA 2025 论文对 LH 模型事件频率的主体形式一致：
  - 异种反应：`nu = k*N_A*N_B*Fnum/area`；
  - 同种反应：`nu = k*[N_A*(N_A-1)/2]*Fnum/area`。
- 这里 `N_A` 是该表面单元上的 DSMC 模型粒子计数；`n_A = N_A*Fnum/area` 才是表面数密度。论文中把速率常数单位写成 mol 基准，而正文又使用 surface number density/模型粒子公式，存在单位表述不一致；当前实现按单粒子数密度基准理解。
- 原 PS 代码额外使用 `factor/max_cover`，对应覆盖率基准；若输入的 `k` 是论文的表面数密度基准，二阶 LH 频率会少一个 `max_cover`。
- 已实现共享开关：
  - `schu yes`：GS 使用已有 Schumakova/Molchanova 路径，PS 非 SB 反应使用 `factor^(alpha-1)`；
  - `schu no`：保留 PS 原覆盖率基准 `coverage_factor^(alpha-1)`；
  - 一阶 DS 因 `alpha-1=0` 不受影响；
  - SB 的空位覆盖率仍必须使用 `factor/max_cover`。
- `schu` 在 `gs/ps` 模式下同时控制 GS 和 PS，不设置时保持原行为。

### `init_cover` 与 `tally_only`
- `init_cover` 原本已经对 `ps` 和 `gs/ps` 生效，不需要额外修改。
- `tally_only` 已扩展到 PS 和 `gs/ps`：事件仍被抽样、计数并扣减相应 `tau`，但不修改表面状态、不创建气相产物、不调用产物碰撞模型。
- PS `tally_only` 不能在函数入口直接返回，也不能跳过 `tau` 更新；否则既无法统计事件，也可能重复选择同一个已到期事件而陷入循环。

### `test/20260727_2` 的 LH2 验证
- 算例为二阶同种吸附物反应，`k = 1.16e-10*exp(-15652/1000) = 1.8487609465e-17`。
- 2D xhi 边界长度按代码的 surface area-like measure 取 `area=0.006`；`Fnum=1.49e11`，`max_cover=6.022e18`。
- 满覆盖时模型粒子数为 `N = ceil(max_cover*area/Fnum) = 242497`。
- `max_cover*area = 3.6132e16` 是该表面代表的真实吸附粒子数，不是反应频率。
- 同种粒子组合数为 `N*(N-1)/2 = 29,402,276,256`。
- `schu yes` 下理论模型事件频率为 `nu = k*[N*(N-1)/2]*(Fnum/area) = 1.3498848720e7 s^-1`。
- `dt=1e-6`、`run 1000` 对应总物理时间 `T=0.001 s`，理论事件数均值为 `13498.85`。
- DSMC 得到 13419 次，对应频率 `13419/(1000*1e-6)=1.3419e7 s^-1`；相对理论偏差约 `-0.59%`，约 `-0.69` 个泊松标准差，验证通过。
- 原先的 `13419/1e-6*1010` 时间换算错误：输出次数或输出步号不应乘入频率；必须除以总模拟时间 `dt*nsteps`。
- 若使用模型粒子计数 `N`，用组合数公式并乘 `Fnum/area`；若使用表面数密度 `n_s`，则应写成近似等价的密度形式 `nu_model ≈ k*n_s^2*area/(2*Fnum)`，不能把两套换算重复使用。
- PS 反应次数应读取 surface reaction tally（例如单反应时累计项 `sr_ID[2]` 或 `sr_ID[4]`），`nsreact` 和 `compute boundary` 不是这类无入射粒子 PS 事件的正确计数来源。
- 算例反应式 `2O(s) --> CO2(g)` 化学上应改成 `O2(g)`；在 `tally_only yes` 下不影响频率计数，但正常执行前必须修正。纯 PS 固定状态验证也无需创建大量气相粒子。

### 后续保留事项
- PS 反应热尚未加入：`OneReaction_PS` 无反应热成员，`readfile_ps()` 不读取反应热，`reaction_coeff()` 也只覆盖 GS；PS 的无入射粒子 tally 路径还需专门设计。该任务留到继续逐行分析完 PS 代码后再实施。
- 常复合系数功能尚未实现；后续应在不混入 PS 反应热改动的前提下单独设计、实现和验证。

## Adsorb GS reaction-energy implementation (2026-07-22)
- The existing `compute surf` algebra already implements positive energy as wall heating and negative energy as wall cooling.
- Therefore adsorb `reaction_coeff()` must return the input energy without changing its sign.
- The value is per real reaction event; `compute_surf.cpp` applies particle weight and flux normalization.
- PS chemistry and FACE-mode boundary heat accounting remain outside this implementation phase.

## Compute boundary reaction-heat path (2026-07-22)
- `Update::move()` passes `outface`, boundary style, and `reaction` to every active boundary tally.
- `domain->surf_react[iface]` is the reaction-model index assigned by `bound_modify ... react`.
- Existing `compute boundary etot` contains only the incident/post-collision particle energy difference.
- The matching wall-positive chemical contribution is `weight * reaction_coeff(reaction-1)` before flux normalization.
- `tally_only yes` records candidate reactions internally but returns reaction number 0 to boundary tallies; candidate-only events correctly contribute no reaction heat.
- Controlled face test normalization: 950 events × `6e-19 J/event` divided by (`0.01 m` × `1e-6 s` / `1e10`) gives `570`, exactly matching `compute boundary echem`.
- With identical trajectories, positive/zero/negative `etot` values were `582.52282`, `12.522824`, and `-557.47718`, proving chemical heat is added once with the intended sign.

## 待处理：PS 反应热读取与统计（2026-07-27）

- 当前 `SurfReactAdsorb::reaction_coeff(int m)` 只对 `0 <= m < nlist_gs` 返回 `rlist_gs[m].reaction_energy`；PS 反应编号会返回 `0.0`。
- `OneReaction_PS` 当前没有 `reaction_energy` 成员，`readfile_ps()` 也没有读取反应热。
- `PS_react()` 通过 `surf_tally(0.0,isurf,-1,ireaction,NULL,NULL,NULL)` 上报 PS 事件；标准 `ComputeSurf::surf_tally()` 遇到 `!iorig && reaction` 会直接返回，因此 PS 事件目前也无法沿现有路径正常进入 `echem/etot` 统计。
- 后续修改 PS 功能时需要一并处理：PS 反应热字段、PS 文件读取、GS/PS 联合编号到 `reaction_coeff()` 的映射、PS 上报反应编号的约定，以及无入射粒子的 PS 能量统计路径。
- 本轮仅记录问题，暂不修改源代码。

## 文献核查：PS/GS 速率常数的单位基准（2026-07-27）

- 核查文献：K. Swaminathan Gopalan et al., *Development of a detailed surface chemistry framework in DSMC*, Computers and Fluids 292 (2025) 106525。
- 论文第 8 页将 `n_A(s)` 明确称为吸附物种的 “surface number density”。按严格术语应理解为表面粒子数密度，单位为 `particles/m^2`，不是体积摩尔密度。
- 论文同时将一般 PS 速率常数单位写成 `(m^2 mol^-1)^(alpha-1) s^-1`，与后续直接采用 DSMC 粒子数 `N_A(s)`、`N_B(s)` 和 `Fnum/S_A` 的频率公式不完全一致。
- 当前 PS 代码没有使用阿伏伽德罗常数，直接以 DSMC 粒子计数和 `Fnum/area` 计算频率。因此代码实际要求的速率常数基准应为 `(m^2/particle)^(alpha-1) s^-1`。
- 若外部文献提供 mol 基准速率常数，应在输入前转换：
  `k_particle = k_mol / N_A^(alpha-1)`。一阶反应 `alpha=1` 不受影响。
- 目前倾向认为论文中的 `mol` 是单位标注笔误，或作者省略了输入前从 mol 基准到单粒子基准的转换说明；后续核查 PS 输入单位时必须保留这一疑点。
- 论文没有像 PS 那样用一句话直接列出 GS 的 `k_GS` 单位，但式 (10) 给出 `k_GS = vbar * gamma_GS / (4 B^alpha)`。若 `B` 采用粒子数面密度，则一般单位为 `m^(2alpha+1) particle^(-alpha) s^-1`；若采用摩尔面密度，则将 particle 换成 mol。必须保证 `B`、表面密度和 `k_GS` 使用同一基准。

## 文献核查：竞争 PS 反应的 MTC/STC 算法（2026-07-27）

- 固定顺序逐条执行多种 PS 反应会偏向反应列表靠前的通道，因为前面的反应先消耗共享表面反应物。
- MTC（Multiple Time-Counter）为每个表面、每条有效 PS 反应保存独立 `tau_i`。每周期累加时间，以 `tau_i * nu_i` 的事件权重随机选择通道；执行反应后只从被选中通道的 `tau_i` 中扣除 `-log(U)/nu_i`，再更新状态和所有频率并继续竞争。
- MTC 的优点是消除固定顺序偏差，并在有限事件集合内更严格地满足相对选择性；缺点是需要 `Nsurface * Nreaction` 个计数器，内存和计算成本较高。
- STC（Single Time-Counter）每个表面只保存一个公共 `tau`，按 `nu_i / sum(nu)` 选择通道，并用 `-log(U)/sum(nu)` 扣减公共计数器。它类似 Gillespie direct method，内存和计算成本更低，论文在无特殊偏好时推荐 STC；其相对选择性只在统计意义上满足，有限事件数下会有更明显随机波动。
- SPARTA 原始 adsorb PS 实现采用 MTC，证据是 `tau[isurf][i]`、按 `nu_tau[i]/sum_nu_tau` 选反应，以及只执行 `tau[isurf][i] -= t`。
- 论文 MTC 伪代码对 `tau_i * nu_i` 使用 `round`，当前源码使用 `floor`，两者并不完全一致。
- 严格 MTC 要求每次事件后立即更新表面组成、重新检查反应可行性并更新全部 `nu_i`。当前源码只更新 `species_delta`，循环内计算频率仍读取未立即改变的 `species_state/total_state`，因此一个同步周期内多次反应可能基于旧覆盖状态并造成过度消耗；这是后续修改 PS 实现时需要重点核查的问题。
- `tau` 是逐表面、逐有效 PS 反应的可反应时间余额；反应物不足时当前代码停止累积但不清零旧 `tau`。指数等待时间可能大于现有 `tau`，使其暂时为负，随后通过未来时间累积恢复。
## 设计决定：`schu` 同时控制 GS 与 PS（2026-07-27）

- 后续扩展不新增 PS 专用关键词，直接复用现有 `schu_flag`。
- 当模式为 `gs/ps` 时：
  - `schu yes`：GS 走现有 Schumakova/Molchanova 分支，PS 使用 Molchanova 表面数密度形式。
  - `schu no`：GS 与 PS 均保持当前/原始行为。
- PS 的一般修正不能固定为乘一次 `max_cover`，而应使用反应级数：
  `nu_yes = nu_no * max_cover^(alpha-1)`。
- 实现时优先直接选择换算因子：
  - 数密度因子：`factor = fnum*weight/area`
  - 覆盖率因子：`factor/max_cover`
- 一阶 DS 的 `alpha-1=0`，不受开关影响。
- SB 的空位覆盖率仍必须由 `factor/max_cover` 计算，不能因 `schu yes` 去掉 `max_cover`。
- 本阶段明确不加入 PS 反应热；该功能留到后续独立修改。

## 设计决定：`tally_only` 扩展到 PS（2026-07-27）

- 当前 `tally_only_flag` 只在 `react()` 和 `react_gs_finite_rate()` 中阻止
  GS 执行，`PS_react()` 尚未读取该标志。
- PS 只统计模式不能在函数入口直接返回，否则不会产生任何 PS 事件统计。
- 正确插入位置是：完成反应选择、`nsingle/tally_single/compute` 统计和所选
  `tau` 的指数等待时间扣减之后，执行表面物种增减及气相产物创建之前。
- 此语义会在固定的当前表面状态下统计假想 PS 事件，与 GS 只统计模式“不改变
  状态但继续统计候选反应”的原则一致。
- `tally_only yes` 下必须继续扣减所选 `tau`，否则同一个到期事件会被重复选择，
  可能造成无限循环。
## 2026-07-28 gamma runtime-test preparation

- The reusable compact species file is `test/20260727_ps_schu/air.species`.
- Existing tests report aggregate reaction activity through `nsreact`; no
  repository input currently demonstrates direct `sr_ID[index]` output, so
  the base `SurfReact::compute_vector()` mapping must be checked before using
  per-model counters in the new assertions.
- `sr_ID[index]` is accepted by `stats_style`. Its one-based indexes map to
  `compute_vector(index-1)`: index 1 is the current-step reaction count,
  index 2 is the cumulative count, the following `nlist` entries are
  per-reaction current-step counts, and the last `nlist` entries are
  per-reaction cumulative counts.
- A deterministic `face` test can use `boundary oo oo so` and
  `create_particles ... single` to produce exactly one `zlo` impact.
- The compact O/O2 species fixture has monatomic O with zero rotational and
  vibrational degrees of freedom and diatomic O2 with both modes, making it
  suitable for the requested adsorption/recombination energy checks.
- Existing energy inputs use
  `compute ID boundary all n nflux ke erot evib etot echem`; this can validate
  that adsorption has zero chemical heat but nonzero total wall energy and
  that recombination reports the file heat through `echem`.

## 2026-07-29 Zuppardi supplemental literature: DS2V wall-event semantics
- `Aerothermochemical analysis of the Orion capsule...` (2022), PDF page 6,
  journal page 2830, gives the most direct implementation description:
  the first wall impactor stays on the surface elemental area; when a second
  particle impacts the same area, they recombine if the pair can do so and the
  product returns to the flow; otherwise both particles leave separately.
- The same page states that surface reactions use a prescribed probability;
  fully catalytic and non-catalytic surfaces set it to one and zero,
  respectively. Table 5 lists five allowed pairs and event energies:
  `O+O->O2`, `N+N->N2`, `N+O->NO`, `CO+O->CO2`, and `C+O->CO`.
- The same paper states that all released reaction energy is transferred to
  the wall, not assigned to the product.
- Morsa et al. (2014), PDF page 7 / journal page 935, independently states
  that DS2V assigns a recombination probability to each reaction when atoms
  meet on the same surface element; probability one represents a fully
  catalytic surface.
- Zuppardi (2020), PDF page 3, states that gas-surface interaction is
  diffuse and fully accommodated. PDF page 16 describes re-emission using
  wall-temperature Maxwell equilibrium. It does not specify the exact
  component-wise sampling of the two separately emitted particles.
- The 2023 Titan paper, PDF page 5, again states that DS2V models NC/FC by
  setting all surface-reaction probabilities to zero/one, but adds no more
  detail about the unmatched-pair event.
- The 1997 paper is a continuum inverse heat-flux method for catalyticity,
  not a DS2V particle-event algorithm.
- Therefore the present constant-gamma no-map behavior (scatter only the
  incident particle and retain the stored surface particle) does not match
  the explicit 2022 description. A DS2V-oriented implementation should remove
  the stored particle and emit it plus the incident particle as two separate
  diffusely reflected gas particles.
- Still unspecified by these papers: whether the second particle must first
  pass a species-level gamma gate; exact joint velocity sampling; and what a
  failed finite-gamma trial does to the stored particle. These details should
  not be inferred beyond the quoted event description.

## 2026-07-29 implemented unmatched-pair behavior
- The unmatched branch remains behind the existing incident-species gamma gate.
  A failed gate therefore preserves stored coverage and scatters only the incident
  particle, while a passed gate can release the stored partner.
- The event returns reaction number zero. Standard boundary/surface particle
  energy exchange includes both emitted particles, but chemical heat and all
  reaction counters remain zero.
- Both outgoing particles are independently sampled by the gamma style's internal
  diffuse model at `Tw` with accommodation one, matching the DS2V-oriented model
  choice and preventing the outer collision style from sampling them a second time.
- `tally_only yes` returns before coverage decrement or `jp` creation, preserving
  its fixed-state contract.
- Explicit-surface serial and distributed MPI tests confirmed the simple
  conservation identity `final gas count = initial gas count + emitted stored
  particles - vacancy adsorptions`, with no reaction events.
