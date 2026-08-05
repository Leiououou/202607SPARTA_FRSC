# 数据与格式发现

本文件记录数据检查结论、列定义和脚本设计依据。

## 文件组织

- 四个有效工况：`nsite_6.022e17`、`nsite_6.022e18`、`nsite_6.022e19`、`nsite_6.022e20`。
- 每个工况均有 `data/surf.10000.dat` 至 `surf.60000.dat`。
- 输入文件采用 `fix 2 ave/surf ... ave running`，因此最终的 `surf.60000.dat` 是截至 60000 步的运行平均结果。

## surf 列定义

输入文件：

`compute 9 surf all all n nwt press fx fy px py shx shy etot ke erot evib echem`

所以 dump 中：

- `f_2[3]`：`press`，压力。
- `f_2[10]`：`etot`，总能量通量，作为热流绘制。
- `f_2[14]`：`echem`，化学能通量。

## 几何与排序

- 圆柱半径为 0.5 m，共 200 条表面线段。
- dump 行顺序不是几何顺序（示例顺序为 1、17、33、...）。
- 使用每条线段中点 `xmid=(v1x+v2x)/2`、`ymid=(v1y+v2y)/2`。
- 上半圆筛选条件采用 `ymid >= -tol`。
- 默认按 `xmid` 升序排列，即从迎风驻点附近 `x=-0.5 m` 到背风侧 `x=0.5 m`。

## 最终绘图

- 四个工况在 60000 步的压力、总热流、echem 对比：3 个 figure。
- `nsite_6.022e18` 和 `nsite_6.022e20` 分别在 10000、20000、30000、40000、50000、60000 步的演化对比：共 6 个 figure。
- 脚本仅显示 figure，不创建 PNG、FIG 或输出文件夹。
- 加上四工况最终结果，共显示 9 个 figure。

## Zuppardi 火星算例参数追溯

- 目标 PDF 共 11 页，已成功抽取全文。
- `D:\博一\气固相互作用\Zupparid` 中共有 6 篇 PDF；第二目录中明确以 Zuppardi 命名的候选包括 `zuppardi2019.pdf` 和 `zuppardi-2020-aerodynamics-of-orion-in-rarefied-flow-along-a-mars-entry-path.pdf`。
- 已抽取候选全文到 `tmp/pdfs/zuppardi_params/`，下一步依据首页作者/题名和正文内容排除非火星或非 Zuppardi 论文。
- 目标论文为 Zuppardi & Mongelluzzo, “Aerothermochemical analysis of the Orion capsule in rarefied transitional flow regime during Mars entry”, Advances in Space Research 69 (2022) 2825–2835。
- 目标论文明确：使用 DS2V 4.5 (64-bit)；火星初始大气 7 组分 O2/N2/NO/CO/CO2/C/Ar，解离后计算体系含 O、N，共 9 组分；给出各初始组分质量/摩尔分数；采用 Bird DS2V 3.3 的 54 反应模型并移植到 4.5。
- 目标论文明确：壁面漫反射、完全能量适应，Tw=300 K；FC/NC 的表面复合概率分别设为 1/0；表面复合反应及反应热有表。
- 对目标论文全文检索未发现 VHS、Variable Hard Sphere、参考直径、黏性指数、Larsen-Borgnakke、转动/振动松弛数或 relaxation number 的明确数值。
- 已确认的同作者火星论文（2018 chemistry、2019 SWBLI/SWSWI、2020 Mars atmosphere Part II、2021 Orion rarefied entry）均重复采用 DS2V 4.5 与 Bird DS2V 3.3 的同一 9 组分/54 反应火星模型及相同大气初始组成。
- 对上述论文的参数关键词检索仍未找到 VHS 参考直径/黏性指数或转动、振动松弛数的数值；论文通常把这些底层分子模型留给 DS2V/Bird 用户指南。
- 第二目录按首页作者全文筛选发现 Zuppardi 2021 “Thermodynamic non-equilibrium and anisotropy in Mars atmosphere entry”。该文直接分析平动、转动、振动温度，但仍未给出转动/振动松弛数，只说明使用 DS2V 4.5，并引用 Bird 2005/2008 用户指南。
- 同目录还发现 Zuppardi 2019 “Influence of the Mars atmosphere model on aerodynamics of an entry capsule”；其组成和 54 反应模型与目标论文一致，仍未公开 VHS 或松弛参数。
- `small-mars-satellite_IAC2016.pdf` 虽有 Zuppardi 合著且涉及火星，但属于系统可行性/工程分析，不提供本任务所需 DSMC 分子模型参数。
- 版面核验目标论文方法页：只描述 DS2V 的网格自适应、时间步、避免连续碰撞和质量指标；没有隐藏的 VHS/松弛参数表或脚注。
- 版面核验 2021 热非平衡论文相关页：表格为 mcs/lambda 与模拟时间质量指标；正文/表格仍没有转动或振动松弛数。
- 对已抽取的全部 Zuppardi 候选全文统一检索 VHS、reference/molecular diameter、viscosity index/exponent、relaxation number、rotational/vibrational collision number、Larsen-Borgnakke、Millikan-White、Parker，零命中。
- 两个指定目录中未找到 Bird 的 DS2V 3.3/4.5 User Guide；论文只在参考文献中引用这些指南。
- 结论：同一 DS2V 4.5 和同一 Bird 3.3 火星化学模型表明作者很可能沿用同一套内置/输入分子数据，但本地论文不能证明每个 VHS 与松弛参数的具体数值，也不能独立支持逐项精确复现。

