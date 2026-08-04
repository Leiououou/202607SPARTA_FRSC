在surf_react   命令的adsorb style中增加了schu 关键词，参数yes 或者 no。yes则壁面反应概率依据舒马科娃文献确定
                                                                                                             ——————————————————————————————————该关键词使用与否，并不影响PS反应在surf_react adsorb风格中的使用
在surf_react   命令的adsorb style中增加了init_cover 关键词，参数一个物种名 + 初始覆盖度。如 init_cover O2 0.5
在surf_react   命令的adsorb style中增加了tally_only 关键词，参数一个yes 或者 no。yes则只统计而不实际发生反应。
增加了壁面反应文件读取反应热的功能，吸热为正。放置位置： 原：O(g) --> O(s)
                                                                                                             AA  A  1.0 0 0 1 
                                                                                                      现：O(g) --> O(s)
                                                                                                            AA  A  1.0 0 0 1 -1.6E-20
                                                                                                      注意：目前只能读取GS反应文件的反应热———————————————————能量项输入为0即恢复到PSARTA原有代码

在compute boundary中增加关键词echem,统计的是adsorb反应壁面热流。——————————————————————————————经过了20260722_1算例验证
                                                                                                                           ——————————————————————————————经过了20260722_2算例验证

——————————————————————————————————————————————————————————————————————————————————————————————                                                                    
【待修正问题：PS/LH反应频率nu中的max_cover（2026-07-27）】
根据Molchanova等2018年论文（Phys. Fluids 30, 107105）以及SPARTA开发者2025年论文，在以表面数密度为基准定义PS/LH反应速率常数k时，一个表面单元上的LH模型反应频率应为：
                                                                                                       不同物种 A(s)+B(s)：nu_LH = k_LH * N_A * N_B * (fnum*weight/area)
                                                                                                       相同物种 A(s)+A(s)：nu_LH = k_LH * [N_A*(N_A-1)/2] * (fnum*weight/area)
SPARTA原码中，多除以了n_site。

20260727修改：在PS反应模式下也加入schu关键词。yes则意味着按照Molchanova 2018 & S.G 2025 文献中PS反应的特征频率公式计算。即在SPARTA原码的基础上多乘上n_site的对应次幂。
                                                                                      ————————————————————————————————————————init_cover ,schu, tally_only关键词均已引入ps和gs/ps模式
通过20260727_1算例，验证了脱附反应频率，相对偏差0.8% 
通过20260727_2算例，验证了LH2反应频率，相对偏差1.58% 
通过20260727_3算例，验证了LH4反应频率，相对偏差1.19% 
——————————————————————————————————————————————————————————————————————————————————————————————
目前问题：PS反应没有echem接口，暂时无法统计PS反应产生的热流。
——————————————————————————————————————————————————————————————————————————————————————————————
【20260728修改：新增独立的surf_react gamma常复合系数风格】即文件夹中sparta_20260728

一、修改摘要
1. 新增独立文件surf_react_gamma.cpp和surf_react_gamma.h，没有为本功能修改surf_react_adsorb.cpp和surf_react_adsorb.h。
2. gamma风格只处理气体粒子与表面吸附物之间的GS常复合系数反应，不包含PS反应，因此命令中不需要、也不接受nsync关键词。
3. 每个入射气相物种可以设置一个0～1之间的常复合系数gamma。命令中没有列出的物种，其gamma默认为0。
4. 每条反应固定为两个无序反应物生成一个气相产物，即A+B-->C。A入射、B吸附和B入射、A吸附均可匹配同一条反应，不受反应物书写顺序影响。
5. 复合产物复用入射粒子的粒子记录并改为气相产物C，随后按照壁温Tw进行完全漫反射。不会额外产生第二个气相粒子。
6. 支持face边界和显式surf表面；支持串行、MPI replicated surf以及global surfs explicit/distributed模式。

二、in文件命令格式
surf_react                  ID                gamma             file_name          surf|face     Tw      n_site     [init_cover species fraction]... [tally_only yes|no] [species gamma]...

参数说明：
ID：人为定义的反应模型ID。
gamma：新风格关键词。
file_name：反应文件名，例如gamma.surf。
surf或face：与adsorb风格含义相同。
Tw：壁面温度，单位K，必须大于0。
n_site：位点数密度，必须大于0。
init_cover species fraction：可重复使用，为不同物种设置初始覆盖度；各覆盖度均在0～1之间，总和不能超过1。
tally_only yes|no：可选，默认为no。
species gamma：物种名与其复合系数成对给出；未给出的物种gamma=0。

