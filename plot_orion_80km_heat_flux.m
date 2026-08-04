%% Orion 80 km TPS heat-flux post-processing
% Compares the fully catalytic case, gamma=0 case, and the case without
% surf_react.  For each case, the surf file with the largest timestep is
% selected automatically.  No figure files are written to disk.

clear;
clc;
close all;

%% User settings
baseDir = 'D:\\博一\\catalytic\\zupparid';

caseInfo = struct( ...
    'name', {'FC', 'gamma0', 'NC'}, ...
    'folder', {'80', '80_gamma_0', '80_nogamma'}, ...
    'label', {'FC: \gamma=1', '\gamma=0', 'NC: no surf\_react'});

heatFluxField = 'f_2[10]';  % etot from: compute 9 surf ... etot ...
shoulderX = 0.8477;          % Point C in the paper, m
geometryTolerance = 1.0e-7;
plotArcLengthMax = 1.8;       % Match the plotted range in Fig. 10, m
paperFCFile = fullfile(baseDir, '80kmFC热流.csv');
paperNCFile = fullfile(baseDir, '80kmNC热流.csv');

%% Locate the largest-timestep surf file and extract the heat shield
nCases = numel(caseInfo);
result = cell(nCases, 1);

for iCase = 1:nCases
    caseDir = fullfile(baseDir, caseInfo(iCase).folder);
    [surfFile, timestep, dataDir] = findLatestSurfFile(caseDir);
    result{iCase} = extractHeatShield(surfFile, heatFluxField, ...
        shoulderX, geometryTolerance);
    result{iCase}.timestep = timestep;
    result{iCase}.file = surfFile;

    fprintf('%-7s: step %d, %d TPS segments\n', ...
        caseInfo(iCase).name, timestep, numel(result{iCase}.s));
    fprintf('         %s\n', dataDir);
end

%% Put all cases on the NC arc-length coordinates
sCommon = result{3}.s;
qFC = interpolateToCommonGrid(result{1}, sCommon);
qGamma0 = interpolateToCommonGrid(result{2}, sCommon);
qNC = result{3}.heatFlux;
qReaction = qFC - qNC;

% Digitized reference curves from the paper. Column 1 is s (m), and
% column 2 is heat flux (kW/m^2), so no unit conversion is required when
% these data are added to the main kW/m^2 plot.
paperFC = readPaperCurve(paperFCFile);
paperNC = readPaperCurve(paperNCFile);

% gamma=0 should reproduce the no-surface-reaction result.  Report both
% an RMS relative difference and a peak-normalized maximum difference.
referenceScale = max(abs(qNC));
if referenceScale <= eps
    referenceScale = 1.0;
end
gamma0Difference = qGamma0 - qNC;
rmsRelativeDifference = sqrt(mean(gamma0Difference.^2)) / ...
    max(sqrt(mean(qNC.^2)), eps) * 100;
maxNormalizedDifference = max(abs(gamma0Difference)) / ...
    referenceScale * 100;

fprintf('\nGamma=0 degradation check against no surf_react:\n');
fprintf('  RMS relative difference       = %.4g %%\n', ...
    rmsRelativeDifference);
fprintf('  Max difference / peak |q_NC| = %.4g %%\n', ...
    maxNormalizedDifference);

[qFCMax, iFCMax] = max(qFC);
[qNCMax, iNCMax] = max(qNC);
[qReactionMax, iReactionMax] = max(qReaction);
fprintf('\nPeak values on the TPS:\n');
fprintf('  FC: %.6g W/m^2 at s = %.6g m\n', qFCMax, sCommon(iFCMax));
fprintf('  NC: %.6g W/m^2 at s = %.6g m\n', qNCMax, sCommon(iNCMax));
fprintf('  q_r: %.6g W/m^2 at s = %.6g m\n', ...
    qReactionMax, sCommon(iReactionMax));

%% Figure 1: paper-style physical comparison
fig1 = figure('Color', 'w', 'Position', [80, 80, 1050, 760]);
ax1 = axes(fig1);
hold(ax1, 'on');

plot(ax1, sCommon, qNC ./ 1000, '-', ...
    'Color', [0.00, 0.32, 0.74], 'LineWidth', 3.0, ...
    'DisplayName', 'Present NC');
