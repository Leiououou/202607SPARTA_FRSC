% 改进版：修正压强等小数值的输出精度（新增温度+数密度输入类型）
clear; clc; close all;

%% 第一步：选择已知量类型（新增第三种类型）
fprintf('请选择已知的参数类型：\n');
fprintf('1. 压强(p)、组分比例、温度(T)\n');
fprintf('2. 密度(ρ)、组分比例、温度(T)\n');
fprintf('3. 数密度(n)、组分比例、温度(T)\n'); % 新增类型
known_type = input('请输入选项（1/2/3）：');
while known_type ~= 1 && known_type ~= 2 && known_type ~= 3
    fprintf('输入错误！请重新选择：\n');
    fprintf('1. 压强+组分+温度 | 2. 密度+组分+温度 | 3. 数密度+组分+温度\n');
    known_type = input('请输入选项（1/2/3）：');
end

%% 第二步：输入计算维度
dim = input('\n请输入计算维度（2或3）：');
while dim ~= 2 && dim ~= 3
    fprintf('输入错误！请输入2（二维）或3（三维）。\n');
    dim = input('请重新输入计算维度（2或3）：');
end

%% 第三步：输入计算域尺寸
Lx = input('请输入计算域长度Lx (单位：m)：');
Ly = input('请输入计算域宽度Ly (单位：m)：');
if dim == 2
    Lz = 1;  % 二维时z方向长度固定为1
    nz = 1;  % 二维时z方向网格数固定为1
    fprintf('二维计算，自动设置Lz = 1 m，nz = 1\n');
else
    Lz = input('请输入计算域高度Lz (单位：m)：');  % 三维手动输入
end

%% 第四步：输入通用参数（与已知量类型无关）
n_percell = input('请输入每网格中粒子数n_percell：');
d = input('请输入网格相对于自由程的比例d：');

%% 第五步：输入已知量（根据类型区分）
% 组分信息
species_name = {'N2', 'O2', 'NO', 'N', 'O', 'CO2', 'CO', 'C', 'Ar'};
Mass_list = [4.65E-26, 5.31E-26, 4.98E-26, 2.325E-26, 2.65E-26, ...
             7.31E-26, 4.65E-26, 1.99E-26, 6.63E-26];                 % 分子质量(kg)
dref_list = [4.17E-10, 4.07E-10, 4.20E-10, 3.00E-10, 3.00E-10, ...
             5.62E-10, 4.19E-10, 4.00E-10, 4.11E-10];                % VSS参考直径(m)
omega_list = [0.74, 0.77, 0.79, 0.80, 0.80, 0.93, 0.73, 0.8066, 0.81]; % 黏性温度指数
Tref_list = [273, 273, 273, 273, 273, 273, 273, 3000, 273.15];       % VSS参考温度(K)
nspecies = numel(species_name);
assert(all([numel(Mass_list), numel(dref_list), numel(omega_list), ...
            numel(Tref_list)] == nspecies), '物种参数数组长度不一致。');
niu_list = omega_list - 0.5;
Kc = 1.38066e-23;  % 玻尔兹曼常数(J/K)
Vdsmc = Lx * Ly * Lz;  % 计算域体积(m^3)

% 输入组分摩尔分数（自动归一化）
fprintf('\n请输入各组分的摩尔分数（共%d种：%s）\n', ...
    nspecies, strjoin(species_name, ', '));
frac_list = zeros(1, nspecies);
for i = 1:nspecies
    frac_list(i) = input(sprintf('组分%s的摩尔分数：', species_name{i}));
end
if any(~isfinite(frac_list)) || any(frac_list < 0) || sum(frac_list) <= 0
    error('摩尔分数必须是有限非负数，且总和必须大于0。');
end
frac_list = frac_list / sum(frac_list);  % 归一化处理
fprintf('归一化后的摩尔分数：');
for i = 1:nspecies
    fprintf('%s: %.3f ', species_name{i}, frac_list(i));
end
fprintf('\n');

% 输入温度和已知状态量（p/ρ/n）
T = input('\n请输入热力学温度T (单位：K)：');
if known_type == 1
    % 已知压强p：计算数密度n = p/(Kc*T)
    p = input('请输入气体压强p (单位：Pa)：');
    n = p / (Kc * T);  % 总分子数密度(m^-3)
    rho = n * sum(Mass_list .* frac_list);  % 计算密度(kg/m^3)
