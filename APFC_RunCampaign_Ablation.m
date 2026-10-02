%% APFC_RunCampaign_Ablation.m  --  harmonic campaign driver (v21b / v22 / v23)
% =========================================================================
% Runs the 15-cell harmonic test matrix (5 supply conditions x 3 load points)
% on one of the three model configurations of the measurement-conditioning
% ablation (report Sections 3.6.4 to 3.6.6 and 4.4.2):
%   'v21b'  APFC_FullModel_v21b_Qmeas          ALPF and output-domain filter
%   'v22'   APFC_FullModel_v22_NoALPF          output-domain filter only
%                                              (the delivered system)
%   'v23'   APFC_FullModel_v23_NoALPF_NodqLPF  no measurement conditioning
% For each cell the driver sets the supply harmonic ratios (H_ratios) and
% the motor shaft speed (Motor mask parameter n_rpm), simulates the model,
% saves the raw output, and calls APFC_HarmonicMetrics to write the
% Results_L###_<tag>.txt file. Results go to a version-specific subfolder
% of '07 - Results'. The driver locates its own folder, so no path set-up
% is needed, and it is resumable: re-running skips completed cells.
%
% HOW TO RUN
%   1. Run APFC_Parameters.m FIRST (base workspace).
%   2. Set VERSION below to 'v21b', 'v22' or 'v23'.
%   3. Leave validation_only = true for the first run: it runs ONLY the
%      clean-grid cell C1 at 100 % load, as a sanity check. If the result
%      matches the published Results_L100_C1_none.txt, set
%      validation_only = false and re-run to sweep all 15 cells.
%
% NOTES
%   * Re-running overwrites the published Results_*.txt files in the
%     version folder; keep the repository copy for comparison.
%   * Each cell is a 50 s simulation and takes tens of minutes. Each raw
%     output file (out_<tag>_L###.mat, needed by the figure scripts) is
%     about 190 MB; these files are not included in the repository.
%
% Project : Fuzzy Logic-Controlled Automatic Power Factor Correction Using
%           Thyristor-Switched Capacitor Banks for a 30 kW Induction Motor
% Author  : Praise Oluwasina Akinlolu, Department of Electrical and
%           Electronics Engineering, University of Lagos
% MATLAB  : R2025b
% Licence : MIT (see LICENSE in the repository root)
% =========================================================================

%% ---- select the model configuration -------------------------------------
VERSION = 'v21b';   % <-- set to 'v21b', 'v22' or 'v23'
switch VERSION
    case 'v22'
        model  = 'APFC_FullModel_v22_NoALPF';
        subdir = 'v22_NoALPF';
    case 'v23'
        model  = 'APFC_FullModel_v23_NoALPF_NodqLPF';
        subdir = 'v23_NoALPF_NodqLPF';
    case 'v21b'
        model  = 'APFC_FullModel_v21b_Qmeas';
        subdir = 'v21b_ALPF_Qmeas';
    otherwise
        error('Set VERSION to ''v22'' or ''v23''.');
end

%% ---- prerequisite guard --------------------------------------------------
req = {'H_orders','I_L','b_dq','a_dq','V_phase'};
missing = req(~cellfun(@(v) evalin('base',['exist(''' v ''',''var'')']), req));
if ~isempty(missing)
    error(['Base workspace is missing: %s\n' ...
           'Run APFC_Parameters.m before running this driver.'], strjoin(missing,', '));
end

%% ---- locate the project, the model, and the results folder ---------------
here = mfilename('fullpath');
if ~isempty(here)
    modelsDir = fileparts(here);
else
    pp = which('APFC_Parameters.m');
    assert(~isempty(pp), 'Set the Current Folder to Models\\ or run APFC_Parameters.m first.');
    modelsDir = fileparts(pp);
end
addpath(modelsDir);

% version-specific results subfolder
resultsDir = fullfile(modelsDir, '07 - Results', subdir);
if ~isfolder(resultsDir), mkdir(resultsDir); end

if ~bdIsLoaded(model)
    if isempty(which([model '.slx']))
        hit = dir(fullfile(modelsDir, '**', [model '.slx']));
        if isempty(hit)
            error('Could not find %s.slx under %s. Open it once, or check the name.', model, modelsDir);
        end
        addpath(hit(1).folder);
    end
    load_system(model);
end

%% ---- USER TOGGLES --------------------------------------------------------
validation_only = true;   % FIRST PASS: run ONLY C1@100 and stop (sanity gate).
skip_existing   = true;   % resume: skip a cell only if its .txt AND out_*.mat both exist
trim_profiler   = true;   % disable the model Profiler per run (overhead only)
save_out_all    = true;   % save raw 'out' for EVERY cell (figure data)

%% ---- fixed maps -----------------------------------------------------------
rpm_of = containers.Map({100, 75, 50}, {1485, 1488.75, 1492.5});   % load% -> rpm (slip scaled linearly with load)

COND = struct( ...
  'C1', struct('ratios',[0    0    0    0    0    0    ], 'tag','C1_none',       'desc','clean grid (baseline)'), ...
  'C2', struct('ratios',[0.02 0.05 0    0    0    0    ], 'tag','C2_2-3',        'desc','low-order pair (2,3); source THD_V 5.39%'), ...
  'C3', struct('ratios',[0    0    0.05 0.04 0.03 0.02 ], 'tag','C3_5-7-11-13',  'desc','characteristic set, tapered (source THD_V 7.35%)'), ...
  'C4', struct('ratios',[0.02 0.03 0.04 0.03 0.02 0.015], 'tag','C4_all',        'desc','all-orders compliant (source THD_V 6.65%)'), ...
  'C5', struct('ratios',[0.02 0.05 0.05 0.04 0.03 0.02 ], 'tag','C5_stress',     'desc','over-ceiling stress (source THD_V 9.11%)'));

%% ---- CELL LIST (all 15; C1@100 first as the sanity check) -------------------
cells = { ...
    'C1', 100; ...                          % sanity/control cell first
    'C1', 75;  'C1', 50; ...
    'C2', 100; 'C2', 75;  'C2', 50; ...
    'C3', 100; 'C3', 75;  'C3', 50; ...
    'C4', 100; 'C4', 75;  'C4', 50; ...
    'C5', 100; 'C5', 75;  'C5', 50 };

if validation_only
    cells = { 'C1', 100 };
    fprintf(['\n** VALIDATION PASS (%s): running C1@100 only. Compare the new\n' ...
             '   Results_L100_C1_none.txt to your preserved v21 clean-grid file.\n' ...
             '   The shared metrics (S, DPF, THD, true PF) should match closely;\n' ...
             '   the ALPF does nothing on a clean grid. If they match, set\n' ...
             '   validation_only = false and re-run for the full sweep. **\n'], VERSION);
end

%% ---- profiler-disable capability (queried once, safely) ------------------
can_disable_profile = false;
if trim_profiler
    try
        get_param(model, 'Profile');
        can_disable_profile = true;
    catch
        warning('APFC:profile', ...
            'Could not access the ''Profile'' parameter; leaving profiler as-is (results identical).');
    end
end

%% ---- run loop (outputs written into resultsDir; Current Folder restored) --
origDir    = pwd;
cd(resultsDir);
cleanupCD  = onCleanup(@() cd(origDir));      %#ok<NASGU>
nCells     = size(cells,1);
summary    = {};
sumFile    = sprintf('APFC_CampaignSummary_%s.mat', VERSION);
fprintf('\n=== APFC ablation campaign [%s]: %d cell(s) | writing to %s ===\n', ...
        VERSION, nCells, resultsDir);

for k = 1:nCells
    cName = cells{k,1};  loadPct = cells{k,2};
    c = COND.(cName);    n_rpm_k = rpm_of(loadPct);

    txtFile  = sprintf('Results_L%03d_%s.txt', round(loadPct), c.tag);
    matFile  = sprintf('out_%s_L%03d.mat',     c.tag, round(loadPct));
    needsOut = save_out_all;

    done = isfile(txtFile) && (~needsOut || isfile(matFile));
    if skip_existing && done
        fprintf('\n[%d/%d] %-3s @ %3d%%  -- SKIP (already complete)\n', k, nCells, cName, loadPct);
        continue
    end

    fprintf('\n[%d/%d] %-3s @ %3d%%   n_rpm = %-8.4g  ratios = %s\n', ...
            k, nCells, cName, loadPct, n_rpm_k, mat2str(c.ratios));

    in = Simulink.SimulationInput(model);
    in = in.setVariable('H_ratios', c.ratios);
    in = in.setBlockParameter([model '/Motor'], 'n_rpm', num2str(n_rpm_k));
    if can_disable_profile
        in = in.setModelParameter('Profile', 'off');
    end

    trun = tic;
    out  = sim(in);
    fprintf('    solved in %.1f min (wall clock)\n', toc(trun)/60);

    if needsOut
        save(matFile, 'out', '-v7.3');
        fprintf('    raw out saved -> %s\n', matFile);
    end

    info = struct('load_pct',loadPct, 'cond_tag',c.tag, 'cond_desc',c.desc, ...
                  'orders',H_orders, 'ratios',c.ratios, 'I_L',I_L);
    R = APFC_HarmonicMetrics(out, info);

    summary{end+1} = R;            %#ok<SAGROW>
    save(sumFile, 'summary');

    clear out
end

clear cleanupCD
fprintf('\n=== [%s] campaign pass complete. Files in %s ===\n', VERSION, resultsDir);
fprintf('Re-run this script (same VERSION) any time to resume unfinished cells.\n');
fprintf('When v22 is done, set VERSION = ''v23'' at the top and repeat.\n');
