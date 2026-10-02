%% ================================================================
%  APFC_WEG_W22_IE3_30kW_Parameter_Estimation_Lee_et_al.m
%  WEG W22 IE3 30 kW Induction Motor - Equivalent Circuit Parameter
%  Estimation from Nameplate Data
%
%  Method  : K. Lee et al., "Estimation of induction motor equivalent
%            circuit parameters from nameplate data", 2012 North
%            American Power Symposium (NAPS). Gauss-Seidel iteration.
%  Grid    : 415 V / 50 Hz
%  Connect.: Star (Y)
%  Report  : Sections 3.4.1 to 3.4.6
%
%  CONVENTION (applied without exception):
%    All quantities fed into circuit equations are PER-PHASE.
%    Three-phase nameplate powers are divided by 3 before use.
%    Three-phase totals are restored by multiplying by 3 for display.
%
%  Equation numbers refer to Lee et al. (2012).
%
%  USE
%    Called by APFC_Parameters.m; it can also be run on its own. It does
%    not call clc or clear, so the calling workspace is preserved.
%    format long is applied for display. The script is deterministic: it
%    recomputes every motor parameter from nameplate data on each run,
%    and no .mat file is required or produced. The workspace variables
%    R1, X1, R2, X2, XM, Rc, s, VRated and J_motor are its outputs.
%
% Project : Fuzzy Logic-Controlled Automatic Power Factor Correction Using
%           Thyristor-Switched Capacitor Banks for a 30 kW Induction Motor
% Author  : Praise Oluwasina Akinlolu, Department of Electrical and
%           Electronics Engineering, University of Lagos
% MATLAB  : R2025b
% Licence : MIT (see LICENSE in the repository root)
%% ================================================================

format long;

%% ================================================================
%  MOTOR-SPECIFIC LOSS FRACTION DERIVATION
%  Source: WEG W22 IE3 Datasheet, Product Code 12914033
%
%  Normative loss points (IEC 60034-2-1), % of POut_rated (30 kW):
%    P1: speed=0.90 pu, torque=1.00 pu → 6.6% → 1980 W
%    P4: speed=0.90 pu, torque=0.50 pu → 3.1% →  930 W
%
%  At same speed, copper+stray losses scale as torque^2:
%    P1 - P4 = 0.75*(PCu_full + PStray_full)
%    1980 - 930 = 1050 W → PCu_full + PStray_full = 1400 W
%
%  PLoss_full = 30000*(1/0.936 - 1) = 2051.28 W
%  PNoLoad (PCore+PMech) = 2051.28 - 1400 = 651.28 W
%
%  PStray = 0.5% of POut = 150 W  (report Section 3.4.3)
%
%  PCore/PMech split: 35%/65% of PNoLoad - DESIGN CHOICE
%  (IE3 motor typical ratio; datasheet does not separate these)
%    PCore = 0.35 * 651.28 = 227.95 W
%    PMech = 0.65 * 651.28 = 423.33 W
%
%  Verification: PCore+PMech+PStray = 801.28 W < PLoss = 2051.28 W ✓
%  Remaining copper loss = 2051.28 - 801.28 = 1250 W ✓ (positive)
%% ================================================================

POut_rated  = 30000;
PLoss_rated = POut_rated * (1/0.936 - 1);
PStray_full = 0.005 * POut_rated;
PNoLoad     = PLoss_rated - 1400;
PCore_full  = 0.35 * PNoLoad;
PMech_full  = 0.65 * PNoLoad;

FCore  = PCore_full  / POut_rated;
FMech  = PMech_full  / PLoss_rated;
FStray = PStray_full / POut_rated;

fprintf('=== MOTOR-SPECIFIC LOSS FRACTIONS ===\n');
fprintf('PNoLoad     = %.10f W\n', PNoLoad);
fprintf('PCore       = %.10f W  [35%% of PNoLoad — design choice]\n', PCore_full);
fprintf('PMech       = %.10f W  [65%% of PNoLoad — design choice]\n', PMech_full);
fprintf('PStray      = %.10f W  [0.5%% of POut — IEC 60034-2-1]\n', PStray_full);
fprintf('FCore       = %.10f\n', FCore);
fprintf('FMech       = %.10f\n', FMech);
fprintf('FStray      = %.10f\n\n', FStray);

