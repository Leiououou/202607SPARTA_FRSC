# nsite 敏感性分析计划

目标：在 cylinder_gamma 中创建单一 SPARTA 输入脚本，依次独立计算五个 nsite 值，并隔离保存结果。

## 阶段

- [completed] 检查 cylinder 与 cylinder_gamma 的文件和输入结构
- [completed] 设计 SPARTA variable/next/jump 循环及每工况 clear 重置
- [completed] 复制依赖文件并修改输入脚本
- [completed] 静态验证变量展开、输出路径、文件完整性和几何方向
- [completed] 交付运行说明
- [pending] 根治低 nsite 下 surf_react_gamma 多 MPI 并行卡死问题
- [pending] 添加 1/2/4/8 MPI 一致性回归测试
- [pending] 重新编译并验证本地 spa_mpi 与超算 spa_0729

## 决策

- 五个工况使用同一个输入文件串行执行。
- 每个工况进入独立目录，避免 dump、日志和平均量输出互相覆盖。
- 每次循环使用 clear，确保工况彼此独立。
- 100段表面仅作为诊断和临时绕行证据，不视为源码 bug 的最终修复。
- 下一阶段目标是实现或验证 owner-rank 表面事件决策，确保结果不依赖 MPI 进程数。

## 错误记录

- 首次实测在 read_surf 报错：初始网格尚未 RCB 分区，ghost cells 不存在。修复为在 read_surf 前执行 balance_grid。
- 使用标准输入重定向启动时，jump SELF 无法重新打开脚本并查找标签。测试版和正式版均改为显式 jump 输入文件名。
- 首次强制 reduce 使用了旧提示中的 `surf/comm reduce`，当前源码实际关键字是 `surftally reduce`；已修正诊断文件。
- 由于本机无可用 Linux MPI 运行环境，其余验证为静态验证，实际数值运行需在超算或 Linux MPI 环境执行。
