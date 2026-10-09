%% FULL RUN 003: 2023 EV6 WIND AWD 77.4-kWh MODEL

clearvars -except SupvsryCtrlBus
clc

projectRoot = ['C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
    'OneDrive_1_8-28-2026\Vehicles_24a\Vehicles\' ...
    'VehicleProjects\Bolt_EV'];

batteryModel = 'EV6_LUT_FourWheel_EV6Battery77p4kWh';

%% 1. Initialize the EV6 model

run(fullfile(projectRoot,'init_EV6_model.m'));

EV6_TractionTorqueGain = 1.223989;
EV6_RegenTorqueGain = 1.348705;

%% 2. Load Run 003 dyno data

run003File = ['C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
    'OneDrive_1_8-28-2026\EV6_drivecycleData\' ...
    'standards_test_08142026_003.mat'];

assert(isfile(run003File), ...
    'Run 003 MAT-file was not found:\n%s',run003File);

loaded003 = load(run003File);

assert(isfield(loaded003,'standards_test_08142026_003'), ...
    'The expected Run 003 structure was not found.');

D003 = loaded003.standards_test_08142026_003;

%% 3. Extract the Run 003 speed demand

channelNames003 = erase( ...
    string({D003.Y.Name}),["<",">"]);

speedIndex003 = find( ...
    channelNames003 == "VEH_vEgo",1,'first');

assert(~isempty(speedIndex003), ...
    'VEH_vEgo was not found in Run 003.');

speedTimeIndex003 = D003.Y(speedIndex003).XIndex;

run003Time_s = double( ...
    D003.X(speedTimeIndex003).Data(:));

run003Speed_mps = double( ...
    D003.Y(speedIndex003).Data(:));

validSpeed003 = ...
    isfinite(run003Time_s) & ...
    isfinite(run003Speed_mps);

run003Time_s = run003Time_s(validSpeed003);
run003Speed_mps = run003Speed_mps(validSpeed003);

% Prevent very small negative standstill values
run003Speed_mps = max(run003Speed_mps,0);

run003StopTime_s = run003Time_s(end);

assert(run003StopTime_s > 600 && run003StopTime_s < 650, ...
    'Run 003 duration is outside the expected range.');

%% 4. Create model input timeseries

ts_Run003_VehSpd_mps = timeseries( ...
    run003Speed_mps,run003Time_s);

% Compatibility variables used by different model locations
ts_VehSpdDmd = ts_Run003_VehSpd_mps;
ts_VehSpd = ts_Run003_VehSpd_mps;
ts_US06VehSpdDmd = ts_Run003_VehSpd_mps;

% External commands remain zero because the longitudinal driver
% tracks the dyno speed demand
ts_AccelPedal = timeseries( ...
    [0;0],[0;run003StopTime_s]);

ts_BrakePedal = timeseries( ...
    [0;0],[0;run003StopTime_s]);

ts_Steer = timeseries( ...
    [0;0],[0;run003StopTime_s]);

ts_Steering = ts_Steer;

fprintf('\n===== RUN 003 FULL INPUT READY =====\n');
fprintf('Samples = %d\n',numel(run003Time_s));
fprintf('Duration = %.3f seconds\n',run003StopTime_s);
fprintf('Speed range = %.3f to %.3f m/s\n', ...
    min(run003Speed_mps),max(run003Speed_mps));
fprintf('====================================\n');

%% 5. Load, configure and update the 77.4-kWh model

load_system(batteryModel);
open_system(batteryModel);

speedBlock = [batteryModel '/From Workspace3'];

assert(getSimulinkBlockHandle(speedBlock) > 0, ...
    'The top-level speed From Workspace block was not found.');

% Point the model directly to Run 003 before updating it
set_param( ...
    speedBlock, ...
    'VariableName', ...
    'ts_Run003_VehSpd_mps');

fprintf('Speed block now uses: %s\n', ...
    get_param(speedBlock,'VariableName'));

