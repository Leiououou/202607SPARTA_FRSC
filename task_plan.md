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
48. [complete] 用户确认最终语法及回退规则，授权开始实现
49. [complete] 实现向后兼容的 gank 参数解析、反应网络检查和串行状态机
50. [complete] 实现每 surf×物种的严格 MPI RMA 库存及状态镜像
51. [complete] 增加 allow/noallow、加权配对、回退和错误输入测试
52. [complete] clean 编译并完成串行、2/4进程回归与压力测试
53. [complete] 更新命令文档、测试说明和变更记录

## 新任务：评估 compute surf 输出 gank 分物种库存（只读评估）

目标：评估在 `compute surf` 中增加吸附物种库存列的接口与实现复杂度；本阶段不修改功能源码。

54. [complete] 核对 compute surf 列布局、gamma 库存自定义属性、MPI 同步时机及现有输出通道，形成接口建议

## 新任务：gank 分物种库存独立文件输出

目标：不修改 `compute surf`，复用 `gamma_<surf_react-ID>_species` 自定义表面数组，将每个显式 surf 上各吸附物种的 DSMC 库存输出到独立文件；打印明确的列—物种映射，并完成串行/MPI 验证、文档和编译。不会运行 80 km 正式算例。

55. [complete] 核对库存物种排序、状态同步和 dump surf/custom 的串行及MPI输出路径
56. [complete] 在 gamma 初始化输出中打印 custom 库存数组列号与物种名映射
57. [complete] 新增独立库存 dump 示例和确定性串行测试
58. [complete] 运行2/4进程库存输出测试，检查全局surf库存一致性
59. [complete] 更新使用文档、测试说明、变更记录和外部代码修改进程
60. [complete] clean MPI编译并完成相关回归测试

## 新任务：代码修改进程精简版

目标：在外部修改流程目录新建一份便于直接查用的精简记录，只保留各版本新增命令、完整使用示例，以及代码版本和计算/验证文件路径；原详细记录保持不变。

61. [complete] 盘点20260714至20260805的命令变化、代码归档和计算目录
62. [complete] 编写`代码修改进程_精简版.txt`
63. [complete] 校验文档内所有本地路径、命令ID和当前二进制哈希
64. [complete] 完成精简记录交付并登记生成位置

## 新任务：常gamma近期尝试PPT前置PDF

目标：将近期围绕Zuppardi Orion算例的常gamma模型修改、计算动机、主要问题、关键结果和当前结论整理为简洁的横向PDF，便于直接拆分制作PPT，并保存到用户桌面。

65. [complete] 汇总研究动机、模型迭代、关键数值结果和论文对照结论
66. [complete] 生成横向PPT提纲PDF并保存到桌面
67. [complete] 渲染全部页面并完成视觉与文本核验
68. [complete] 交付PDF及简短内容说明

## 新任务：gamma `only_one noleave` 驻留保持模式

目标：为 `surf_react gamma` 的 nsite、only_one 和 gank 三种状态机增加通用可选裸关键词 `noleave`。启用后，未发生反应时只让入射粒子继续散射，已存在的驻留粒子/库存保持；gank 无兼容伙伴且未满时仍正常吸附，noallow 满容量时不再释放库存粒子。省略时维持现有行为。完成向后兼容解析、严格MPI状态更新、针对性回归、clean编译和文档记录。

69. [complete] 核对 only_one 参数解析、串行/RMA状态转移和现有测试入口
70. [complete] 实现三种模式通用 noleave 语法、状态机及非法位置检查
71. [complete] 增加 nsite/only_one/gank 保持行为及旧行为回归测试
72. [complete] 完成串行、2/4进程压力测试与clean MPI编译
73. [complete] 更新命令文档、测试说明和代码修改记录

新错误记录：首次在沙箱内启动 WSL 编译返回 `Wsl/Service/CreateInstance/E_ACCESSDENIED`（1次）；按权限流程升级执行后编译成功。