%% ================================================================
%  NAMEPLATE INPUTS - DO NOT MODIFY
%% ================================================================
POut  = 30000;
VLL   = 415;
eta   = 0.936;
PF    = 0.79;
N_rpm = 1485;
Poles = 4;
I_LR  = 7.8 * 56.4;   % = 439.92 A exactly
f     = 50;
Ratio = 0.4;           % X1/XLR - NEMA Design B / IEC Design N (report Section 3.4.4)
tol   = 1e-6;

%% ================================================================
%  SECTION IV-A: KNOWN QUANTITIES
%% ================================================================

VRated = VLL / sqrt(3);

Ns = 120 * f / Poles;
s  = (Ns - N_rpm) / Ns;

PIn_3ph  = POut / eta;
PLoss_3ph= PIn_3ph - POut;
SIn_3ph  = POut / (eta * PF);
QIn_3ph  = sqrt(SIn_3ph^2 - PIn_3ph^2);

PIn_ph   = PIn_3ph  / 3;
QIn_ph   = QIn_3ph  / 3;

I1 = (PIn_ph - 1j*QIn_ph) / VRated;

fprintf('=== SECTION IV-A ===\n');
fprintf('VRated      = %.10f V\n', VRated);
fprintf('Ns          = %.10f rpm\n', Ns);
fprintf('s           = %.10f\n', s);
fprintf('PIn  (3ph)  = %.10f W\n', PIn_3ph);
fprintf('QIn  (3ph)  = %.10f VAr\n', QIn_3ph);
fprintf('PIn  (1ph)  = %.10f W\n', PIn_ph);
fprintf('QIn  (1ph)  = %.10f VAr\n', QIn_ph);
fprintf('|I1| (1ph)  = %.10f A\n', abs(I1));
fprintf('angle(I1)   = %.10f deg\n', angle(I1)*180/pi);
fprintf('Datasheet I_rated = 56.4 A  |  Error = %.6f A\n', abs(I1)-56.4);

PMech_ph  = (PLoss_3ph * FMech)  / 3;
PStray_ph = (POut      * FStray) / 3;
PCore_ph  = (POut      * FCore)  / 3;

fprintf('PMech (1ph) = %.10f W\n', PMech_ph);
fprintf('PStray(1ph) = %.10f W\n', PStray_ph);
fprintf('PCore (1ph) = %.10f W\n', PCore_ph);

PConv_ph = (POut/3) + PMech_ph + PStray_ph;
PAG_ph   = PConv_ph / (1 - s);
PSCL_ph  = PIn_ph - PAG_ph - PCore_ph;
PRCL_ph  = PAG_ph - PConv_ph;

fprintf('PConv(1ph)  = %.10f W\n', PConv_ph);
fprintf('PAG  (1ph)  = %.10f W\n', PAG_ph);
fprintf('PSCL (1ph)  = %.10f W\n', PSCL_ph);
fprintf('PRCL (1ph)  = %.10f W\n', PRCL_ph);

if PSCL_ph <= 0
    error('FATAL: PSCL_ph = %.6f W is non-positive. Check loss fractions.', PSCL_ph);
end

R1 = PSCL_ph / abs(I1)^2;
fprintf('R1          = %.10f Ohm\n\n', R1);

if R1 <= 0
    error('FATAL: R1 = %.6f Ohm is non-positive.', R1);
end

%% ================================================================
%  SECTION IV-C: GAUSS-SEIDEL ITERATIONS
%% ================================================================

E      = VRated + 0j;
I2     = real(I1);
X1_est = 0; R2_est = 0; X2_est = 0; Rc_est = 0; XM_est = 0;

