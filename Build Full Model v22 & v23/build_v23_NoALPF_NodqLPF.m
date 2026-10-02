%% build_v23_NoALPF_NodqLPF.m
%  Ablation build 2 of 2: starting from v22, ALSO remove the two 5 Hz
%  low-pass filters on the P and Q outputs inside the Measurement
%  subsystem. Result: no ALPF and no output-domain filter, i.e. no
%  measurement conditioning at all (report Section 3.6.6).
%
%  RECORD OF DERIVATION. This script documents exactly which blocks were
%  removed to create APFC_FullModel_v23_NoALPF_NodqLPF from
%  APFC_FullModel_v22_NoALPF. Both models are included in this
%  repository, so the script does not need to be run.
%
%  The source model is never modified: a disk copy is made first. The
%  script only edits structure, so APFC_Parameters.m need not have run.
%
% Project : Fuzzy Logic-Controlled Automatic Power Factor Correction Using
%           Thyristor-Switched Capacitor Banks for a 30 kW Induction Motor
% Author  : Praise Oluwasina Akinlolu, Department of Electrical and
%           Electronics Engineering, University of Lagos
% MATLAB  : R2025b
% Licence : MIT (see LICENSE in the repository root)

srcName = 'APFC_FullModel_v22_NoALPF';            % must match the v22 you built
dstName = 'APFC_FullModel_v23_NoALPF_NodqLPF';

%% ---- save-as FIRST ----
srcFile = which([srcName '.slx']);
assert(~isempty(srcFile), ...
    ['Cannot find ' srcName '.slx on the MATLAB path. Build v22 first, ' ...
     'or cd/addpath its folder.']);
dstFile = fullfile(fileparts(srcFile), [dstName '.slx']);
if isfile(dstFile)
    error('%s already exists. Delete or rename it before re-running.', dstFile);
end
copyfile(srcFile, dstFile);
fprintf('Created %s\n', dstFile);

%% ---- edit the copy ----
load_system(dstName);
meas = [dstName '/Measurement'];

% the two dq low-pass filters on the P and Q outputs
delete_block([meas '/Discrete Transfer Fcn']);     % P-output 5 Hz LPF
delete_block([meas '/Discrete Transfer Fcn1']);    % Q-output 5 Hz LPF

% wire the power / reactive-power function blocks straight to the outports
add_line(meas, 'P-Fcn/1', 'P/1', 'autorouting','on');
add_line(meas, 'Q-Fcn/1', 'Q/1', 'autorouting','on');

save_system(dstName);
fprintf('Saved %s : ALPF and dq-LPF both removed.\n', dstName);
