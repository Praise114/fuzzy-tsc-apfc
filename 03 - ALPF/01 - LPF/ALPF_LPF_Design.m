%% ALPF_LPF_Design.m
% ALPF - Low-Pass Filter Stage (report Section 3.5.5)
% 6th-order Chebyshev Type I, fs = 12.5 kHz
% Coefficients from N. M. Rodrigues, F. M. Janeiro and P. M. Ramos,
% "Digital filter performance for zero crossing detection in power
% quality embedded measurement systems", IEEE I2MTC 2018, Table I.
% Implemented as 3 cascaded biquadratic sections.
%
% Design specification (inherited from Rodrigues et al.):
%   Sampling rate  fs     = 12,500 Hz
%   Passband edge  fpass  =   100 Hz
%   Passband ripple Apass =     1 dB
%   Stopband edge  fstop  =   350 Hz
%   Stopband atten. Astop =    80 dB
%
% Purpose of this script:
%   1. Reconstruct the filter from the published coefficients
%   2. Verify magnitude and phase response match the design spec
%   3. Extract phase response across the 45-55 Hz tracking band
%   4. Confirm phase slope is smooth and monotonic
%   5. Save the SOS matrix and key parameters for the ALPF tables design
%      (ALPF_Tables_Design.m) and for APFC_Parameters.m
%
% Output: ALPF_LPF_Coefficients.mat, saved beside this script. The
% 12.5 kHz sampling rate stored in it (fs) is also the measurement sample
% rate of every full model.
%
% Project : Fuzzy Logic-Controlled Automatic Power Factor Correction Using
%           Thyristor-Switched Capacitor Banks for a 30 kW Induction Motor
% Author  : Praise Oluwasina Akinlolu, Department of Electrical and
%           Electronics Engineering, University of Lagos
% MATLAB  : R2025b
% Licence : MIT (see LICENSE in the repository root)

clear; clc; close all;

%% Section 1 - Define filter coefficients

fs = 12500;                         % Sampling rate [Hz]

% Each row of SOS: [b0 b1 b2 a0 a1 a2]
% where b = Gi * [1, a_i1, a_i2]   (numerator, from Rodrigues Table I 'a' columns)
%   and a =      [1, b_i1, b_i2]   (denominator, from Rodrigues Table I 'b' columns)
%
% Note: Rodrigues et al. use 'a' for numerator and 'b' for denominator.
% MATLAB convention is the opposite (b = numerator, a = denominator).
% The mapping below is correct; only the column labels differ between sources.

sos = [ ...
    6.886e-4 * [1, 2, 1],   [1, -1.9868, 0.9895]; ...
    4.130e-4 * [1, 2, 1],   [1, -1.9700, 0.9717]; ...
    1.427e-4 * [1, 2, 1],   [1, -1.9610, 0.9615]  ...
];

g = 1;   % Overall gain scalar - gain is already distributed per section

fprintf('Number of biquadratic sections: %d\n', size(sos,1));
fprintf('Filter order: %d\n', 2*size(sos,1));

%% Section 2 - Verify magnitude and phase response (0 to 1 kHz)

figure('Name','LPF Magnitude and Phase — 0 to 1 kHz', 'NumberTitle','off');
freqz(sos, 4096, fs);
title('Rodrigues et al. 6th-order Chebyshev Type I LPF — Full Response');

%% Section 3 - Verify key design points against specification

f_check = [50, 100, 150, 250, 350];
[h_check, ~] = freqz(sos, f_check, fs);
mag_dB_check = 20*log10(abs(h_check));

fprintf('\nKey frequency checkpoints (magnitude response):\n');
fprintf('%-20s %-15s\n', 'Frequency', 'Attenuation');
fprintf('%-20s %-15s\n', '---------', '-----------');
fprintf('%-20s %+.3f dB\n', '50 Hz (fundamental)',    mag_dB_check(1));
fprintf('%-20s %+.3f dB\n', '100 Hz (2nd harm.)',     mag_dB_check(2));
fprintf('%-20s %+.3f dB\n', '150 Hz (3rd harm.)',     mag_dB_check(3));
fprintf('%-20s %+.3f dB\n', '250 Hz (5th harm.)',     mag_dB_check(4));
fprintf('%-20s %+.3f dB\n', '350 Hz (7th harm.)',     mag_dB_check(5));