示例：
surf_react recomb gamma gamma.surf face 1000 6.022e18 init_cover O 0.25 init_cover N 0.10 tally_only no O 0.5 N 0.2
bound_modify zlo react recomb

注意：gamma风格没有nsync和schu关键词。

三、gamma反应文件格式
有效信息严格两行一组：
O + O --> O2
8.19e-19

或：
N + O --> NO
5.20e-19

第一行为A + B --> C，只允许两个反应物和一个气相产物。
第二行为反应热h，表示真实物理世界中每一次反应的热量，单位J。
h>0表示向壁面放热；h<0表示从壁面吸热；h=0表示无化学热。


四、事件处理规则
1. 入射物种A首先以gamma_A的概率进入表面化学分支；未通过则执行外部surf_collide所设置的普通壁面散射。
2. 通过gamma判断后，在当前表面的全部位点中均匀抽取一个位点。
3. 抽到空位：A吸附到壁面，气相粒子被删除，表面增加一个A(s)。该吸附过程不属于反应文件中的反应，因此不增加反应计数。
4. 抽到B(s)且文件中存在A+B-->C：消耗一个B(s)，将出射气相粒子改为C，并在Tw下进行完全漫反射。
5. 抽到已占据位点但没有对应反应：不发生化学反应，执行普通壁面散射。

五、能量与热流统计
吸附到空位：
echem = 0
etot = E入射
即入射粒子被壁面吸收，其平动、转动和振动能全部计入壁面能量；对于单原子O，转动和振动能为0，因此只贡献平动能。

发生复合反应：
echem = h
etot = E入射 - E出射产物 + h
其中正值表示加热壁面，负值表示冷却壁面。出射产物的平动能按照Tw采样；转动和振动能使用SPARTA原有的能量采样接口，在相应碰撞能量模式开启时按照Tw采样。
compute boundary和compute surf输出时仍会按照SPARTA原有规则进行fnum、weight、面积和时间步归一化；反应文件中的h本身始终是J/真实反应。

六、tally_only说明
tally_only yes时，只统计已经通过gamma判断、抽到占据位点且能够匹配反应文件的候选复合反应。
不消耗表面覆盖物，不改变气相物种，不执行化学热echem，也不吸附空位粒子。
候选反应记录在sr_ID统计量中，但nsreact不增加。
之后粒子仍执行普通surf_collide散射，所以普通非反应壁面碰撞造成的粒子能量交换仍可出现在etot中，echem保持0。

七、MPI处理
face模式下，各进程保存局部覆盖度增量，并在每个时间步通过MPI_Allreduce同步。
显式surf模式下，按照surface ID归并增量，再将所有者状态spread到本地及ghost表面。
支持普通显式表面和global surfs explicit/distributed表面。
每个gamma反应ID使用独立的gamma_ID_*表面自定义属性，避免多个gamma模型互相覆盖状态。
同步后检查表面粒子数，若出现负数或超过位点容量则直接报错，不静默破坏守恒。

八、验证结果
1. 空表面、满覆盖复合、tally_only、未指定gamma默认0均通过确定性测试。
2. N+O-->NO在N入射/O(s)和O入射/N(s)两个方向均通过，产物均为唯一气相NO。
3. gamma=0.5串行统计：1557次候选/3174次撞壁=0.4905，与0.5一致。
4. 正、零、负反应热的echem和etot符号与公式一致。
5. 两进程face实际反应测试：3120次反应准确生成3120个O2，总气相粒子数守恒。
6. 两进程distributed explicit surf测试：991次反应准确生成991个O2。
7. Windows串行程序spa_serial.exe和WSL MPI程序spa_mpi均已编译；spa_mpi位于：
D:\博一\气固相互作用\202607_src\src\spa_mpi
8. 当前实现为标准CPU/MPI路径，尚未新增专用Kokkos反应内核。

原有GS/PS能量热流处理保持现状，本次gamma功能没有修改surf_react_adsorb.cpp和surf_react_adsorb.h。
—————————————————————————————————————————————————————————————————————————————————————————————
20260729版本修改：
若粒子抽中了未定义的反应，则两粒子同时散射而非撞击粒子散射吸附粒子保持不动