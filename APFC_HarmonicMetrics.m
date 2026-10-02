function R = APFC_HarmonicMetrics(out, info)
%APFC_HARMONICMETRICS  IEEE-519 harmonic / power-factor metrics for one APFC run.
%
%   R = APFC_HarmonicMetrics(out, info)
%
%   Post-processes ONE 50 s run of an APFC full model into the reported
%   harmonic and power-factor metrics (report Sections 4.4.3 and 4.4.4).
%   Waveform metrics come from a leakage-free integer-cycle Fourier
%   projection of out.V_sim / out.I_sim over a whole number of fundamental
%   cycles; only the two window endpoints are interpolated, so the
%   non-uniform samples of the variable-step solver are used directly. A
%   native thd() call provides an independent cross-check.
%
%   Two windows are analysed: the uncompensated window ending at t = 24 s
%   (before the 25 s startup gate opens) and the compensated window ending
%   at the final sample.
%
%   Also reported:
%     * Fundamental residual reactive power Q1_true_VAR for each window.
%     * Measured-Q accuracy block, if out.Qmeas_sim was logged.
%     * STEADY-STATE / HUNTING CHECK over the last t_settle_win seconds:
%       whether the bank state is constant, and the PF and eQ envelopes.
%       The settled scalars are only trustworthy when this check says
%       SETTLED; under HUNTING they are a snapshot, and the block says so.
%
%   INPUT  out  : Simulink.SimulationOutput logged by the full model
%                 (tout, V_sim, I_sim, P_sim, Q_sim, PFdisp_sim, eQ_sim,
%                 S_sim; Qmeas_sim optional)
%          info : struct with load_pct, cond_tag, cond_desc, orders, ratios
%                 and I_L (as built by APFC_RunCampaign_Ablation); optional
%                 f0, Ncyc, Hmax, writefile, t_comp_end, t_uncomp_end and
%                 t_settle_win (default 15 s)
%   OUTPUT R    : struct of metrics. Unless info.writefile is false, the
%                 report is also written to Results_L###_<tag>.txt in the
%                 current folder.
%
%   Requires: Signal Processing Toolbox (thd).
%
% Project : Fuzzy Logic-Controlled Automatic Power Factor Correction Using
%           Thyristor-Switched Capacitor Banks for a 30 kW Induction Motor
% Author  : Praise Oluwasina Akinlolu, Department of Electrical and
%           Electronics Engineering, University of Lagos
% MATLAB  : R2025b
% Licence : MIT (see LICENSE in the repository root)

% ---------- defaults ----------
if ~isfield(info,'f0'),           info.f0 = 50;   end
if ~isfield(info,'Ncyc'),         info.Ncyc = 20; end
if ~isfield(info,'Hmax'),         info.Hmax = 25; end
if ~isfield(info,'writefile'),    info.writefile = true; end
if ~isfield(info,'t_settle_win'), info.t_settle_win = 15; end   % steady-state window (s)
f0 = info.f0;  Ncyc = info.Ncyc;  Hmax = info.Hmax;

% ---------- extract raw waveforms as [N x 3] and time as [N x 1] ----------
t = out.tout(:);
V = permute(out.V_sim, [3 2 1]);
I = permute(out.I_sim, [3 2 1]);
if size(V,2) ~= 3 || size(I,2) ~= 3
    error('APFC:shape', 'Expected 3-phase [1x3xN] V_sim/I_sim; got V=%s, I=%s.', ...
        mat2str(size(out.V_sim)), mat2str(size(out.I_sim)));
end
[t, iu] = unique(t);
V = V(iu,:);  I = I(iu,:);

% ---------- settled scalars from the timeseries channels ----------
P_sensor = out.P_sim(end);
Q_sensor = out.Q_sim(end);
DPF_disp = squeezeLast(out.PFdisp_sim.Data);
eQ_final = squeezeLast(out.eQ_sim.Data);
S_state  = settledVec(out.S_sim.Data);

% ---------- window ends ----------
if ~isfield(info,'t_comp_end'),   info.t_comp_end   = t(end); end
if ~isfield(info,'t_uncomp_end'), info.t_uncomp_end = 24;     end

% ---------- analyse compensated and uncompensated windows ----------
Wc = analyze_window(t, V, I, f0, Ncyc, info.t_comp_end,   Hmax);
Wu = analyze_window(t, V, I, f0, Ncyc, info.t_uncomp_end, Hmax);