新错误记录：首次用PowerShell组合`rg`正则搜索`${...}`时双引号转义触发解析错误（1次）；改用单引号正则并拆分搜索后解决。

新错误记录：首次运行独立库存测试时默认`log.sparta`无法在挂载目录创建（1次），改用`-log /tmp/...`；随后发现本版本`dump surf`不支持`dump_modify sort id`（1次），已从测试输入删除该非必要选项。

新错误记录：显式方形surf测试从外部及内部近壁切分单元创建单粒子均失败（2次）；第三次改为10×10细网格、从未切分的内部单元起步并在单步内飞向底边。

新错误记录：制作PPT前置PDF时，系统MSYS2 Python缺少reportlab；首次执行`pip install --user`因PEP 668 externally-managed-environment被拒绝（1次），改用工作区独立虚拟环境安装，避免修改系统Python。

新错误记录：独立虚拟环境安装reportlab/pypdf/pdfplumber超过120秒并超时，依赖未安装（1次）；改用本机已有XeLaTeX生成PDF，并继续使用Poppler渲染核验。

新错误记录：首次XeLaTeX编译因未加载TikZ positioning库报错（1次），补充库后解决；初次逐页渲染发现第2、7、9页局部拥挤，压缩内容并复检后消除可见裁切。

新错误记录：最终重编译时沙箱进程无法写入已有TeX临时目录（2次），按权限流程在同一工作区内完成编译；首次`pdftotext`写校验文件亦受限（1次），改为标准输出内存校验。

新错误记录：启动`noleave`实现审查时，PowerShell下对`src\\surf_react_gamma.*`使用路径通配符且误写不存在的`tests`目录，导致`rg`失败（1次）；后续改为明确文件路径和实际`test`目录。

新错误记录：首次用PowerShell双引号封装WSL shell循环运行noleave测试时，循环变量被外层解析吞掉且无SPARTA输出（1次）；改为逐项显式执行，避免双层变量转义。
## 新任务：美化代码修改进程精简版

74. [complete] 按“版本索引—命令速查—配置对照—用户计算目录—程序路径”重排精简版
75. [complete] 删除内部验证文件与测试说明，仅保留用户实际计算文件夹
76. [complete] 覆盖回外部记录目录并核对关键命令、路径与 noleave 版本提醒

## 新任务：汇总 catalytic 下全部 80 km 热流结果

目标：盘点 `D:\博一\catalytic` 下所有 80 km 计算结果，统一提取各算例最新有效表面总热流，在一张图中与 Zuppardi 论文 FC 参考曲线对照，并交付可重复运行的 MATLAB 脚本。

77. [complete] 递归盘点所有 80 km 算例、结果文件和已有后处理脚本
78. [complete] 核对各文件热流列、几何映射、统计窗口与论文 FC 数据来源
79. [complete] 编写汇总绘图脚本并设置清晰的曲线分组和图例
80. [complete] 使用 MATLAB 实际运行，核对纳入算例、步数和数值范围
81. [complete] 将脚本保存到 catalytic 总目录并交付说明

## 新任务：gamma 吸附—复合能量记账审查

目标：逐行核查第一颗粒子吸附、第二颗粒子触发复合、生成物散射及反应热统计，判断入射能、生成物带走能量和显式反应热是否遗漏或重复；仅诊断，不修改源码。

82. [complete] 定位 gamma 状态机、粒子创建/删除和能量 tally 调用链
83. [complete] 审查首次吸附时入射粒子的平动/转动/振动能去向
84. [complete] 审查复合时驻留粒子、入射粒子和生成物散射能量去向
85. [complete] 审查 reaction heat 到 echem/etot 的缩放、符号及重复计数风险
86. [complete] 用最小单事件算例或现有测试定量验证代码级能量平衡
87. [complete] 汇总结论、确定性证据和仍需验证的边界

错误记录：首次用 PowerShell 双引号封装 WSL shell 循环时，`$f` 被外层解析为空，三个测试均因空文件名失败（1次）；改为逐条显式运行，避免双层变量转义。
