function APFC_MakeFigures_v2(varargin)
%APFC_MAKEFIGURES_V2  Generate the campaign figures from the saved raw output.
%
%   PURPOSE
%   Produces the per-cell and cross-configuration overlay figures of
%   report Chapter 4 (displacement power factor traces, line-current
%   waveforms, bank state, reactive power error, harmonic spectra and
%   the ablation overlays) from raw-waveform files already on disk. NO
%   SIMULATION IS RE-RUN. Every campaign folder found under
%   '07 - Results' is processed. The axes titles carry condition and load
%   only; the model version is kept in the output file name.
%
%   INPUTS  (read only)
%     07 - Results\<version>\out_<tag>_L###.mat
%     These raw-output files (about 190 MB each) are not included in the
%     repository; run APFC_RunCampaign_Ablation first to regenerate them.
%
%   OUTPUTS  (written)
%     08 - Figures\<version>\       PNG at 300 dpi + PDF vector
%     08 - Figures\_Overlays\       cross-version comparison figures
%     08 - Figures\FigureIndex.csv  index of every file produced
%
%   USAGE
%       APFC_MakeFigures_v2('limit',1)        % one cell, to check styling
%       APFC_MakeFigures_v2                   % the full batch
%       APFC_MakeFigures_v2('overwrite',true) % regenerate existing files
%       APFC_MakeFigures_v2('types',{'PF','Spectrum'})   % a subset
%
%   SIGNAL TIME BASES  (as logged by the full models)
%     tout, V_sim, I_sim, P_sim, Q_sim   variable-step solver, ~2.81e6 samples
%     PFdisp_sim, eQ_sim                 fixed 12.5 kHz,        625001 samples
%     S_sim                              0.5 s sampling,        101 samples
%     Qmeas_sim                          present in v21b, v22, v23 only
%   Each signal is therefore carried with its OWN time vector. Signals are
%   never trimmed to a common length, because doing so would silently
%   truncate the solver traces to the length of the bank-state trace.
%
%   ARRAY SHAPES
%     V_sim and I_sim are logged as [1 x 3 x N]. They are squeezed to
%     [3 x N] and transposed to [N x 3] on load.
%
%   METHOD NOTE
%     Harmonic spectra use the same leakage-free integer-cycle Fourier
%     projection as APFC_HarmonicMetrics: an exact whole number of
%     fundamental cycles is windowed, the two window endpoints are
%     interpolated, and every native variable-step sample inside the window
%     is used. The authoritative NUMBERS remain those in the
%     Results_*.txt files; these figures present the same quantities.
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
cfg = struct();
cfg.f1          = 50;          % fundamental frequency, Hz
cfg.maxOrder    = 25;          % highest harmonic order plotted
cfg.nCycles     = 20;          % cycles in the Fourier window (report Section 4.4.3)
cfg.gateTime    = 25;          % startup gate duration, s (report Section 3.6.3)
cfg.deadband    = 3;           % anti-hunt deadband, kVAr (FLC_deadband_kVAR)
cfg.pfFloor     = 0.95;        % displacement power factor floor
cfg.detuning    = 0.06;        % reactor detuning ratio p
cfg.bankRatings = [5 10 20];   % nominal bank ratings, kVAr
cfg.waveCycles  = 4;           % cycles shown in waveform figures
cfg.preGateEnd  = 24;          % END of the uncompensated window, s. The metrics
                               % engine projects the baseline over twenty cycles
                               % ending here, so the waveform window is placed to
                               % end here too and the figure, the baseline table
                               % and the current table all cite one window.
cfg.maxPlotPts  = 40000;       % decimation ceiling for long traces

% ---- presentation ----------------------------------------------------
% Figures are deliberately SMALL with LARGE type. When a 14 cm figure is
% placed at 14 cm in the report the type reproduces at its stated point
% size. Do not enlarge the figure in Word; place it at its natural size.
cfg.figWidthCm  = 15;          % single-panel width
cfg.figHeightCm = 9.0;         % single-panel height
cfg.figTallCm   = 11.8;        % height for two-panel (tiled) figures
cfg.fontName    = 'Times New Roman';
cfg.fontSize    = 14;          % tick labels and general text
cfg.labelSize   = 16;          % x and y axis labels
cfg.titleSize   = 16;          % axes title
cfg.subSize     = 13;          % axes subtitle
cfg.legendSize  = 13;          % legend entries
cfg.dpi         = 300;
cfg.savePDF     = true;