% ---------- native thd() cross-check (phase-a, compensated window) ----------
[THDv_nat, THDi_nat] = native_thd_check(t, V(:,1), I(:,1), f0, Ncyc, ...
                                        info.t_comp_end, Hmax);

% ---------- assemble ----------
R = struct();
R.info = info;
R.S_state = S_state;  R.eQ_kVAR = eQ_final;
R.P_sensor_W = P_sensor;  R.Q_sensor_VAR = Q_sensor;  R.DPF_disp = DPF_disp;
R.comp = Wc;  R.uncomp = Wu;
R.THDv_native_pct = THDv_nat;  R.THDi_native_pct = THDi_nat;

% ---------- steady-state / hunting check ----------
R.settle = settle_check(out, info.t_comp_end, info.t_settle_win);

% ---------- measured-Q accuracy (ablation mechanism metric) ----------
R.Qmeas_logged = false;
try, logged = out.who; catch, logged = {}; end
if any(strcmp(logged,'Qmeas_sim'))
    Qm = squeezeLast(out.Qmeas_sim.Data);
    R.Qmeas_logged   = true;
    R.Qmeas_VAR      = Qm;
    R.Qtrue_fund_VAR = Wc.Q1_true_VAR;
    R.Qmeas_err_VAR  = Qm - Wc.Q1_true_VAR;
    R.Qmeas_err_pct  = 100 * R.Qmeas_err_VAR / max(abs(Wc.Q1_true_VAR), 1);
end

% ---------- report ----------
txt = format_report(R);
fprintf('%s', txt);
if info.writefile
    fn = sprintf('Results_L%03d_%s.txt', round(info.load_pct), info.cond_tag);
    fid = fopen(fn, 'w');
    if fid > 0
        fprintf(fid, '%s', txt); fclose(fid);
        fprintf('[written to %s]\n', fullfile(pwd, fn));
    else
        warning('APFC:file', 'Could not open %s for writing.', fn);
    end
end
end % ===================== main =====================


function ST = settle_check(out, t_end, win)
% Steady-state / hunting diagnostic over [t_end-win, t_end].
% Primary verdict = bank state constant over the window (banks fixed => settled).
ST = struct('checked',false,'hunting',false);
try
    tS = out.S_sim.Time(:);
    DS = squeeze(out.S_sim.Data);
    if size(DS,2) ~= 3 && size(DS,1) == 3, DS = DS.'; end
    if size(DS,1) ~= numel(tS) && size(DS,2) == numel(tS), DS = DS.'; end
    m  = tS >= (t_end - win) - 1e-9 & tS <= t_end + 1e-9;
    Sw = round(DS(m,:));                       % bank states are 0/1
    ST.states     = unique(Sw, 'rows');
    ST.n_states   = size(ST.states,1);
    ST.S_constant = (ST.n_states == 1);

    tP = out.PFdisp_sim.Time(:);  DP = squeeze(out.PFdisp_sim.Data);  DP = DP(:);
    mp = tP >= (t_end - win) - 1e-9 & tP <= t_end + 1e-9;
    PFw = DP(mp);
    ST.PF_min = min(PFw);  ST.PF_max = max(PFw);  ST.PF_pp = ST.PF_max - ST.PF_min;

    te = out.eQ_sim.Time(:);  DE = squeeze(out.eQ_sim.Data);  DE = DE(:);
    me = te >= (t_end - win) - 1e-9 & te <= t_end + 1e-9;
    eQw = DE(me);
    ST.eQ_min = min(eQw);  ST.eQ_max = max(eQw);  ST.eQ_pp = ST.eQ_max - ST.eQ_min;

    ST.win     = win;
    ST.checked = true;
    ST.hunting = ~ST.S_constant;              % banks must be fixed to be settled
catch ME
    ST.err = ME.message;
end
end


function W = analyze_window(t, V, I, f0, Ncyc, tend, Hmax)
% Integer-cycle Fourier projection + time-domain totals over [tend-T, tend].
T = Ncyc / f0;
tstart = tend - T;
if tstart < t(1) - 1e-9 || tend > t(end) + 1e-9
    error('APFC:window', 'Window [%.4f, %.4f] s lies outside data range [%.4f, %.4f] s.', ...
        tstart, tend, t(1), t(end));
