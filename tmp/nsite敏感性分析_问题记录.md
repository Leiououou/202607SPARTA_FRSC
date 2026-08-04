# SPARTA constant-gamma 模型 nsite 敏感性分析问题记录

记录日期：2026-07-29  
算例目录：`D:\博一\sparta代码修改流程\test\cylinder_gamma`  
涉及模型：`surf_react gamma`，模型输出名称为 `constant-gamma`

## 1. 研究目标

在同一个 SPARTA 输入文件中，使用 `variable`、`next` 和 `jump` 命令依次计算五个表面位点密度：

| 工况顺序 | nsite |
|---:|---:|
| 1 | `6.022e18` |
| 2 | `6.022e19` |
| 3 | `6.022e20` |
| 4 | `6.022e17` |
| 5 | `6.022e16` |

要求各工况：

- 使用相同气体参数、几何、时间步长和随机种子；
- 每个工况开始前执行 `clear`，防止粒子和壁面状态从上一工况继承；
- 分别输出到独立目录；
- 最终在超算上调用新版 `spa_0729` 执行。

## 2. 相关程序版本

超算新版程序的编译目录：

```text
/data/user/shengpengju/sparta_20260729/build/src/spa_0729
```

编译环境：

```text
openmpi/5.0.5
SPARTA_MACHINE=0729
Release
BUILD_SHARED_LIBS=OFF
```

本地测试程序 `spa_mpi` 与超算 `spa_0729` 使用相同版本的修改后源码，但两者仍可能链接不同的 MPI 和系统运行库。

## 3. 初始壁面反应为零的问题

最初输入文件中定义了：

```sparta
surf_react gamma gamma gamma.surf surf 560 6.022e18 O 1 C 1 N 1
```

但没有把该反应模型赋给圆柱表面。日志中存在大量真实撞壁：

```text
SurfColl occurs = 127535
```

同时：

```text
Surf reactions = 0
reaction all: 0
```

修复方式：

```sparta
surf_modify all react gamma
```

结论：`surf_react` 只创建反应模型，内部显式表面还必须通过 `surf_modify` 挂载反应模型。

## 4. 圆柱内外方向错误

原始圆柱表面按逆时针方向排列，SPARTA 将圆柱内部识别为流场。日志中的流场面积为：

```text
0.785398
```

该数值等于：

\[
\pi(0.5)^2=0.785398
\]

说明模拟的是圆柱内部，而不是圆柱外绕流。

翻转表面方向后，日志中的流场面积变为：

```text
15.2146
```

与理论外流场面积一致：

\[
4\times4-\pi(0.5)^2=15.214602
\]

后续重新生成的圆柱文件均采用顺时针顶点顺序，因此读取时不再使用 `invert`。

## 5. 10000 段圆柱与自适应网格错误

原圆柱包含10000条线段，单段长度约：

```text
3.14159e-4 m
```

在执行表面网格自适应时出现：

```text
CELL1 proc 1 icell 13054 id 5005573 iface 0
jcell 12403 id 221445 marktype 2 jtype 1
ERROR on proc 1: Cell type mis-match when marking on self
MPI_ABORT
```

这表示网格内外标记传播时，同一个相邻单元被判定成了两种相反类型。10000段表面相对于约 `0.01794 m` 的基础网格过密，增加了表面重标记的复杂度。

处理措施：

- 重新生成较低段数的顺时针圆柱；
- 正式敏感性输入中不再执行两次基于表面的 `adapt_grid`；
- 保留后续基于粒子数的网格自适应。

## 6. read_surf 前缺少 ghost cells

最初生成敏感性输入时，`balance_grid rcb cell` 被放在 `read_surf` 之后，四进程运行时报错：

```text
WARNING: Could not acquire nearby ghost cells b/c grid partition is not clumped
ERROR: Cannot mark grid cells as inside/outside surfs because ghost cells do not exist
```

正确顺序：

```sparta
create_box   -2 2 -2 2 -0.5 0.5
create_grid  223 223 1
balance_grid rcb cell
read_surf    circle_R0.5_P200.surf
```

结论：当前并行划分条件下，读取并标记闭合表面之前必须先进行 RCB 网格分区。

## 7. jump SELF 与标准输入重定向不兼容

五工况测试的第一个工况正常完成后出现：

```text
Quick test completed: nsite = 6.022e18
ERROR: Label wasn't found in input script
```

当程序通过以下方式启动时：

```bash
mpirun -np 4 ./spa_mpi < in.cylinder_gamma_test
```

SPARTA 从标准输入读取命令，`jump SELF` 无法重新打开实际文件并搜索标签。

修复方式：

测试文件：

```sparta
jump in.cylinder_gamma_test loop_nsite
```

正式文件：

```sparta
jump in.cylinder_gamma loop_nsite
```

注意：上传超算后必须保持这两个输入文件的名称不变。

## 8. 五工况循环结构

正式输入采用两个同步的 `index` 变量：

```sparta
variable nsite index 6.022e18 6.022e19 6.022e20 6.022e17 6.022e16
variable caseid index nsite_6.022e18 nsite_6.022e19 nsite_6.022e20 nsite_6.022e17 nsite_6.022e16
```