% ---- cross-version overlays -----------------------------------------
% The ablation is a THREE-configuration comparison: v21b, v22, v23
% (labelled A, B and C). Any other campaign folder found, such as the
% untapped v21 baseline used during development, carries no Qmeas_sim
% signal and is not part of the experiment, so it is excluded from the
% overlays. Leave this empty to plot every version found.
cfg.overlayVersions = {'v21b','v22','v23'};

% Legend text for the overlays, one row per version: {tag, label}.
% Any version absent from this list keeps its own tag as the label.
cfg.overlayLabels = { ...
    'v21b', 'A: both filters'; ...
    'v22',  'B: output filter only'; ...
    'v23',  'C: no conditioning' };

ip = inputParser;
ip.addParameter('overwrite', false, @islogical);
ip.addParameter('limit',     inf,   @isnumeric);
ip.addParameter('types', {'PF','Bank','eQ','Waveform','Spectrum','MeasQ'}, @iscell);
ip.addParameter('overlays',  true,  @islogical);
ip.parse(varargin{:});
opt = ip.Results;

fprintf('\n==============================================================\n');
fprintf(' APFC FIGURE GENERATION\n');
fprintf('==============================================================\n');

% =====================================================================
% Locate folders
% =====================================================================
resultsRoot = local_findFolder('07 - Results');
if isempty(resultsRoot)
    error('Could not locate ''07 - Results''. Place this script in the repository root folder.');
end
figRoot = fullfile(fileparts(resultsRoot), '08 - Figures');
if ~isfolder(figRoot); mkdir(figRoot); end

fprintf('\nResults root : %s\n', resultsRoot);
fprintf('Figure root  : %s\n', figRoot);

% =====================================================================
% Build the work list
% =====================================================================
work = local_buildWorkList(resultsRoot);
if isempty(work)
    error('No out_*.mat files found under %s', resultsRoot);
end

fprintf('\nCells found  : %d\n', numel(work));
vers = unique({work.version}, 'stable');
for k = 1:numel(vers)
    fprintf('   %-10s %d cells\n', vers{k}, sum(strcmp({work.version}, vers{k})));
end

nDo = min(numel(work), opt.limit);
fprintf('\nProcessing %d of %d cells.\n', nDo, numel(work));

oldState = local_pushStyle(cfg);
restorer = onCleanup(@() local_popStyle(oldState)); %#ok<NASGU>

% =====================================================================
% PASS 1: per-cell figures
% =====================================================================
cache = struct('version',{},'cond',{},'condFull',{},'load',{}, ...
               'tpf',{},'pf',{},'ts',{},'qdel',{},'teq',{},'eq',{});
indexRows = {};
tStart = tic;