end
in = t > tstart & t < tend;
tw = [tstart;              t(in);   tend];
Vw = [interp1(t,V,tstart); V(in,:); interp1(t,V,tend)];
Iw = [interp1(t,I,tstart); I(in,:); interp1(t,I,tend)];

aV = zeros(Hmax,3); bV = zeros(Hmax,3);
aI = zeros(Hmax,3); bI = zeros(Hmax,3);
for h = 1:Hmax
    ch = cos(2*pi*h*f0*tw);  sh = sin(2*pi*h*f0*tw);
    aV(h,:) = (2/T) * trapz(tw, Vw.*ch);
    bV(h,:) = (2/T) * trapz(tw, Vw.*sh);
    aI(h,:) = (2/T) * trapz(tw, Iw.*ch);
    bI(h,:) = (2/T) * trapz(tw, Iw.*sh);
end
magV = hypot(aV, bV);  magI = hypot(aI, bI);
phV  = atan2(-bV, aV);  phI = atan2(-bI, aI);

V1 = magV(1,:);  I1 = magI(1,:);
THDv_ph = sqrt(sum(magV(2:end,:).^2, 1)) ./ V1 * 100;
THDi_ph = sqrt(sum(magI(2:end,:).^2, 1)) ./ I1 * 100;
DPF_ph  = cos(phV(1,:) - phI(1,:));
Q1_true_ph = 0.5 .* V1 .* I1 .* sin(phV(1,:) - phI(1,:));

P_total = (1/T) * trapz(tw, sum(Vw.*Iw, 2));
Vrms    = sqrt((1/T) * trapz(tw, Vw.^2));
Irms    = sqrt((1/T) * trapz(tw, Iw.^2));
S_arith = sum(Vrms .* Irms);
PF_true = P_total / S_arith;

W = struct();
W.tstart=tstart; W.tend=tend; W.T=T;
W.V1_peak_mean = mean(V1);  W.I1_peak_mean = mean(I1);
W.THDv_pct = mean(THDv_ph); W.THDv_ph = THDv_ph;
W.THDi_pct = mean(THDi_ph); W.THDi_ph = THDi_ph;
W.DPF = mean(DPF_ph);       W.DPF_ph = DPF_ph;
W.Q1_true_VAR = sum(Q1_true_ph);
W.P_total_W = P_total;
W.Vrms_ph = Vrms; W.Irms_ph = Irms; W.S_VA = S_arith;
W.PF_true = PF_true;
W.Ih_rms   = mean(magI, 2) / sqrt(2);
W.Vh_ratio = mean(magV, 2) / mean(V1) * 100;
end


function [THDv, THDi] = native_thd_check(t, v1, i1, f0, Ncyc, tend, Hmax)
T = Ncyc / f0;  tstart = tend - T;
fsr = 25600;  M = round(T * fsr);
tq  = tstart + (0:M-1).' / fsr;
vq  = interp1(t, v1, tq, 'pchip');
iq  = interp1(t, i1, tq, 'pchip');
THDv = 100 * 10.^(thd(vq, fsr, Hmax) / 20);
THDi = 100 * 10.^(thd(iq, fsr, Hmax) / 20);
end


function v = squeezeLast(D)
D = squeeze(D);  D = D(:);  v = D(end);
end


function s = settledVec(D)
D = squeeze(D);
if size(D,2) ~= 3 && size(D,1) == 3, D = D.'; end
s = D(end,:);
end


function txt = format_report(R)
o = R.info.orders(:).';  c = R.comp;  u = R.uncomp;  nl = newline;
L = {};
L{end+1} = '==================================================================';
L{end+1} = sprintf(' APFC HARMONIC METRICS  |  Load %d%%  |  %s  (%s)', ...
                   round(R.info.load_pct), R.info.cond_tag, R.info.cond_desc);
