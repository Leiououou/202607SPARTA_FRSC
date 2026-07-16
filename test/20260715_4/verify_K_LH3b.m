% verify_K_LH3b.m
% 验证带体相的 LH3: O(g) + C(b) --> CO(s) 的 K_DSMC vs K_theory
% 核心验证点: 体相反应物 C(b) 的 Gamma_b = 1 (数密度视为常数, 不修正概率)
%
% 与 20260715_3 (O(g)+O(s)-->O2(s)) 的关键区别:
%   s 相反应物换成了 C(b), 概率只含【一个】表面密度因子 (空位 n(S), 来自 coeff[3]=1):
%   P(Vn) = min(1, 2 * K * n(S) / Vn)          <-- C(b) 贡献 Gamma_b = 1
%
% === 两种 K 反算方法 ===
%
% 方法1 — Molchanova Eq.(52) 碰撞概率反算:
%   系综平均: K = P_bar / (2 * n(S) * <1/Vn>)   <-- 只除一个 n_S
%   <1/Vn> = sqrt(pi*m/(2*k*T))
%
% 方法2 — 反应速率定义直接反算 (n_Cb 按约定取常数 1, 已吸收进 A):
%   dn_cos/dt = K * n_og * n_s * n_Cb = K * n_og * n_s
%   K = (N_react * fnum / se / t_total) / (n_og * n_S)
%   注意: N_react 是模拟粒子计数(需 x fnum); se 为 2D 面的真实面积(y宽 x 1m深)
%
% K_theory = A * T^b * exp(-Ea/T)
%
% 判据: 若 ratio ≈ 1, 证明 Gamma_b=1 实现正确;
%       若 ratio 恰差 n_S 或 N_site 的倍数, 说明 b 相被多乘/多除了一次

clear; close all;

%% ====== 物理常数 ======
k_B = 1.380649e-23;      % Boltzmann (J/K)
m_O = 2.65E-26; % O 原子质量 (kg)

%% ====== 模拟参数 (来自 in.LH3) ======
nsteps   = 5000;          % 运行步数
dt       = 1e-6;          % 时间步长 (s)
t_total  = nsteps * dt;   % 总模拟时间 (s)
n_og     = 4.138807e+20;  % 气相 O 数密度 (m^-3), 来自 global nrho
fnum     = 1.4900e+11;    % 每个模拟粒子代表的真实原子数, 来自 global fnum
se       = 6e-3 ;   % xhi 反应面面积 (m^2): 2D 算例, y 向 6mm x z 向隐含深度 1m

%% ====== 反应参数 (来自 schu_gs_1.surf: LH3 A 5.2e-20 0.5 5000 1) ======
A   = 5.2e-20;
b   = 0.5;
Ea  = 5000;              % K

%% ====== 表面参数 (来自 in.LH3: max_cover 6.022e18, init_cover O 0.5) ======
N_site    = 6.022e18;           % 总位点密度 (m^-2)
cov_frac  = 0.5;                % init_cover fraction (O 占据, tally_only 下恒定)
n_S       = (1-cov_frac) * N_site;  % 空位 S 数密度 (m^-2)
n_Cb      = 1;                  % 体相 C(b) 数密度取常数 1 (已吸收进 A)

%% ====== 模拟温度 (K) ======
T = [700, 800, 900, 1000, 1100, 1200, 1300, 1400, ...
     1500, 1600, 1700, 1800, 1900, 2000]';

%% ====== 从 log.sparta 提取 (2026-07-16, A=5.2e-20, 5000 步, tally_only) ======
% Surface reaction tallies: reaction O(g) + C(b) --> CO(s)
N_react = [269; 718; 1567; 2842; ...
           4619; 7168; 10294; 14003; ...
           18010; 23040; 28646; 34503; ...
           41233; 47923];

% Boundary collides (4 个边界面总数, /4 得 xhi 反应面碰撞数)
% 与 20260715_2/3 逐点相同 (相同 seed 和气相工况, tally_only 不改状态)
N_coll = [80323932; 85861235; 91050146; 95985218; ...
          100677534; 105174265; 109434151; 113566377; ...
          117559173; 121412098; 125170445; 128783559; ...
          132290130; 135726644]/4;

