# Findings: 常复合系数 gamma

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
