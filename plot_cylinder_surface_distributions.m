%% Plot upper-cylinder surface distributions for the four nsite cases
% The SPARTA surf dump is NOT assumed to be ordered geometrically.
% Each surface segment is positioned by its midpoint, filtered to the
% upper semicircle, and then sorted by midpoint x-coordinate.

clear;
clc;
close all;

%% User settings
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end

caseNames = { ...
    'nsite_6.022e17', ...
    'nsite_6.022e18', ...
    'nsite_6.022e19', ...
    'nsite_6.022e20'};

% The extended nsite=6.022e20 calculation is stored beside cylinder_gamma.
longN20Dir = fullfile(fileparts(scriptDir), ...
    'cylinder_n20_longlongstep', 'nsite_6.022e20_100k');

caseDirs = { ...
    fullfile(scriptDir, caseNames{1}), ...
    fullfile(scriptDir, caseNames{2}), ...
    fullfile(scriptDir, caseNames{3}), ...
    longN20Dir};

caseTimesteps = [60000, 60000, 60000, 250000];

caseLabels = { ...
    'n_{site}=6.022\times10^{17}', ...
    'n_{site}=6.022\times10^{18}', ...
    'n_{site}=6.022\times10^{19}', ...
    'n_{site}=6.022\times10^{20}'};

historyCases = {'nsite_6.022e18', 'nsite_6.022e20'};
historyDirs = {fullfile(scriptDir, historyCases{1}), longN20Dir};
historyCaseTitles = { ...
    'Upper cylinder surface, n_{site}=6.022\times10^{18}', ...
    'Upper cylinder surface, n_{site}=6.022\times10^{20}'};
historySteps = { ...
    10000:10000:60000, ...
    10000:10000:250000};

% SPARTA "compute surf" field positions in f_2[*]:
pressureColumn = 3;     % press
heatFluxColumn = 10;    % etot (total energy flux)
echemColumn = 14;       % echem (chemical energy flux)

%% Read, select upper semicircle, and sort by physical x-coordinate
nCases = numel(caseNames);
results = cell(nCases, 1);

for iCase = 1:nCases
    surfFile = fullfile(caseDirs{iCase}, 'data', ...
        sprintf('surf.%d.dat', caseTimesteps(iCase)));

    if ~isfile(surfFile)
        error('Missing surface result file: %s', surfFile);
    end

    results{iCase} = extractUpperSurface(surfFile, pressureColumn, ...
        heatFluxColumn, echemColumn);
end

%% Plot the three requested distributions
colors = lines(nCases);
finalTitle = ['Upper cylinder surface, final running averages ' ...
    '(10^{17}-10^{19}: 60000; 10^{20}: 250000 steps)'];

plotOneQuantity(results, caseLabels, colors, 'pressure', ...
    'Pressure, Pa', finalTitle);

plotOneQuantity(results, caseLabels, colors, 'heatFlux', ...
    'Total heat flux, W/m^2', finalTitle);

plotOneQuantity(results, caseLabels, colors, 'echem', ...
    'Chemical-energy flux echem, W/m^2', finalTitle);

%% Plot time-history curves for selected nsite cases
for iHistoryCase = 1:numel(historyCases)
    currentSteps = historySteps{iHistoryCase};
    nSteps = numel(currentSteps);
    historyResults = cell(nSteps, 1);
    historyLabels = cell(nSteps, 1);

    for iStep = 1:nSteps
        surfFile = fullfile(historyDirs{iHistoryCase}, 'data', ...
            sprintf('surf.%d.dat', currentSteps(iStep)));
        if ~isfile(surfFile)
            error('Missing surface result file: %s', surfFile);
        end

        historyResults{iStep} = extractUpperSurface(surfFile, ...
            pressureColumn, heatFluxColumn, echemColumn);
        historyLabels{iStep} = sprintf('%d steps', currentSteps(iStep));
    end

    historyColors = parula(nSteps);
    plotOneQuantity(historyResults, historyLabels, historyColors, ...
        'pressure', 'Pressure, Pa', historyCaseTitles{iHistoryCase});
    plotOneQuantity(historyResults, historyLabels, historyColors, ...
        'heatFlux', 'Total heat flux, W/m^2', ...
        historyCaseTitles{iHistoryCase});
    plotOneQuantity(historyResults, historyLabels, historyColors, ...
        'echem', 'Chemical-energy flux echem, W/m^2', ...
        historyCaseTitles{iHistoryCase});
end

fprintf('Processed %d final cases at timesteps %s.\n', ...
    nCases, mat2str(caseTimesteps));
fprintf(['Upper-surface points are ordered by segment-midpoint x, ' ...
    'not by surface ID.\n']);
for iHistoryCase = 1:numel(historyCases)
    fprintf('Time history for %s: %s.\n', historyCases{iHistoryCase}, ...
        mat2str(historySteps{iHistoryCase}));