%% ====== 计算 ======
P_bar   = N_react ./ N_coll;                    % 平均反应概率
Vn_1    = sqrt(pi * m_O ./ (2 * k_B * T));      % <1/Vn> (flux-weighted harmonic mean)

% ---- 方法1: Molchanova Eq.(52) 碰撞概率反算 (只除一个 n_S) ----
K_DSMC_eq52 = (N_react ./ N_coll) ./ (2 * n_S .* Vn_1);

% ---- 方法2: dn_cos/dt = K * n_og * n_s  直接反算 (n_Cb=1) ----
dncos_dt = N_react * fnum ./ (se * t_total);     % N_react 为模拟粒子数, x fnum 换算真实反应数
K_DSMC_rate = dncos_dt ./ (n_og * n_S * n_Cb);   % K = (dn_cos/dt) / (n_og * n_s * n_Cb)

% K_theory = A * T^b * exp(-Ea/T)
K_theory = A * T.^b .* exp(-Ea ./ T);

ratio_eq52 = K_DSMC_eq52 ./ K_theory;
ratio_rate = K_DSMC_rate ./ K_theory;

% ---- min(1,P) 截断修正: 带截断的解析期望 (通量加权 Maxwell 分布) ----
% P(Vn) = min(1, a/Vn), a = 2*K_theory*n_S   <-- 只有一个 n_S
% f(v) = (v/s^2)*exp(-v^2/(2s^2)), s = sqrt(kT/m)
% P_capped = [1 - exp(-a^2/2s^2)] + (a/s)*sqrt(pi/2)*erfc(a/(sqrt(2)*s))
% P_uncapped = (a/s)*sqrt(pi/2)
a_cap    = 2 * K_theory * n_S;                       % 截断临界速度 (m/s)
s_th     = sqrt(k_B * T / m_O);                      % 热速度尺度 (m/s)
P_capped = (1 - exp(-a_cap.^2 ./ (2*s_th.^2))) + ...
           (a_cap./s_th) * sqrt(pi/2) .* erfc(a_cap ./ (sqrt(2)*s_th));
C_cap    = P_capped ./ ((a_cap./s_th) * sqrt(pi/2)); % 截断损失因子 C(T) <= 1
ratio_corr = ratio_eq52 ./ C_cap;                    % 截断修正后的 ratio

%% ====== 输出表格 ======
fprintf('========== LH3(带体相): O(g)+C(b)-->CO(s)  K_DSMC 验证 ==========\n');
fprintf('反应参数: A=%.1e, b=%.1f, Ea=%d K\n', A, b, Ea);
fprintf('n_og = %.4e m^-3,  n(S) = %.4e m^-2  (%.0f%% cover),  n_Cb = %g (常数约定)\n', ...
    n_og, n_S, cov_frac*100, n_Cb);
fprintf('se = %.2e m^2,  t_total = %.4f s\n\n', se, t_total);

fprintf('  T(K)     P_bar       N_react      N_coll\n');
fprintf('  ----     -----       -------      ------\n');
for i = 1:length(T)
    fprintf('%5d    %.4e    %9.3e  %10d\n', ...
        T(i), P_bar(i), N_react(i), N_coll(i));
end

fprintf('\n===== 方法1: Molchanova Eq.(52) 碰撞概率反算 =====\n');
fprintf('  T(K)      K_DSMC(eq52)    K_theory         ratio\n');
fprintf('  ----      ------------    --------         -----\n');
for i = 1:length(T)
    fprintf('%5d    %12.4e    %12.4e    %8.2f\n', ...
        T(i), K_DSMC_eq52(i), K_theory(i), ratio_eq52(i));
end
fprintf('\nratio(eq52) 均值 = %.2f +/- %.2f\n', mean(ratio_eq52), std(ratio_eq52));

fprintf('\n===== 方法2: dn_cos/dt = K * n_og * n_s  直接反算 =====\n');
fprintf('  T(K)      K_DSMC(rate)    K_theory         ratio\n');
fprintf('  ----      ------------    --------         -----\n');
for i = 1:length(T)
    fprintf('%5d    %12.4e    %12.4e    %8.2f\n', ...
        T(i), K_DSMC_rate(i), K_theory(i), ratio_rate(i));
end
fprintf('\nratio(rate) 均值 = %.2f +/- %.2f\n', mean(ratio_rate), std(ratio_rate));

