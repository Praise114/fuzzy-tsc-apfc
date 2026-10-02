%% ALPF_Tables_Design.m
% ALPF - Gross and fine lookup tables for the adaptive all-pass (AAP)
% control block (report Section 3.5.5)
%
% Architecture after G. Dossi, "Adaptive low-pass filter for zero-crossing
% detection", US 12,294,375 B2, Fig. 3:
%
%   GROSS table: 80 entries, 1.125 deg/step. Constructed so the nominal
%     AAP phase at 50 Hz lands EXACTLY on entry 40 (k_powerOn = 40),
%     matching the patent's index-40 power-on at the operating-point
%     centre; power-on residual is therefore zero. Each entry stores the
%     ABSOLUTE all-pass coefficient alpha from a closed-form quadratic,
%     selecting the |alpha| < 1 root for filter stability.
%
%   FINE table: 80 entries, ONE per gross operating point (single shared
%     index, frozen during the fine state). Each entry is the SIGNED
%     delta-alpha producing a uniform fine phase nudge dphi_fine at THAT
%     operating point, from the closed-form slope d(phi)/d(alpha) at
%     alpha_gross(j). Additive: alpha(k) = alpha(k-1) + Fine(index)*DIR.
%     dphi_fine is a tunable convergence parameter; 0.05 deg is used,
%     within the < 20 us zero-crossing error budget.
%
% AAP topology: Form 2 all-pass - H(z) = (alpha - z^-1)/(1 - alpha*z^-1).
%   Positive phase at 50 Hz. d(phi)/d(alpha) < 0, so the signed
%   delta-alpha entries are negative (raising phase lowers alpha).
%   FAP uses Form 1 (negative phase); AAP uses Form 2.
%
% Dependencies (located by searching upward for the '03 - ALPF' folder):
%   03 - ALPF\01 - LPF\ALPF_LPF_Coefficients.mat
%   03 - ALPF\02 - FAP\ALPF_FAP_Coefficients.mat
%
% Output: ALPF_Tables.mat (Tables struct only), saved beside this script.
% This is a standalone design script: it starts with clear, clc and
% close all, so run it in its own session, not after APFC_Parameters.m.
%
% Project : Fuzzy Logic-Controlled Automatic Power Factor Correction Using
%           Thyristor-Switched Capacitor Banks for a 30 kW Induction Motor
% Author  : Praise Oluwasina Akinlolu, Department of Electrical and
%           Electronics Engineering, University of Lagos
% MATLAB  : R2025b
% Licence : MIT (see LICENSE in the repository root)

clear; clc; close all;

%% -- 0. Resolve dependency paths (robust to script location) -----------------
% Coefficient files live at:
%   <03 - ALPF>\01 - LPF\ALPF_LPF_Coefficients.mat
%   <03 - ALPF>\02 - FAP\ALPF_FAP_Coefficients.mat
% Search upward from this script's own folder for the '03 - ALPF' root, so
% the paths resolve regardless of where the script sits in the project tree.
scriptDir = fileparts(mfilename('fullpath'));

alpfRoot = '';
d = scriptDir;
while true
    if isfile(fullfile(d, '01 - LPF', 'ALPF_LPF_Coefficients.mat'))
        alpfRoot = d;                                      % d IS the '03 - ALPF' root
        break;
    elseif isfile(fullfile(d, '03 - ALPF', '01 - LPF', 'ALPF_LPF_Coefficients.mat'))
        alpfRoot = fullfile(d, '03 - ALPF');               % d sits above '03 - ALPF'
        break;
    end
    parent = fileparts(d);
    if isempty(parent) || strcmp(parent, d)                % reached the drive root
        break;
    end
    d = parent;
end

if isempty(alpfRoot)
    error(['Could not locate ALPF_LPF_Coefficients.mat by searching upward from:' ...
           '\n  %s\nExpected it under  ...\\03 - ALPF\\01 - LPF\\'], scriptDir);
end

LPF_mat = fullfile(alpfRoot, '01 - LPF', 'ALPF_LPF_Coefficients.mat');
FAP_mat = fullfile(alpfRoot, '02 - FAP', 'ALPF_FAP_Coefficients.mat');

