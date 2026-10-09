%% FULL RUN 002: 2023 EV6 WIND AWD 77.4-kWh MODEL

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

%% 2. Load Run 002 dyno data

run002File = ['C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
    'OneDrive_1_8-28-2026\EV6_drivecycleData\' ...
    'standards_test_08142026_002.mat'];

assert(isfile(run002File), ...
    'Run 002 MAT-file was not found:\n%s',run002File);

loaded002 = load(run002File);

assert(isfield(loaded002,'standards_test_08142026_002'), ...
    'The expected Run 002 structure was not found.');

D002 = loaded002.standards_test_08142026_002;

%% 3. Extract the Run 002 speed demand

channelNames002 = erase( ...
    string({D002.Y.Name}),["<",">"]);

speedIndex002 = find( ...
    channelNames002 == "VEH_vEgo",1,'first');

assert(~isempty(speedIndex002), ...
    'VEH_vEgo was not found in Run 002.');

speedTimeIndex002 = D002.Y(speedIndex002).XIndex;

run002Time_s = double( ...
    D002.X(speedTimeIndex002).Data(:));

run002Speed_mps = double( ...
    D002.Y(speedIndex002).Data(:));

validSpeed002 = ...
    isfinite(run002Time_s) & ...
    isfinite(run002Speed_mps);

run002Time_s = run002Time_s(validSpeed002);
run002Speed_mps = run002Speed_mps(validSpeed002);

% Prevent very small negative standstill values
run002Speed_mps = max(run002Speed_mps,0);

run002StopTime_s = run002Time_s(end);

assert(run002StopTime_s > 1400 && run002StopTime_s < 1450, ...
    'Run 002 duration is outside the expected range.');

%% 4. Create model input timeseries

ts_Run002_VehSpd_mps = timeseries( ...
    run002Speed_mps,run002Time_s);

% Compatibility variables used by different model locations
ts_VehSpdDmd = ts_Run002_VehSpd_mps;
ts_VehSpd = ts_Run002_VehSpd_mps;
ts_US06VehSpdDmd = ts_Run002_VehSpd_mps;

% External commands remain zero because the longitudinal driver
% tracks the dyno speed demand
ts_AccelPedal = timeseries( ...
    [0;0],[0;run002StopTime_s]);

ts_BrakePedal = timeseries( ...
    [0;0],[0;run002StopTime_s]);

ts_Steer = timeseries( ...
    [0;0],[0;run002StopTime_s]);

ts_Steering = ts_Steer;

fprintf('\n===== RUN 002 FULL INPUT READY =====\n');
fprintf('Samples = %d\n',numel(run002Time_s));
fprintf('Duration = %.3f seconds\n',run002StopTime_s);
fprintf('Speed range = %.3f to %.3f m/s\n', ...
    min(run002Speed_mps),max(run002Speed_mps));
fprintf('====================================\n');

%% 5. Load, configure and update the 77.4-kWh model

load_system(batteryModel);
open_system(batteryModel);

speedBlock = [batteryModel '/From Workspace3'];

assert(getSimulinkBlockHandle(speedBlock) > 0, ...
    'The top-level speed From Workspace block was not found.');

% Point the model directly to Run 002 before updating it
set_param( ...
    speedBlock, ...
    'VariableName', ...
    'ts_Run002_VehSpd_mps');

fprintf('Speed block now uses: %s\n', ...
    get_param(speedBlock,'VariableName'));

try
    set_param(batteryModel,'SimulationCommand','update');
    fprintf('Model update = SUCCESS\n');

catch updateError
    fprintf('\nModel update = FAILED\n');
    fprintf('%s\n',getReport( ...
        updateError,'extended','hyperlinks','off'));

    error('Stop here. Do not start the Run 002 simulation.');
end
%% 6. Prepare the full Run 002 simulation

fullInput002 = Simulink.SimulationInput(batteryModel);

fullInput002 = fullInput002.setBlockParameter( ...
    speedBlock, ...
    'VariableName', ...
    'ts_Run002_VehSpd_mps');

fullInput002 = fullInput002.setModelParameter( ...
    'StopTime',sprintf('%.3f',run002StopTime_s), ...
    'SignalLogging','on');

runIDsBefore002 = Simulink.sdi.getAllRunIDs;

fprintf('\n===== STARTING FULL RUN 002 =====\n');
fprintf('Model = %s\n',batteryModel);
fprintf('Stop time = %.3f seconds\n',run002StopTime_s);
fprintf('Expected runtime is approximately 25-35 minutes.\n');
fprintf('Watch the open model status bar for simulation time.\n');
fprintf('=================================\n');

%% 7. Run the simulation

tic;
out002EV6Battery77p4Full = sim(fullInput002);
runtimeMinutes002 = toc/60;

%% 8. Find and rename the new SDI run

runIDsAfter002 = Simulink.sdi.getAllRunIDs;

newRunIDs002 = setdiff( ...
    runIDsAfter002,runIDsBefore002,'stable');

assert(~isempty(newRunIDs002), ...
    'The simulation completed, but no new SDI run was found.');

fullRun002ID = newRunIDs002(end);
fullRun002SDI = Simulink.sdi.getRun(fullRun002ID);

fullRun002SDI.Name = ...
    'Run002_EV6Battery77p4kWh_Corrected_Full';

%% 9. Verify the main SimulationOutput variables

outputVariables002 = string( ...
    out002EV6Battery77p4Full.who);

requiredOutputs002 = [
    "battery_current"
    "battery_power"
    "battery_soc"
    "tout"
    ];

for k = 1:numel(requiredOutputs002)

    assert(any(outputVariables002 == requiredOutputs002(k)), ...
        'Required output %s was not saved.', ...
        requiredOutputs002(k));
end

%% 10. Print preliminary battery ranges

batteryCurrent002 = ...
    out002EV6Battery77p4Full.get('battery_current');

batteryPower002 = ...
    out002EV6Battery77p4Full.get('battery_power');

batterySoc002 = ...
    out002EV6Battery77p4Full.get('battery_soc');

fprintf('\n===== RUN 002 OUTPUT CHECK =====\n');
fprintf('Battery-current range = %.3f to %.3f A\n', ...
    min(double(batteryCurrent002.Data(:))), ...
    max(double(batteryCurrent002.Data(:))));

fprintf('Battery-power raw range = %.3f to %.3f\n', ...
    min(double(batteryPower002.Data(:))), ...
    max(double(batteryPower002.Data(:))));

fprintf('Battery-SOC range = %.6f to %.6f\n', ...
    min(double(batterySoc002.Data(:))), ...
    max(double(batterySoc002.Data(:))));
fprintf('================================\n');

%% 11. Save the complete SimulationOutput

run002OutputFile = fullfile( ...
    projectRoot, ...
    'EV6_Run002_77p4kWh_Corrected_Full_Output.mat');

save(run002OutputFile, ...
    'out002EV6Battery77p4Full', ...
    '-v7.3');

fprintf('\n===== FULL 2023 EV6 RUN 002 COMPLETE =====\n');
fprintf('Runtime = %.2f minutes\n',runtimeMinutes002);
fprintf('SDI run = %s\n',string(fullRun002SDI.Name));
fprintf('Stop time = %.3f seconds\n',run002StopTime_s);

fprintf('\nSimulation output saved to:\n%s\n', ...
    run002OutputFile);

fprintf('===========================================\n');