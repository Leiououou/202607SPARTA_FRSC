%% All available Orion 80 km heat-flux results versus Zuppardi FC
% Recursively scans this script's folder. For every result folder that
% contains 80surf.<timestep>.dat, only the largest numeric timestep is used.

clear; clc; close all;

%% Settings
rootDir = fileparts(mfilename('fullpath'));
heatFluxField = 'f_2[10]';       % etot from compute/fix/dump settings
paperFCFile = fullfile(rootDir, 'zupparid', '80kmFC热流.csv');
outputFile = fullfile(rootDir, 'all_80km_heat_flux_vs_paper_FC.png');
shoulderX = 0.8477;              % Orion TPS shoulder point C, m
geometryTolerance = 1.0e-7;
plotArcLengthMax = 1.8;          % Same range as the paper figure

%% Find the latest 80 km surface result in every data folder
[latestFiles, latestSteps, resultDirs] = findLatestResults(rootDir);
nCases = numel(latestFiles);
if nCases == 0
    error('No 80surf.<timestep>.dat files were found under %s.', rootDir);
end

labels = cell(nCases, 1);
results = cell(nCases, 1);
fprintf('All detected 80 km result folders (latest snapshot only)\n');
fprintf('%-42s %12s %14s\n', 'Case', 'Step', 'Peak (kW/m2)');
fprintf('%s\n', repmat('-', 1, 72));
for iCase = 1:nCases
    labels{iCase} = makeCaseLabel(resultDirs{iCase}, rootDir);
    results{iCase} = extractHeatShield(latestFiles{iCase}, ...
        heatFluxField, shoulderX, geometryTolerance);
    peak = max(results{iCase}.heatFlux) / 1000;
    fprintf('%-42s %12d %14.6f\n', labels{iCase}, ...
        latestSteps(iCase), peak);
end

paperFC = readReferenceCurve(paperFCFile);

%% Draw all calculations in one figure
fig = figure('Color', 'w', 'Position', [70, 70, 1460, 820]);
ax = axes(fig);
hold(ax, 'on');
ax.Toolbar.Visible = 'off';

colors = lines(nCases);
lineStyles = {'-', '--', '-.', ':', '-', '--', '-.', ':'};
for iCase = 1:nCases
    style = lineStyles{1 + mod(iCase - 1, numel(lineStyles))};
    plot(ax, results{iCase}.s, results{iCase}.heatFlux / 1000, ...
        'LineStyle', style, 'Color', colors(iCase, :), ...
        'LineWidth', 2.4, ...
        'DisplayName', sprintf('%s (%d steps)', ...
        labels{iCase}, latestSteps(iCase)));
end

% Plot the paper curve last so its symbols remain visible above all lines.
plot(ax, paperFC.s, paperFC.q, 'ko--', ...
    'LineWidth', 3.0, 'MarkerSize', 8, ...
    'MarkerFaceColor', 'w', 'MarkerEdgeColor', 'k', ...
    'DisplayName', 'Zuppardi paper FC');

box(ax, 'on');
grid(ax, 'off');
set(ax, 'FontName', 'Times New Roman', 'FontSize', 18, ...
    'LineWidth', 1.6, 'TickDir', 'in', ...
    'TickLength', [0.015, 0.015], ...
    'XMinorTick', 'on', 'YMinorTick', 'on', 'Layer', 'top');
xlim(ax, [0, plotArcLengthMax]);
xlabel(ax, 'Surface arc length from stagnation point, s (m)', ...
    'FontSize', 21, 'FontWeight', 'bold');
ylabel(ax, 'Heat flux (kW/m^2)', ...
    'FontSize', 21, 'FontWeight', 'bold');
title(ax, 'Orion 80 km: all available calculations versus Zuppardi FC', ...
    'FontSize', 21, 'FontWeight', 'bold');
legend(ax, 'Location', 'eastoutside', 'Interpreter', 'none', ...
    'FontName', 'Times New Roman', 'FontSize', 13, 'Box', 'off');

exportgraphics(fig, outputFile, 'Resolution', 300);
fprintf('\nIncluded %d calculation folders.\n', nCases);
fprintf('Figure saved to:\n%s\n', outputFile);

%% Local functions
function [latestFiles, latestSteps, resultDirs] = findLatestResults(rootDir)
%FINDLATESTRESULTS Keep only the largest timestep in each containing folder.

    files = dir(fullfile(rootDir, '**', '80surf.*.dat'));
    steps = nan(numel(files), 1);
    valid = false(numel(files), 1);
    folders = cell(numel(files), 1);
    for iFile = 1:numel(files)
        token = regexp(files(iFile).name, ...
            '^80surf\.(\d+)\.dat$', 'tokens', 'once');
        if ~isempty(token)
            steps(iFile) = sscanf(token{1}, '%f', 1);
            folders{iFile} = files(iFile).folder;
            valid(iFile) = true;
        end
    end
    files = files(valid);
    steps = steps(valid);
    folders = folders(valid);

    if isempty(files)
        latestFiles = {};
        latestSteps = [];
        resultDirs = {};
        return;
    end

    uniqueFolders = unique(folders);
    latestFiles = cell(numel(uniqueFolders), 1);
    latestSteps = zeros(numel(uniqueFolders), 1);
    resultDirs = uniqueFolders;
    for iFolder = 1:numel(uniqueFolders)
        indices = find(strcmp(folders, uniqueFolders{iFolder}));
        [latestSteps(iFolder), localIndex] = max(steps(indices));
        selected = files(indices(localIndex));
        latestFiles{iFolder} = fullfile(selected.folder, selected.name);
    end

    % Stable, reproducible legend order based on relative path.
    relativeDirs = cell(size(resultDirs));
    for iFolder = 1:numel(resultDirs)
        relativeDirs{iFolder} = strrep(resultDirs{iFolder}, ...
            [rootDir filesep], '');
    end
    [~, order] = sort(lower(relativeDirs));
    latestFiles = latestFiles(order);
    latestSteps = latestSteps(order);
    resultDirs = resultDirs(order);