fprintf('\n===== 两方法交叉验证 =====\n');
fprintf('ratio_eq52 / ratio_rate 均值 = %.2f\n', mean(ratio_eq52 ./ ratio_rate));
fprintf('若 ≈ 1, 两方法等价且 se 面积参数正确\n');

fprintf('\n===== min(1,P) 截断修正 =====\n');
fprintf('a = 2K·nS (本算例只有一个 nS 因子), 预期 a/s ~ 1e-3, 截断可忽略\n');
fprintf('  T(K)    a(m/s)    a/s      C(T)    P_bar实测   P_capped解析   ratio修正后\n');
fprintf('  ----    ------    ---      ----    --------    ----------    ----------\n');
for i = 1:length(T)
    fprintf('%5d    %6.4f    %.2e    %.4f    %.4e    %.4e    %8.3f\n', ...
        T(i), a_cap(i), a_cap(i)/s_th(i), C_cap(i), P_bar(i), P_capped(i), ratio_corr(i));
end

fprintf('\n===== Gamma_b = 1 验证判据 =====\n');
fprintf('ratio ≈ 1            --> 体相反应物 Gamma_b=1 实现正确\n');
fprintf('ratio ~ n_S (3e18)   --> b 相被当成 s 相多乘了一次密度\n');
fprintf('ratio ~ 1/n_S        --> b 相被多除了一次密度\n');

%% ====== 绘图 ======
figure('Position', [100 100 1200 800]);

% (1) P_bar vs T
subplot(2,3,1);
plot(T, P_bar, 'ro-', 'LineWidth', 1.5, 'MarkerSize', 6);
xlabel('T (K)'); ylabel('P_{bar}');
title('平均反应概率 P_{bar} = N_{react}/N_{coll}');
grid on;

% (2) N_react vs T
subplot(2,3,2);
plot(T, N_react/1e4, 'bo-', 'LineWidth', 1.5, 'MarkerSize', 6);
xlabel('T (K)'); ylabel('N_{react} (10^4)');
title('反应计数');
grid on;

% (3) N_coll vs T
subplot(2,3,3);
plot(T, N_coll/1e6, 'go-', 'LineWidth', 1.5, 'MarkerSize', 6);
xlabel('T (K)'); ylabel('N_{coll} (10^6)');
title('边界碰撞数');
grid on;

% (4) dncos/dt vs T
subplot(2,3,4);
plot(T, dncos_dt, 'co-', 'LineWidth', 1.5, 'MarkerSize', 6);
xlabel('T (K)'); ylabel('dn_{cos}/dt (m^{-2}s^{-1})');
title('反应速率 dn_{cos}/dt');
grid on;

% (5) K comparison — 方法1 Eq.(52)
subplot(2,3,5);
loglog(T, K_DSMC_eq52, 'rs-', 'LineWidth', 1.5, 'MarkerSize', 6); hold on;
loglog(T, K_theory, 'k-', 'LineWidth', 2);
xlabel('T (K)');
title('方法1: K_{DSMC}(eq52) vs K_{theory}');
legend('K_{DSMC} eq52', 'K_{theory}', 'Location', 'nw');
grid on;

% (6) K comparison — 方法2 rate definition
subplot(2,3,6);
loglog(T, K_DSMC_rate, 'bo-', 'LineWidth', 1.5, 'MarkerSize', 6); hold on;
loglog(T, K_theory, 'k-', 'LineWidth', 2);
xlabel('T (K)');
title('方法2: K_{DSMC}(rate) vs K_{theory}');
legend('K_{DSMC} rate', 'K_{theory}', 'Location', 'nw');
grid on;

sgtitle('LH3(带体相): O(g)+C(b)\rightarrowCO(s)  --  A=5.2e-20, init\_cover=0.5, tally\_only, \Gamma_b=1');

%% ====== 保存数据 ======
save('verify_K_LH3b_data.mat', 'T', 'P_bar', 'N_react', 'N_coll', ...
     'K_DSMC_eq52', 'K_DSMC_rate', 'K_theory', ...
     'ratio_eq52', 'ratio_rate', 'dncos_dt', ...
     'a_cap', 'C_cap', 'P_capped', 'ratio_corr', ...
     'n_S', 'n_Cb', 'n_og', 'se', 't_total', 'N_site');
fprintf('\n数据已保存至 verify_K_LH3b_data.mat\n');
