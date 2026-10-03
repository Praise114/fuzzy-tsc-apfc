function APFC_PlotResultCharts()
%APFC_PLOTRESULTCHARTS  The two grouped bar charts for Chapter 4.
%
%   Produces:
%     Fig_4_9_PF_Correction.png    Figure 4.9,  Section 4.5.2
%         Uncompensated against compensated displacement power factor
%         at the three load points, on a clean supply.
%
%     Fig_4_17_DPF_vs_TruePF.png   Figure 4.17, Section 4.5.6
%         Displacement against true power factor at half load across the
%         five harmonic conditions.
%
%   Both are drawn in the same house style as APFC_MakeFigures_v2: white
%   canvas immune to the MATLAB dark theme, Times New Roman, type sized
%   for a 14 cm placement in the report.
%
%   USAGE
%       APFC_PlotResultCharts
%
%   Output is written to the current folder.
%
%   DATA PROVENANCE
%   Every value below is transcribed from the v22 campaign result tables
%   (Tables 4.6, 4.7, 4.8). Nothing is computed or estimated here. If a
%   result table is corrected, correct the arrays in this file to match.
%
%   Project : Fuzzy Logic-Controlled Automatic Power Factor Correction Using
%             Thyristor-Switched Capacitor Banks for a 30 kW Induction Motor
%   Author  : Praise Oluwasina Akinlolu, Department of Electrical and
%             Electronics Engineering, University of Lagos
%   MATLAB  : R2025b
%   Licence : MIT (see LICENSE in the repository root)

% =====================================================================
% CONFIGURATION
% =====================================================================
cfg.fontName    = 'Times New Roman';
cfg.fontSize    = 14;      % tick labels
cfg.labelSize   = 16;      % axis labels
cfg.legendSize  = 13;
cfg.valueSize   = 12;      % numbers printed above the bars
cfg.figWidthCm  = 15;      % place at this width in Word, do not enlarge
cfg.figHeightCm = 9.0;
% Value labels are rotated to vertical once a chart carries this many
% category groups or more. Below the threshold the bars are wide enough
% for horizontal labels; at or above it they are not, and horizontal
% labels from adjacent bars collide.
cfg.rotateFrom  = 4;
cfg.headHoriz   = 1.15;    % y-axis top when labels are horizontal
cfg.headRot     = 1.38;    % y-axis top when labels are rotated
cfg.dpi         = 300;
cfg.savePDF     = true;

% Greyscale-safe fills: clearly different in tone as well as in hue
cfg.colA = [0.72 0.72 0.72];    % first series, light
cfg.colB = [0.16 0.32 0.31];    % second series, dark
cfg.floorPF = 0.95;

outDir = pwd;
fprintf('\n==============================================================\n');
fprintf(' CHAPTER 4 RESULT CHARTS\n');
fprintf('==============================================================\n');
fprintf('\nOutput folder : %s\n\n', outDir);

% =====================================================================
% FIGURE 4.9  Power factor correction at the three load points
% =====================================================================
labels49 = {'100 % load','75 % load','50 % load'};
uncomp   = [0.7899 0.7167 0.5852];      % Tables 4.6, 4.7, 4.8
comp     = [0.9639 0.9539 0.9956];      % condition C1, clean supply

local_barChart( ...
    [uncomp(:) comp(:)], labels49, ...
    {'Uncompensated','Compensated'}, ...
    'Displacement power factor', ...
    'Fig_4_9_PF_Correction', ...
    true, ...                            % draw the 0.95 floor line
    outDir, cfg);
fprintf('Figure 4.9  written : Fig_4_9_PF_Correction.png\n');

% =====================================================================
% FIGURE 4.17  Displacement against true power factor at half load
% =====================================================================
labels417 = {'C1','C2','C3','C4','C5'};
dpf       = [0.9956 0.9956 0.9956 0.9956 0.9956];   % Table 4.8
truepf    = [0.9956 0.9857 0.7699 0.8291 0.7650];   % Table 4.8

local_barChart( ...
    [dpf(:) truepf(:)], labels417, ...
    {'Displacement power factor','True power factor'}, ...
    'Power factor', ...
    'Fig_4_17_DPF_vs_TruePF', ...
    false, ...                           % no floor line on this one
    outDir, cfg);
fprintf('Figure 4.17 written : Fig_4_17_DPF_vs_TruePF.png\n');