for k = 1:nDo
    W = work(k);
    outDir = fullfile(figRoot, W.version);
    if ~isfolder(outDir); mkdir(outDir); end

    stem = sprintf('Fig_%s_%s_L%03d', W.version, W.cond, W.load);
    fprintf('\n[%d/%d] %s\n', k, nDo, stem);

    if ~opt.overwrite && local_allExist(outDir, stem, opt.types, cfg)
        fprintf('        already complete, skipped\n');
        continue
    end

    try
        D = local_loadCell(W.path, cfg);
    catch ME
        warning('        LOAD FAILED: %s', ME.message);
        continue
    end
    fprintf('        solver %d samples (%.2f to %.2f s)', ...
            numel(D.t), D.t(1), D.t(end));
    if ~isempty(D.pf);   fprintf(' | PF %d', numel(D.tpf)); end
    if ~isempty(D.bank); fprintf(' | S %d', numel(D.ts));   end
    if ~isempty(D.eq);   fprintf(' | eQ %d', numel(D.teq)); end
    if ~isempty(D.qmeas);fprintf(' | Qmeas %d', numel(D.tqm)); end
    fprintf('\n');

    if ismember('PF', opt.types) && ~isempty(D.pf)
        f = local_figPF(D, cfg, W);
        local_save(f, outDir, [stem '_PFtrace'], cfg); close(f);
        indexRows(end+1,:) = {W.version, W.cond, W.condFull, W.load, ...
                              'PFtrace', [stem '_PFtrace.png']}; %#ok<AGROW>
    end

    if ismember('Bank', opt.types) && ~isempty(D.bank)
        f = local_figBank(D, cfg, W);
        local_save(f, outDir, [stem '_BankState'], cfg); close(f);
        indexRows(end+1,:) = {W.version, W.cond, W.condFull, W.load, ...
                              'BankState', [stem '_BankState.png']};
    end

    if ismember('eQ', opt.types) && ~isempty(D.eq)
        f = local_figEQ(D, cfg, W);
        local_save(f, outDir, [stem '_ReactiveError'], cfg); close(f);
        indexRows(end+1,:) = {W.version, W.cond, W.condFull, W.load, ...
                              'ReactiveError', [stem '_ReactiveError.png']};
    end

    if ismember('Waveform', opt.types) && ~isempty(D.I)
        f = local_figWaveform(D, cfg, W);
        local_save(f, outDir, [stem '_Waveforms'], cfg); close(f);
        indexRows(end+1,:) = {W.version, W.cond, W.condFull, W.load, ...
                              'Waveforms', [stem '_Waveforms.png']};
    end

    if ismember('Spectrum', opt.types) && ~isempty(D.I)
        f = local_figSpectrum(D, cfg, W);
        local_save(f, outDir, [stem '_Spectrum'], cfg); close(f);
        indexRows(end+1,:) = {W.version, W.cond, W.condFull, W.load, ...
                              'Spectrum', [stem '_Spectrum.png']};
    end

    if ismember('MeasQ', opt.types) && ~isempty(D.qmeas)
        f = local_figMeasQ(D, cfg, W);
        local_save(f, outDir, [stem '_MeasuredQ'], cfg); close(f);
        indexRows(end+1,:) = {W.version, W.cond, W.condFull, W.load, ...
                              'MeasuredQ', [stem '_MeasuredQ.png']};
    end

    cache(end+1) = struct('version', W.version, 'cond', W.cond, ...
        'condFull', W.condFull, 'load', W.load, ...
        'tpf',  local_dec(D.tpf,  cfg.maxPlotPts), ...
        'pf',   local_dec(D.pf,   cfg.maxPlotPts), ...
        'ts',   D.ts, 'qdel', D.qdel, ...
        'teq',  local_dec(D.teq,  cfg.maxPlotPts), ...
        'eq',   local_dec(D.eq,   cfg.maxPlotPts)); %#ok<AGROW>

    clear D
    fprintf('        done (%.1f min elapsed)\n', toc(tStart)/60);
end

% =====================================================================
% PASS 2: cross-version overlays
% =====================================================================
if opt.overlays && ~isempty(cache)
    ovDir = fullfile(figRoot, '_Overlays');
    if ~isfolder(ovDir); mkdir(ovDir); end
    fprintf('\n--------------------------------------------------------------\n');
    fprintf(' CROSS-VERSION OVERLAYS\n');
    fprintf('--------------------------------------------------------------\n');

    % restrict the overlays to the versions that form the experiment
    ovCache = cache;
    if ~isempty(cfg.overlayVersions)
        keep = ismember({ovCache.version}, cfg.overlayVersions);
        dropped = unique({ovCache(~keep).version});
        ovCache = ovCache(keep);
        if ~isempty(dropped)
            fprintf('   excluded from overlays: %s\n', strjoin(dropped, ', '));
        end
    end
    if numel(unique({ovCache.version})) < 2
        fprintf('   fewer than two permitted versions cached, overlays skipped\n');
        ovCache = ovCache([]);
    end

    keys = unique(arrayfun(@(c) sprintf('%s_L%03d', c.cond, c.load), ...
                           ovCache, 'UniformOutput', false));
    for k = 1:numel(keys)
        sel = arrayfun(@(c) strcmp(sprintf('%s_L%03d', c.cond, c.load), keys{k}), ovCache);
        grp = ovCache(sel);
        if numel(grp) < 2; continue; end

        stem = sprintf('Fig_Overlay_%s_PF', keys{k});
        fprintf('   %s  (%d versions)\n', stem, numel(grp));
        f = local_figOverlay(grp, cfg, 'pf');
        local_save(f, ovDir, stem, cfg); close(f);
        indexRows(end+1,:) = {'overlay', grp(1).cond, grp(1).condFull, ...
                              grp(1).load, 'OverlayPF', [stem '.png']};

        stem2 = sprintf('Fig_Overlay_%s_kVAr', keys{k});
        f = local_figOverlay(grp, cfg, 'qdel');
        local_save(f, ovDir, stem2, cfg); close(f);
        indexRows(end+1,:) = {'overlay', grp(1).cond, grp(1).condFull, ...
                              grp(1).load, 'OverlaykVAr', [stem2 '.png']};
    end
