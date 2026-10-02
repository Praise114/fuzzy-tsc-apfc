%% build_v22_NoALPF.m
%  Ablation build 1 of 2: remove the ALPF measurement path and KEEP the
%  dq low-pass filters on the P and Q outputs (report Section 3.6.6).
%
%  Effect: the raw phase-to-neutral three-phase voltage bus feeds the
%  Measurement block (and its internal SRF-PLL) directly, with the ALPF's
%  sign/magnitude normalising gain removed. At the fundamental this is the
%  same voltage the ALPF delivers; the difference is that voltage harmonics
%  now reach the PLL and dq computation instead of being pre-filtered.
%
%  RECORD OF DERIVATION. This script documents exactly which blocks were
%  removed to create APFC_FullModel_v22_NoALPF. Its source model,
%  APFC_FullModel_v21_PQoutputLPF, is not included in this repository.
%  APFC_FullModel_v21b_Qmeas (included) is that model with one
%  logging-only To Workspace tap (Qmeas_sim) added; a logging tap of the
%  same kind was added to v22 and v23 after they were built. The derived
%  models are included, so this script does not need to be run.
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

srcName = 'APFC_FullModel_v21_PQoutputLPF';
dstName = 'APFC_FullModel_v22_NoALPF';

%% ---- save-as FIRST: duplicate the .slx on disk, leaving v21 untouched ----
srcFile = which([srcName '.slx']);
assert(~isempty(srcFile), ...
    ['Cannot find ' srcName '.slx on the MATLAB path. cd into its folder ' ...
     '(or addpath the folder) and re-run.']);
dstFile = fullfile(fileparts(srcFile), [dstName '.slx']);
if isfile(dstFile)
    error('%s already exists. Delete or rename it before re-running.', dstFile);
end
copyfile(srcFile, dstFile);
fprintf('Created %s\n', dstFile);

%% ---- edit the copy ----
load_system(dstName);

% the three per-phase ALPF instances
delete_block([dstName '/ALPF']);
delete_block([dstName '/ALPF1']);
delete_block([dstName '/ALPF2']);

% the Demux/Mux that only fanned voltage into and out of the ALPFs
delete_block([dstName '/Demux']);
delete_block([dstName '/Mux']);

% the sign + magnitude normalising gain ( -1/ALPF_LPF_mag50_lin )
delete_block([dstName '/Gain']);

% raw phase-to-neutral voltage bus -> Measurement Vabc input (port 1)
add_line(dstName, 'Rate Transition/1', 'Measurement/1', 'autorouting','on');

save_system(dstName);
fprintf('Saved %s : ALPF path removed, dq-LPF retained.\n', dstName);
