# 任务计划：cylinder_gamma 后处理脚本

目标：为四个已有计算工况编写并验证 MATLAB `.m` 脚本，绘制上半圆柱表面的压力、热流和 echem 分布；依据表面几何坐标排序，不依赖 surf 文件的 ID 顺序。

## 阶段

1. [complete] 盘点四个工况、结果文件、surf 几何文件及数据列格式
2. [complete] 明确 ID 到几何位置及三个物理量的映射和上半圆筛选规则
3. [complete] 编写健壮的 MATLAB 读取、匹配、排序和绘图脚本；增加 6.022e18 的多步数曲线
4. [complete] 用现有数据运行 MATLAB 验证并修正（不保存图片文件）
5. [complete] 将脚本交付至目标文件夹并说明用法

## 约束与决策

- 只处理已有结果的四个工况。
- 横轴使用由圆柱表面坐标计算的角度或弧向位置，并按该量排序。
- 仅绘制上半圆柱。
- 不覆盖用户已有数据文件。

## 错误记录

| 错误 | 次数 | 处理 |
|---|---:|---|
| 暂无 | 0 | — |
| Windows 下 `rg` 直接使用 `*.txt` 路径通配符失败 | 1 | 改为搜索目录并使用 `-g '*.txt'` |

## 新任务：Zuppardi 火星算例参数追溯

目标：核查目标论文复现所需的 VHS/物种/转动与振动松弛参数；不足部分仅从本地 Zuppardi 火星论文中交叉追溯，并区分直接证据、同作者惯用设置和仍未明确项。

6. [complete] 识别目标论文题名、算例、模型说明和参数表
7. [complete] 盘点两个目录内 Zuppardi 的火星相关论文
8. [complete] 在候选论文中检索并核验 VHS、物种与松弛参数
9. [complete] 建立可复现参数表，注明来源、适用性和不确定项

## 新任务：Zuppardi 80 km SPARTA 算例审查

目标：静态和初始化检查 `D:\博一\catalytic\zupparid\80`，识别会导致运行失败、偏离论文工况或影响结果可信度的设置问题；不修改用户算例。

10. [complete] 检查输入脚本、物种、VSS、振动、TCE和表面反应文件的一致性
11. [complete] 检查来流参数、混合物归一化、粒子权重和二维表面拓扑
12. [in_progress] 在工作区副本上执行 SPARTA `run 0` 初始化验证
13. [pending] 汇总问题严重程度、依据和建议修改项

## 2026-07-30 收尾状态

- [complete] Phase 12：已在工作区副本中完成 SPARTA `run 0` 初始化验证。
- [complete] Phase 13：已汇总问题严重程度、依据和建议修改项。
- 下次继续前先确认采用常数松弛数，还是 Parker/Millikan–White 变松弛模型。
- 优先清理 `data.orion2d` 中长度约 `1.4142e-10 m` 的微小闭合线段。
- 随后处理 `xhi` 入流面、统计前 `reset_timestep 0`，并开展时间步敏感性分析。

## 新任务：80 km 热防护层热流后处理

目标：编写并验证 MATLAB `.m` 脚本，自动读取 `80`、`80_gamma_0`、`80_nogamma` 三个算例各自 `data` 目录中步数最大的 surf 文件，只绘制 80 km 热防护层热流分布，并检验 0-gamma 是否退化到无壁面反应模式。

14. [complete] 盘点三个 data 目录、surf 文件命名/列格式和既有后处理风格
15. [complete] 确定 TPS 几何筛选、弧长排序和三组热流定义
16. [complete] 编写 MATLAB 脚本及自动选择最大步数文件的辅助函数
17. [complete] 运行 MATLAB 验证读取、匹配、绘图及 0-gamma 差异指标
18. [complete] 交付脚本并说明曲线物理含义与用法

新错误记录：MATLAB R2021a 将工具箱 `str2double.m` 识别为脚本，无法函数调用（1次）；已改用 `sscanf(...,'%f',1)` 解析步数。