fprintf('\n==============================================================\n');
fprintf(' COMPLETE. Place each figure at %g cm width in Word.\n', cfg.figWidthCm);
fprintf(' Do NOT enlarge it: the type is sized for that width.\n');
fprintf('==============================================================\n\n');
end % ===================== main ends =====================


% =====================================================================
% Grouped bar chart with value labels, in the project house style
% =====================================================================
function local_barChart(data, catLabels, seriesNames, yLabel, stem, ...
                        showFloor, outDir, cfg)

f = figure('Units','centimeters', ...
           'Position',[2 2 cfg.figWidthCm cfg.figHeightCm], ...
           'Color','w','Visible','off','InvertHardcopy','off');
try, theme(f,'light'); catch, end        % pin the light theme, R2023b+

b = bar(data, 'grouped', 'BarWidth', 0.82);
b(1).FaceColor = cfg.colA;  b(1).EdgeColor = [0.35 0.35 0.35];
b(2).FaceColor = cfg.colB;  b(2).EdgeColor = 'none';
b(1).LineWidth = 0.8;

hold on

% ---- optional 0.95 reference line, drawn under the value labels ----
if showFloor
    % Short label, set ABOVE the line at the left margin. The previous
    % "0.95 floor" text sat below the line and ran into the first value
    % label. The line is identified in the figure caption.
    yl = yline(cfg.floorPF, '--', sprintf('%.2f', cfg.floorPF), ...
               'LineWidth', 1.3, 'Color', [0.35 0.35 0.35]);
    yl.LabelHorizontalAlignment = 'left';
    yl.LabelVerticalAlignment   = 'top';
    yl.FontName = cfg.fontName;
    yl.FontSize = cfg.valueSize;
end

% ---- print each value above its bar ----
% With four or more groups the bars are narrower than a four-decimal
% label, so horizontal text from neighbouring bars overlaps. Rotating to
% vertical removes the collision without dropping any value.
nGroups = size(data, 1);
rotateLabels = nGroups >= cfg.rotateFrom;

for k = 1:numel(b)
    xt = b(k).XEndPoints;
    yt = b(k).YEndPoints;
    if rotateLabels
        text(xt, yt + 0.030, compose('%.4f', yt), ...
             'Rotation', 90, ...
             'HorizontalAlignment','left', 'VerticalAlignment','middle', ...
             'FontName', cfg.fontName, 'FontSize', cfg.valueSize, 'Color','k');
    else
        text(xt, yt + 0.022, compose('%.4f', yt), ...
             'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
             'FontName', cfg.fontName, 'FontSize', cfg.valueSize, 'Color','k');
    end
end
hold off

set(gca, 'XTickLabel', catLabels);
ylabel(yLabel);
if rotateLabels
    ylim([0 cfg.headRot]);
else
    ylim([0 cfg.headHoriz]);
end
yticks(0:0.2:1);
grid on; box on

lgd = legend(seriesNames, 'Location','southoutside', ...
             'Orientation','horizontal');
lgd.Box = 'off';

% ---- force light colours and the size hierarchy ----
set(findall(f,'-property','FontName'), 'FontName', cfg.fontName);
set(findall(f,'-property','FontSize'), 'FontSize', cfg.fontSize);
set(f, 'Color','w', 'InvertHardcopy','off');

ax = gca;
set(ax, 'Color','w', 'XColor','k', 'YColor','k', ...
        'GridColor',[0.75 0.75 0.75], 'GridAlpha',1, ...
        'LineWidth',0.9, 'Layer','top');
ax.XLabel.FontSize = cfg.labelSize;
ax.YLabel.FontSize = cfg.labelSize;  ax.YLabel.Color = 'k';
set(lgd, 'FontSize', cfg.legendSize, 'TextColor','k');

% value labels and the floor label keep their own smaller size
tx = findall(ax, 'Type','text');
set(tx, 'FontSize', cfg.valueSize, 'Color','k');

drawnow

% ---- export ----
exportgraphics(f, fullfile(outDir, [stem '.png']), ...
               'Resolution', cfg.dpi, 'BackgroundColor','white');
if cfg.savePDF
    try
        exportgraphics(f, fullfile(outDir, [stem '.pdf']), ...
                       'ContentType','vector', 'BackgroundColor','white');
    catch ME
        warning('    vector export failed for %s: %s', stem, ME.message);
    end
end
close(f);
end