plot(ax1, sCommon, qFC ./ 1000, '-', ...
    'Color', [0.86, 0.12, 0.12], 'LineWidth', 3.0, ...
    'DisplayName', 'Present FC');
plot(ax1, sCommon, qReaction ./ 1000, '-.', ...
    'Color', [0.10, 0.58, 0.22], 'LineWidth', 2.8, ...
    'DisplayName', 'q_r = q_{FC}-q_{NC}');
plot(ax1, paperFC.s, paperFC.heatFlux, 'o--', ...
    'Color', [0.72, 0.05, 0.05], 'LineWidth', 2.3, ...
    'MarkerSize', 8.0, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', [0.72, 0.05, 0.05], ...
    'DisplayName', 'Paper FC');
plot(ax1, paperNC.s, paperNC.heatFlux, 's--', ...
    'Color', [0.05, 0.20, 0.55], 'LineWidth', 2.3, ...
    'MarkerSize', 8.0, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', [0.05, 0.20, 0.55], ...
    'DisplayName', 'Paper NC');

formatAxes(ax1);
xlim(ax1, [0, plotArcLengthMax]);
xlabel(ax1, 'Surface arc length from stagnation point, s (m)');
ylabel(ax1, 'Heat flux (kW/m^2)');
title(ax1, 'Orion TPS heat flux at 80 km');
legend(ax1, 'Location', 'best', 'Interpreter', 'tex', ...
    'FontName', 'Times New Roman', 'FontSize', 17, ...
    'LineWidth', 1.2, 'Box', 'off');

%% Figure 2: gamma=0 degradation validation
fig2 = figure('Color', 'w', 'Position', [130, 100, 1050, 820]);
layout = tiledlayout(fig2, 2, 1, 'TileSpacing', 'compact', ...
    'Padding', 'compact');

ax2 = nexttile(layout);
hold(ax2, 'on');
plot(ax2, sCommon, qNC ./ 1000, '-', ...
    'Color', [0.00, 0.32, 0.74], 'LineWidth', 3.0, ...
    'DisplayName', 'NC: no surf\_react');
plot(ax2, sCommon, qGamma0 ./ 1000, '--', ...
    'Color', [0.72, 0.05, 0.55], 'LineWidth', 3.0, ...
    'DisplayName', '\gamma=0');
formatAxes(ax2);
xlim(ax2, [0, plotArcLengthMax]);
ylabel(ax2, 'Heat flux (kW/m^2)');
title(ax2, 'Gamma=0 degradation check at 80 km');
legend(ax2, 'Location', 'best', 'Interpreter', 'tex', ...
    'FontName', 'Times New Roman', 'FontSize', 17, 'Box', 'off');

ax3 = nexttile(layout);
plot(ax3, sCommon, gamma0Difference ./ 1000, '-', ...
    'Color', [0.72, 0.05, 0.05], 'LineWidth', 3.0);
formatAxes(ax3);
xlim(ax3, [0, plotArcLengthMax]);
xlabel(ax3, 'Surface arc length from stagnation point, s (m)');
ylabel(ax3, 'q_{\gamma=0}-q_{NC} (kW/m^2)', 'Interpreter', 'tex');

%% Figure 3: evolution of the FC heat flux with sampling timestep
fcCaseDir = fullfile(baseDir, caseInfo(1).folder);
[historyFiles, historySteps] = selectSurfHistory(fcCaseDir, 5);
nHistory = numel(historyFiles);
historyResult = cell(nHistory, 1);
for iHistory = 1:nHistory
    historyResult{iHistory} = extractHeatShield(historyFiles{iHistory}, ...
        heatFluxField, shoulderX, geometryTolerance);
end

historyColors = parula(nHistory);
fig3 = figure('Color', 'w', 'Position', [180, 120, 1050, 760]);
ax4 = axes(fig3);
hold(ax4, 'on');
for iHistory = 1:nHistory
    plot(ax4, historyResult{iHistory}.s, ...
        historyResult{iHistory}.heatFlux ./ 1000, '-', ...
        'Color', historyColors(iHistory, :), 'LineWidth', 2.8, ...
        'DisplayName', sprintf('%d steps', historySteps(iHistory)));