## Zuppardi 80 km SPARTA 算例审查

- `in.orion` 的80 km来流温度135 K、数密度1.94e19 m^-3和直接进入速度7269 m/s与论文 Tables 3/4a一致。
- 9组分摩尔分数之和为1.0；按当前质量计算得到 p=0.036159 Pa、rho=1.38893e-6 kg/m^3。压力与论文3.74e-2 Pa接近，密度比论文1.42e-6低约2.2%。
- 初始网格700x350对应0.01 m，fnum=6.4667e13给出约735万模拟粒子，即初始每格约30粒子。
- `data.orion2d` 为1000点/1000线的闭合、无重复、无零长度顺时针完整轮廓，y范围约[-2.50975,2.50981]；轴对称盒仅保留y>=0，依赖`read_surf ... clip`裁切下半部。
- `air.tce` 实际为40条D、14条E、1条R，共55条；但`react_modify recomb no`会在初始化时把唯一R反应设为inactive，所以实际活跃数仍为54。
- `surf_react gamma`参数合法：Tw=300 K、nsite=6.022e18 m^-2、O/C/N的gamma均为1，未列出的物种gamma为0。
- `air.tce`没有Ar作为解离碰撞伙伴；这与Bird 54反应计数相符，但意味着Ar只参与弹性/内能碰撞，不诱发文件中的解离反应。

## 2026-07-30：Zuppardi 80 km 算例检查补充结论

- `in.orion` 可通过本地 SPARTA 24 Sep 2025 的 `run 0` 初始化，没有阻止启动的语法错误。
- 80 km 来流 `T=135 K`、`nrho=1.94e19 m^-3`、`V=7269 m/s` 与目标论文一致，组分摩尔分数之和为 1。
- 当前组分对应 `p≈0.03616 Pa`、`rho≈1.389e-6 kg/m^3`；与论文表值分别相差约 3.3% 和 2.2%，论文表格自身存在舍入/数据不完全自洽。
- `data.orion2d` 的整体拓扑闭合，但有一条约 `1.4142e-10 m` 的退化闭合线。裁剪后得到 501 条线，初始化同时警告 4 个点几乎在线上；正式计算前应合并重复端点并删除微小线段。
- `fix in emit/face air xlo xhi yhi` 会因正 x 来流而对 `xhi` 报反向入流警告。通常应保留 `xlo yhi`，让 `xhi` 作为开边界流出。
- 统计 fix 在预处理已运行 5010 步后才定义；后续运行 150000 步将结束于 155010，和每 10000 步输出不对齐。建议正式统计前 `reset_timestep 0`。
- 当前 `collide vss air air.vss` 没有 `relax variable`，实际采用 `air.species` 中的常数松弛概率，即 `Zrot=5`、`Zvib=50`；`air.vss` 后面的 Parker 参数不生效。
- 若要采用 Table 7.4 的 Parker 参数，需启用 `relax variable`，并修正 O2、NO：表中 O2 为 `14.4/90.0 K`，NO 为 `18.1/91.5 K`，当前文件分别约为 `16.5/113.5 K`、`7.5/119 K`。
- `air.tce` 共列出 55 条反应；`react_modify recomb no` 会停用唯一的 R 型反应，因此活跃反应为 54 条，与论文描述一致。文件注释宜写清“55 条列出、54 条活跃”，或删掉停用项。
- Ar 已正确作为惰性物种加入物种和 VSS 碰撞数据；没有作为 TCE 解离伙伴，符合当前 54 反应复现方案。
- 5 条表面复合反应及反应热与论文相符；有限位点模型的 `nsite=6.022e18 m^-2` 是额外建模假设，不是论文 DS2V 原始参数。
- `dt=5e-7 s` 下高速粒子每步约移动 `0.00363 m`，可能跨越多个近壁细网格。建议以壁面热流和组分分布为指标，与 `1e-7` 或 `5e-8 s` 做时间步敏感性对照。
- `bal1` 和 `bal2` 两个周期负载均衡 fix 会在部分步数重复触发，建议只保留一个策略。

