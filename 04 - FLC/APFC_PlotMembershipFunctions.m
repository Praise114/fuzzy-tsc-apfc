function APFC_PlotMembershipFunctions()
%APFC_PLOTMEMBERSHIPFUNCTIONS  Publication-quality membership function plots.
%
%   Produces the two figures for Section 3.5.7 of the report:
%     Fig_MF_Input.png    input membership functions on the reactive power error
%     Fig_MF_Output.png   output membership functions on the compensation increment
%
%   The built-in plotmf produces axis labels far too small to read once the
%   figure is placed in a report. This script draws the same curves with the
%   type sized for print, on a white canvas immune to the MATLAB dark theme.
%
%   USAGE
%       APFC_PlotMembershipFunctions
%
%   The script looks for APFC_FLC.fis beside itself, then one folder up,
%   then in the current folder. Output is written to the same folder as
%   the .fis file, or to the current folder if that is not writable.
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
cfg.fisName     = 'APFC_FLC.fis';
cfg.fontName    = 'Times New Roman';
cfg.fontSize    = 15;      % tick labels
cfg.labelSize   = 17;      % x and y axis labels
cfg.legendSize  = 14;      % legend entries and set names
cfg.lineWidth   = 2.0;
cfg.figWidthCm  = 15;      % place at this width in Word, do not enlarge
cfg.figHeightCm = 9.0;
cfg.dpi         = 300;
cfg.nPoints     = 4001;
cfg.savePDF     = true;    % vector copy alongside each PNG

% Distinct line styles so the sets remain separable in greyscale print
cfg.styles = {'-','--',':','-.','-'};
cfg.widths = [2.0 2.0 2.4 2.0 2.6];

fprintf('\n==============================================================\n');
fprintf(' MEMBERSHIP FUNCTION PLOTS\n');
fprintf('==============================================================\n');

% =====================================================================
% Locate and read the inference system
% =====================================================================
fisPath = local_findFis(cfg.fisName);
if isempty(fisPath)
    error(['Could not find %s. Place this script beside the .fis file, ', ...
           'or set the current folder to where it lives.'], cfg.fisName);
end
fprintf('\nInference system : %s\n', fisPath);

fis = readfis(fisPath);
outDir = fileparts(fisPath);
if isempty(outDir); outDir = pwd; end
fprintf('Output folder    : %s\n\n', outDir);

% =====================================================================
% Plot both variables
% =====================================================================
jobs = { ...
  struct('kind','input',  'idx',1, ...
         'xlabel','Reactive power error, e_Q (kVAr)', ...
         'file','Fig_MF_Input'), ...
  struct('kind','output', 'idx',1, ...
         'xlabel','Compensation increment, \DeltaQ_C (kVAr)', ...
         'file','Fig_MF_Output') };

for j = 1:numel(jobs)
    job = jobs{j};
    [range, names, curves, x] = local_getCurves(fis, job.kind, job.idx, cfg.nPoints);

    fprintf('%-8s variable "%s"  range [%g %g]  %d sets\n', ...
            upper(job.kind), local_varName(fis, job.kind, job.idx), ...
            range(1), range(2), numel(names));
    for k = 1:numel(names)
        fprintf('    %-4s\n', names{k});
    end

    f = local_newFig(cfg);
    hold on
    h = gobjects(1, numel(names));
    for k = 1:numel(names)
        st = cfg.styles{min(k, numel(cfg.styles))};
        lw = cfg.widths(min(k, numel(cfg.widths)));
        h(k) = plot(x, curves(k,:), st, 'LineWidth', lw);
    end
    hold off

    grid on; box on
    xlim(range);
    ylim([-0.04 1.10]);
    yticks(0:0.2:1);
    xticks(local_ticks(range));

    xlabel(job.xlabel);
    ylabel('Degree of membership');

    lgd = legend(h, names, 'Location', 'northoutside', ...
                 'Orientation', 'horizontal', 'NumColumns', numel(names));
    lgd.Box = 'off';

    local_style(f, cfg);
    local_save(f, outDir, job.file, cfg);
    close(f);
    fprintf('    written %s.png\n\n', job.file);
end

fprintf('==============================================================\n');
fprintf(' COMPLETE. Place each figure in Word at %g cm width.\n', cfg.figWidthCm);
fprintf(' Do NOT enlarge it: the type is sized for that width.\n');
fprintf('==============================================================\n\n');
end % ===================== main ends =====================


