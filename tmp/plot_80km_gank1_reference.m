%% 80 km non-conservative prob-style heat flux versus paper reference
% Reads every data/80surf.<timestep>.dat snapshot, plots the running-average
% heat-flux evolution, and overlays the digitized Zuppardi FC/NC curves.

clear; clc; close all;

%% Settings
caseDir = fileparts(mfilename('fullpath'));
dataDir = fullfile(caseDir, 'data');
fcFile = fullfile(caseDir, '80kmFC热流.csv');
ncFile = fullfile(caseDir, '80kmNC热流.csv');
heatFluxField = 'f_2[10]';
shoulderX = 0.8477;
geometryTolerance = 1.0e-7;
plotArcLengthMax = 1.8;
outputFile = fullfile(caseDir, '80km_prob_vs_paper_reference.png');

%% Read all valid surface snapshots
files = dir(fullfile(dataDir, '80surf.*.dat'));
steps = nan(numel(files), 1);
valid = false(numel(files), 1);
for i = 1:numel(files)
    token = regexp(files(i).name, '^80surf\.(\d+)\.dat$', 'tokens', 'once');
    if ~isempty(token)
        steps(i) = sscanf(token{1}, '%f', 1);
        valid(i) = true;
    end
end
files = files(valid);
steps = steps(valid);
[steps, order] = sort(steps);
files = files(order);
if isempty(files)
    error('No 80surf.<timestep>.dat files found in %s.', dataDir);
end

results = cell(numel(files), 1);
fprintf('80 km non-conservative prob style versus paper reference\n');
fprintf('%12s %16s %14s\n', 'Step', 'Peak (kW/m^2)', 'Peak s (m)');
for i = 1:numel(files)
    fileName = fullfile(files(i).folder, files(i).name);
    results{i} = extractHeatShield(fileName, heatFluxField, ...
        shoulderX, geometryTolerance);
    [peak, index] = max(results{i}.heatFlux);
    fprintf('%12d %16.6f %14.6f\n', steps(i), peak / 1000, ...
        results{i}.s(index));
end

paperFC = readReferenceCurve(fcFile);
paperNC = readReferenceCurve(ncFile);

%% Plot calculation history and paper reference values
fig = figure('Color', 'w', 'Position', [100, 80, 1250, 760]);
ax = axes(fig); hold(ax, 'on');
colors = parula(numel(files));
for i = 1:numel(files)
    width = 2.0;
    if i == numel(files), width = 3.2; end
    plot(ax, results{i}.s, results{i}.heatFlux / 1000, '-', ...
        'Color', colors(i, :), 'LineWidth', width, ...
        'DisplayName', sprintf('prob, %d steps', steps(i)));
end
plot(ax, paperFC.s, paperFC.q, 'o--', 'Color', [0.82, 0.10, 0.10], ...
    'LineWidth', 2.3, 'MarkerSize', 7, 'MarkerFaceColor', 'w', ...
    'DisplayName', 'Zuppardi FC');
plot(ax, paperNC.s, paperNC.q, 's--', 'Color', [0.05, 0.25, 0.72], ...
    'LineWidth', 2.3, 'MarkerSize', 7, 'MarkerFaceColor', 'w', ...
    'DisplayName', 'Zuppardi NC');

box(ax, 'on'); grid(ax, 'off');
set(ax, 'FontName', 'Times New Roman', 'FontSize', 18, ...
    'LineWidth', 1.5, 'TickDir', 'in', 'XMinorTick', 'on', ...
    'YMinorTick', 'on', 'Layer', 'top');
xlim(ax, [0, plotArcLengthMax]);
xlabel(ax, 'Surface arc length from stagnation point, s (m)', ...
    'FontSize', 20, 'FontWeight', 'bold');
ylabel(ax, 'Heat flux (kW/m^2)', 'FontSize', 20, 'FontWeight', 'bold');
title(ax, sprintf(['Orion 80 km: non-conservative prob style ', ...
    'versus Zuppardi reference (latest: %d steps)'], steps(end)), ...
    'FontSize', 20, 'FontWeight', 'bold', 'Interpreter', 'none');
legend(ax, 'Location', 'northeastoutside', 'FontName', ...
    'Times New Roman', 'FontSize', 14, 'Box', 'off');
exportgraphics(fig, outputFile, 'Resolution', 300);
fprintf('\nFigure saved to:\n%s\n', outputFile);

%% Latest-snapshot convergence check
if numel(results) >= 2
    latest = results{end};
    previousQ = interp1(results{end-1}.s, results{end-1}.heatFlux, ...
        latest.s, 'linear', 'extrap');
    difference = latest.heatFlux - previousQ;
    rmsRelative = sqrt(mean(difference.^2)) / ...
        max(sqrt(mean(latest.heatFlux.^2)), eps) * 100;
    maxNormalized = max(abs(difference)) / ...
        max(max(abs(latest.heatFlux)), eps) * 100;
    fprintf(['Latest running-average comparison: %d versus %d steps\n', ...
        '  RMS relative difference          = %.6g %%\n', ...
        '  Max difference / latest peak |q| = %.6g %%\n'], ...
        steps(end), steps(end-1), rmsRelative, maxNormalized);
end

%% Local functions
function result = extractHeatShield(fileName, heatFluxField, shoulderX, tol)
    data = readSpartaSurfDump(fileName);
    xMid = 0.5 * (data.v1x + data.v2x);
    yMid = 0.5 * (data.v1y + data.v2y);
    keep = xMid >= -tol & xMid <= shoulderX + tol & yMid >= -tol;
    x1 = data.v1x(keep); y1 = data.v1y(keep);
    x2 = data.v2x(keep); y2 = data.v2y(keep);
    q = data.(matlab.lang.makeValidName(heatFluxField))(keep);
    segmentLength = hypot(x2-x1, y2-y1);
    [~, order] = sort(xMid(keep), 'ascend');
    segmentLength = segmentLength(order);
    result.s = cumsum(segmentLength) - 0.5 * segmentLength;
    result.heatFlux = q(order);
end

function data = readSpartaSurfDump(fileName)
    fid = fopen(fileName, 'r');
    if fid < 0, error('Cannot open %s.', fileName); end
    cleaner = onCleanup(@() fclose(fid));
    header = '';
    while ~feof(fid)
        line = fgetl(fid);
        if startsWith(line, 'ITEM: SURFS')
            header = strtrim(extractAfter(line, 'ITEM: SURFS'));
            break;
        end
    end
    if isempty(header), error('SURFS header not found in %s.', fileName); end
    names = strsplit(header);
    values = textscan(fid, repmat('%f', 1, numel(names)), ...
        'CollectOutput', true);
    values = values{1};
    data = struct();
    for i = 1:numel(names)
        data.(matlab.lang.makeValidName(names{i})) = values(:, i);
    end
end

function curve = readReferenceCurve(fileName)
    if ~isfile(fileName), error('Reference file not found: %s', fileName); end
    tableData = readtable(fileName, 'VariableNamingRule', 'preserve');
    curve.s = tableData{:, 1};
    curve.q = tableData{:, 2};
    [curve.s, order] = sort(curve.s);
    curve.q = curve.q(order);
end
