# 发现

- cylinder_gamma 目标目录存在且为空。
- 源算例 cylinder 使用顺时针 1000 段圆柱文件，读取时不需要 invert。
- gamma 模型的 nsite 位于 `surf_react ... surf 560 nsite ...` 的数值参数位置，可由 `${nsite}` 展开。
- `clear` 调用 SPARTA destroy/create，但 Input/Variable 对象不被销毁，index 变量可跨工况保留。
- `shell mkdir` 是 SPARTA 内建处理，各 MPI 进程同步且只由 rank 0 创建目录。
- 每个工况必须 clear，并使用相同 seed，避免状态串扰并保证对比一致。
- nsite=6.022e16 单进程可完成、4 MPI 进程稳定卡住；AUTO 对 4 procs/1000 surfs 选择 rendezvous，卡点位于 gamma 每步表面状态 collate_array 通信路径。诊断方案为强制 `global surf/comm reduce`。
- 强制 reduce 后仍卡住，排除 rendezvous 特有问题。最低 nsite 配合 1000 段表面时每段仅约 5 个模拟位点；准备使用 100 段（约 49 位点/段）测试表面状态离散分辨率。
- 100 段、4 MPI、最低 nsite 可完成，确认每表面单元位点分辨率是触发因素。正式与五工况测试统一采用 200 段，最低值约 24–25 个模拟位点/段。
- 200 段在最低 nsite 下约 24–25 位点/段，实测第 0 步卡住；稳定阈值高于该值。下一诊断保持 200 段并将 fnum 减半到 1.94655e13，使最低值恢复约 49 位点/段。
