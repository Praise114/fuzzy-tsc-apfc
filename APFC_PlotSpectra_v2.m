function APFC_PlotSpectra_v2(cells)
%APFC_PLOTSPECTRA_V2  Harmonic spectrum figures for the report.
%
%   Produces report Figures 4.14, 4.15 and 4.18 by default. Compared with
%   the spectrum output of APFC_MakeFigures_v2 it adds:
%
%     1. Short y-axis labels. The basis of each panel is stated in the
%        panel subtitle, so the labels of a two-panel figure do not collide.
%
%     2. A limit comparison. The current panel can be plotted on the
%        DEMAND basis, that is as a percentage of the maximum demand
%        current (I_L = 56.4 A), with the IEEE-519 individual limits
%        overlaid. That is the only basis on which a limit comparison is
%        meaningful (report Section 4.5.7).
%
%     3. cfg.titleMode controls the in-figure title: 'noVersion' (default)
%        prints condition and load without the model version tag; 'none'
%        prints no title; 'full' includes the version tag.
%
%   USAGE
%       APFC_PlotSpectra_v2                 % the three report figures
%       APFC_PlotSpectra_v2(myCells)        % a custom list, see below
%
%   Each entry of the cells array is a struct with fields:
%       ver    'v21b' | 'v22' | 'v23'
%       cond   'C1' ... 'C5'
%       load   100 | 75 | 50
%       basis  'fundamental' | 'demand'
%       limits true | false      (only meaningful with the demand basis)
%       name   output file stem
%
%   INPUT DATA: the raw output files out_<tag>_L###.mat (about 190 MB
%   each), which are not included in the repository; run
%   APFC_RunCampaign_Ablation first to regenerate them.
%
%   METHOD
%   Spectra are computed by the same leakage-free integer-cycle Fourier
%   projection used by APFC_HarmonicMetrics: an exact whole number of
%   fundamental cycles is windowed at the end of the run and only the two
%   window endpoints are interpolated.
%
%   Project : Fuzzy Logic-Controlled Automatic Power Factor Correction Using
%             Thyristor-Switched Capacitor Banks for a 30 kW Induction Motor
%   Author  : Praise Oluwasina Akinlolu, Department of Electrical and
%             Electronics Engineering, University of Lagos
%   MATLAB  : R2025b
%   Licence : MIT (see LICENSE in the repository root)

% =====================================================================
% CONFIGURATION
% =====================================================================
cfg.f1          = 50;
cfg.maxOrder    = 25;
cfg.nCycles     = 20;
cfg.IL          = 56.4;      % maximum demand current, A

cfg.fontName    = 'Times New Roman';
cfg.fontSize    = 14;
cfg.labelSize   = 16;
cfg.subSize     = 13;
cfg.legendSize  = 13;
cfg.figWidthCm  = 15;
cfg.figTallCm   = 12.5;      % two panels need the extra height
cfg.figShortCm  = 8.5;       % single panel
cfg.dpi         = 300;
cfg.savePDF     = true;
cfg.titleMode   = 'noVersion';   % 'noVersion' | 'none' | 'full'

cfg.barColor    = [0.16 0.32 0.31];
cfg.limitColor  = [0.70 0.25 0.10];

% IEEE-519, short-circuit ratio band 100 to 1000, percentage of I_L.
% Odd harmonics by order band; even harmonics at 25 per cent of these.
cfg.limOdd  = [12.0 12.0 12.0 12.0 5.5 5.5 5.0 5.0 2.0 2.0 2.0 2.0];
cfg.limEdge = [3 5 7 9 11 13 15 17 19 21 23 25];