elseif known_type == 2
    % 已知密度ρ：通过平均摩尔质量计算数密度
    rho = input('请输入气体密度ρ (单位：kg/m^3)：');
    m_avg = sum(Mass_list .* frac_list);  % 平均分子质量(kg)
    n = rho / m_avg;  % 总分子数密度(m^-3)
    p = n * Kc * T;   % 计算压强(Pa)
else
    % 新增类型3：已知总分子数密度n，计算压强和密度
    n = input('请输入总分子数密度n (单位：m^-3)：');
    p = n * Kc * T;  % 计算压强(Pa)
    m_avg = sum(Mass_list .* frac_list);  % 平均分子质量(kg)
    rho = n * m_avg;  % 计算密度(kg/m^3)
end

%% 第六步：核心参数计算
n_list = n * frac_list;  % 各组分数密度(m^-3)

% 计算各组分平均自由程和碰撞时间
lambda_d_list = zeros(1, nspecies);
lambda_list = zeros(1, nspecies);
t_d_list = zeros(1, nspecies);
t_list = zeros(1, nspecies);
for q = 1:nspecies
    for i = 1:nspecies
        niu_i = mean([niu_list(q), niu_list(i)]);
        Tref_ij = mean([Tref_list(q), Tref_list(i)]);
        mr = Mass_list(q) * Mass_list(i) / (Mass_list(q) + Mass_list(i));
        % 累加平均自由程倒数项
        lambda_d_list(q) = lambda_d_list(q) + ...
            (power(Tref_ij/T, niu_i) * n_list(i) * pi * ...
            power(mean([dref_list(q), dref_list(i)]), 2) * ...
            sqrt(1 + Mass_list(q)/Mass_list(i)));
        % 累加碰撞时间倒数项
        t_d_list(q) = t_d_list(q) + ...
            power(T/Tref_ij, 0.5 - niu_i) * 2 * n_list(i) * ...
            power(mean([dref_list(q), dref_list(i)]), 2) * ...
            sqrt(2 * pi * Kc * Tref_ij / mr);
    end
    lambda_list(q) = 1 / lambda_d_list(q);
    t_list(q) = 1 / t_d_list(q);
end

% 混合物平均参数（按数密度加权）
lambda = sum(lambda_list .* (n_list / n));
t_dsmc = sum(t_list .* (n_list / n));

% 网格与粒子权重计算
dL = lambda * d;
nx = Lx / dL;
ny = Ly / dL;
if dim == 3
    nz = Lz / dL;
end
fnum = n * Vdsmc / (nx * ny * nz * n_percell);

%% 第七步：输出结果（优化格式，支持小数值显示）
fprintf('\n===== 计算结果（%d维，类型%d）=====\n', dim, known_type);
fprintf('计算域尺寸：Lx = %.3f m, Ly = %.3f m, Lz = %.3f m\n', Lx, Ly, Lz);
fprintf('温度：T = %.1f K\n', T);

% 按类型输出已知量和计算量，均用科学计数法确保精度
if known_type == 1
    fprintf('已知压强：p = %e Pa | 计算密度：ρ = %e kg/m^3 | 总分子数密度：n = %e m^-3\n', p, rho, n);
elseif known_type == 2
    fprintf('已知密度：ρ = %e kg/m^3 | 计算压强：p = %e Pa | 总分子数密度：n = %e m^-3\n', rho, p, n);
else
    fprintf('已知总分子数密度：n = %e m^-3 | 计算压强：p = %e Pa | 计算密度：ρ = %e kg/m^3\n', n, p, rho);
end

fprintf('混合物平均自由程：lambda = %e m\n', lambda);
fprintf('混合物平均碰撞时间：t_dsmc = %e s\n', t_dsmc);

% 最小组分参数
[min_lambda, min_lambda_idx] = min(lambda_list);
fprintf('最小组分平均自由程：lambda_min = %e m（组分：%s）\n', min_lambda, species_name{min_lambda_idx});
[min_t, min_t_idx] = min(t_list);
fprintf('最小组分平均碰撞时间：t_min = %e s（组分：%s）\n', min_t, species_name{min_t_idx});

fprintf('网格尺寸：dL = %e m\n', dL);
fprintf('网格数量：nx = %.1f, ny = %.1f, nz = %.1f\n', nx, ny, nz);
fprintf('粒子权重：fnum = %e\n', fnum);
