# Fuzzy Logic-Controlled Automatic Power Factor Correction Using Thyristor-Switched Capacitor Banks for a 30 kW Induction Motor

MATLAB/Simulink models, scripts and simulation results for the final year project of the same title (B.Sc. Electrical and Electronics Engineering, University of Lagos, 2026; supervisor: Dr N. O. Shokoya).

The system compensates the reactive power of a 30 kW, 415 V, 50 Hz squirrel cage induction motor (WEG W22 IE3) with three binary-weighted, 6 % detuned, delta-connected thyristor-switched capacitor banks (5, 10 and 20 kVAr). A synchronous reference frame phase-locked loop and dq0 transformation measure the reactive power, and a Mamdani fuzzy logic controller selects the banks. The models were run across a 15-cell harmonic test matrix (five supply conditions at 100, 75 and 50 % load) in three measurement-conditioning configurations.

| Configuration | Model | Measurement conditioning |
|---|---|---|
| A | `APFC_FullModel_v21b_Qmeas.slx` | Adaptive low-pass filter (ALPF) on the voltage and 5 Hz low-pass filter on the P and Q outputs |
| B (**delivered system**) | `APFC_FullModel_v22_NoALPF.slx` | 5 Hz low-pass filter on the P and Q outputs only |
| C | `APFC_FullModel_v23_NoALPF_NodqLPF.slx` | None |

Configuration B is the delivered system. Configurations A and C form the ablation study reported in Chapter 4 of the report; A contains the complete adaptive low-pass filter.

## Requirements

- MATLAB and Simulink **R2025b** (the release used; other releases have not been tested)
- Simscape and Simscape Electrical
- Fuzzy Logic Toolbox
- Signal Processing Toolbox (`thd`, `freqz`)
- Stateflow and DSP System Toolbox (configuration A only, for the ALPF)

## Quick start

1. Download or clone the repository. Keep the folder layout unchanged: the scripts locate their files relative to their own folders.
2. In MATLAB, set the repository root as the Current Folder and run `APFC_Parameters.m`. It estimates the motor parameters, computes the capacitor bank values, loads the ALPF tables and the fuzzy inference system, and prints a summary.
3. Open a model from `06 - Full Model` and run it (50 s of simulated time).
4. To reproduce the 15-cell results, open `APFC_RunCampaign_Ablation.m`, set `VERSION` to `'v21b'`, `'v22'` or `'v23'`, and follow the instructions in its header. Each cell takes tens of minutes.

## Repository structure

| Path | Contents | Report section |
|---|---|---|
| `APFC_Parameters.m` | Parameter initialisation script; run first | 4.2.4 |
| `02 - Motor/` | Equivalent circuit parameter estimation from nameplate data (Lee et al.) | 3.4.1 to 3.4.6 |
| `03 - ALPF/` | Design scripts and coefficient files of the adaptive low-pass filter (low-pass, fixed all-pass, lookup tables). The `.mat` files are required by every model, because the 12.5 kHz measurement sample rate is read from them | 3.5.5 |
| `04 - FLC/` | Fuzzy inference system (`APFC_FLC.fis`), the script that builds it, and the membership-function plots | 3.5.6 to 3.5.8 |
| `06 - Full Model/` | The three full-system models | 3.6, 4.2 |
| `07 - Results/` | The 45 result files, 15 per configuration | 4.5 |
| `Build Full Model v22 & v23/` | Record of the blocks removed to derive configurations B and C | 3.6.6 |
| `APFC_RunCampaign_Ablation.m` | Campaign driver: runs the 15-cell matrix for one configuration | 4.4.2 |
| `APFC_HarmonicMetrics.m` | Metrics function: integer-cycle Fourier projection, power factor, THD, TDD and steady-state check | 4.4.3, 4.4.4 |
| `APFC_MakeFigures_v2.m`, `APFC_PlotSpectra_v2.m`, `APFC_PlotResultCharts.m` | Figure scripts for Chapter 4 | 4.5 |
| `APFC_CurrentReduction.m`, `APFC_ExtractFifthHarmonic.m` | Post-processing utilities | 4.5, 4.6 |

## Result files

Each file in `07 - Results/<configuration>/` is named `Results_L<load>_<condition>.txt` and reports the settled bank state, displacement and true power factor before and after compensation, voltage and current THD, current TDD (referred to the motor rated current, 56.4 A), the per-order harmonic magnitudes, the measured reactive power error and a steady-state verdict. The supply conditions are:

| Condition | Harmonic orders and amplitudes (% of fundamental) | Supply voltage THD |
|---|---|---|
| C1 none | Clean supply | 0 % |
| C2 2-3 | 2nd 2, 3rd 5 | 5.39 % |
| C3 5-7-11-13 | 5th 5, 7th 4, 11th 3, 13th 2 | 7.35 % |
| C4 all | 2nd 2, 3rd 3, 5th 4, 7th 3, 11th 2, 13th 1.5 | 6.65 % |
| C5 stress | 2nd 2, 3rd 5, 5th 5, 7th 4, 11th 3, 13th 2 | 9.11 % |

The load points are 100, 75 and 50 %, imposed as shaft speeds of 1485, 1488.75 and 1492.5 rpm.

The raw waveform files (`out_<condition>_L<load>.mat`, about 190 MB each) are not included because of their size. The campaign driver regenerates them, and the figure scripts and `APFC_CurrentReduction.m` need them.

## Not included

Literature and manufacturer datasheets are not redistributed. The main sources are:

- K. Lee, S. Frank, P. K. Sen, L. G. Polese, M. Alahmad, and C. Waters, "Estimation of induction motor equivalent circuit parameters from nameplate data," in *2012 North American Power Symposium (NAPS)*, Sep. 2012, pp. 1–6, doi: 10.1109/NAPS.2012.6336384.
- N. M. Rodrigues, F. M. Janeiro, and P. M. Ramos, "Digital filter performance for zero crossing detection in power quality embedded measurement systems," in *2018 IEEE International Instrumentation and Measurement Technology Conference (I2MTC)*, May 2018, pp. 1–6, doi: 10.1109/I2MTC.2018.8409701.
- G. Dossi, "Adaptive low-pass filter for zero-crossing detection," US Patent 12,294,375 B2, May 6, 2025.
- *IEEE Standard for Harmonic Control in Electric Power Systems*, IEEE Std 519-2022, Aug. 2022, doi: 10.1109/IEEESTD.2022.9848440.
- WEG S/A, "Data Sheet: Three Phase Induction Motor - Squirrel Cage," product code 12914033, Mar. 2026.

## Licence

Released under the MIT Licence. See [LICENSE](LICENSE).

## Author

Praise Oluwasina Akinlolu, Department of Electrical and Electronics Engineering, University of Lagos.