## 2026-08-04：80 km 热流后处理数据

- `80/data` 最大步数表面文件为 `80surf.100000.dat`。
- `80_gamma_0/data` 最大步数表面文件为 `80surf.300000.dat`。
- `80_nogamma` 不使用名为 `data` 的目录，结果位于 `data_80`，最大步数表面文件为 `80surf.240000.dat`。
- 三个输入中 `compute surf` 的 `f_2[10]` 均为 `etot`，用作总热流。
- `80` 启用 gamma 壁面模型且 O/C/N 系数为 1；`80_gamma_0` 启用同一模型但系数为 0；`80_nogamma` 注释掉 `surf_react` 和 `surf_modify ... react`。

## surf_react gamma only_one 设计发现

- 现语法为 `surf_react ID gamma file mode Twall nsite ...`；用户要求 `only_one` 紧跟 style，推荐新语法为 `surf_react ID gamma only_one yes|no file mode Twall [nsite] ...`。
- 兼容性：省略 `only_one` 时默认 no 并完全沿用旧语法；显式 no 仍要求 nsite；yes 禁止/不解析 nsite。
- 单进程下可通过 `only_one_flag` 和 `max_sites()=1` 复用现有状态、反应映射和双粒子散射路径。
- 现有 `react()` 已实现：入射粒子先用其 gamma 判定；空位点则吸附；已占位则用无序 `reaction_map[incident][adsorbed]` 查表；未定义反应时释放吸附粒子并对两者执行 diffuse 散射。
- 关键并行风险：显式 surf 状态变化在各进程的 `species_delta` 中累积，到每时间步 `tally_update()` 才通过 `collate_array()` 合并。同一全局 surf 可在多进程同时被判定为空并各自吸附，合并后可超过容量1。
- 因此仅将 `max_sites()` 改为1不足以在 MPI 下实现严格单位点，且可能重现低 nsite 卡死/容量越界。
- `init_cover` 对单位点存在分数覆盖的离散化歧义；当前 `only_one yes` 明确禁止 `init_cover`，每个位点从空状态开始。
- 粒子仍应由碰撞网格单元的进程推进；把整粒子送到 surf 属主会侵入移动和迁移主流程。
- 严格全局占位改由唯一 surf 属主保存一个编码物种状态，并对每次通过 gamma 门槛的事件使用 MPI RMA 排他锁执行不可分割的读/改/写。
- 显式 surf 复用 SPARTA 已有的 `(surfID-1) % nprocs` 属主约定；粗 surf 横跨多个网格分区时仍只有一个全局位点。
- 原有按步合并 delta 的路径只用于 `only_one no`，保持向后兼容。
- 2/4 进程的共享箱体面、分布式细 surf 和跨分区粗 surf 压力测试均已通过；无需修改 `surf_react_adsorb.cpp/.h`。