% =====================================================================
% Default job list: the three figures Chapter 4 needs
% =====================================================================
if nargin < 1 || isempty(cells)
    cells = { ...
      struct('ver','v22','cond','C1','load',100,'basis','fundamental', ...
             'limits',false,'name','Fig_4_14_Spectrum_C1_L100'), ...
      struct('ver','v22','cond','C3','load', 50,'basis','fundamental', ...
             'limits',false,'name','Fig_4_15_Spectrum_C3_L050'), ...
      struct('ver','v22','cond','C3','load', 50,'basis','demand', ...
             'limits',true, 'name','Fig_4_18_Spectrum_C3_L050_Limits') };
end

fprintf('\n==============================================================\n');
fprintf(' HARMONIC SPECTRUM FIGURES\n');
fprintf('==============================================================\n');

root = local_findFolder('07 - Results');
if isempty(root)
    error('Could not locate ''07 - Results''. Place this script in the repository root folder.');
end
outDir = fullfile(fileparts(root), '08 - Figures');
if ~isfolder(outDir); mkdir(outDir); end
fprintf('\nResults root : %s\nOutput       : %s\n', root, outDir);

% =====================================================================
% Produce each figure
% =====================================================================
for k = 1:numel(cells)
    job = cells{k};
    fprintf('\n[%d/%d] %s\n', k, numel(cells), job.name);

    matPath = local_findCell(root, job.ver, job.cond, job.load);
    if isempty(matPath)
        warning('        no waveform file found for %s %s L%03d, skipped', ...
                job.ver, job.cond, job.load);
        continue
    end
    fprintf('        source %s\n', matPath);

    [t, V, I] = local_load(matPath);
    if isempty(t); warning('        could not resolve signals, skipped'); continue; end

    orders = 1:cfg.maxOrder;
    [pv, ~]      = local_spectrum(t, V(:,1), cfg);            % voltage, %% of fundamental
    [pi_, iabs]  = local_spectrum(t, I(:,1), cfg);            % current, %% of fundamental

    if strcmpi(job.basis, 'demand')
        curCurve = 100 * iabs / cfg.IL;
        curLabel = 'Current (% of I_L)';
        curSub   = sprintf('Phase A line current, I_L = %.1f A', cfg.IL);
    else
        curCurve = pi_;
        curLabel = 'Current (%)';
        curSub   = 'Phase A line current as a percentage of its own fundamental';
    end

    if job.limits
        f = local_singlePanel(orders, curCurve(orders+1), curLabel, curSub, cfg, job);
    else
        f = local_twoPanel(orders, pv(orders+1), curCurve(orders+1), ...
                           curLabel, curSub, cfg, job);
    end

    local_save(f, outDir, job.name, cfg);
    close(f);
    fprintf('        written %s.png\n', job.name);
end

fprintf('\n==============================================================\n');
fprintf(' COMPLETE. Place each figure at %g cm width in Word.\n', cfg.figWidthCm);
fprintf('==============================================================\n\n');
end % ===================== main ends =====================


% =====================================================================
% Two stacked panels, voltage above current
% =====================================================================
function f = local_twoPanel(orders, vCurve, cCurve, curLabel, curSub, cfg, job)
f = local_newFig(cfg, cfg.figTallCm);
tl = tiledlayout(2, 1, 'TileSpacing', 'loose', 'Padding', 'compact');

nexttile
bar(orders, vCurve, 0.7, 'FaceColor', cfg.barColor, 'EdgeColor', 'none');
grid on; box on
ylabel('Voltage (%)');
subtitle('Phase A voltage as a percentage of its own fundamental');
xlim([0.5 cfg.maxOrder + 0.5]);
xticks(local_xticks(cfg.maxOrder));
set(gca, 'XTickLabel', []);

nexttile
bar(orders, cCurve, 0.7, 'FaceColor', cfg.barColor, 'EdgeColor', 'none');
grid on; box on
xlabel('Harmonic order');
ylabel(curLabel);
subtitle(curSub);
xlim([0.5 cfg.maxOrder + 0.5]);
xticks(local_xticks(cfg.maxOrder));