% =====================================================================
% Curve extraction, tolerant of both the modern object API and the
% older struct API returned by readfis in earlier releases.
% =====================================================================
function [range, names, curves, x] = local_getCurves(fis, kind, idx, n)
try
    if strcmpi(kind, 'input'); v = fis.Inputs(idx); else; v = fis.Outputs(idx); end
    range = v.Range;
    mfs   = v.MembershipFunctions;
    names = arrayfun(@(m) m.Name, mfs, 'UniformOutput', false);
    x = linspace(range(1), range(2), n);
    curves = zeros(numel(mfs), n);
    for k = 1:numel(mfs)
        curves(k,:) = evalmf(mfs(k), x);
    end
catch
    if strcmpi(kind, 'input'); v = fis.input(idx); else; v = fis.output(idx); end
    range = v.range;
    names = {v.mf.name};
    x = linspace(range(1), range(2), n);
    curves = zeros(numel(v.mf), n);
    for k = 1:numel(v.mf)
        curves(k,:) = evalmf(x, v.mf(k).params, v.mf(k).type);
    end
end
names = names(:).';
end


function nm = local_varName(fis, kind, idx)
try
    if strcmpi(kind,'input'); nm = fis.Inputs(idx).Name; else; nm = fis.Outputs(idx).Name; end
catch
    if strcmpi(kind,'input'); nm = fis.input(idx).name; else; nm = fis.output(idx).name; end
end
end


function tk = local_ticks(range)
%LOCAL_TICKS  Round tick spacing giving roughly nine ticks across the range.
span = range(2) - range(1);
cand = [1 2 2.5 5 10 20 25 50 100];
step = cand(find(span./cand <= 9, 1, 'first'));
if isempty(step); step = span/8; end
tk = ceil(range(1)/step)*step : step : floor(range(2)/step)*step;
end


% =====================================================================
% Figure plumbing, identical in spirit to APFC_MakeFigures_v2
% =====================================================================
function f = local_newFig(cfg)
f = figure('Units','centimeters', ...
           'Position',[2 2 cfg.figWidthCm cfg.figHeightCm], ...
           'Color','w','Visible','off','InvertHardcopy','off');
try, theme(f,'light'); catch, end
end


function local_style(f, cfg)
set(findall(f,'-property','FontName'), 'FontName', cfg.fontName);
set(findall(f,'-property','FontSize'), 'FontSize', cfg.fontSize);

set(f, 'Color', 'w', 'InvertHardcopy', 'off');
ax = findall(f, 'Type', 'axes');
set(ax, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', ...
        'GridColor', [0.75 0.75 0.75], 'GridAlpha', 1, ...
        'LineWidth', 0.9, 'Layer', 'top');
set(findall(f, 'Type', 'text'), 'Color', 'k');

lg = findall(f, 'Type', 'legend');
set(lg, 'TextColor', 'k', 'FontSize', cfg.legendSize);

for k = 1:numel(ax)
    a = ax(k);
    try, a.XLabel.FontSize = cfg.labelSize; a.XLabel.Color = 'k'; catch, end
    try, a.YLabel.FontSize = cfg.labelSize; a.YLabel.Color = 'k'; catch, end
end
drawnow
end


function local_save(f, outDir, stem, cfg)
png = fullfile(outDir, [stem '.png']);
exportgraphics(f, png, 'Resolution', cfg.dpi, 'BackgroundColor', 'white');
if cfg.savePDF
    try
        exportgraphics(f, fullfile(outDir, [stem '.pdf']), ...
                       'ContentType', 'vector', 'BackgroundColor', 'white');
    catch ME
        warning('    vector export failed for %s: %s', stem, ME.message);
    end
end
end


function p = local_findFis(name)
p = '';
here = fileparts(mfilename('fullpath'));
if isempty(here); here = pwd; end
cand = { fullfile(here, name), ...
         fullfile(fileparts(here), name), ...
         fullfile(pwd, name) };
for k = 1:numel(cand)
    if isfile(cand{k}); p = cand{k}; return; end
end
% last resort: search two levels down from the script folder
d = dir(fullfile(here, '**', name));
if ~isempty(d); p = fullfile(d(1).folder, d(1).name); end
end