## 2026-08-04：多节点 MPI_ERR_RMA_SYNC

- 管理员日志确认真正的 abort 位于 `MPI_Win_sync`，错误码为 `MPI_ERR_RMA_SYNC`。
- 当前初始化在 `MPI_Win_allocate` 后直接调用 `MPI_Win_sync`，但没有通过 `MPI_Win_lock` 或 `MPI_Win_lock_all` 建立 passive-target epoch；MPI 标准规定 sync/flush 只能在该 epoch 内调用。
- 本地 OpenMPI 后端宽松接受了该调用，256 rank 多节点 UCX 路径进行了严格检查并 abort。
- one-site RMA 窗口只保存每个 surf 一个 int。831 个 surf 全局约 3.3 KB，256 rank 下每 rank 约 3–4 个 int；它不包含 245000 个网格单元、surface2grid 映射或迁移数据。
- UCX 1.16/1.17 警告是独立的平台环境告警，不是这次 `MPI_ERR_RMA_SYNC` 的直接代码原因。

## 2026-08-05：80 km 常 gamma 热流偏低分析

- 论文 Table 7 给出 80 km 直接进入驻点热流：FC 71.4 kW/m2，NC 37.8 kW/m2；论文明确总热流为 `q=qc+qr`，FC/NC 均为 300 K、完全适应漫反射，FC 的五个表面反应概率均为1，且全部反应热传给壁面。
- 当前 80 km `gamma_CO=1` 最新结果峰值为 57.179 kW/m2，NC 峰值为 40.264 kW/m2；因此并非基础对流热流整体低20%，而是 FC-NC 催化增量不足。
- 在 s=0.1--1.8 m 的共同位置，当前 NC 比论文 NC 高约 0.3%--5.5%，当前 FC 比论文 FC 低约16.3%--19.9%。
- 当前催化增量约14.9--16.8 kW/m2，论文约28.1--30.5 kW/m2；当前仅为论文的53%--58%，且该比例沿TPS基本恒定。这说明首要问题是表面复合事件率/催化热通量口径，而不是几何排序、驻点取平均或整条对流热流缩放。
- 当前驻点附近 `gamma_CO=1` 能量分量为 etot=57.179、ke=22.566、erot=7.606、evib=14.062、echem=12.944 kW/m2；NC 为 etot=40.264、ke=26.680、erot=6.136、evib=7.448、echem=0。FC-NC=16.915 kW/m2，其中直接 echem 为12.944 kW/m2。
- `gamma.surf` 中五个反应热与论文 Table 5 数值一致；加入 `gamma_CO=1` 后 CO+O 反应是当前全局最多的表面反应，因此漏设 CO 已被修正，但仍不能解释剩余约一半的催化增量缺口。

## 2026-08-05：gamma `gank` 分物种库存设计

- `gank yes` 不使用共享总容量；每个 surf 对每种可吸附物种保存独立的模拟粒子库存计数。入射粒子先在全部兼容库存中按数量加权选伴，有伙伴则反应，无伙伴才进入本物种库存逻辑。
- 建议语法：`gamma gank yes every_n N allow|noallow file mode Tw ...`；`N` 必须为正整数。`gank no` 回到现有 nsite 路径并继续要求 nsite；旧语法保持不变。`gank` 与 `only_one` 应互斥。
- `allow` 的分块扩容无需动态重分配：以64位库存计数保存实际数量，逻辑容量为 `ceil(count/N)*N`，可另外统计扩容次数和最大库存。
- `noallow` 下，若入射 A 无兼容伙伴且 `n_A >= N`，选择一个已存 A 与入射 A 同时按 Tw 漫反射，库存 `n_A--`；如果 A+A 本身是定义反应，则兼容反应优先，不进入满容量分支。
- gank 的严格 MPI 语义不能沿用现有按时间步合并 delta 的 nsite 状态；需要唯一属主 RMA 窗口保存每 surf × 每表面物种的整条库存向量，并在一次排他锁内完成读取、加权选择和读改写。
- 建议初始化硬检查：正 gamma 物种必须出现在反应物集合中，且至少有一个正 gamma 的兼容伙伴，否则 allow 模式会产生不可消耗库存。