end

%% Local functions
function data = readSpartaSurfDump(fileName)
%READSPARTASURFDUMP Read one SPARTA custom surf dump snapshot.

    fid = fopen(fileName, 'rt');
    if fid < 0
        error('Cannot open file: %s', fileName);
    end
    cleanup = onCleanup(@() fclose(fid));

    headerFound = false;
    columnNames = {};

    while ~feof(fid)
        line = strtrim(fgetl(fid));
        if startsWith(line, 'ITEM: SURFS')
            columnNames = strsplit(line);
            columnNames = columnNames(3:end);
            headerFound = true;
            break;
        end
    end

    if ~headerFound
        error('No "ITEM: SURFS" header found in %s.', fileName);
    end

    nColumns = numel(columnNames);
    values = textscan(fid, repmat('%f', 1, nColumns), ...
        'CollectOutput', true, ...
        'MultipleDelimsAsOne', true, ...
        'Delimiter', {' ', '\t'});
    values = values{1};

    if isempty(values) || size(values, 2) ~= nColumns
        error('Unexpected numeric data layout in %s.', fileName);
    end

    requiredNames = {'id', 'v1x', 'v1y', 'v2x', 'v2y'};
    columnIndex = zeros(size(requiredNames));
    for k = 1:numel(requiredNames)
        matchedColumn = find(strcmp(columnNames, requiredNames{k}), 1);
        if isempty(matchedColumn)
            error('Required column "%s" is missing in %s.', ...
                requiredNames{k}, fileName);
        end
        columnIndex(k) = matchedColumn;
    end

    firstField = find(startsWith(columnNames, 'f_2['), 1, 'first');
    lastField = find(startsWith(columnNames, 'f_2['), 1, 'last');
    if isempty(firstField) || isempty(lastField)
        error('No f_2[*] surface fields found in %s.', fileName);
    end

    data = struct();
    data.id = values(:, columnIndex(1));
    data.v1x = values(:, columnIndex(2));
    data.v1y = values(:, columnIndex(3));
    data.v2x = values(:, columnIndex(4));
    data.v2y = values(:, columnIndex(5));
    data.fields = values(:, firstField:lastField);
end

function result = extractUpperSurface(fileName, pressureColumn, ...
        heatFluxColumn, echemColumn)
%EXTRACTUPPERSURFACE Select and geometrically sort upper-cylinder segments.

    surfData = readSpartaSurfDump(fileName);
    xMid = 0.5 .* (surfData.v1x + surfData.v2x);
    yMid = 0.5 .* (surfData.v1y + surfData.v2y);

    radiusScale = max(hypot(xMid, yMid));
    geometryTolerance = max(1.0, radiusScale) * 1.0e-10;
    isUpper = yMid >= -geometryTolerance;

    xUpper = xMid(isUpper);
    yUpper = yMid(isUpper);
    upperFields = surfData.fields(isUpper, :);
    upperIds = surfData.id(isUpper);

    % Critical step: sort by geometry, never by dump row or surface ID.
    [xUpper, order] = sort(xUpper, 'ascend');
    yUpper = yUpper(order);
    upperFields = upperFields(order, :);
    upperIds = upperIds(order);

    if any(diff(xUpper) <= 0)
        warning(['File %s contains repeated/non-increasing upper-surface ' ...
            'midpoint x coordinates.'], fileName);
    end

    result = struct( ...
        'x', xUpper, ...
        'y', yUpper, ...
        'id', upperIds, ...
        'pressure', upperFields(:, pressureColumn), ...
        'heatFlux', upperFields(:, heatFluxColumn), ...
        'echem', upperFields(:, echemColumn));
end

function plotOneQuantity(results, labels, colors, fieldName, ...
        yLabelText, titleText)
%PLOTONEQUANTITY Plot one surface quantity for every nsite case.

    fig = figure('Color', 'w', 'Position', [100, 100, 900, 620]);
    ax = axes(fig);
    hold(ax, 'on');

    for iCase = 1:numel(results)
        plot(ax, results{iCase}.x, results{iCase}.(fieldName), ...
            'LineWidth', 1.8, ...
            'Color', colors(iCase, :), ...
            'DisplayName', labels{iCase});
    end

    grid(ax, 'on');
    box(ax, 'on');
    xlabel(ax, 'Surface-segment midpoint x, m', 'Interpreter', 'tex');
    ylabel(ax, yLabelText, 'Interpreter', 'tex');
    title(ax, titleText, 'Interpreter', 'tex');
    legend(ax, 'Location', 'best', 'Interpreter', 'tex');
    set(ax, 'FontName', 'Times New Roman', 'FontSize', 12, ...
        'LineWidth', 1.0);
    xlim(ax, [-0.5, 0.5]);
end
