% K_ER_validation.m
% DSMC统计反算ER速率常数 vs 输入速率常数
% 温度扫描: 700~2000K, 步长100K
% 反应: O(g) + O(s) --> O2(g)
% 日期: 2026-07-14

clear; close all;

%% ============== 模拟参数 ==============
Lx     = 6e-3;          % 盒子x方向长度 [m]
Ly     = 6e-3;          % 盒子y方向长度 [m]
N_site = 6.022e18;      % 表面位点密度 [m^-2]
Np     = 99998;         % 模拟粒子总数
dt     = 1e-6;          % 时间步长 [s]
N_step = 50000;         % 每轮步数
t_sim  = N_step * dt;   % 模拟物理时间 [s]

% ER速率常数输入参数 (来自schu_gs_1.surf)
A_ER    = 1e-16;        % 指前因子 [m^3/s]
beta_ER = 0;            % 温度指数
Ea_ER   = 7654;         % 活化温度 [K]  (Ea/k)

%% ============== 温度扫描 ==============
T = (700:100:2000)';    % 14个温度点 [K]

%% ============== 从log提取的ER tally数据 ==============
% reaction all (即 O(g)+O(s)-->O2(g) 的唯一GS反应)
N_ER = [
    8903;                % T =  700 K
    35070;               % T =  800 K
    101394;              % T =  900 K
    238131;              % T = 1000 K
    475943;              % T = 1100 K
    850767;              % T = 1200 K
    1.38862e6;           % T = 1300 K
    2.11394e6;           % T = 1400 K
    3.04274e6;           % T = 1500 K
    4.18010e6;           % T = 1600 K
    5.53339e6;           % T = 1700 K
    7.09304e6;           % T = 1800 K
    8.85909e6;           % T = 1900 K
    1.08138e7;           % T = 2000 K
];

% 总边界碰撞次数 (取自 log 中 Boundary collides)
Boundary_collides = [
    802951345;           % T =  700 K
    858470124;           % T =  800 K
    910463178;           % T =  900 K
    959700447;           % T = 1000 K
    1006533585;          % T = 1100 K
    1051296093;          % T = 1200 K
    1094288903;          % T = 1300 K
    1135458615;          % T = 1400 K
    1175483566;          % T = 1500 K
    1213904398;          % T = 1600 K
    1251440629;          % T = 1700 K
    1287685550;          % T = 1800 K
    1322906128;          % T = 1900 K
    1357329329;          % T = 2000 K
];

%% ============== 计算 K_DSMC ==============
% N_hits_xhi = Boundary_collides / 4  (4个等面积壁面, xhi占1/4)
% ⟨1/Vn⟩ = sqrt(pi*m/(2*kB*T))  (flux-averaged inverse normal velocity)
% K_DSMC = N_ER / (2 * N_site * N_hits_xhi * ⟨1/Vn⟩)

m_O = 2.65e-26;                  % O原子质量 [kg]
k_B = 1.380649e-23;              % Boltzmann常数 [J/K]

N_hits_xhi = Boundary_collides / 4;                      % xhi面实际碰撞数
inv_Vn_avg = sqrt(pi * m_O ./ (2 * k_B * T));            % ⟨1/Vn⟩ [s/m]
K_DSMC = N_ER ./ (2 * N_site * N_hits_xhi .* inv_Vn_avg); % [m^3/s]

%% ============== 计算 K_input ==============
% 公式: K = A * (T/T_ref)^beta * exp(-Ea/T)
K_input = A_ER * (T/1000).^beta_ER .* exp(-Ea_ER ./ T);

%% ============== 计算相对偏差 ==============
deviation = (K_DSMC - K_input) ./ K_input * 100;  % 百分比

%% ============== 验证: BC/4 vs 解析N_hits ==============
% 理论边界碰撞数 (应与BC/4一致)
flux_theory = (Np / (Lx * Ly)) .* sqrt(k_B * T ./ (2 * pi * m_O));
N_hits_theory = flux_theory * Ly * t_sim;
fprintf('\nBC/4 vs 解析碰撞数:\n');
fprintf('  平均偏差: %.2f%%\n', mean(abs(N_hits_xhi - N_hits_theory) ./ N_hits_theory * 100));

%% ============== 打印结果表 ==============
fprintf('\n========== K_ER 验证结果 ==========\n');
fprintf('反应: O(g) + O(s) --> O2(g)\n');
fprintf('K_input = %.1e * exp(-%.0f/T) [m^3/s]\n\n', A_ER, Ea_ER);
fprintf('  T[K]   N_ER         K_DSMC        K_input       Dev[%%]\n');
fprintf('  ----   ----------   -----------   -----------   ------\n');
for i = 1:length(T)
    fprintf('  %4d   %10.4e  %10.3e  %10.3e  %+6.2f\n', ...
        T(i), N_ER(i), K_DSMC(i), K_input(i), deviation(i));
end
fprintf('\n平均绝对偏差: %.2f%%\n', mean(abs(deviation)));

%% ============== 图1: K_DSMC vs K_input ==============
figure('Position', [100 100 900 650]);

subplot(2,2,1);
loglog(T, K_DSMC, 'ro-', 'LineWidth', 1.5, 'MarkerSize', 6, 'DisplayName', 'K_{DSMC} (tally反算)');
hold on;
loglog(T, K_input, 'b--', 'LineWidth', 1.5, 'DisplayName', 'K_{input} (Arrhenius)');
xlabel('温度 T [K]');
ylabel('K_{ER} [m^3/s]');
title('ER速率常数: DSMC vs 输入');
legend('Location', 'northwest');
grid on;
set(gca, 'FontSize', 11);

%% ============== 图2: 相对偏差 ==============
subplot(2,2,2);
plot(T, deviation, 'ko-', 'LineWidth', 1.5, 'MarkerSize', 6, 'MarkerFaceColor', 'k');
hold on;
yline(0, 'r--', 'LineWidth', 1);
xlabel('温度 T [K]');
ylabel('相对偏差 [%]');
title(sprintf('相对偏差 (均值 |dev| = %.2f%%)', mean(abs(deviation))));
grid on;
set(gca, 'FontSize', 11);

%% ============== 图3: N_ER tally vs 温度 ==============
subplot(2,2,3);
semilogy(T, N_ER, 'rs-', 'LineWidth', 1.5, 'MarkerSize', 6, 'MarkerFaceColor', 'r');
xlabel('温度 T [K]');
ylabel('ER 反应 tally 计数 N_{ER}');
title('DSMC Tally: ER反应次数 vs 温度');
grid on;
set(gca, 'FontSize', 11);

%% ============== 图4: Arrhenius图 (ln K vs 1/T) ==============
subplot(2,2,4);
plot(1000./T, log(K_DSMC), 'ro-', 'LineWidth', 1.5, 'MarkerSize', 6, 'DisplayName', 'K_{DSMC}');
hold on;
plot(1000./T, log(K_input), 'b--', 'LineWidth', 1.5, 'DisplayName', 'K_{input}');
xlabel('1000 / T [K^{-1}]');
ylabel('ln(K_{ER})');
title('Arrhenius图 (斜率 = -E_a/k = -7654 K)');
legend('Location', 'northeast');
grid on;
set(gca, 'FontSize', 11);

sgtitle('K_{ER} 验证: DSMC Tally反算 vs Arrhenius输入', 'FontSize', 14, 'FontWeight', 'bold');

%% ============== 保存 ==============
saveas(gcf, 'K_ER_validation.png');
fprintf('\n图片已保存: K_ER_validation.png\n');
