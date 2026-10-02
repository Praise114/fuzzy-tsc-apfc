function T = APFC_CurrentReduction(resultsDir, loads)
%APFC_CURRENTREDUCTION  Line current before and after compensation, clean supply.
%
%   T = APFC_CurrentReduction                  % opens a folder picker
%   T = APFC_CurrentReduction(resultsDir)
%   T = APFC_CurrentReduction(resultsDir, [100 75 50])
%
%   resultsDir is the campaign folder that holds the .mat output files for
%   the delivered system, for example
%       D:\...\Models\07 - Results\v22_NoALPF
%   Pass the REAL path. Calling it with a literal three dots will not work;
%   the dots in the example above stand for the rest of your own path.
%   Calling it with no arguments opens a folder picker instead.
%
%   Returns a table with, for each load point, the root mean square line
%   current in the uncompensated window and in the settled compensated
%   window, the percentage reduction, the implied reduction in conductor
%   loss, which goes as the square of the current, and the file each row
%   came from.
%
%   WHY THE RESAMPLING MATTERS
%   The solver writes samples at a non-uniform spacing. Calling rms()
%   straight on those samples weights every sample equally and therefore
%   biases the answer wherever the step size varies (for example 46.22 A
%   against the 46.45 A the metrics function reports for the same
%   window). This function interpolates onto a uniform grid spanning a
%   whole number of cycles before taking the root mean square, which
%   removes that bias.
%
%   WINDOWS
%   Both windows are twenty cycles, 0.4 s, matching the metrics engine that
%   produced every other published figure. The uncompensated window ENDS at
%   t = 24 s, one second before the startup gate opens, and the compensated
%   window ends at the final sample. Taking the current from the same window
%   the displacement power factor was measured in is what makes the current
%   ratio agree with the power factor ratio; a four cycle window opening at
%   t = 20 s does not, and reads about one point low.
%
%   INPUT DATA: the raw output files out_<tag>_L###.mat written by
%   APFC_RunCampaign_Ablation. They are not included in the repository
%   (about 190 MB each); run the campaign for 'v22' first.
%
%   Project : Fuzzy Logic-Controlled Automatic Power Factor Correction Using
%             Thyristor-Switched Capacitor Banks for a 30 kW Induction Motor
%   Author  : Praise Oluwasina Akinlolu, Department of Electrical and
%             Electronics Engineering, University of Lagos
%   MATLAB  : R2025b
%   Licence : MIT (see LICENSE in the repository root)

% ---- resolve the folder -------------------------------------------------
if nargin < 1 || isempty(resultsDir)
    resultsDir = uigetdir(pwd, 'Select the campaign folder holding the .mat files');
    if isequal(resultsDir, 0); T = table(); return; end
end
if ~isfolder(resultsDir)
    error('APFC:badFolder', ...
        ['Folder not found:\n    %s\n\nPass the full path to the campaign ' ...
         'folder, or call APFC_CurrentReduction with no arguments and pick ' ...
         'it from the dialog.'], resultsDir);
end
if nargin < 2 || isempty(loads); loads = [100 75 50]; end

fprintf('Folder : %s\n', resultsDir);

% ---- find the clean-grid cell files -------------------------------------
% Matched loosely on the C1 tag so that naming variants are still found.
hits = dir(fullfile(resultsDir, '*.mat'));
hits = hits(~[hits.isdir]);
if ~isempty(hits)
    hits = hits(contains({hits.name}, 'C1', 'IgnoreCase', true));
end

if isempty(hits)
    allMat = dir(fullfile(resultsDir, '*.mat'));
    fprintf('\nNo clean-grid (C1) .mat file found. The folder contains:\n');
    if isempty(allMat)
        fprintf('   (no .mat files at all)\n');
    else
        fprintf('   %s\n', allMat.name);
    end
    error('APFC:noFiles', 'No C1 .mat file found in %s', resultsDir);
end

Load    = loads(:);
Iuncomp = nan(numel(Load),1);
Icomp   = nan(numel(Load),1);
Source  = strings(numel(Load),1);

f1 = 50; nCycles = 20; preGateEnd = 24; nGrid = 20001;
Twin = nCycles / f1;        % 0.4 s, the metrics engine's projection window

for k = 1:numel(Load)
    tok = sprintf('L%03d', Load(k));
    sel = find(contains({hits.name}, tok, 'IgnoreCase', true), 1, 'first');
    if isempty(sel)
        warning('APFC:missing', 'No C1 file matching %s in this folder', tok);
        continue
    end
    matPath  = fullfile(hits(sel).folder, hits(sel).name);
    Source(k) = string(hits(sel).name);

    try
        [t, I] = local_load(matPath);
    catch ME
        warning('APFC:loadFail', '%s: %s', hits(sel).name, ME.message); continue
    end
    if isempty(t) || isempty(I)
        warning('APFC:nosignal', 'No time or current signal in %s', hits(sel).name); continue
    end

    Iuncomp(k) = local_rms(t, I, preGateEnd - Twin, preGateEnd, nGrid);
    Icomp(k)   = local_rms(t, I, t(end) - Twin,     t(end),     nGrid);
    fprintf('  %-42s t = %.2f to %.2f s, %d samples\n', ...
            hits(sel).name, t(1), t(end), numel(t));
end

Reduction_pct     = 100 * (1 - Icomp ./ Iuncomp);
LossReduction_pct = 100 * (1 - (Icomp ./ Iuncomp).^2);

T = table(Load, Iuncomp, Icomp, Reduction_pct, LossReduction_pct, Source);
fprintf('\n');
disp(T)
end


function [t, I] = local_load(matPath)
S = load(matPath);
tops = fieldnames(S);
obj = S.(tops{1});
for k = 1:numel(tops)
    if isa(S.(tops{k}), 'Simulink.SimulationOutput'); obj = S.(tops{k}); break; end
end

t = local_num(obj, {'tout','time','t'});
I = local_sig(obj, {'I_sim','Iabc_sim','Iline_sim','I'});
if isempty(I); return; end
if isempty(t); t = (0:size(I,1)-1).'; end
I = I(:,1);
n = min(numel(t), size(I,1));
t = t(1:n);  I = I(1:n);
end


function r = local_rms(t, x, t0, t1, nGrid)
if t1 <= t0 || t0 < t(1) || t1 > t(end); r = NaN; return; end
tu = linspace(t0, t1, nGrid).';
xu = interp1(t, x, tu, 'linear');
r  = sqrt(mean(xu.^2, 'omitnan'));
end


function v = local_num(obj, names)
v = [];
for k = 1:numel(names)
    try
        c = local_get(obj, names{k});
        if isnumeric(c) && ~isempty(c); v = c(:); return; end
    catch
    end
end
end


function data = local_sig(obj, names)
data = [];
for k = 1:numel(names)
    try
        raw = local_get(obj, names{k});
    catch
        continue
    end
    if isempty(raw); continue; end
    if isa(raw, 'timeseries')
        data = raw.Data;
    elseif isstruct(raw) && isfield(raw, 'signals')
        data = raw.signals.values;
    elseif isnumeric(raw)
        data = raw;
    else
        continue
    end
    data = squeeze(data);
    if ndims(data) > 2                                        %#ok<ISMAT>
        data = reshape(data, [], size(data, ndims(data))).';
    end
    if isvector(data); data = data(:); end
    if size(data,1) < size(data,2) && size(data,1) <= 4; data = data.'; end
    return
end
end


function v = local_get(obj, name)
if isa(obj, 'Simulink.SimulationOutput'); v = obj.get(name); else; v = obj.(name); end
end
