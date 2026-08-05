%% Compare two 80 km noleave calculations with Zuppardi references
% Each calculation folder contributes only its largest numeric timestep.

clear; clc; close all;

%% Settings
baseDir = fileparts(mfilename('fullpath'));
catalyticDir = fileparts(baseDir);
caseInfo = struct( ...
    'folder', {'80_gCO_g1', '80_gCO_onlyone'}, ...
    'label', {'gank1 noallow + noleave', 'only_one + noleave'});
heatFluxField = 'f_2[10]';
shoulderX = 0.8477;
tol = 1.0e-7;
plotArcLengthMax = 1.8;
paperFCFile = fullfile(catalyticDir, 'zupparid', '80kmFC热流.csv');
paperNCFile = fullfile(catalyticDir, 'zupparid', '80kmNC热流.csv');
outputFile = fullfile(baseDir, '80km_noleave_comparison.png');

%% Read latest result from each folder
nCases = numel(caseInfo);
results = cell(nCases, 1);
steps = zeros(nCases, 1);
fprintf('80 km noleave comparison (latest snapshot per folder)\n');
fprintf('%-30s %12s %14s\n', 'Case', 'Step', 'Peak (kW/m2)');
fprintf('%s\n', repmat('-', 1, 60));
for iCase = 1:nCases
    caseDir = fullfile(baseDir, caseInfo(iCase).folder);
    [surfFile, steps(iCase)] = findLatestSurf(caseDir);
    results{iCase} = extractHeatShield(surfFile, heatFluxField, ...
        shoulderX, tol);
    fprintf('%-30s %12d %14.6f\n', caseInfo(iCase).label, ...
        steps(iCase), max(results{iCase}.q) / 1000);
end

paperFC = readReferenceCurve(paperFCFile);
paperNC = readReferenceCurve(paperNCFile);

%% One comparison figure
fig = figure('Color', 'w', 'Position', [90, 80, 1320, 780]);
ax = axes(fig); hold(ax, 'on');
ax.Toolbar.Visible = 'off';
plot(ax, results{1}.s, results{1}.q / 1000, '-', ...
    'Color', [0.85, 0.20, 0.12], 'LineWidth', 3.0, ...
    'DisplayName', sprintf('%s (%d steps)', caseInfo(1).label, steps(1)));
plot(ax, results{2}.s, results{2}.q / 1000, '--', ...
    'Color', [0.05, 0.35, 0.78], 'LineWidth', 3.0, ...
    'DisplayName', sprintf('%s (%d steps)', caseInfo(2).label, steps(2)));
plot(ax, paperFC.s, paperFC.q, 'ko--', ...
    'LineWidth', 2.8, 'MarkerSize', 8, 'MarkerFaceColor', 'w', ...
    'DisplayName', 'Zuppardi paper FC');
plot(ax, paperNC.s, paperNC.q, 'ks:', ...
    'LineWidth', 2.3, 'MarkerSize', 7, 'MarkerFaceColor', 'w', ...
    'DisplayName', 'Zuppardi paper NC');

box(ax, 'on'); grid(ax, 'off');
set(ax, 'FontName', 'Times New Roman', 'FontSize', 18, ...
    'LineWidth', 1.6, 'TickDir', 'in', ...
    'XMinorTick', 'on', 'YMinorTick', 'on', 'Layer', 'top');
xlim(ax, [0, plotArcLengthMax]);
xlabel(ax, 'Surface arc length from stagnation point, s (m)', ...
    'FontSize', 21, 'FontWeight', 'bold');
ylabel(ax, 'Heat flux (kW/m^2)', ...
    'FontSize', 21, 'FontWeight', 'bold');
title(ax, 'Orion 80 km: effect of noleave in gank1 and only_one modes', ...
    'FontSize', 21, 'FontWeight', 'bold');
legend(ax, 'Location', 'eastoutside', 'Interpreter', 'none', ...
    'FontName', 'Times New Roman', 'FontSize', 14, 'Box', 'off');
exportgraphics(fig, outputFile, 'Resolution', 300);
fprintf('\nFigure saved to:\n%s\n', outputFile);

%% Local functions
function [surfFile, step] = findLatestSurf(caseDir)
    files = dir(fullfile(caseDir, '**', '80surf.*.dat'));
    steps = nan(numel(files), 1);
    valid = false(numel(files), 1);
    for iFile = 1:numel(files)
        token = regexp(files(iFile).name, ...
            '^80surf\.(\d+)\.dat$', 'tokens', 'once');
        if ~isempty(token)
            steps(iFile) = sscanf(token{1}, '%f', 1);
            valid(iFile) = true;
        end
    end
    files = files(valid); steps = steps(valid);
    if isempty(files)
        error('No 80surf.<step>.dat found under %s.', caseDir);
    end
    [step, index] = max(steps);
    surfFile = fullfile(files(index).folder, files(index).name);
end

function result = extractHeatShield(fileName, heatFluxField, shoulderX, tol)
    data = readSurfDump(fileName);
    xMid = 0.5 .* (data.v1x + data.v2x);
    yMid = 0.5 .* (data.v1y + data.v2y);
    keep = xMid >= -tol & xMid <= shoulderX + tol & yMid >= -tol;
    qIndex = find(strcmp(data.names, heatFluxField), 1);
    if isempty(qIndex)
        error('Missing %s in %s.', heatFluxField, fileName);
    end
    x1 = data.v1x(keep); y1 = data.v1y(keep);
    x2 = data.v2x(keep); y2 = data.v2y(keep);
    q = data.values(keep, qIndex);
    [~, order] = sort(yMid(keep), 'ascend');
    x1 = x1(order); y1 = y1(order);
    x2 = x2(order); y2 = y2(order); q = q(order);
    lengths = hypot(x2 - x1, y2 - y1);
    result.s = cumsum(lengths) - 0.5 .* lengths;
    result.q = q;
end

function data = readSurfDump(fileName)
    fid = fopen(fileName, 'rt');
    if fid < 0, error('Cannot open %s.', fileName); end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
    names = {};
    while ~feof(fid)
        line = strtrim(fgetl(fid));
        if startsWith(line, 'ITEM: SURFS')
            words = strsplit(line); names = words(3:end); break;
        end
    end
    if isempty(names), error('SURFS header missing in %s.', fileName); end
    values = textscan(fid, repmat('%f', 1, numel(names)), ...
        'CollectOutput', true, 'MultipleDelimsAsOne', true, ...
        'Delimiter', {' ', '\t'});
    values = values{1};
    data.names = names; data.values = values;
    for name = {'v1x', 'v1y', 'v2x', 'v2y'}
        index = find(strcmp(names, name{1}), 1);
        if isempty(index), error('Missing %s in %s.', name{1}, fileName); end
        data.(name{1}) = values(:, index);
    end
end

function curve = readReferenceCurve(fileName)
    if ~isfile(fileName), error('Reference file missing: %s', fileName); end
    values = readmatrix(fileName, 'NumHeaderLines', 1);
    values = values(:, 1:2);
    values = values(all(isfinite(values), 2), :);
    values = sortrows(values, 1);
    curve.s = values(:, 1); curve.q = values(:, 2);
end