L{end+1} = sprintf(' Injected orders : %s', mat2str(o));
L{end+1} = sprintf(' Injected ratios : %s   (V_h / V_1)', mat2str(R.info.ratios));
L{end+1} = '==================================================================';
L{end+1} = sprintf(' Bank state (settled)     S  = [%d %d %d]', R.S_state);
L{end+1} = sprintf(' Reactive error (settled) eQ = %+9.4f kVAR', R.eQ_kVAR);
if isfield(R,'settle') && R.settle.checked
    st = R.settle;
    L{end+1} = '------------------------------------------------------------------';
    L{end+1} = sprintf(' STEADY-STATE CHECK (last %.0f s)', st.win);
    if st.S_constant
        L{end+1} = sprintf('   bank state         : CONSTANT  [%d %d %d]', st.states(1,:));
    else
        L{end+1} = sprintf('   bank state         : CHANGING  (%d distinct states in window):', st.n_states);
        for r = 1:size(st.states,1)
            L{end+1} = sprintf('                          [%d %d %d]', st.states(r,:));
        end
    end
    L{end+1} = sprintf('   PF envelope        : [%.4f, %.4f]   (p-p %.4f)', st.PF_min, st.PF_max, st.PF_pp);
    L{end+1} = sprintf('   eQ envelope [kVAR] : [%+.4f, %+.4f]  (p-p %.4f)', st.eQ_min, st.eQ_max, st.eQ_pp);
    if st.hunting
        L{end+1} = '   VERDICT            : *** HUNTING / NOT SETTLED -- values below are a SNAPSHOT ***';
    else
        L{end+1} = '   VERDICT            : SETTLED';
    end
end
L{end+1} = '------------------------------------------------------------------';
L{end+1} = '                                  UNCOMP        COMP';
L{end+1} = sprintf(' Displacement PF (DPF)         %8.4f    %8.4f', u.DPF, c.DPF);
L{end+1} = sprintf(' True PF  P/(Vrms*Irms)        %8.4f    %8.4f', u.PF_true, c.PF_true);
L{end+1} = sprintf(' DPF/sqrt(1+THDi^2) [check]    %8.4f    %8.4f', ...
                   u.DPF/sqrt(1+(u.THDi_pct/100)^2), c.DPF/sqrt(1+(c.THDi_pct/100)^2));
L{end+1} = sprintf(' Fundamental residual Q [VAR]  %8.1f    %8.1f', u.Q1_true_VAR, c.Q1_true_VAR);
L{end+1} = '------------------------------------------------------------------';
L{end+1} = ' Distortion (compensated window)';
L{end+1} = sprintf('   THD_V = %8.4f %%    (native thd() = %8.4f %%)', c.THDv_pct, R.THDv_native_pct);
L{end+1} = sprintf('   THD_I = %8.4f %%    (native thd() = %8.4f %%)', c.THDi_pct, R.THDi_native_pct);
L{end+1} = sprintf('   TDD_I = %8.4f %%    (I_L = %.1f A)', ...
                   sqrt(sum(c.Ih_rms(2:end).^2))/R.info.I_L*100, R.info.I_L);
if isfield(R,'Qmeas_logged') && R.Qmeas_logged
    L{end+1} = '------------------------------------------------------------------';
    L{end+1} = ' Measured-Q accuracy (FLC input vs true fundamental residual Q)';
    L{end+1} = sprintf('   Q measured (FLC dq)   = %11.1f VAR', R.Qmeas_VAR);
    L{end+1} = sprintf('   Q true (fundamental)  = %11.1f VAR', R.Qtrue_fund_VAR);
    L{end+1} = sprintf('   measurement error     = %11.1f VAR   (%.2f %%)', R.Qmeas_err_VAR, R.Qmeas_err_pct);
end
L{end+1} = '------------------------------------------------------------------';
L{end+1} = ' Per-order (compensated)   order    V_h/V_1 [%]    I_h [A rms]';
for k = 1:numel(o)
    h = o(k);
    L{end+1} = sprintf('                           %4d    %10.4f    %10.4f', h, c.Vh_ratio(h), c.Ih_rms(h));
end
L{end+1} = '------------------------------------------------------------------';
L{end+1} = ' Cross-checks';
L{end+1} = sprintf('   P_total (waveform) = %11.2f W   vs P_sim(end) = %11.2f W', c.P_total_W, R.P_sensor_W);
L{end+1} = sprintf('   DPF (script)       = %9.4f       vs PFdisp     = %9.4f', c.DPF, R.DPF_disp);
L{end+1} = sprintf('   V1_peak (phase)    = %9.4f V     (expect ~338.85 = phase-neutral)', c.V1_peak_mean);
L{end+1} = sprintf('   I1_peak (phase)    = %9.4f A', c.I1_peak_mean);
L{end+1} = '==================================================================';
txt = [strjoin(L, nl) nl];
end