end

% =====================================================================
% Index
% =====================================================================
if ~isempty(indexRows)
    T = cell2table(indexRows, 'VariableNames', ...
        {'Version','Condition','ConditionFull','LoadPercent','FigureType','FileName'});
    idxFile = fullfile(figRoot, 'FigureIndex.csv');
    writetable(T, idxFile);
    fprintf('\nFigure index written: %s\n', idxFile);
end

fprintf('\n==============================================================\n');
fprintf(' COMPLETE. %d figure files recorded. Total time %.1f min.\n', ...
        size(indexRows,1), toc(tStart)/60);
fprintf(' Output folder: %s\n', figRoot);
fprintf('==============================================================\n\n');
end % ===================== main ends =====================


% =====================================================================
% Work list
% =====================================================================
function work = local_buildWorkList(resultsRoot)
work = struct('version',{},'cond',{},'condFull',{},'load',{},'path',{});

folders = {};
d = dir(resultsRoot);
for k = 1:numel(d)
    if d(k).isdir && ~any(strcmp(d(k).name, {'.','..','slprj'}))
        folders{end+1} = fullfile(resultsRoot, d(k).name); %#ok<AGROW>
    end
end
folders{end+1} = resultsRoot;   % any loose files at the root

for f = 1:numel(folders)
    files = dir(fullfile(folders{f}, 'out_*.mat'));
    if isempty(files); continue; end
    [~, leaf] = fileparts(folders{f});
    verLabel = local_shortVersion(leaf);

    for m = 1:numel(files)
        [c, cFull, loadPct] = local_parseName(files(m).name);
        work(end+1) = struct('version', verLabel, 'cond', c, ...
            'condFull', cFull, 'load', loadPct, ...
            'path', fullfile(files(m).folder, files(m).name)); %#ok<AGROW>
    end
end

% Fixed-width key so 'v21    ' sorts before 'v21b   '
keys = arrayfun(@(w) sprintf('%-8s%-6s%03d', w.version, w.cond, w.load), ...
                work, 'UniformOutput', false);
[~, ord] = sort(keys);
work = work(ord);
end


function s = local_shortVersion(name)
tok = regexp(name, '^(v\d+[a-z]?)', 'tokens', 'once');
if ~isempty(tok); s = tok{1}; else; s = matlab.lang.makeValidName(name); end
end


function [cShort, cFull, loadPct] = local_parseName(fname)
cShort = 'Cx'; cFull = 'unknown'; loadPct = 0;
tok = regexp(fname, '^out_(.+)_L(\d+)\.mat$', 'tokens', 'once');
if ~isempty(tok)
    cFull   = matlab.lang.makeValidName(tok{1});
    loadPct = str2double(tok{2});
    t2 = regexp(cFull, '^(C\d+)', 'tokens', 'once');
    if ~isempty(t2); cShort = t2{1}; else; cShort = cFull; end
end
end


% =====================================================================
% Loading: every signal keeps its own time vector
% =====================================================================
function D = local_loadCell(matPath, cfg)
S = load(matPath);
tops = fieldnames(S);
obj = S.(tops{1});
for k = 1:numel(tops)
    if isa(S.(tops{k}), 'Simulink.SimulationOutput'); obj = S.(tops{k}); break; end
end

D = struct('t',[],'V',[],'I',[],'P',[],'Q',[], ...
           'tpf',[],'pf',[], 'ts',[],'bank',[], 'teq',[],'eq',[], ...
           'tqm',[],'qmeas',[], 'qdel',[],'qdelSource','');

% --- solver base ---
D.t = local_num(obj, {'tout','time','t'});
[D.V, tv] = local_sig(obj, {'V_sim','Vabc_sim','Vpcc_sim','V'});
[D.I, ti] = local_sig(obj, {'I_sim','Iabc_sim','Iline_sim','I'});
[D.P, ~ ] = local_sig(obj, {'P_sim','Pnet_sim','P'});
[D.Q, ~ ] = local_sig(obj, {'Q_sim','Qnet_sim','Q'});
if isempty(D.t)
    if ~isempty(tv); D.t = tv; elseif ~isempty(ti); D.t = ti; end