end

function label = makeCaseLabel(dataDir, rootDir)
%MAKECASELABEL Convert known folder names into concise physical labels.

    relative = strrep(dataDir, [rootDir filesep], '');
    relative = strrep(relative, '/', filesep);
    if endsWith(relative, [filesep 'data_80'])
        relative = extractBefore(relative, strlength(relative) - 7);
    elseif endsWith(relative, [filesep 'data'])
        relative = extractBefore(relative, strlength(relative) - 4);
    end
    relative = char(relative);

    switch lower(strrep(relative, '/', filesep))
        case lower(['zupparid' filesep '80'])
            label = 'Original gamma, gamma_CO=0';
        case lower(['zupparid' filesep '80_gCO'])
            label = 'nsite gamma, gamma_CO=1';
        case lower(['zupparid' filesep '80_gamma_0'])
            label = 'gamma=0';
        case lower(['zupparid' filesep '80_nogamma'])
            label = 'NC, no surf_react';
        case lower(['z_0804' filesep '80_gCO'])
            label = 'only_one';
        case lower(['z_0805' filesep '80_gCO_g1'])
            label = 'gank, every_n=1 noallow';
        case lower(['z_0805_1' filesep '80_gCO_g1'])
            label = 'gank1 noallow + noleave';
        case lower(['z_0805_1' filesep '80_gCO_onlyone'])
            label = 'only_one + noleave';
        case lower(['z_prob' filesep '80'])
            label = 'prob';
        case lower(['z_prob_max' filesep '80'])
            label = 'prob max';
        case lower('z_prob_max_yuan')
            label = 'prob max, original';
        otherwise
            label = strrep(relative, filesep, ' / ');
    end
end

function result = extractHeatShield(fileName, heatFluxField, shoulderX, tol)
%EXTRACTHEATSHIELD Read and order the stagnation-point-to-shoulder TPS.

    data = readSpartaSurfDump(fileName);
    xMid = 0.5 .* (data.v1x + data.v2x);
    yMid = 0.5 .* (data.v1y + data.v2y);
    keep = xMid >= -tol & xMid <= shoulderX + tol & yMid >= -tol;

    fieldIndex = find(strcmp(data.columnNames, heatFluxField), 1);
    if isempty(fieldIndex)
        error('Missing heat-flux field %s in %s.', heatFluxField, fileName);
    end

    x1 = data.v1x(keep); y1 = data.v1y(keep);
    x2 = data.v2x(keep); y2 = data.v2y(keep);
    ySelected = yMid(keep);
    q = data.values(keep, fieldIndex);
    if isempty(q)
        error('No TPS segments were selected from %s.', fileName);
    end

    [~, order] = sort(ySelected, 'ascend');
    x1 = x1(order); y1 = y1(order);
    x2 = x2(order); y2 = y2(order);
    q = q(order);
    segmentLength = hypot(x2 - x1, y2 - y1);
    s = cumsum(segmentLength) - 0.5 .* segmentLength;
    result = struct('s', s, 'heatFlux', q);
end

function data = readSpartaSurfDump(fileName)
%READSPARTASURFDUMP Read one SPARTA custom surf snapshot by column name.

    fid = fopen(fileName, 'rt');
    if fid < 0
        error('Cannot open file: %s', fileName);
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

    columnNames = {};
    while ~feof(fid)
        line = strtrim(fgetl(fid));
        if startsWith(line, 'ITEM: SURFS')
            words = strsplit(line);
            columnNames = words(3:end);
            break;
        end
    end
    if isempty(columnNames)
        error('No ITEM: SURFS header found in %s.', fileName);
    end

    nColumns = numel(columnNames);
    values = textscan(fid, repmat('%f', 1, nColumns), ...
        'CollectOutput', true, 'MultipleDelimsAsOne', true, ...
        'Delimiter', {' ', '\t'});
    values = values{1};
    if isempty(values) || size(values, 2) ~= nColumns
        error('Unexpected numeric data layout in %s.', fileName);
    end

    required = {'v1x', 'v1y', 'v2x', 'v2y'};
    data = struct();
    for iName = 1:numel(required)
        index = find(strcmp(columnNames, required{iName}), 1);
        if isempty(index)
            error('Missing column %s in %s.', required{iName}, fileName);
        end
        data.(required{iName}) = values(:, index);
    end
    data.columnNames = columnNames;
    data.values = values;
end

function curve = readReferenceCurve(fileName)
%READREFERENCECURVE Read digitized paper data: s (m), q (kW/m^2).

    if ~isfile(fileName)
        error('Paper FC reference file not found: %s', fileName);
    end
    values = readmatrix(fileName, 'NumHeaderLines', 1);
    values = values(:, 1:2);
    values = values(all(isfinite(values), 2), :);
    if isempty(values)
        error('No valid numeric data in %s.', fileName);
    end
    values = sortrows(values, 1);
    curve = struct('s', values(:, 1), 'q', values(:, 2));
end