if ~isfile(FAP_mat)
    error('Located ALPF root:\n  %s\nbut FAP coefficients are missing:\n  %s', ...
          alpfRoot, FAP_mat);
end

fprintf('Resolved ALPF root: %s\n', alpfRoot);

%% -- 1. Load dependencies ----------------------------------------------------
LPF_data   = load(LPF_mat, 'sos', 'fs', 'phase_50Hz');
sos        = LPF_data.sos;
fs         = LPF_data.fs;            % 12500 Hz
phi_LPF_50 = LPF_data.phase_50Hz;   % degrees

FAP_data  = load(FAP_mat, 'FAP');
FAP       = FAP_data.FAP;
alpha_FAP = FAP.alpha;              % 0.9751778762

if FAP.fs ~= fs
    error('fs mismatch: LPF file = %.0f Hz, FAP file = %.0f Hz', fs, FAP.fs);
end

f0       = FAP.f0;
omega_d0 = 2*pi*f0/fs;

fprintf('=== DEPENDENCIES LOADED ===\n');
fprintf('fs         = %.0f Hz\n', fs);
fprintf('phi_LPF_50 = %.4f deg  [from LPF design]\n', phi_LPF_50);
fprintf('alpha_FAP  = %.10f  [from FAP design]\n\n', alpha_FAP);

%% -- 2. Phase + slope evaluation functions -----------------------------------
% FAP: Form 1 - H(z) = (z^-1 - alpha)/(1 - alpha*z^-1) - negative phase
phi_FAP_fn = @(a, od) ( atan2(-sin(od), cos(od) - a) ...
                       - atan2(a*sin(od), 1 - a*cos(od)) ) * 180/pi;

% AAP: Form 2 - H(z) = (alpha - z^-1)/(1 - alpha*z^-1) - positive phase
phi_AAP_fn = @(a, od) ( atan2(sin(od), a - cos(od)) ...
                       - atan2(a*sin(od), 1 - a*cos(od)) ) * 180/pi;

% AAP at 50 Hz - alpha is the free variable (degrees)
phi_AAP_50 = @(a) phi_AAP_fn(a, omega_d0);

% Closed-form slope d(phi_AAP)/d(alpha) for Form 2 (deg per unit-alpha):
%   = -2 sin(od) / (1 - 2 alpha cos(od) + alpha^2)
dphidalpha_fn = @(a, od) ( -2*sin(od) / (1 - 2*a*cos(od) + a^2) ) * 180/pi;

% LPF SOS cascade phase (degrees)
phi_LPF_fn = @(od) eval_LPF_phase(sos, od);

%% -- 3. PRE-VERIFICATION: Form 2 reachable phase range at 50 Hz ---------------
alpha_scan = linspace(-0.9999, 0.9999, 10000);
phi_scan   = arrayfun(phi_AAP_50, alpha_scan);

fprintf('=== AAP FORM 2 REACHABLE PHASE RANGE AT 50 Hz ===\n');
fprintf('[%.4f, %.4f] deg\n\n', min(phi_scan), max(phi_scan));

%% -- 4. phi_LPF, phi_FAP, phi_AAP across 45-55 Hz -----------------------------
f_band       = 45:0.1:55;
N            = length(f_band);
phi_LPF_band = zeros(1, N);
phi_FAP_band = zeros(1, N);

for ii = 1:N
    od = 2*pi*f_band(ii)/fs;
    phi_LPF_band(ii) = phi_LPF_fn(od);
    phi_FAP_band(ii) = phi_FAP_fn(alpha_FAP, od);
end

phi_AAP_band   = -180 - phi_LPF_band - phi_FAP_band;
[~, idx50]     = min(abs(f_band - 50));     % robust to colon round-off
phi_AAP_nom    = phi_AAP_band(idx50);

fprintf('=== AAP PHASE REQUIREMENT ACROSS 45-55 Hz ===\n');
fprintf('phi_AAP(45 Hz) = %.4f deg\n', phi_AAP_band(1));
fprintf('phi_AAP(50 Hz) = %.4f deg\n', phi_AAP_nom);
fprintf('phi_AAP(55 Hz) = %.4f deg\n', phi_AAP_band(end));
fprintf('Total swing    = %.4f deg\n\n', phi_AAP_band(end) - phi_AAP_band(1));