end
n = numel(D.t);
D.V = local_fit(D.V, n);  D.I = local_fit(D.I, n);
D.P = local_fit(D.P, n);  D.Q = local_fit(D.Q, n);

% --- own bases ---
[D.pf,    D.tpf] = local_sig(obj, {'PFdisp_sim','PF_sim','DPF_sim','PF'});
[D.bank,  D.ts ] = local_sig(obj, {'S_sim','Banks_sim','BankState_sim','S'});
[D.eq,    D.teq] = local_sig(obj, {'eQ_sim','eQerr_sim','eQ'});
[D.qmeas, D.tqm] = local_sig(obj, {'Qmeas_sim','Qmeas'});

if isempty(D.tpf) && ~isempty(D.pf); D.tpf = local_synthT(D.t, size(D.pf,1)); end
if isempty(D.ts)  && ~isempty(D.bank); D.ts = local_synthT(D.t, size(D.bank,1)); end
if isempty(D.teq) && ~isempty(D.eq); D.teq = local_synthT(D.t, size(D.eq,1)); end
if isempty(D.tqm) && ~isempty(D.qmeas); D.tqm = local_synthT(D.t, size(D.qmeas,1)); end

% --- delivered reactive power ---
[qd, tqd] = local_sig(obj, {'Qinj_sim','Qc_sim','Qcap_sim','Qdel_sim'});
if ~isempty(qd)
    D.qdel = qd(:,1);  D.ts = tqd;  D.qdelSource = 'logged';
elseif ~isempty(D.bank) && size(D.bank,2) >= 3
    % Nominal delivered reactive power. The detuning reactor raises the
    % effective 50 Hz output of each branch by 1/(1-p).
    D.qdel = (D.bank(:,1:3) * cfg.bankRatings(:)) / (1 - cfg.detuning);
    D.qdelSource = 'derived from bank state';
end
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


function [data, tvec] = local_sig(obj, names)
%LOCAL_SIG  Fetch a signal and its own time vector, in any logged format.
data = []; tvec = [];
for k = 1:numel(names)
    try
        raw = local_get(obj, names{k});
    catch
        continue
    end
    if isempty(raw); continue; end

    if isa(raw, 'timeseries')
        data = raw.Data;  tvec = raw.Time(:);
    elseif isstruct(raw) && isfield(raw,'signals')
        data = raw.signals.values;
        if isfield(raw,'time'); tvec = raw.time(:); end
    elseif isnumeric(raw)
        data = raw;
    else
        continue
    end

    % Collapse singleton dimensions, e.g. [1 x 3 x N] -> [3 x N]
    data = squeeze(data);
    if ndims(data) > 2                                        %#ok<ISMAT>
        data = reshape(data, [], size(data, ndims(data))).';
    end
    if isvector(data); data = data(:); end
    % Orient samples down the rows
    if size(data,1) < size(data,2) && size(data,1) <= 4
        data = data.';
    end
    return
end
end


function v = local_get(obj, name)
if isa(obj, 'Simulink.SimulationOutput'); v = obj.get(name); else; v = obj.(name); end
end


function y = local_fit(x, n)
if isempty(x) || n == 0; y = x; return; end
m = min(n, size(x,1));
y = x(1:m, :);
end


function t = local_synthT(tref, n)
if isempty(tref) || n == 0; t = (0:n-1).'; return; end
t = linspace(tref(1), tref(end), n).';
end


% =====================================================================
% Figures
% =====================================================================
function f = local_figPF(D, cfg, W)
f = local_newFig(cfg);
[t, y] = local_dec2(D.tpf, D.pf(:,1), cfg.maxPlotPts);
plot(t, y, 'LineWidth', 1.1); hold on
yline(cfg.pfFloor, '--', sprintf('Floor %.2f', cfg.pfFloor), 'LineWidth', 1.0);
xline(cfg.gateTime, ':', 'Gate release', 'LineWidth', 1.0);
grid on; box on
xlabel('Time (s)'); ylabel('Displacement power factor');
title(local_ttl(W, 'displacement power factor'));
ylim([max(0, min(y)-0.05) 1.02]);
end


function f = local_figBank(D, cfg, W)
f = local_newFig(cfg, true);
nb = min(3, size(D.bank,2));
tiledlayout(2,1,'TileSpacing','loose','Padding','compact');