%% Section 4 - Extract phase response across the 45-55 Hz tracking band

f_interest = 45:0.5:55;
[h, f_out] = freqz(sos, f_interest, fs);
phase_deg  = rad2deg(unwrap(angle(h)));
mag_dB     = 20*log10(abs(h));

fprintf('\nLPF Phase and Magnitude across tracking band (45-55 Hz):\n');
fprintf('%-12s %-15s %-15s\n', 'Freq (Hz)', 'Mag (dB)', 'Phase (deg)');
fprintf('%-12s %-15s %-15s\n', '---------', '--------', '-----------');
for k = 1:length(f_interest)
    fprintf('%-12.2f %-15.4f %-15.4f\n', f_out(k), mag_dB(k), phase_deg(k));
end

%% Section 5 - Extract phase at the nominal frequency (50 Hz)

idx_50Hz   = find(f_interest == 50, 1);
phase_50Hz = phase_deg(idx_50Hz);
mag_50Hz   = mag_dB(idx_50Hz);

fprintf('\nLPF response at nominal 50 Hz:\n');
fprintf('   Magnitude: %+.4f dB\n', mag_50Hz);
fprintf('   Phase:     %+.4f degrees\n', phase_50Hz);

%% Section 6 - Verify phase slope is monotonic across tracking band

dphase_per_step = diff(phase_deg);
dphase_per_Hz   = dphase_per_step / 0.5;

if all(dphase_per_step < 0)
    fprintf('\nPhase slope: monotonically decreasing — CONFIRMED.\n');
    fprintf('Mean dPhase/df across 45-55 Hz: %+.4f deg/Hz\n', mean(dphase_per_Hz));
    fprintf('Max  dPhase/df across 45-55 Hz: %+.4f deg/Hz\n', max(dphase_per_Hz));
    fprintf('Min  dPhase/df across 45-55 Hz: %+.4f deg/Hz\n', min(dphase_per_Hz));
elseif all(dphase_per_step > 0)
    fprintf('\nPhase slope: monotonically increasing — UNEXPECTED, investigate.\n');
else
    fprintf('\nWARNING: Phase slope is NOT monotonic. Investigation required.\n');
end

%% Section 7 - Plot phase response across tracking band

figure('Name','LPF Phase — 45 to 55 Hz Tracking Band', 'NumberTitle','off');
plot(f_interest, phase_deg, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 6);
grid on;
xlabel('Frequency (Hz)');
ylabel('Phase (degrees)');
title('LPF Phase Response across Tracking Band (45-55 Hz)');
xline(50, 'r--', 'LineWidth', 1, 'Label', 'Nominal 50 Hz');

%% Section 8 - Save essential outputs only (clean save - explicit variables)
%
% Saved variables and their purpose:
%   sos        - 3x6 SOS coefficient matrix; defines the LPF completely.
%                Required by the tables design and by the Simulink
%                Discrete Filter block configuration.
%   g          - overall gain scalar (= 1); completes the filter definition.
%   fs         - sampling frequency (Hz); shared parameter for all ALPF stages.
%   phase_50Hz - phi_LPF(50 Hz) in degrees; authoritative cascade budget input.
%   mag_50Hz   - LPF magnitude at 50 Hz in dB; retained for verification.
%
% Intermediate variables (phase_deg, f_interest, dphase_per_Hz) are NOT saved.
% They are diagnostic results recomputable from sos by any downstream script.

scriptDir = fileparts(mfilename('fullpath'));
outFile   = fullfile(scriptDir, 'ALPF_LPF_Coefficients.mat');
save(outFile, 'sos', 'g', 'fs', 'phase_50Hz', 'mag_50Hz');

fprintf('\nLPF coefficients saved to:\n   %s\n', outFile);
fprintf('Saved variables: sos, g, fs, phase_50Hz, mag_50Hz\n');
fprintf('\nLPF design complete. Next: ALPF_FAP_Design.m.\n');