% LPF phase cross-check: loaded scalar vs recomputed SOS (wrap-safe)
d_lpf = mod(phi_LPF_band(idx50) - phi_LPF_50 + 180, 360) - 180;
fprintf('LPF phase cross-check (loaded vs recomputed) = %.2e deg\n', abs(d_lpf));
if abs(d_lpf) > 1e-6
    error('LPF phase mismatch: loaded %.4f vs recomputed %.4f deg.', ...
          phi_LPF_50, phi_LPF_band(idx50));
end

% Cascade budget cross-check against the FAP design (ALPF_FAP_Design.m)
budget_discrepancy = abs(phi_AAP_nom - FAP.phi_AAP_required_at_50Hz);
fprintf('Cascade budget cross-check:\n');
fprintf('  Expected phi_AAP(50 Hz) [FAP]  : %.4f deg\n', FAP.phi_AAP_required_at_50Hz);
fprintf('  Computed phi_AAP(50 Hz) [sweep] : %.4f deg\n', phi_AAP_nom);
fprintf('  Discrepancy                     : %.2e deg\n', budget_discrepancy);
if budget_discrepancy > 1e-3
    error('phi_AAP cross-check FAILED: discrepancy = %.4f deg.', budget_discrepancy);
else
    fprintf('  Cross-check PASSED.\n\n');
end

%% -- 5. Gross table: phase targets, nominal on entry k_powerOn = 40 -----------
gross_step = 1.125;     % deg per gross step (patent)
n_gross    = 80;        % entries (patent)
k_powerOn  = 40;        % power-on index (patent index 40, op-point centre)

% Nominal lands exactly on entry k_powerOn -> zero power-on residual
phi_gross  = phi_AAP_nom + ((1:n_gross) - k_powerOn) * gross_step;

fprintf('=== GROSS TABLE SPAN ===\n');
fprintf('Nominal phi_AAP(50 Hz)  = %.4f deg  (placed on entry k=%d)\n', ...
        phi_AAP_nom, k_powerOn);
fprintf('Gross table span        = [%.4f, %.4f] deg\n', phi_gross(1), phi_gross(end));

% Band edges must lie inside the table span
in45 = phi_AAP_band(1)   >= phi_gross(1) && phi_AAP_band(1)   <= phi_gross(end);
in55 = phi_AAP_band(end) >= phi_gross(1) && phi_AAP_band(end) <= phi_gross(end);
fprintf('phi_AAP(45 Hz) = %.4f deg — within table? %s\n', phi_AAP_band(1),   string(in45));
fprintf('phi_AAP(55 Hz) = %.4f deg — within table? %s\n', phi_AAP_band(end), string(in55));
if ~in45 || ~in55
    error('Band-edge AAP requirement falls outside gross table span.');
end

% All gross targets must lie inside the Form 2 reachable range
if any(phi_gross < min(phi_scan)) || any(phi_gross > max(phi_scan))
    error('One or more gross targets fall outside AAP Form 2 reachable range.');
else
    fprintf('All %d gross targets within AAP Form 2 reachable range.\n\n', n_gross);
end

%% -- 6. Gross alpha via closed-form quadratic (|alpha| < 1 selection) ---------
alpha_gross    = zeros(1, n_gross);
alpha_unstable = zeros(1, n_gross);   % rejected root, kept for stability record

for k = 1:n_gross
    [alpha_gross(k), alpha_unstable(k)] = solve_alpha_form2(phi_gross(k), omega_d0);
end

% Self-consistency: re-evaluate the phase from each solved alpha
phi_check    = arrayfun(phi_AAP_50, alpha_gross);
gross_maxerr = max(abs(phi_check - phi_gross));

fprintf('=== GROSS ALPHA (closed-form quadratic, stable root) ===\n');
fprintf('k=1  : alpha = %.10f  phi = %.4f deg  (rejected root %.6f)\n', ...
        alpha_gross(1),  phi_gross(1),  alpha_unstable(1));
fprintf('k=%-2d : alpha = %.10f  phi = %.4f deg  (rejected root %.6f)\n', ...
        k_powerOn, alpha_gross(k_powerOn), phi_gross(k_powerOn), alpha_unstable(k_powerOn));
