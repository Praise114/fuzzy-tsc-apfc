%% ========================================================================
%  build_APFC_FLC.m
%  FUZZY LOGIC CONTROLLER - FIS construction and self-check
%  ------------------------------------------------------------------------
%  Single-input Mamdani FLC for discrete, binary-weighted TSC bank switching
%  (report Sections 3.5.6 to 3.5.8).
%
%    INPUT   eQ  = reactive-power error  (Q_net - Q_target)    [kVAR]
%            universe of discourse: [-40, +40]
%    OUTPUT  dQc = compensation increment (change in command)  [kVAR]
%            universe of discourse: [-20, +20]
%
%    Inference : Mamdani  (AND=min, OR=max, implication=min, aggregation=max)
%    Defuzzify : centroid (centre of area)        <-- mamfis default
%
%  Output: APFC_FLC.fis, written to the CURRENT folder. Run this script
%  with '04 - FLC' as the current folder so that the file lands where
%  APFC_Parameters.m reads it.
%
%  Requires: Fuzzy Logic Toolbox.
%  Accuracy: all membership-function breakpoints are exact (no rounding).
%
% Project : Fuzzy Logic-Controlled Automatic Power Factor Correction Using
%           Thyristor-Switched Capacitor Banks for a 30 kW Induction Motor
% Author  : Praise Oluwasina Akinlolu, Department of Electrical and
%           Electronics Engineering, University of Lagos
% MATLAB  : R2025b
% Licence : MIT (see LICENSE in the repository root)
%% ========================================================================

clear; clc;

%% ---- 0.  Confirm the Fuzzy Logic Toolbox is installed -------------------
assert(~isempty(which('mamfis')), ...
    'Fuzzy Logic Toolbox not found. Install it via Home > Add-Ons > Get Add-Ons.');

%% ---- 1.  Create an empty Mamdani FIS ------------------------------------
%  A new mamfis already uses centroid defuzzification and min/max inference,
%  which is exactly what this design requires, so no method changes are made.
fis = mamfis(Name="APFC_FLC");

%% ---- 2.  INPUT variable  eQ  and its five membership functions ----------
fis = addInput(fis,[-40 40],Name="eQ");

fis = addMF(fis,"eQ","trapmf",[-40 -40 -20 -10],Name="NB");  % Negative Big
fis = addMF(fis,"eQ","trimf", [-20 -10   0    ],Name="NS");  % Negative Small
fis = addMF(fis,"eQ","trimf", [-10   0  10    ],Name="ZE");  % Zero (hold band)
fis = addMF(fis,"eQ","trimf", [  0  10  20    ],Name="PS");  % Positive Small
fis = addMF(fis,"eQ","trapmf",[ 10  20  40  40],Name="PB");  % Positive Big

%% ---- 3.  OUTPUT variable  dQc  and its five membership functions --------
fis = addOutput(fis,[-20 20],Name="dQc");

fis = addMF(fis,"dQc","trapmf",[-20 -20 -10  -5],Name="NB");
fis = addMF(fis,"dQc","trimf", [-10  -5   0    ],Name="NS");
fis = addMF(fis,"dQc","trimf", [ -5   0   5    ],Name="ZE");
fis = addMF(fis,"dQc","trimf", [  0   5  10    ],Name="PS");
fis = addMF(fis,"dQc","trapmf",[  5  10  20  20],Name="PB");

%% ---- 4.  The five diagonal rules ----------------------------------------
%  Columns: [ inputMF  outputMF  weight  connection(1 = AND) ]
%  MF index order matches the order added above:  1=NB 2=NS 3=ZE 4=PS 5=PB
ruleList = [ ...
    1 1 1 1; ...   % If eQ is NB then dQc is NB
    2 2 1 1; ...   % If eQ is NS then dQc is NS
    3 3 1 1; ...   % If eQ is ZE then dQc is ZE
    4 4 1 1; ...   % If eQ is PS then dQc is PS
    5 5 1 1];      % If eQ is PB then dQc is PB
fis = addRule(fis,ruleList);

%% ---- 5.  Save the FIS to file -------------------------------------------
writeFIS(fis,"APFC_FLC");      % creates APFC_FLC.fis in the current folder
fprintf('\nAPFC_FLC.fis written to: %s\n\n', pwd);

%% ---- 6.  Numerical self-check (expected values in the comment) ----------
%    eQ (kVAR)  | expected dQc (kVAR)
%    ---------- | -------------------
%      -30      |   ~ -13.67
%      -10      |     -5.00
%        0      |      0.00
%       10      |      5.00
%       30      |   ~ +13.67
testInputs  = [-30 -10 0 10 30].';
testOutputs = evalfis(fis,testInputs);
disp(table(testInputs,testOutputs, ...
     VariableNames=["eQ_kVAR","dQc_kVAR"]));

%% ---- 7.  Visual verification --------------------------------------------
figure; plotmf(fis,"input",1);  title("Input MFs:  eQ  (kVAR)");
figure; plotmf(fis,"output",1); title("Output MFs:  dQc  (kVAR)");
figure; gensurf(fis);           title("Control surface:  eQ \rightarrow dQc");

%% ---- 8.  (Optional) open in the Fuzzy Logic Designer app to inspect -----
% fuzzyLogicDesigner(fis);