nexttile; hold on
for b = 1:nb
    [tc, yc] = local_steps(D.ts, D.bank(:,b));
    stairs(tc, yc + 1.4*(nb-b), 'LineWidth', 1.2);
end
grid on; box on; yticks([]); ylabel('Bank state');
legend(arrayfun(@(b) sprintf('B%d (%g kVAr)', b, cfg.bankRatings(b)), ...
       1:nb, 'UniformOutput', false), 'Location','eastoutside');
title(local_ttl(W, 'bank switching and delivered reactive power'));

nexttile
if ~isempty(D.qdel)
    [tc, yc] = local_steps(D.ts, D.qdel);
    stairs(tc, yc, 'LineWidth', 1.2);
    ylabel('Delivered Q (kVAr)');
    subtitle(sprintf('Delivered reactive power, %s', D.qdelSource));
else
    text(0.5,0.5,'delivered kVAr unavailable','Units','normalized', ...
         'HorizontalAlignment','center');
end
grid on; box on; xlabel('Time (s)');
end


function f = local_figEQ(D, cfg, W)
f = local_newFig(cfg);
[t, y] = local_dec2(D.teq, D.eq(:,1), cfg.maxPlotPts);
xl = [t(1) t(end)];
patch([xl fliplr(xl)], [-cfg.deadband -cfg.deadband cfg.deadband cfg.deadband], ...
      [0.85 0.85 0.85], 'EdgeColor','none', 'FaceAlpha', 0.6); hold on
plot(t, y, 'LineWidth', 1.1);
yline(0, 'k-', 'LineWidth', 0.6);
xline(cfg.gateTime, ':', 'Gate release', 'LineWidth', 1.0);
grid on; box on
xlabel('Time (s)'); ylabel('Reactive power error e_Q (kVAr)');
title(local_ttl(W, 'reactive error into the deadband'));
legend({sprintf('\\pm%g kVAr deadband', cfg.deadband), 'e_Q'}, 'Location','best');
end


function f = local_figMeasQ(D, cfg, W)
f = local_newFig(cfg);
[t1, y1] = local_dec2(D.tqm, D.qmeas(:,1), cfg.maxPlotPts);
plot(t1, y1, 'LineWidth', 1.1); hold on
if ~isempty(D.Q)
    [t2, y2] = local_dec2(D.t, D.Q(:,1)/1000, cfg.maxPlotPts);
    plot(t2, y2, 'LineWidth', 0.8);
    legend({'Controller measured Q','Power sensor Q'}, 'Location','best');
end
xline(cfg.gateTime, ':', 'Gate release', 'LineWidth', 1.0);
grid on; box on
xlabel('Time (s)'); ylabel('Reactive power (kVAr)');
title(local_ttl(W, 'measured against sensed reactive power'));
subtitle(['Comparison against the true fundamental residual is in the ' ...
          'Results text file, not here']);
end


function f = local_figWaveform(D, cfg, W)
f = local_newFig(cfg, true);
Twin = cfg.waveCycles / cfg.f1;
tiledlayout(2,1,'TileSpacing','loose','Padding','compact');

axTop = nexttile;
[tA, IA] = local_window(D.t, D.I, cfg.preGateEnd - Twin, cfg.preGateEnd);
if ~isempty(tA)
    plot(tA - tA(1), IA, 'LineWidth', 1.0); grid on; box on
    ylabel('Line current (A)');
    title(local_ttl(W, 'line current before and after compensation'));
    subtitle(sprintf('Uncompensated, window ending at t = %g s, startup gate active', ...
             cfg.preGateEnd));
end

axBot = nexttile;
tEnd = D.t(end);
[tB, IB] = local_window(D.t, D.I, tEnd - Twin, tEnd);
if ~isempty(tB)
    plot(tB - tB(1), IB, 'LineWidth', 1.0); grid on; box on
    xlabel('Time within window (s)'); ylabel('Line current (A)');
    subtitle(sprintf('Compensated, window ending at t = %g s, settled', tEnd));
end

% Common current axis on both panels. Without this the two tiles are
% scaled independently and the reduction is not visible at a glance.
if ~isempty(tA) && ~isempty(tB)
    yMax = max([max(abs(IA(:))), max(abs(IB(:)))]);
    linkaxes([axTop axBot], 'xy');
    ylim(axTop, [-1 1] * ceil(yMax/10)*10);