fprintf('k=80 : alpha = %.10f  phi = %.4f deg  (rejected root %.6f)\n', ...
        alpha_gross(80), phi_gross(80), alpha_unstable(80));
fprintf('Max |re-evaluated phi - target| over 80 entries = %.3e deg\n', gross_maxerr);
if gross_maxerr > 1e-6
    error('Gross alpha self-consistency FAILED (max err = %.3e deg).', gross_maxerr);
else
    fprintf('Gross alpha self-consistency PASSED.\n\n');
end

%% -- 7. Power-on point -------------------------------------------------------
residual_powerOn = phi_AAP_nom - phi_gross(k_powerOn);   % zero by construction
fprintf('=== POWER-ON POINT ===\n');
fprintf('Power-on index k_powerOn = %d\n', k_powerOn);
fprintf('phi at power-on          = %.4f deg\n', phi_gross(k_powerOn));
fprintf('alpha at power-on        = %.10f\n', alpha_gross(k_powerOn));
fprintf('Power-on residual        = %.3e deg  (zero by construction)\n\n', residual_powerOn);

%% -- 8. Fine table: per-operating-point signed delta-alpha --------------------
n_fine    = n_gross;     % one fine entry per gross operating point
dphi_fine = 0.05;        % deg - uniform fine nudge (tunable)

dphidalpha_gross = arrayfun(@(a) dphidalpha_fn(a, omega_d0), alpha_gross);  % deg/unit-alpha
alpha_fine_delta = dphi_fine ./ dphidalpha_gross;                          % signed (negative)

zc_error_us = dphi_fine * (1/50) / 360 * 1e6;    % terminal ZC error at 50 Hz, us
fprintf('=== FINE TABLE (per-operating-point delta-alpha) ===\n');
fprintf('Uniform fine nudge dphi_fine        = %.4f deg  (tunable)\n', dphi_fine);
fprintf('Implied terminal ZC error           = %.3f us   (budget < 20 us)\n', zc_error_us);
fprintf('Cycles to clear one half-gross-step = %.1f\n', (gross_step/2)/dphi_fine);
fprintf('slope at k=1   = %9.3f deg/unit-alpha -> delta-alpha = %.4e\n', ...
        dphidalpha_gross(1),         alpha_fine_delta(1));
fprintf('slope at k=%-2d  = %9.3f deg/unit-alpha -> delta-alpha = %.4e\n', ...
        k_powerOn, dphidalpha_gross(k_powerOn), alpha_fine_delta(k_powerOn));
fprintf('slope at k=80  = %9.3f deg/unit-alpha -> delta-alpha = %.4e\n', ...
        dphidalpha_gross(80),        alpha_fine_delta(80));
fprintf('All fine entries negative (Option 1)? %s\n\n', string(all(alpha_fine_delta < 0)));
if ~all(alpha_fine_delta < 0)
    error('Fine table sign check FAILED: not all delta-alpha entries negative.');
end

%% -- 9. End-to-end cascade verification at power-on ---------------------------
phi_AAP_powerOn  = phi_AAP_50(alpha_gross(k_powerOn));
phi_LPF_50_check = phi_LPF_band(idx50);
phi_FAP_50_check = phi_FAP_band(idx50);
cascade_powerOn  = phi_LPF_50_check + phi_FAP_50_check + phi_AAP_powerOn;

fprintf('=== END-TO-END CASCADE AT POWER-ON ===\n');
fprintf('phi_LPF(50 Hz)     = %.4f deg\n', phi_LPF_50_check);
fprintf('phi_FAP(50 Hz)     = %.4f deg\n', phi_FAP_50_check);
fprintf('phi_AAP at k=%-2d    = %.4f deg\n', k_powerOn, phi_AAP_powerOn);
fprintf('Cascade total      = %.6f deg\n', cascade_powerOn);
fprintf('Residual from -180 = %.3e deg\n', cascade_powerOn + 180);
if abs(cascade_powerOn + 180) > 1e-6
    error('Cascade does not close to -180 deg (residual = %.4e deg).', cascade_powerOn + 180);
else
    fprintf('Cascade closes to -180 deg at power-on.\n\n');
end