ttl = local_ttl(job, cfg);
if ~isempty(ttl)
    title(tl, ttl, 'FontName', cfg.fontName, 'FontSize', cfg.labelSize, ...
          'FontWeight', 'bold', 'Color', 'k');
end
end


% =====================================================================
% Single panel with the IEEE-519 individual limits overlaid
% =====================================================================
function f = local_singlePanel(orders, cCurve, curLabel, curSub, cfg, job)
f = local_newFig(cfg, cfg.figShortCm);

lim = local_limits(orders, cfg);

b = bar(orders, cCurve, 0.7, 'FaceColor', cfg.barColor, 'EdgeColor', 'none');
hold on
s = stairs([orders - 0.5, cfg.maxOrder + 0.5], [lim, lim(end)], ...
           'LineWidth', 2.0, 'Color', cfg.limitColor);
hold off

grid on; box on
xlabel('Harmonic order');
ylabel(curLabel);
subtitle(curSub);
xlim([0.5 cfg.maxOrder + 0.5]);
xticks(local_xticks(cfg.maxOrder));

lgd = legend([b s], {'Measured', 'IEEE-519 individual limit'}, ...
             'Location', 'northeast');
lgd.Box = 'off';

ttl = local_ttl(job, cfg);
if ~isempty(ttl); title(ttl); end
end


function s = local_ttl(job, cfg)
%LOCAL_TTL  In-figure title, with the model version suppressed by default.
%           The version stays in the output file name either way.
switch lower(cfg.titleMode)
    case 'none'
        s = '';
    case 'full'
        s = sprintf('%s, %s, %d%% load', job.ver, job.cond, job.load);
    otherwise   % 'noVersion'
        s = sprintf('%s, %d%% load', job.cond, job.load);
end
end


function lim = local_limits(orders, cfg)
%LOCAL_LIMITS  Individual current limits by order, percentage of I_L.
lim = zeros(size(orders));
for k = 1:numel(orders)
    h = orders(k);
    if h == 1; lim(k) = NaN; continue; end
    idx = find(cfg.limEdge >= h, 1, 'first');
    if isempty(idx); idx = numel(cfg.limOdd); end
    v = cfg.limOdd(idx);
    if mod(h, 2) == 0; v = 0.25 * v; end   % even harmonics, quarter rule
    lim(k) = v;
end
end


function tk = local_xticks(maxOrder)
tk = [1 3 5 7 9 11 13 15 17 19 21 23 25];
tk = tk(tk <= maxOrder);
end


% =====================================================================
% Fourier projection, identical in method to the metrics engine
% =====================================================================
function [pct, absMag] = local_spectrum(t, x, cfg)
Twin = cfg.nCycles / cfg.f1;
[tw, xw] = local_window(t, x, t(end) - Twin, t(end));
if numel(tw) < 8
    pct = zeros(cfg.maxOrder + 1, 1); absMag = pct; return
end
X = zeros(cfg.maxOrder + 1, 1);
for h = 0:cfg.maxOrder
    integ = trapz(tw, xw .* exp(-1j * 2 * pi * h * cfg.f1 * tw));
    if h == 0; X(h+1) = abs(integ / Twin); else; X(h+1) = abs(2 * integ / Twin); end
end
absMag = X / sqrt(2);                      % peak to rms
if X(2) > 0; pct = 100 * X / X(2); else; pct = zeros(size(X)); end
end


function [tw, xw] = local_window(t, x, t1, t2)
tw = []; xw = [];
if isempty(t) || t(end) < t1 || t(1) > t2; return; end
t1 = max(t1, t(1)); t2 = min(t2, t(end));
inside = t > t1 & t < t2;
tw = [t1; t(inside); t2];
xw = [interp1(t, x, t1, 'linear'); x(inside, :); interp1(t, x, t2, 'linear')];
end