end
end


function f = local_figSpectrum(D, cfg, W)
f = local_newFig(cfg, true);
orders = 1:cfg.maxOrder;
tiledlayout(2,1,'TileSpacing','loose','Padding','compact');

nexttile
if ~isempty(D.V)
    pv = local_spectrumPct(D.t, D.V(:,1), cfg);
    bar(orders, pv(orders+1)); grid on; box on
    ylabel('Voltage (% of fundamental)');
    title(local_ttl(W, 'harmonic spectrum'));
    subtitle('Phase A voltage'); xlim([0.5 cfg.maxOrder+0.5]);
end

nexttile
pc = local_spectrumPct(D.t, D.I(:,1), cfg);
bar(orders, pc(orders+1)); grid on; box on
xlabel('Harmonic order'); ylabel('Current (% of fundamental)');
subtitle('Phase A line current'); xlim([0.5 cfg.maxOrder+0.5]);
end


function f = local_figOverlay(grp, cfg, field)
f = local_newFig(cfg);
hold on; labels = {};
for k = 1:numel(grp)
    if strcmp(field,'pf'); tt = grp(k).tpf; else; tt = grp(k).ts; end
    y = grp(k).(field);
    if isempty(y) || isempty(tt); continue; end
    n = min(numel(tt), size(y,1));
    if strcmp(field,'pf')
        plot(tt(1:n), y(1:n,1), 'LineWidth', 1.1);
    else
        stairs(tt(1:n), y(1:n,1), 'LineWidth', 1.1);
    end
    labels{end+1} = local_label(grp(k).version, cfg); %#ok<AGROW>
end
grid on; box on; xlabel('Time (s)');
if strcmp(field,'pf')
    ylabel('Displacement power factor');
    yline(cfg.pfFloor, '--', sprintf('Floor %.2f', cfg.pfFloor), 'LineWidth', 1.0);
    what = 'power factor, version comparison';
else
    ylabel('Delivered reactive power (kVAr)');
    what = 'delivered reactive power, version comparison';
end
xline(cfg.gateTime, ':', 'Gate release', 'LineWidth', 1.0);
title(sprintf('%s, %d%% load: %s', ...
      strrep(grp(1).condFull,'_','-'), grp(1).load, what));
if ~isempty(labels); legend(labels, 'Location','best'); end
end


function lbl = local_label(tag, cfg)
%LOCAL_LABEL  Legend text for a version tag, from cfg.overlayLabels.
lbl = tag;
if isempty(cfg.overlayLabels); return; end
idx = find(strcmp(cfg.overlayLabels(:,1), tag), 1, 'first');
if ~isempty(idx); lbl = cfg.overlayLabels{idx,2}; end
end


function s = local_ttl(W, what)
%LOCAL_TTL  Short axes title. The full cell identity is in the file name
%           and belongs in the report caption, not on the figure.
s = sprintf('%s, %d%% load', W.cond, W.load);   % version tag removed for publication
if nargin >= 2 && ~isempty(what)
    s = {s, what};      % two-line title keeps the type large
end
end


% =====================================================================
% Numerics
% =====================================================================
function pct = local_spectrumPct(t, x, cfg)
Twin = cfg.nCycles / cfg.f1;
[tw, xw] = local_window(t, x, t(end) - Twin, t(end));
if numel(tw) < 8; pct = zeros(cfg.maxOrder+1,1); return; end

X = zeros(cfg.maxOrder+1, 1);
for h = 0:cfg.maxOrder
    integ = trapz(tw, xw .* exp(-1j*2*pi*h*cfg.f1*tw));
    if h == 0; X(h+1) = abs(integ/Twin); else; X(h+1) = abs(2*integ/Twin); end
end
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


function y = local_dec(x, maxPts)
if isempty(x); y = x; return; end
n = size(x,1);
if n <= maxPts; y = x; return; end
y = x(round(linspace(1, n, maxPts)), :);
end


function [td, yd] = local_dec2(t, y, maxPts)
n = min(numel(t), size(y,1));
t = t(1:n); y = y(1:n, :);
if n <= maxPts; td = t; yd = y; return; end
idx = round(linspace(1, n, maxPts));
td = t(idx); yd = y(idx, :);
end