try
    set_param(batteryModel,'SimulationCommand','update');
    fprintf('Model update = SUCCESS\n');

catch updateError
    fprintf('\nModel update = FAILED\n');
    fprintf('%s\n',getReport( ...
        updateError,'extended','hyperlinks','off'));

    error('Stop here. Do not start the Run 003 simulation.');
end
%% 6. Prepare the full Run 003 simulation

fullInput003 = Simulink.SimulationInput(batteryModel);

fullInput003 = fullInput003.setBlockParameter( ...
    speedBlock, ...
    'VariableName', ...
    'ts_Run003_VehSpd_mps');

fullInput003 = fullInput003.setModelParameter( ...
    'StopTime',sprintf('%.3f',run003StopTime_s), ...
    'SignalLogging','on');

runIDsBefore003 = Simulink.sdi.getAllRunIDs;

fprintf('\n===== STARTING FULL RUN 003 =====\n');
fprintf('Model = %s\n',batteryModel);
fprintf('Stop time = %.3f seconds\n',run003StopTime_s);
fprintf('Expected runtime is approximately 12-18 minutes.\n');
fprintf('Watch the open model status bar for simulation time.\n');
fprintf('=================================\n');

%% 7. Run the simulation

tic;
out003EV6Battery77p4Full = sim(fullInput003);
runtimeMinutes003 = toc/60;

%% 8. Find and rename the new SDI run

runIDsAfter003 = Simulink.sdi.getAllRunIDs;

newRunIDs003 = setdiff( ...
    runIDsAfter003,runIDsBefore003,'stable');

assert(~isempty(newRunIDs003), ...
    'The simulation completed, but no new SDI run was found.');

fullRun003ID = newRunIDs003(end);
fullRun003SDI = Simulink.sdi.getRun(fullRun003ID);

fullRun003SDI.Name = ...
    'Run003_EV6Battery77p4kWh_Corrected_Full';

%% 9. Verify the main SimulationOutput variables

outputVariables003 = string( ...
    out003EV6Battery77p4Full.who);

requiredOutputs003 = [
    "battery_current"
    "battery_power"
    "battery_soc"
    "tout"
    ];

for k = 1:numel(requiredOutputs003)

    assert(any(outputVariables003 == requiredOutputs003(k)), ...
        'Required output %s was not saved.', ...
        requiredOutputs003(k));
end

%% 10. Print preliminary battery ranges

batteryCurrent003 = ...
    out003EV6Battery77p4Full.get('battery_current');

batteryPower003 = ...
    out003EV6Battery77p4Full.get('battery_power');

batterySoc003 = ...
    out003EV6Battery77p4Full.get('battery_soc');

fprintf('\n===== RUN 003 OUTPUT CHECK =====\n');
fprintf('Battery-current range = %.3f to %.3f A\n', ...
    min(double(batteryCurrent003.Data(:))), ...
    max(double(batteryCurrent003.Data(:))));

fprintf('Battery-power raw range = %.3f to %.3f\n', ...
    min(double(batteryPower003.Data(:))), ...
    max(double(batteryPower003.Data(:))));

fprintf('Battery-SOC range = %.6f to %.6f\n', ...
    min(double(batterySoc003.Data(:))), ...
    max(double(batterySoc003.Data(:))));
fprintf('================================\n');

%% 11. Save the complete SimulationOutput

run003OutputFile = fullfile( ...
    projectRoot, ...
    'EV6_Run003_77p4kWh_Corrected_Full_Output.mat');

save(run003OutputFile, ...
    'out003EV6Battery77p4Full', ...
    '-v7.3');

fprintf('\n===== FULL 2023 EV6 RUN 003 COMPLETE =====\n');
fprintf('Runtime = %.2f minutes\n',runtimeMinutes003);
fprintf('SDI run = %s\n',string(fullRun003SDI.Name));
fprintf('Stop time = %.3f seconds\n',run003StopTime_s);

fprintf('\nSimulation output saved to:\n%s\n', ...
    run003OutputFile);

fprintf('===========================================\n');