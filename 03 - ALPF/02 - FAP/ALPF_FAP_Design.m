%% ALPF_FAP_Design.m
% ALPF - Fixed All-Pass (FAP) coefficient design (report Section 3.5.5)
% FAP topology: first-order IIR all-pass, Proakis & Manolakis Form 1
%   H(z) = (z^-1 - alpha) / (1 - alpha * z^-1), |alpha| < 1
% Target: phi_FAP(50 Hz) = -90 degrees (DESIGN CHOICE)
% Sampling frequency: fs = 12500 Hz (inherited from Rodrigues et al., 2018)
%
% DESIGN JUSTIFICATION:
%   (1) Engineering: quarter-wave shift gives AAP bilateral adaptive headroom.
%   (2) Filter-theoretic: -90 deg is near-centre of degree-one reachable range
%       at 50 Hz / 12500 Hz, maximising distance from stability boundaries.
%
% Input : ..\01 - LPF\ALPF_LPF_Coefficients.mat (run ALPF_LPF_Design.m first)
% Output: ALPF_FAP_Coefficients.mat, saved beside this script.
% This is a standalone design script: it starts with clear, clc and
% close all, so run it in its own session, not after APFC_Parameters.m.
%
% Saved variables: FAP struct only.
%   FAP.alpha                   - solved alpha coefficient
%   FAP.b, FAP.a                - transfer function numerator/denominator
%   FAP.phi_at_50Hz             - achieved phase at 50 Hz (degrees)
%   FAP.fs, FAP.f0              - sampling and target frequencies
%   FAP.phi_target              - design target phase (degrees)
%   FAP.phi_AAP_required_at_50Hz - AAP initial phase required for -180 total
%
% Project : Fuzzy Logic-Controlled Automatic Power Factor Correction Using
%           Thyristor-Switched Capacitor Banks for a 30 kW Induction Motor
% Author  : Praise Oluwasina Akinlolu, Department of Electrical and
%           Electronics Engineering, University of Lagos
% MATLAB  : R2025b
% Licence : MIT (see LICENSE in the repository root)

clear; clc; close all;

%% -- 0. Resolve paths and load LPF phase (relative paths, no addpath) ------
scriptDir = fileparts(mfilename('fullpath'));

LPF_mat = fullfile(scriptDir, '..', '01 - LPF', 'ALPF_LPF_Coefficients.mat');
% '..' navigates from 02 - FAP\ up to 03 - ALPF\, then into 01 - LPF\.
if ~isfile(LPF_mat)
    error('Cannot find ALPF_LPF_Coefficients.mat at:\n  %s\nCheck folder structure.', LPF_mat);
end

tmp        = load(LPF_mat, 'phase_50Hz', 'fs');
phi_LPF_50 = tmp.phase_50Hz;   % phi_LPF(50 Hz) from ALPF_LPF_Design.m
fs         = tmp.fs;            % 12500 Hz

fprintf('Loaded phi_LPF(50 Hz) = %.4f deg from ALPF_LPF_Coefficients.mat\n\n', ...
        phi_LPF_50);

%% -- 1. Parameters ------------------------------------------------------------
f0             = 50;
phi_target_deg = -90;
phi_target_rad = phi_target_deg * pi / 180;
omega_d        = 2 * pi * f0 / fs;

%% -- 2. FAP phase function ----------------------------------------------------
phi_FAP = @(a) atan2(-sin(omega_d), cos(omega_d) - a) ...
              - atan2(a * sin(omega_d), 1 - a * cos(omega_d));

%% -- 3. PRE-VERIFICATION: Diagnostic plot before solver call ---------------
alpha_vec = linspace(-0.9999, 0.9999, 5000);
phi_vec   = arrayfun(phi_FAP, alpha_vec) * 180/pi;

figure('Name','FAP Phase vs Alpha — Pre-verification');
plot(alpha_vec, phi_vec, 'b-', 'LineWidth', 1.5); hold on;
yline(phi_target_deg, 'r--', 'LineWidth', 1.5, ...
      'Label', sprintf('Target: %g°', phi_target_deg));
xlabel('\alpha'); ylabel('\phi_{FAP} at 50 Hz (degrees)');
title('Degree-1 All-Pass Phase at 50 Hz vs \alpha  (f_s = 12500 Hz)');
grid on;

phi_min = min(phi_vec);
phi_max = max(phi_vec);
fprintf('=== PRE-VERIFICATION ===\n');
fprintf('Reachable phase range at 50 Hz: [%.4f, %.4f] degrees\n', phi_min, phi_max);
fprintf('Target phase: %.4f degrees\n', phi_target_deg);

if phi_target_deg < phi_min || phi_target_deg > phi_max
    error(['TARGET OUT OF RANGE. First-order all-pass cannot achieve ' ...
           '%.4f deg at 50 Hz with fs = %.0f Hz. ' ...
           'Revise FAP target or topology before proceeding.'], ...
          phi_target_deg, fs);
else
    fprintf('Target IS within reachable range. Proceeding to solver.\n\n');
end