每个循环开头执行：

```sparta
clear
shell mkdir ${caseid}
shell mkdir ${caseid}/data
log ${caseid}/log.sparta
```

循环结尾执行：

```sparta
next nsite caseid
jump in.cylinder_gamma loop_nsite
```

源码检查确认，`clear` 会销毁并重建模拟对象，但不会销毁 `Input/Variable` 对象，因此 `index` 变量能够跨循环保持。

## 9. 最低 nsite 的并行卡顿问题

### 9.1 复现条件

最低值：

```text
nsite = 6.022e16 m^-2
```

使用1000段圆柱、原始：

```text
fnum = 3.8931e13
```

时出现：

- `-np 1`：100步可以完成；
- `-np 4`：稳定表现为长时间停在约第20步，且没有 `ERROR`、`MPI_ABORT` 或 `Killed`。

这证明：

- 参数可以被模型解析；
- 不是普通输入语法错误；
- 不是单纯的本地无限循环；
- 问题与多MPI进程下的表面状态更新有关。

### 9.2 每表面单元模拟位点数

`surf_react_gamma.cpp` 中每个表面单元的最大模拟位点数为：

\[
N_{\mathrm{site,elem}}
=
\left\lceil
\frac{n_{\mathrm{site}}A_{\mathrm{elem}}}
{F_N W_{\mathrm{elem}}}
\right\rceil
\]

当前表面权重 \(W_{\mathrm{elem}}=1\)。

半径0.5 m的二维圆周长度为：

\[
L=2\pi R=\pi
\]

对应最低 `nsite` 时：

| 圆柱段数 | 单段长度约值 | 模拟位点数/段约值 | 4 MPI测试 |
|---:|---:|---:|---|
| 1000 | `0.00314159 m` | 5 | 卡住 |
| 200 | `0.0157073 m` | 24–25 | 用户报告第0步附近卡住 |
| 100 | `0.0314108 m` | 48–49 | 完成100步 |

上述结果表明，卡顿与每个表面单元可表示的模拟位点数量高度相关。

### 9.3 已排除的通信算法原因

默认 `surftally auto` 在4进程、1000个表面单元时会选择 rendezvous 汇总。为排除该通信路径，曾测试：

```sparta
global gridcut 0.0 comm/sort yes surftally reduce
```

即强制使用 `MPI_Allreduce`。

结果：四进程低 `nsite` 仍然卡住。

结论：问题不是 rendezvous 算法独有的；简单切换为 Allreduce 不能根治。

曾误用：

```sparta
surf/comm reduce
```

当前源码不支持该关键字，报：

```text
ERROR: Illegal global command
```

当前版本的正确关键字是：

```sparta
surftally reduce
```

### 9.4 当前源码机制

当前 `surf_react_gamma` 的主要流程是：

1. 每个rank使用本地可见的表面覆盖状态处理撞壁粒子；
2. 吸附、脱附或复合先写入本rank的 `species_delta`；
3. 每个时间步结束时调用 `update_state_surf()`；
4. 通过 `surf->collate_array()` 汇总各rank对同一表面单元的修改；
5. owner rank更新表面状态，再传播给本地和ghost表面副本。

关键限制是：各rank在作出反应决定时，只能看到该时间步开始时同步的状态及本rank局部增量，不能看到其他rank在同一步内已经预占或释放的位点。

当每段只有少量模拟位点时，不同rank可能基于同一旧状态同时作出互相冲突的决策。切换汇总算法只能改变步末通信方式，无法撤销此前已经执行的粒子吸附、生成、反应和散射，因此不能从根本上解决该问题。

## 10. 为什么增加MPI核心数仍有风险

本地4进程能够完成某一离散方案，并不保证超算30或60进程一定能完成，因为：

- MPI进程数变化会改变网格RCB分区；
- 每个进程拥有的网格和ghost表面集合会变化；
- 同一表面单元可能接收来自不同rank的碰撞更新；
- 本地与超算可能使用不同的MPI运行库；
- 更多进程可能增加表面状态并发更新的频率。

因此，在源码问题彻底解决前，必须以最低 `nsite=6.022e16` 作为压力工况，逐级测试：

```text
1 → 4 → 8 → 16 → 30 → 60 MPI进程
```

正式计算只能使用已经通过最低 `nsite` 测试的最大进程数。

## 11. fnum 的讨论和最终决定

降低 `fnum` 可以增加每个表面单元对应的模拟位点数，但同时会增加气相模拟粒子数和计算成本。

曾临时提出将：

```text
fnum = 3.8931e13
```

减半为：

```text
fnum = 1.94655e13
```

但用户明确要求不修改 `fnum`，该临时修改已经撤销。

当前三个输入文件均保持：

```sparta
global nrho 3.63e18 fnum 3.8931e13 vstream 4811 0 0 temp 144.74
```

## 12. 当前文件状态

### 正式输入

文件：

```text
in.cylinder_gamma
```

当前设置：