## 新任务：80/90/100 km 驻点热流及尖端效应检查

19. [complete] 确认三高度 FC 最大步数 surf 文件和热流列
20. [complete] 手动检查近驻点前 12 个单元的热流连续性
21. [complete] 编写并验证独立驻点热流 MATLAB 脚本
22. [complete] 交付脚本和尖端效应诊断结论

## 新任务：surf_react gamma `only_one` 设计（仅规划）

目标：为 gamma style 设计可选关键词 `only_one yes|no`。默认为 `no`；`yes` 时每个显式 surf 只有1个位点且不输入 `nsite`，保留 gamma 吸附判定、无匹配反应时两粒子同时散射的语义。本阶段不修改源码。

23. [complete] 检查现有命令解析、表面状态、反应执行、MPI 合并和网格变更路径
24. [complete] 定义新老语法兼容矩阵及 only_one 单位点状态机
25. [complete] 识别 MPI 跨进程同时占位为实现前的关键架构门槛
26. [complete] 列出分阶段实现、回归、并行压力和物理验证计划
27. [complete] 用户确认开始实现；only_one 从空位点开始，FACE 也采用全局唯一位点
28. [complete] 增加向后兼容的 `only_one yes|no` 命令解析
29. [complete] 实现严格的单个位点串行事件状态机
30. [complete] 用唯一属主 MPI RMA 状态替代 only_one 的进程局部增量
31. [complete] 增加串行、兼容性、共享面和跨分区显式 surf 测试
32. [complete] 完整重编译并完成串行、2/4 进程回归与压力测试
33. [complete] 更新命令文档、测试说明和变更记录

## 新任务：修复多节点 `MPI_ERR_RMA_SYNC`

目标：移除 `only_one` 窗口初始化阶段位于 passive-target epoch 外的非法 `MPI_Win_sync`，改用标准兼容的自目标 lock/put/unlock 初始化，并重新完成归档和验证。

34. [complete] 根据管理员日志定位 `MPI_Win_sync` 和 epoch 约束
35. [complete] 将窗口清零改为合法的自目标 RMA 事务
36. [complete] 完整 clean 编译并运行串行回归
37. [complete] 运行 2/4 进程共享面和跨分区 surf 压力测试
38. [complete] 审查全部 RMA 调用的 epoch 合法性
39. [complete] 替换 sparta-20260804 归档 src 并更新修改记录

## 新任务：常 gamma 热流较论文低约 20% 的原因分析

目标：核准 Zuppardi 论文热流定义和算例条件，对照当前 gamma 两种模式的输入、输出与 MATLAB 后处理，识别造成约 20% 系统性低估的主要原因，并给出可区分各原因的验证方案。

40. [complete] 提取论文中的工况、壁面模型、热流定义、数值设置和参考曲线
41. [complete] 核对当前两种 gamma 模式的输入参数、统计口径和结果差异
42. [in_progress] 定量检查可疑因素对约 20% 偏差的方向与量级
43. [pending] 按证据强弱排序原因并提出最小验证矩阵

新错误记录：首次用 PowerShell 汇总能量分量时 foreach 后直接接管道导致空管道解析错误（1次）；改为先累积对象数组再格式化，已解决。

## 新任务：`surf_react gamma gank` 分物种库存模式（仅规划）

目标：设计可选 `gank yes|no` 模式。`yes` 时每个 surf 为每种可吸附物种保存独立的模拟粒子库存，兼容伙伴按库存数量加权选择；`every_n N allow|noallow` 控制每物种容量分块及满容量行为。当前阶段只评估和规划，不修改功能源码。

44. [complete] 明确 gank 状态机、兼容优先、加权选伴和每物种容量语义
45. [complete] 评估命令语法、旧模式兼容关系和错误输入检查
46. [complete] 评估串行、FACE、显式 surf、MPI RMA 和网格变化实现范围
47. [complete] 制定单元回归、MPI 压力、统计选择和80 km物理验证计划
48. [pending] 用户确认最终语法及两个边界语义后开始实现