%% -- 4. Solve for alpha using fzero ------------------------------------------
obj      = @(a) phi_FAP(a) - phi_target_rad;
obj_vec  = arrayfun(obj, alpha_vec);
sc       = find(diff(sign(obj_vec)));

if isempty(sc)
    error('fzero bracket not found. Check phi_FAP formulation.');
end

a_lo = alpha_vec(sc(1));
a_hi = alpha_vec(sc(1) + 1);
fprintf('Bracket for fzero: [%.6f, %.6f]\n', a_lo, a_hi);

options   = optimset('TolX', 1e-14, 'Display', 'off');
alpha_FAP = fzero(obj, [a_lo, a_hi], options);

%% -- 5. Verification ----------------------------------------------------------
phi_achieved_rad = phi_FAP(alpha_FAP);
phi_achieved_deg = phi_achieved_rad * 180 / pi;
error_deg        = phi_achieved_deg - phi_target_deg;

fprintf('=== SOLUTION ===\n');
fprintf('alpha_FAP         = %.10f\n', alpha_FAP);
fprintf('Phase achieved    = %.6f degrees\n', phi_achieved_deg);
fprintf('Phase target      = %.6f degrees\n', phi_target_deg);
fprintf('Residual error    = %.2e degrees\n', error_deg);

if abs(error_deg) > 1e-6
    warning('Residual error exceeds 1e-6 degrees. Inspect solution.');
else
    fprintf('Verification PASSED. Residual within tolerance.\n\n');
end

%% -- 6. Cascade phase budget verification -------------------------------------
% phi_LPF_50 loaded from ALPF_LPF_Coefficients.mat in Section 0 above.
% No hardcoded values - fully traceable to ALPF_LPF_Design.m output.

phi_AAP_required = -180 - phi_LPF_50 - phi_achieved_deg;

fprintf('=== CASCADE PHASE BUDGET ===\n');
fprintf('phi_LPF(50)      = %.4f deg  [loaded from LPF design]\n', phi_LPF_50);
fprintf('phi_FAP(50)      = %.4f deg  [this design]\n', phi_achieved_deg);
fprintf('phi_AAP_required = %.4f deg  [for -180 deg total]\n', phi_AAP_required);
fprintf('Cascade total    = %.4f deg\n', ...
        phi_LPF_50 + phi_achieved_deg + phi_AAP_required);

expected_AAP_init = 47.7280;
AAP_discrepancy   = phi_AAP_required - expected_AAP_init;
fprintf('\nExpected AAP initial phase (design target): +%.4f deg\n', expected_AAP_init);
fprintf('Computed AAP initial phase:        %.4f deg\n', phi_AAP_required);
fprintf('Discrepancy:                       %.4e deg\n', AAP_discrepancy);

if abs(AAP_discrepancy) > 0.001
    warning('AAP initial phase discrepancy > 0.001 deg. Investigate.');
else
    fprintf('AAP budget consistent with the design target.\n\n');
end

%% -- 7. Transfer function coefficients ---------------------------------------
b_FAP = [-alpha_FAP, 1];
a_FAP = [1, -alpha_FAP];

fprintf('=== TRANSFER FUNCTION COEFFICIENTS ===\n');
fprintf('Numerator   b = [%.10f, %.10f]\n', b_FAP(1), b_FAP(2));
fprintf('Denominator a = [%.10f, %.10f]\n', a_FAP(1), a_FAP(2));

%% -- 8. Frequency response plot (full band) -----------------------------------
[H, f] = freqz(b_FAP, a_FAP, 4096, fs);
phi_full = angle(H) * 180/pi;
mag_full = abs(H);

figure('Name','FAP Frequency Response');
subplot(2,1,1);
plot(f, mag_full, 'b-', 'LineWidth', 1.5);
xlabel('Frequency (Hz)'); ylabel('|H(f)|');
title('FAP Magnitude Response (should be unity)');
ylim([0.99, 1.01]); grid on;

subplot(2,1,2);
plot(f, phi_full, 'b-', 'LineWidth', 1.5); hold on;
xline(f0, 'r--', 'LineWidth', 1.2, 'Label', '50 Hz');
yline(phi_target_deg, 'g--', 'LineWidth', 1.2, ...
      'Label', sprintf('Target: %g°', phi_target_deg));
xlabel('Frequency (Hz)'); ylabel('\phi_{FAP} (degrees)');
title('FAP Phase Response');
grid on;

%% -- 9. Save - explicit variable, path-portable ---------------------------
FAP.alpha                    = alpha_FAP;
FAP.b                        = b_FAP;
FAP.a                        = a_FAP;
FAP.phi_at_50Hz              = phi_achieved_deg;
FAP.fs                       = fs;
FAP.f0                       = f0;
FAP.phi_target               = phi_target_deg;
FAP.phi_AAP_required_at_50Hz = phi_AAP_required;

outFile = fullfile(scriptDir, 'ALPF_FAP_Coefficients.mat');
save(outFile, 'FAP');   % explicit variable - clean save, no workspace pollution

fprintf('FAP coefficients saved to:\n   %s\n', outFile);
fprintf('Saved variable: FAP struct\n');
fprintf('\n=== FAP design COMPLETE ===\n');