- 五个 `nsite` 依次循环；
- `fnum=3.8931e13`；
- 读取 `circle_R0.5_P200.surf`；
- 每个工况执行4段1000步预运行/粒子自适应，再运行60000步；
- 每个工况独立输出日志、网格数据和表面数据；
- 使用显式文件名跳转。

### 五工况快速测试

文件：

```text
in.cylinder_gamma_test
```

当前设置：

- 五个 `nsite` 依次循环；
- 每个工况只运行100步；
- `fnum=3.8931e13`；
- 读取 `circle_R0.5_P200.surf`；
- 不执行自适应网格；
- 不生成大型dump文件；
- 使用显式文件名跳转。

### 最低值诊断输入

文件：

```text
in.gamma_low_test
```

当前设置：

- 只计算 `nsite=6.022e16`；
- 运行100步；
- `fnum=3.8931e13`；
- 当前读取 `circle_R0.5_P200.surf`；
- 当前保留 `surftally reduce`，仅用于诊断，不代表已解决问题。

### 表面文件

目录中保留：

```text
circle_R0.5_P100.surf
circle_R0.5_P200.surf
circle_R0.5_P10000.surf
```

其中：

- P100：最低 `nsite` 四进程100步测试完成；
- P200：正式及五工况测试当前采用，但最低值并行测试报告卡住；
- P10000：文件名沿用历史命名，实际为此前重新生成的1000段版本。

## 13. 当前确定结论

1. 壁面反应挂载问题已经解决。
2. 圆柱表面方向问题已经解决。
3. `read_surf` 前的并行网格分区顺序已经解决。
4. 标准输入模式下的循环跳转问题已经解决。
5. `nsite=6.022e16` 单进程可以运行。
6. 低 `nsite` 多进程卡顿与每表面单元模拟位点数量有关。
7. 强制 Allreduce 不能解决卡顿。
8. 100段圆柱在本地4进程、最低 `nsite`、100步条件下完成。
9. 200段圆柱在相同最低值并行测试中仍报告卡顿。
10. 用户要求保持原 `fnum=3.8931e13`。
11. 当前尚不能证明正式200段方案在超算30或60进程下可靠。

## 14. 尚未解决的问题

核心未解决问题：

> 如何在多个MPI进程同时访问同一显式表面单元时，对有限离散位点执行守恒、无竞争的吸附/脱附/复合决策。

真正的源码级解决方向是：

1. 收集各rank在当前时间步内的撞壁候选事件；
2. 将每个表面单元的候选事件发送给唯一owner rank；
3. owner依据真实剩余位点顺序处理事件；
4. owner将吸附、反应、双粒子散射等结果返回事件来源rank；
5. 来源rank再修改粒子；
6. 最后统一传播新的表面覆盖状态。

该方案能保证：

- 同一位点不会被多个rank重复占用；
- 表面物种计数不会被并行过度消耗；
- 粒子数、物种数和反应统计一致；
- 结果不依赖MPI进程数或汇总算法。

这属于结构性并行算法修改，不能用简单的状态裁剪或更换MPI集合通信代替。

## 15. 超算提交前建议

在当前源码未完成owner-rank事件处理前：

1. 不要直接提交完整五工况长时间计算；
2. 先上传最低值诊断输入；
3. 使用超算新版 `spa_0729`；
4. 从较少进程逐级增加；
5. 每级只运行100步；
6. 检查是否正常输出到第100步并正常退出；
7. 同时比较反应数和最终粒子数是否随MPI进程数发生异常跳变；
8. 只有通过稳定性和结果一致性检查后，才能选择正式进程数。

推荐记录表：

| 表面段数 | nsite | MPI进程数 | 是否完成100步 | 用时 | 总壁面反应数 | 最终粒子数 | 备注 |
|---:|---:|---:|---|---:|---:|---:|---|
| 100 | `6.022e16` | 1 |  |  |  |  |  |
| 100 | `6.022e16` | 4 | 已完成 |  |  |  | 本地测试 |
| 100 | `6.022e16` | 8 |  |  |  |  |  |
| 100 | `6.022e16` | 16 |  |  |  |  |  |
| 100 | `6.022e16` | 30 |  |  |  |  | 超算 |
| 200 | `6.022e16` | 1 |  |  |  |  |  |
| 200 | `6.022e16` | 4 | 报告卡住 |  |  |  | 本地测试 |

## 16. 后续建议

建议将后续工作分成两条线：

### A. 临时完成敏感性分析

- 保持 `fnum` 不变；
- 选择本地和超算多进程均通过测试的统一表面段数；
- 五个工况使用完全相同的表面文件；
- 做至少一次100段与更细表面的几何/结果误差比较；
- 记录MPI进程数，避免将并行数变化误判成 `nsite` 敏感性。

### B. 根治源码并行问题

- 在 `surf_react_gamma` 中实现owner-rank事件决策；
- 添加低位点密度、多rank同时撞击同一表面的回归测试；
- 对1、2、4、8进程比较粒子守恒、表面覆盖和逐通道反应计数；
- 验证结果在不同MPI分区下统计一致；
- 重新编译本地 `spa_mpi` 和超算 `spa_0729`。