end
formatAxes(ax4);
xlim(ax4, [0, plotArcLengthMax]);
xlabel(ax4, 'Surface arc length from stagnation point, s (m)');
ylabel(ax4, 'Heat flux (kW/m^2)');
title(ax4, 'Evolution of FC heat flux at 80 km');
legend(ax4, 'Location', 'best', 'Interpreter', 'tex', ...
    'FontName', 'Times New Roman', 'FontSize', 17, ...
    'LineWidth', 1.2, 'Box', 'off');

fprintf('\nFC heat-flux history steps: %s\n', mat2str(historySteps));

%% Local functions
function [surfFile, timestep, dataDir] = findLatestSurfFile(caseDir)
%FINDLATESTSURFFILE Select the surf file with the largest numeric step.
% The no-gamma calculation currently uses data_80, so both data and
% data_* directories are accepted.  The largest step, not modification
% time or lexicographic file order, determines the selected file.

    if ~isfolder(caseDir)
        error('Case directory does not exist: %s', caseDir);
    end

    candidateDirs = {};
    standardDataDir = fullfile(caseDir, 'data');
    if isfolder(standardDataDir)
        candidateDirs{end + 1} = standardDataDir; %#ok<AGROW>
    end

    extraDirs = dir(fullfile(caseDir, 'data_*'));
    extraDirs = extraDirs([extraDirs.isdir]);
    for iDir = 1:numel(extraDirs)
        candidateDirs{end + 1} = fullfile(extraDirs(iDir).folder, ...
            extraDirs(iDir).name); %#ok<AGROW>
    end

    if isempty(candidateDirs)
        error('No data or data_* directory found under %s.', caseDir);
    end

    bestStep = -inf;
    surfFile = '';
    dataDir = '';
    for iDir = 1:numel(candidateDirs)
        files = dir(fullfile(candidateDirs{iDir}, '*surf.*.dat'));
        for iFile = 1:numel(files)
            token = regexp(files(iFile).name, ...
                'surf\.(\d+)\.dat$', 'tokens', 'once');
            if isempty(token)
                continue;
            end
            currentStep = sscanf(token{1}, '%f', 1);
            if currentStep > bestStep
                bestStep = currentStep;
                surfFile = fullfile(files(iFile).folder, files(iFile).name);
                dataDir = candidateDirs{iDir};
            end
        end
    end

    if isempty(surfFile)
        error('No *surf.<timestep>.dat file found under %s.', caseDir);
    end
    timestep = bestStep;
end

function result = extractHeatShield(fileName, heatFluxField, ...
        shoulderX, geometryTolerance)
%EXTRACTHEATSHIELD Extract E-to-C heat-shield segments and calculate s.

    surfData = readSpartaSurfDump(fileName);
    xMid = 0.5 .* (surfData.v1x + surfData.v2x);
    yMid = 0.5 .* (surfData.v1y + surfData.v2y);

    % Paper geometry: stagnation point E=(0,0), TPS ends at point C.
    isTPS = xMid >= -geometryTolerance & ...
        xMid <= shoulderX + geometryTolerance & ...
        yMid >= -geometryTolerance;

    x1 = surfData.v1x(isTPS);
    y1 = surfData.v1y(isTPS);
    x2 = surfData.v2x(isTPS);
    y2 = surfData.v2y(isTPS);
    xMid = xMid(isTPS);
    yMid = yMid(isTPS);
    heatFluxIndex = find(strcmp(surfData.columnNames, heatFluxField), 1);
    if isempty(heatFluxIndex)
        error('Missing column %s in %s.', heatFluxField, fileName);
    end
    qAll = surfData.values(:, heatFluxIndex);
    q = qAll(isTPS);

    if isempty(q)
        error('No TPS segments selected from %s.', fileName);
    end

    % The heat shield is monotonic in radial coordinate y from E to C.
    [yMid, order] = sort(yMid, 'ascend');
    xMid = xMid(order);
    x1 = x1(order);
    y1 = y1(order);
    x2 = x2(order);
    y2 = y2(order);
    q = q(order);

    segmentLength = hypot(x2 - x1, y2 - y1);
    s = cumsum(segmentLength) - 0.5 .* segmentLength;

    if any(diff(s) <= 0)
        error('Non-increasing TPS arc length in %s.', fileName);
    end

    result = struct('s', s, 'x', xMid, 'y', yMid, ...
        'heatFlux', q);
end

