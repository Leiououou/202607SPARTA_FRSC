%% Orion stagnation-point heat flux at 80, 90, and 100 km
% Each FC case uses the surf file with the largest numeric timestep.
% The stagnation-region value is the arithmetic mean of the four surface
% segments closest to the stagnation point (the first segment plus its
% three nearest neighboring segments).

clear;
clc;
close all;

%% User settings
baseDir = 'D:\\博一\\catalytic\\zupparid';
altitudes = [80, 90, 100];
heatFluxField = 'f_2[10]';    % etot, W/m^2
shoulderX = 0.8477;           % Point C in the paper, m
geometryTolerance = 1.0e-7;
nStagnationSegments = 4;

%% Read latest FC data and estimate stagnation heat flux
nCases = numel(altitudes);
result = cell(nCases, 1);
qStagnationAverage = zeros(nCases, 1);
selectedSteps = zeros(nCases, 1);

for iCase = 1:nCases
    caseDir = fullfile(baseDir, sprintf('%d', altitudes(iCase)));
    [surfFile, selectedSteps(iCase)] = findLatestSurfFile(caseDir);
    result{iCase} = extractHeatShield(surfFile, heatFluxField, ...
        shoulderX, geometryTolerance);

    nAverage = min(nStagnationSegments, numel(result{iCase}.heatFlux));
    qStagnationAverage(iCase) = mean(result{iCase}.heatFlux(1:nAverage));

    fprintf('%3d km: step %d, mean of first %d segments = %.6g kW/m^2\n', ...
        altitudes(iCase), selectedSteps(iCase), nAverage, ...
        qStagnationAverage(iCase) / 1000);
end

%% Stagnation-point heat flux versus altitude
paperFC = [71.4, 30.0, 9.0];  % Table 7, kW/m^2 at 80, 90, 100 km

fig1 = figure('Color', 'w', 'Position', [80, 80, 1000, 740]);
ax1 = axes(fig1);
hold(ax1, 'on');
plot(ax1, altitudes, qStagnationAverage ./ 1000, 'o-', ...
    'Color', [0.86, 0.12, 0.12], 'LineWidth', 3.0, ...
    'MarkerSize', 9, 'MarkerFaceColor', [0.86, 0.12, 0.12], ...
    'DisplayName', 'Present, mean of 4 stagnation-region segments');
plot(ax1, altitudes, paperFC, 'd--', ...
    'Color', [0.20, 0.20, 0.20], 'LineWidth', 2.5, ...
    'MarkerSize', 8, 'MarkerFaceColor', 'w', ...
    'DisplayName', 'Paper FC');
formatAxes(ax1);
xlim(ax1, [78, 102]);
xticks(ax1, altitudes);
xlabel(ax1, 'Altitude (km)');
ylabel(ax1, 'Stagnation-point heat flux (kW/m^2)');
title(ax1, 'Orion FC stagnation-point heat flux');
legend(ax1, 'Location', 'northeast', 'Interpreter', 'tex', ...
    'FontName', 'Times New Roman', 'FontSize', 16, 'Box', 'off');

%% Local functions
function [surfFile, timestep] = findLatestSurfFile(caseDir)
%FINDLATESTSURFFILE Select the largest numeric surf timestep.

    candidateDirs = {};
    if isfolder(fullfile(caseDir, 'data'))
        candidateDirs{end + 1} = fullfile(caseDir, 'data'); %#ok<AGROW>
    end
    extraDirs = dir(fullfile(caseDir, 'data_*'));
    extraDirs = extraDirs([extraDirs.isdir]);
    for iDir = 1:numel(extraDirs)
        candidateDirs{end + 1} = fullfile(extraDirs(iDir).folder, ...
            extraDirs(iDir).name); %#ok<AGROW>
    end
    if isempty(candidateDirs)
        error('No data directory found under %s.', caseDir);
    end

    timestep = -inf;
    surfFile = '';
    for iDir = 1:numel(candidateDirs)
        files = dir(fullfile(candidateDirs{iDir}, '*surf.*.dat'));
        for iFile = 1:numel(files)
            token = regexp(files(iFile).name, ...
                'surf\.(\d+)\.dat$', 'tokens', 'once');
            if isempty(token)
                continue;
            end
            currentStep = sscanf(token{1}, '%f', 1);
            if currentStep > timestep
                timestep = currentStep;
                surfFile = fullfile(files(iFile).folder, files(iFile).name);
            end
        end
    end
    if isempty(surfFile)
        error('No surf timestep file found under %s.', caseDir);
    end
end

function result = extractHeatShield(fileName, heatFluxField, ...
        shoulderX, geometryTolerance)
%EXTRACTHEATSHIELD Extract and order the E-to-C heat-shield segments.

    surfData = readSpartaSurfDump(fileName);
    xMid = 0.5 .* (surfData.v1x + surfData.v2x);
    yMid = 0.5 .* (surfData.v1y + surfData.v2y);
    isTPS = xMid >= -geometryTolerance & ...
        xMid <= shoulderX + geometryTolerance & ...
        yMid >= -geometryTolerance;

    x1 = surfData.v1x(isTPS);
    y1 = surfData.v1y(isTPS);
    x2 = surfData.v2x(isTPS);
    y2 = surfData.v2y(isTPS);
    yMid = yMid(isTPS);

    heatFluxIndex = find(strcmp(surfData.columnNames, heatFluxField), 1);
    if isempty(heatFluxIndex)
        error('Missing column %s in %s.', heatFluxField, fileName);
    end
    qAll = surfData.values(:, heatFluxIndex);
    q = qAll(isTPS);

    [~, order] = sort(yMid, 'ascend');
    x1 = x1(order); y1 = y1(order);
    x2 = x2(order); y2 = y2(order);
    q = q(order);
    segmentLength = hypot(x2 - x1, y2 - y1);
    s = cumsum(segmentLength) - 0.5 .* segmentLength;
    result = struct('s', s, 'heatFlux', q);
end

function data = readSpartaSurfDump(fileName)
%READSPARTASURFDUMP Read one SPARTA custom surface dump.

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

    data = struct('columnNames', {columnNames}, 'values', values);
    for name = {'v1x', 'v1y', 'v2x', 'v2y'}
        index = find(strcmp(columnNames, name{1}), 1);
        if isempty(index)
            error('Missing geometry column %s in %s.', name{1}, fileName);
        end
        data.(name{1}) = values(:, index);
    end
end

function formatAxes(ax)
%FORMATAXES Apply the supervisor's publication-style appearance.

    grid(ax, 'off');
    box(ax, 'on');
    set(ax, 'FontName', 'Times New Roman', 'FontSize', 18, ...
        'LineWidth', 1.6, 'TickDir', 'in', ...
        'TickLength', [0.018, 0.018], ...
        'XMinorTick', 'on', 'YMinorTick', 'on', 'Layer', 'top');
    ax.XLabel.FontSize = 22;
    ax.XLabel.FontWeight = 'bold';
    ax.YLabel.FontSize = 22;
    ax.YLabel.FontWeight = 'bold';
    ax.Title.FontSize = 22;
    ax.Title.FontWeight = 'bold';
end
