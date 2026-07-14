# Task Plan: tally_only 关键词 — ✅ 已完成

## Goal
在 `surf_react adsorb` 命令中新增 `tally_only yes/no` 关键词。✅ 完成

## 完成状态：全部 8 个 Phase 均已完成

| Phase | 内容 | 状态 |
|-------|------|:--:|
| 1 | 头文件 — tally_only_flag 成员变量 | ✅ |
| 2 | 构造函数 — tally_only 关键词解析 | ✅ |
| 3 | react() — tally_only 跳过逻辑 | ✅ |
| 4 | react_gs_finite_rate() — tally_only 跳过逻辑 | ✅ |
| 5 | gs_model() + init() 打印状态 | ✅ |
| 6 | WSL 编译验证 | ✅ |
| 7 | 运行验证（对比测试） | ✅ |
| 8 | 变更日志 + 记忆文件更新 | ✅ |

## 验证结果
- 无 tally_only: Surf reactions=11, tally=11
- 有 tally_only: Surf reactions=0, tally=11 ✓（统计但不执行）

---

## 后续任务
- PS 反应的 tally_only 扩展
- Molchanova 2018 Fig 4 验证算例