%% -- 10. Band verification plot -----------------------------------------------
figure('Name','AAP Phase Requirement vs Frequency');
plot(f_band, phi_AAP_band, 'b-', 'LineWidth', 1.5); hold on;
yline(phi_gross(1),   'r--', 'LineWidth', 1.2, 'Label', 'Table lower bound');
yline(phi_gross(end), 'r--', 'LineWidth', 1.2, 'Label', 'Table upper bound');
yline(phi_AAP_nom,    'g--', 'LineWidth', 1.2, 'Label', 'Nominal 50 Hz (entry 40)');
xlabel('Frequency (Hz)');
ylabel('\phi_{AAP} required (degrees)');
title('AAP Required Phase Across 45-55 Hz vs Gross Table Span');
grid on;

%% -- 11. Save - explicit variable only ---------------------------------------
Tables.alpha_gross          = alpha_gross;
Tables.alpha_gross_unstable = alpha_unstable;     % stability-selection record
Tables.phi_gross            = phi_gross;
Tables.alpha_fine_delta     = alpha_fine_delta;   % per-operating-point, signed
Tables.dphidalpha_gross     = dphidalpha_gross;   % closed-form slope per entry
Tables.dphi_fine_deg        = dphi_fine;          % tunable fine nudge
Tables.k_powerOn            = k_powerOn;
Tables.gross_step_deg       = gross_step;
Tables.phi_AAP_at_45Hz      = phi_AAP_band(1);
Tables.phi_AAP_at_50Hz      = phi_AAP_nom;
Tables.phi_AAP_at_55Hz      = phi_AAP_band(end);
Tables.phi_LPF_band         = phi_LPF_band;
Tables.phi_FAP_band         = phi_FAP_band;
Tables.phi_AAP_band         = phi_AAP_band;
Tables.f_band               = f_band;

outFile = fullfile(scriptDir, 'ALPF_Tables.mat');
save(outFile, 'Tables');

fprintf('ALPF_Tables.mat saved to:\n   %s\n', outFile);
fprintf('Saved variable: Tables struct\n');
fprintf('Move to 03 - ALPF\\04 - Tables\\ after verification.\n');
fprintf('\n=== Tables design COMPLETE ===\n');

%% -- Local functions ---------------------------------------------------------
function phi_deg = eval_LPF_phase(sos, omega_d)
    H = 1;
    z = exp(1j * omega_d);
    for s = 1:size(sos, 1)
        b  = sos(s, 1:3);
        a  = sos(s, 4:6);
        Hs = (b(1) + b(2)*z^(-1) + b(3)*z^(-2)) / ...
             (a(1) + a(2)*z^(-1) + a(3)*z^(-2));
        H  = H * Hs;
    end
    phi_deg = angle(H) * 180/pi;
end

function [alpha_stable, alpha_unstable] = solve_alpha_form2(phi_target_deg, omega_d)
    % Solve Form 2 all-pass phase phi(alpha) = phi_target for alpha.
    %   tan(phi) = (1-a^2) sin(od) / (2a - (1+a^2) cos(od))  rearranges to
    %   A a^2 + B a + C = 0,  A = sin(od-phi), B = 2 sin(phi), C = -sin(od+phi)
    % The sin form avoids the tan singularity at phi = 90 deg.
    phi = phi_target_deg * pi/180;
    A = sin(omega_d - phi);
    B = 2*sin(phi);
    C = -sin(omega_d + phi);
    disc = B^2 - 4*A*C;
    if disc < 0
        error('solve_alpha_form2: negative discriminant at phi=%.4f deg.', phi_target_deg);
    end
    if abs(A) < 1e-12
        error('solve_alpha_form2: degenerate quadratic (A~0) at phi=%.4f deg.', phi_target_deg);
    end
    r1 = (-B + sqrt(disc)) / (2*A);
    r2 = (-B - sqrt(disc)) / (2*A);
    in1 = abs(r1) < 1;
    in2 = abs(r2) < 1;
    if in1 && ~in2
        alpha_stable = r1;  alpha_unstable = r2;
    elseif in2 && ~in1
        alpha_stable = r2;  alpha_unstable = r1;
    else
        error(['solve_alpha_form2: expected exactly one |alpha|<1 root at ' ...
               'phi=%.4f deg (r1=%.6f, r2=%.6f).'], phi_target_deg, r1, r2);
    end
end