fprintf('=== GAUSS-SEIDEL ITERATIONS ===\n');
fprintf('%-5s %-12s %-12s %-12s %-14s %-12s %-12s %-10s\n', ...
        'Iter','X1(Ohm)','R2(Ohm)','X2(Ohm)','XM(Ohm)','Rc(Ohm)','|E|(V)','MaxDelta');

for iter = 1:500

    X1_prev = X1_est; R2_prev = R2_est; X2_prev = X2_est;
    Rc_prev = Rc_est; XM_prev = XM_est;

    disc = abs(E)^4 - 4 * PAG_ph * X2_est^2;
    if disc < 0; disc = 0; end
    R2_over_s = (abs(E)^2 + sqrt(disc)) / (2 * PAG_ph);
    R2_est = R2_over_s * s;

    XLR_sq = (VRated / I_LR)^2 - (R1 + R2_est)^2;
    if XLR_sq < 0; XLR_sq = 0; end
    XLR = sqrt(XLR_sq);

    X1_est = Ratio * XLR;
    X2_est = (1 - Ratio) * XLR;

    denom_XM = QIn_ph - abs(I1)^2 * X1_est - I2^2 * X2_est;
    if denom_XM > 0
        XM_est = abs(E)^2 / denom_XM;
    else
        XM_est = XM_prev;
    end

    Rc_est = abs(E)^2 / PCore_ph;

    maxDelta = max([abs(X1_est-X1_prev), abs(R2_est-R2_prev), ...
                    abs(X2_est-X2_prev), abs(Rc_est-Rc_prev), ...
                    abs(XM_est-XM_prev)]);

    fprintf('%-5d %-12.6f %-12.6f %-12.6f %-14.4f %-12.4f %-12.6f %-10.2e\n', ...
            iter, X1_est, R2_est, X2_est, XM_est, Rc_est, abs(E), maxDelta);

    if maxDelta < tol
        fprintf('\nConverged at iteration %d\n', iter);
        break;
    end

    E  = VRated - I1 * (R1 + 1j*X1_est);
    I2_phasor_temp = E / (R2_est/s + 1j*X2_est);
    I2 = abs(I2_phasor_temp);

    if iter == 500
        fprintf('\nWARNING: Did not converge within 500 iterations.\n');
    end

end

X1 = X1_est; R2 = R2_est; X2 = X2_est; XM = XM_est; Rc = Rc_est;

%% ================================================================
%  FINAL PARAMETERS
%% ================================================================

fprintf('\n================================================================\n');
fprintf('FINAL EQUIVALENT CIRCUIT PARAMETERS\n');
fprintf('Motor : WEG W22 IE3, 30 kW, 415 V / 50 Hz, 4-pole, Star (Y)\n');
fprintf('Method: Lee et al. (2012) with motor-specific loss fractions\n');
fprintf('================================================================\n');
fprintf('R1   Stator resistance        = %.10f  Ohm\n', R1);
fprintf('X1   Stator leakage reactance = %.10f  Ohm\n', X1);
fprintf('R2   Rotor resistance (ref.)  = %.10f  Ohm\n', R2);
fprintf('X2   Rotor leakage reactance  = %.10f  Ohm\n', X2);
fprintf('XM   Magnetising reactance    = %.10f  Ohm\n', XM);
fprintf('Rc   Core loss resistance     = %.10f  Ohm\n', Rc);
fprintf('----------------------------------------------------------------\n');
fprintf('s    Full-load slip           = %.10f\n', s);
fprintf('J    Moment of inertia        = 0.3202000000  kg.m^2  [Datasheet]\n');
fprintf('p    Pole pairs               = 2              [Datasheet]\n');

%% ================================================================
%  VALIDATION
%% ================================================================

fprintf('\n================================================================\n');
fprintf('VALIDATION\n');
fprintf('================================================================\n');

E_v   = VRated - I1 * (R1 + 1j*X1);
I2_v  = E_v / (R2/s + 1j*X2);
Im_v  = E_v / (1j*XM);
Ic_v  = E_v / Rc;
I1_v  = I2_v + Im_v + Ic_v;