function [tc, yc] = local_steps(t, y)
n = min(numel(t), size(y,1));
t = t(1:n); y = y(1:n, 1);
d = [true; diff(y) ~= 0]; d(end) = true;
tc = t(d); yc = y(d);
end


% =====================================================================
% Plumbing
% =====================================================================
function f = local_newFig(cfg, tall)
%LOCAL_NEWFIG  White-canvas figure, immune to the MATLAB dark theme.
if nargin < 2 || isempty(tall); tall = false; end
h = cfg.figHeightCm;
if tall; h = cfg.figTallCm; end
f = figure('Units','centimeters', ...
           'Position',[2 2 cfg.figWidthCm h], ...
           'Color','w','Visible','off','InvertHardcopy','off');
% R2023b and later apply a figure theme that can force dark axes on
% export. Pin it to light. Wrapped because older releases lack theme().
try, theme(f,'light'); catch, end
end


function local_save(f, outDir, stem, cfg)
% ---- font family and base size everywhere -------------------------------
set(findall(f,'-property','FontName'), 'FontName', cfg.fontName);
set(findall(f,'-property','FontSize'), 'FontSize', cfg.fontSize);

% ---- force light colours regardless of the session theme ----------------
set(f, 'Color', 'w', 'InvertHardcopy', 'off');
ax = findall(f, 'Type', 'axes');
set(ax, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'ZColor', 'k', ...
        'GridColor', [0.75 0.75 0.75], 'MinorGridColor', [0.85 0.85 0.85], ...
        'GridAlpha', 1, 'Box', 'on');
set(findall(f, 'Type', 'text'), 'Color', 'k');
lg = findall(f, 'Type', 'legend');
set(lg, 'TextColor', 'k', 'Color', 'w', 'EdgeColor', [0.4 0.4 0.4], ...
        'FontSize', cfg.legendSize);
tl = findall(f, 'Type', 'tiledlayout');
for k = 1:numel(tl)
    try, tl(k).Title.Color = 'k'; catch, end
end

% ---- size hierarchy: labels and titles larger than tick labels ----------
for k = 1:numel(ax)
    a = ax(k);
    try, a.XLabel.FontSize = cfg.labelSize; a.XLabel.Color = 'k'; catch, end
    try, a.YLabel.FontSize = cfg.labelSize; a.YLabel.Color = 'k'; catch, end
    try, a.Title.FontSize  = cfg.titleSize; a.Title.Color  = 'k'; catch, end
    try, a.Subtitle.FontSize = cfg.subSize; a.Subtitle.Color = [0.25 0.25 0.25]; catch, end
end
drawnow
exportgraphics(f, fullfile(outDir, [stem '.png']), 'Resolution', cfg.dpi);
if cfg.savePDF
    try
        exportgraphics(f, fullfile(outDir, [stem '.pdf']), 'ContentType','vector');
    catch ME
        warning('        vector export failed for %s: %s', stem, ME.message);
    end
end
end


function tf = local_allExist(outDir, stem, types, cfg)
map = struct('PF','_PFtrace','Bank','_BankState','eQ','_ReactiveError', ...
             'Waveform','_Waveforms','Spectrum','_Spectrum','MeasQ','_MeasuredQ');
tf = true;
for k = 1:numel(types)
    if ~isfield(map, types{k}); continue; end
    if strcmp(types{k},'MeasQ'); continue; end   % absent in v21 by construction
    if ~isfile(fullfile(outDir, [stem map.(types{k}) '.png'])); tf = false; return; end
    if cfg.savePDF && ~isfile(fullfile(outDir, [stem map.(types{k}) '.pdf']))
        tf = false; return
    end
end
end


function st = local_pushStyle(cfg)
st = struct();
st.axName = get(groot,'defaultAxesFontName');
st.txName = get(groot,'defaultTextFontName');
st.lgName = get(groot,'defaultLegendFontName');
st.axSize = get(groot,'defaultAxesFontSize');
set(groot,'defaultAxesFontName',   cfg.fontName);
set(groot,'defaultTextFontName',   cfg.fontName);
set(groot,'defaultLegendFontName', cfg.fontName);
set(groot,'defaultAxesFontSize',   cfg.fontSize);
end


function local_popStyle(st)
set(groot,'defaultAxesFontName',   st.axName);
set(groot,'defaultTextFontName',   st.txName);
set(groot,'defaultLegendFontName', st.lgName);
set(groot,'defaultAxesFontSize',   st.axSize);
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
