%% DIAGNOSE RUN 004 SPEED INPUT
% Do not use clearvars in this script.

%% 1. Initialize the model first

initFile = ['C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
    'OneDrive_1_8-28-2026\Vehicles_24a\Vehicles\' ...
    'VehicleProjects\Bolt_EV\init_EV6_model.m'];

run(initFile);

projectRoot = ['C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
    'OneDrive_1_8-28-2026\Vehicles_24a\Vehicles\' ...
    'VehicleProjects\Bolt_EV'];

batteryModel = 'EV6_LUT_FourWheel_EV6Battery84kWh';

%% 2. Restore torque calibration gains

gainFile = fullfile(projectRoot,'EV6_TorqueCalibration_Gains.mat');

if isfile(gainFile)
    load(gainFile, ...
        'EV6_TractionTorqueGain', ...
        'EV6_RegenTorqueGain');
else
    EV6_TractionTorqueGain = 1.223989;
    EV6_RegenTorqueGain    = 1.348705;
end

assignin('base','EV6_TractionTorqueGain',EV6_TractionTorqueGain);
assignin('base','EV6_RegenTorqueGain',EV6_RegenTorqueGain);

%% 3. Load Run 004 dyno data

run004File = ['C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
    'OneDrive_1_8-28-2026\EV6_drivecycleData\' ...
    'standards_test_08142026_004.mat'];

loadedRun004 = load(run004File);
D004 = loadedRun004.standards_test_08142026_004;

channelNames004 = erase( ...
    string({D004.Y.Name}),["<",">"]);

speedIndex = find( ...
    channelNames004 == "VEH_vEgo",1,'first');

assert(~isempty(speedIndex), ...
    'VEH_vEgo was not found in Run 004.');

timeIndex = D004.Y(speedIndex).XIndex;

run004Time_s = double( ...
    D004.X(timeIndex).Data(:));

run004Speed_mps = double( ...
    D004.Y(speedIndex).Data(:));

valid = isfinite(run004Time_s) & ...
        isfinite(run004Speed_mps);

run004Time_s = run004Time_s(valid);
run004Speed_mps = max(run004Speed_mps(valid),0);

% Remove duplicate timestamps if present
[run004Time_s,uniqueIndex] = ...
    unique(run004Time_s,'stable');

run004Speed_mps = run004Speed_mps(uniqueIndex);

%% 4. Create a uniquely named Run 004 input

ts_Run004_VehSpd_mps = timeseries( ...
    run004Speed_mps,run004Time_s);

% Maintain compatibility with existing model names
ts_VehSpdDmd = ts_Run004_VehSpd_mps;
ts_VehSpd    = ts_Run004_VehSpd_mps;

assignin('base','ts_Run004_VehSpd_mps', ...
    ts_Run004_VehSpd_mps);

assignin('base','ts_VehSpdDmd', ...
    ts_Run004_VehSpd_mps);

assignin('base','ts_VehSpd', ...
    ts_Run004_VehSpd_mps);

fprintf('\n===== RUN 004 INPUT CREATED =====\n');
fprintf('Samples = %d\n',numel(run004Time_s));
fprintf('Duration = %.3f s\n',run004Time_s(end));
fprintf('Speed range = %.3f to %.3f m/s\n', ...
    min(run004Speed_mps),max(run004Speed_mps));
fprintf('=================================\n');

%% 5. Find every From Workspace block

load_system(batteryModel);

fromWorkspaceBlocks = find_system( ...
    batteryModel, ...
    'LookUnderMasks','all', ...
    'FollowLinks','on', ...
    'MatchFilter',@Simulink.match.allVariants, ...
    'BlockType','FromWorkspace');

fprintf('\n===== FROM WORKSPACE BLOCKS =====\n');

for k = 1:numel(fromWorkspaceBlocks)

    blockPath = fromWorkspaceBlocks{k};

    try
        variableExpression = ...
            get_param(blockPath,'VariableName');
    catch
        variableExpression = ...
            '<VariableName unavailable>';
    end

    isPossibleSpeedSource = ...
        contains(lower(string(variableExpression)),'vehspd') || ...
        contains(lower(string(variableExpression)),'speed')  || ...
        contains(lower(string(variableExpression)),'us06')   || ...
        contains(lower(string(blockPath)),'velref')           || ...
        contains(lower(string(blockPath)),'drive cycle');

    if isPossibleSpeedSource
        marker = '  <=== POSSIBLE SPEED SOURCE';
    else
        marker = '';
    end

    fprintf('\nBlock:\n%s\n',blockPath);
    fprintf('Variable: %s%s\n', ...
        variableExpression,marker);
end

fprintf('\n=================================\n');
fprintf('Do not start the simulation yet.\n');