function data = readSpartaSurfDump(fileName)
%READSPARTASURFDUMP Read one SPARTA custom surf dump snapshot by name.

    fid = fopen(fileName, 'rt');
    if fid < 0
        error('Cannot open file: %s', fileName);
    end
    cleanup = onCleanup(@() fclose(fid));

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

    requiredNames = {'v1x', 'v1y', 'v2x', 'v2y'};
    data = struct();
    for iName = 1:numel(requiredNames)
        index = find(strcmp(columnNames, requiredNames{iName}), 1);
        if isempty(index)
            error('Missing column %s in %s.', requiredNames{iName}, fileName);
        end
        data.(requiredNames{iName}) = values(:, index);
    end

    data.columnNames = columnNames;
    data.values = values;
end

function q = interpolateToCommonGrid(source, sCommon)
%INTERPOLATETOCOMMONGRID Match geometrically equivalent TPS grids.

    if numel(source.s) == numel(sCommon) && ...
            max(abs(source.s - sCommon)) < 1.0e-10
        q = source.heatFlux;
    else
        if sCommon(1) < source.s(1) || sCommon(end) > source.s(end)
            error('TPS arc-length ranges do not overlap completely.');
        end
        q = interp1(source.s, source.heatFlux, sCommon, 'linear');
    end
end

function curve = readPaperCurve(fileName)
%READPAPERCURVE Read digitized paper data: s (m), q (kW/m^2).

    if ~isfile(fileName)
        error('Paper reference CSV does not exist: %s', fileName);
    end
    values = readmatrix(fileName, 'NumHeaderLines', 1);
    if size(values, 2) < 2
        error('Paper reference CSV must contain at least two columns: %s', ...
            fileName);
    end
    values = values(:, 1:2);
    values = values(all(isfinite(values), 2), :);
    if isempty(values)
        error('No finite numeric reference data in %s.', fileName);
    end
    values = sortrows(values, 1);
    curve = struct('s', values(:, 1), 'heatFlux', values(:, 2));
end

function [selectedFiles, selectedSteps] = selectSurfHistory(caseDir, nSelect)
%SELECTSURFHISTORY Select approximately evenly spaced available timesteps.

    dataDir = fullfile(caseDir, 'data');
    if ~isfolder(dataDir)
        error('FC history data directory does not exist: %s', dataDir);
    end
    files = dir(fullfile(dataDir, '*surf.*.dat'));
    allSteps = nan(numel(files), 1);
    isValid = false(numel(files), 1);
    for iFile = 1:numel(files)
        token = regexp(files(iFile).name, ...
            'surf\.(\d+)\.dat$', 'tokens', 'once');
        if ~isempty(token)
            allSteps(iFile) = sscanf(token{1}, '%f', 1);
            isValid(iFile) = true;
        end
    end
    files = files(isValid);
    allSteps = allSteps(isValid);
    if isempty(files)
        error('No surf history files found in %s.', dataDir);
    end

    [allSteps, order] = sort(allSteps, 'ascend');
    files = files(order);
    nSelect = min(nSelect, numel(files));
    selectedIndex = unique(round(linspace(1, numel(files), nSelect)), ...
        'stable');
    selectedSteps = allSteps(selectedIndex).';
    selectedFiles = cell(numel(selectedIndex), 1);
    for iSelect = 1:numel(selectedIndex)
        selectedFiles{iSelect} = fullfile(files(selectedIndex(iSelect)).folder, ...
            files(selectedIndex(iSelect)).name);
    end
end

function formatAxes(ax)
%FORMATAXES Apply the supervisor's publication-style appearance.

    grid(ax, 'off');
    box(ax, 'on');
    set(ax, 'FontName', 'Times New Roman', 'FontSize', 18, ...
        'FontWeight', 'normal', 'LineWidth', 1.6, ...
        'TickDir', 'in', 'TickLength', [0.018, 0.018], ...
        'XMinorTick', 'on', 'YMinorTick', 'on', ...
        'Layer', 'top');
    ax.XLabel.FontSize = 22;
    ax.XLabel.FontWeight = 'bold';
    ax.YLabel.FontSize = 22;
    ax.YLabel.FontWeight = 'bold';
    ax.Title.FontSize = 22;
    ax.Title.FontWeight = 'bold';
    xlim(ax, [0, max(ax.Children(1).XData)]);
end