PAG_v_ph   = abs(I2_v)^2 * (R2/s);
PConv_v_ph = PAG_v_ph * (1 - s);
PIn_v_ph   = real(VRated * conj(I1_v));
PSCL_v_ph  = abs(I1_v)^2 * R1;
PRCL_v_ph  = abs(I2_v)^2 * R2;
PCore_v_ph = abs(E_v)^2 / Rc;

PAG_v   = 3 * PAG_v_ph;
PConv_v = 3 * PConv_v_ph;
POut_v  = PConv_v - 3*PMech_ph - 3*PStray_ph;
PIn_v   = 3 * PIn_v_ph;
PSCL_v  = 3 * PSCL_v_ph;
PRCL_v  = 3 * PRCL_v_ph;
PCore_v = 3 * PCore_v_ph;
eta_v   = POut_v / PIn_v;
PF_v    = PIn_v_ph / (abs(VRated) * abs(I1_v));

fprintf('%-12s  %20s  %20s\n', 'Quantity', 'Reconstructed', 'Target');
fprintf('%-12s  %20.6f W  %20.6f W\n', 'POut',   POut_v,   POut);
fprintf('%-12s  %20.6f W  %20.6f W\n', 'PIn',    PIn_v,    PIn_3ph);
fprintf('%-12s  %20.6f W  %20.6f W\n', 'PAG',    PAG_v,    PAG_ph*3);
fprintf('%-12s  %20.6f W  %20.6f W\n', 'PConv',  PConv_v,  PConv_ph*3);
fprintf('%-12s  %20.6f W  %20.6f W\n', 'PSCL',   PSCL_v,   PSCL_ph*3);
fprintf('%-12s  %20.6f W  %20.6f W\n', 'PCore',  PCore_v,  PCore_ph*3);
fprintf('%-12s  %20.6f W  %20.6f W\n', 'PRCL',   PRCL_v,   PRCL_ph*3);
fprintf('%-12s  %20.10f   %20.10f\n',  'eta',    eta_v,    eta);
fprintf('%-12s  %20.10f   %20.10f\n',  'PF',     PF_v,     PF);
fprintf('%-12s  %20.10f A %20.10f A\n','|I1_chk|',abs(I1_v), abs(I1));
fprintf('%-12s  %20.6f V\n', '|E_v|', abs(E_v));

eta_lower = eta - 0.15*(1-eta);
PF_lower  = PF  - (1/6)*(1-PF);
fprintf('\n--- IEC 60034-1 Tolerance Band Check ---\n');
fprintf('Efficiency : %.6f  |  Lower limit >= %.6f  |  %s\n', ...
        eta_v, eta_lower, tf2str(eta_v >= eta_lower));
fprintf('PF         : %.6f  |  Lower limit >= %.6f  |  %s\n', ...
        PF_v, PF_lower, tf2str(PF_v >= PF_lower));

%% ================================================================
%  WORKSPACE DEPOSIT CONFIRMATION
%  The following variables are now available in the workspace:
%    R1, X1, R2, X2, XM, Rc  - equivalent circuit parameters (Ohm)
%    s                        - full-load slip (dimensionless)
%    VRated                   - per-phase rated voltage (V)
%    f, Poles, I_LR           - nameplate quantities
%    J_motor                  - moment of inertia (kg.m^2) [datasheet]
%% ================================================================

J_motor = 0.3202;   % kg.m^2 - from WEG W22 IE3 datasheet, Product Code 12914033

fprintf('\n=== Motor parameters deposited into workspace ===\n');
fprintf('R1 = %.10f  X1 = %.10f  R2 = %.10f\n', R1, X1, R2);
fprintf('X2 = %.10f  XM = %.10f  Rc = %.10f\n', X2, XM, Rc);
fprintf('s = %.10f  J = %.10f kg.m^2\n', s, J_motor);
fprintf('=================================================\n');

function out = tf2str(c); if c; out='PASS'; else; out='FAIL'; end; end