% =====================================================================
% Loading
% =====================================================================
function [t, V, I] = local_load(matPath)
S = load(matPath); tops = fieldnames(S); obj = S.(tops{1});
for k = 1:numel(tops)
    if isa(S.(tops{k}), 'Simulink.SimulationOutput'); obj = S.(tops{k}); break; end
end
t = local_num(obj, {'tout','time','t'});
V = local_sig(obj, {'V_sim','Vabc_sim','Vpcc_sim','V'});
I = local_sig(obj, {'I_sim','Iabc_sim','Iline_sim','I'});
n = min([numel(t), size(V,1), size(I,1)]);
t = t(1:n); V = V(1:n,:); I = I(1:n,:);
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
    try, raw = local_get(obj, names{k}); catch, continue; end
    if isempty(raw); continue; end
    if isa(raw, 'timeseries'); data = raw.Data;
    elseif isstruct(raw) && isfield(raw,'signals'); data = raw.signals.values;
    elseif isnumeric(raw); data = raw;
    else, continue; end
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


function p = local_findCell(root, ver, cond, loadPct)
p = '';
d = dir(root);
for k = 1:numel(d)
    if ~d(k).isdir || any(strcmp(d(k).name, {'.','..','slprj'})); continue; end
    if isempty(regexp(d(k).name, ['^' ver '(_|$)'], 'once')); continue; end
    f = dir(fullfile(root, d(k).name, sprintf('out_%s*_L%03d.mat', cond, loadPct)));
    if ~isempty(f); p = fullfile(f(1).folder, f(1).name); return; end
end
end


% =====================================================================
% Figure plumbing
% =====================================================================
function f = local_newFig(cfg, hCm)
f = figure('Units','centimeters', ...
           'Position',[2 2 cfg.figWidthCm hCm], ...
           'Color','w','Visible','off','InvertHardcopy','off');
try, theme(f,'light'); catch, end
end


function local_save(f, outDir, stem, cfg)
set(findall(f,'-property','FontName'), 'FontName', cfg.fontName);
set(findall(f,'-property','FontSize'), 'FontSize', cfg.fontSize);
set(f, 'Color','w', 'InvertHardcopy','off');

ax = findall(f, 'Type','axes');
set(ax, 'Color','w', 'XColor','k', 'YColor','k', ...
        'GridColor',[0.75 0.75 0.75], 'GridAlpha',1, ...
        'LineWidth',0.9, 'Layer','top');
set(findall(f, 'Type','text'), 'Color','k');
lg = findall(f, 'Type','legend');
set(lg, 'TextColor','k', 'FontSize', cfg.legendSize);

for k = 1:numel(ax)
    a = ax(k);
    try, a.XLabel.FontSize = cfg.labelSize; a.XLabel.Color = 'k'; catch, end
    try, a.YLabel.FontSize = cfg.labelSize; a.YLabel.Color = 'k'; catch, end
    try, a.Title.FontSize  = cfg.labelSize; a.Title.Color  = 'k'; catch, end
    try, a.Subtitle.FontSize = cfg.subSize; a.Subtitle.Color = [0.25 0.25 0.25]; catch, end
end
drawnow

exportgraphics(f, fullfile(outDir, [stem '.png']), ...
               'Resolution', cfg.dpi, 'BackgroundColor','white');
if cfg.savePDF
    try
        exportgraphics(f, fullfile(outDir, [stem '.pdf']), ...
                       'ContentType','vector', 'BackgroundColor','white');
    catch ME
        warning('        vector export failed for %s: %s', stem, ME.message);
    end
end
end


function p = local_findFolder(target)
p = '';
here = fileparts(mfilename('fullpath'));
if isempty(here); here = pwd; end
probe = here;
for depth = 1:6
    cand = fullfile(probe, target);
    if isfolder(cand); p = cand; return; end
    [~, leaf] = fileparts(probe);
    if strcmpi(leaf, target); p = probe; return; end
    parent = fileparts(probe);
    if strcmp(parent, probe); break; end
    probe = parent;
end
end
