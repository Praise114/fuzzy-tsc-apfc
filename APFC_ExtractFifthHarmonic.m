function APFC_ExtractFifthHarmonic(resultsFolder)
%APFC_EXTRACTFIFTHHARMONIC  Print per-order harmonic data from campaign result files.
%
%   PURPOSE
%   Reads the Results_*.txt files of a campaign folder (for example the
%   delivered system, '07 - Results\v22_NoALPF') and prints the
%   per-order harmonic lines of the nine cells that inject a fifth
%   harmonic (C3, C4 and C5 at the three load points). Used to check the
%   measured fifth-harmonic line current against the analytically computed
%   capacitor-bank contribution (report Sections 4.5.5, 4.5.7 and
%   4.6.1.5). Nothing is written to disk and no file is modified.
%
%   USAGE
%       APFC_ExtractFifthHarmonic
%           Opens a folder picker.
%
%       APFC_ExtractFifthHarmonic('D:\APFC\07 - Results\v22')
%           Reads the named folder. Use your own full path.
%
%   OUTPUT
%       SECTION 1 prints one complete result file, so the exact field layout
%       is visible.
%       SECTION 2 prints every line that looks like per-order harmonic data,
%       for each of the nine cells that inject a fifth harmonic.
%
%   Project : Fuzzy Logic-Controlled Automatic Power Factor Correction Using
%             Thyristor-Switched Capacitor Banks for a 30 kW Induction Motor
%   Author  : Praise Oluwasina Akinlolu, Department of Electrical and
%             Electronics Engineering, University of Lagos
%   MATLAB  : R2025b
%   Licence : MIT (see LICENSE in the repository root)

% ---------------------------------------------------------------- folder ---
if nargin < 1 || isempty(resultsFolder)
    resultsFolder = uigetdir(pwd, ...
        'Select the folder holding the v22 Results_*.txt files');
    if isequal(resultsFolder, 0)
        fprintf('Cancelled. No folder was selected.\n');
        return
    end
end

resultsFolder = char(resultsFolder);

if ~isfolder(resultsFolder)
    fprintf('THAT IS NOT A FOLDER:\n  %s\n', resultsFolder);
    fprintf('Check the path and try again, or call the function with no arguments\n');
    fprintf('to use the folder picker.\n');
    return
end

% ----------------------------------------------------------------- files ---
files = dir(fullfile(resultsFolder, 'Results_L*_C*.txt'));
if ~isempty(files)
    files = files(~[files.isdir]);
end

if isempty(files)
    fprintf('No file matching Results_L*_C*.txt was found in:\n  %s\n\n', resultsFolder);
    everything = dir(resultsFolder);
    everything = everything(~[everything.isdir]);
    if isempty(everything)
        fprintf('That folder contains no files at all.\n');
    else
        fprintf('That folder contains these %d files:\n', numel(everything));
        nShow = min(numel(everything), 40);
        for k = 1:nShow
            fprintf('    %s\n', everything(k).name);
        end
        if numel(everything) > nShow
            fprintf('    (and %d more)\n', numel(everything) - nShow);
        end
        fprintf('\nIf the result files live in a subfolder, select that subfolder instead.\n');
    end
    return
end

names = string({files.name});
[names, order] = sort(names);
files = files(order);

% Keep only the nine cells that inject a fifth harmonic.
isFifth = ~cellfun(@isempty, regexp(cellstr(names), '_C[345][_.]', 'once'));
if any(isFifth)
    sel = find(isFifth);
else
    fprintf('WARNING: no file name matched the C3, C4 or C5 pattern.\n');
    fprintf('All %d matched files will be printed instead.\n\n', numel(files));
    sel = 1:numel(files);
end

fprintf('Folder            : %s\n', resultsFolder);
fprintf('Files matched     : %d\n', numel(files));
fprintf('Files to be read  : %d\n', numel(sel));
fprintf('MATLAB version    : %s\n', version);
fprintf('Run at            : %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS')); %#ok<TNOW1,DATST>
fprintf('%s\n', repmat('=', 1, 74));

% ------------------------------------------- SECTION 1: one complete file ---
pick = sel(1);
idxC3 = find(~cellfun(@isempty, regexp(cellstr(names(sel)), '_C3[_.]', 'once')), 1);
if ~isempty(idxC3)
    pick = sel(idxC3);
end

fprintf('SECTION 1 - COMPLETE DUMP OF ONE FILE\n');
fprintf('FILE: %s\n', names(pick));
fprintf('%s\n', repmat('-', 1, 74));

theseLines = readlines(fullfile(resultsFolder, names(pick)));
for k = 1:numel(theseLines)
    fprintf('%s\n', theseLines(k));
end

fprintf('%s\n', repmat('=', 1, 74));

% -------------------------------- SECTION 2: per-order lines, every cell ---
pat = '(?i)(harmonic|order|\<h\s*=|\<h\d|[1-9]\d?\s*(st|nd|rd|th)\>|fundamental|peak)';

fprintf('SECTION 2 - PER-ORDER LINES FROM EACH OF THE NINE CELLS\n');

for f = sel
    fprintf('%s\n', repmat('-', 1, 74));
    fprintf('FILE: %s\n', names(f));

    L = readlines(fullfile(resultsFolder, names(f)));
    hit = false;

    for k = 1:numel(L)
        s = strtrim(L(k));
        if strlength(s) == 0
            continue
        end
        isNumberedRow = ~isempty(regexp(s, '^\d{1,2}\s', 'once'));
        isPatternRow  = ~isempty(regexp(s, pat, 'once'));
        if isNumberedRow || isPatternRow
            fprintf('    %s\n', s);
            hit = true;
        end
    end

    if ~hit
        fprintf('    (no line in this file matched the per-order pattern)\n');
    end
end

fprintf('%s\n', repmat('=', 1, 74));
fprintf('Done.\n');

end
