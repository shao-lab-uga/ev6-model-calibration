%% FULL RUN 004: 2023 EV6 WIND AWD 77.4-kWh BATTERY

projectRoot = ['C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
    'OneDrive_1_8-28-2026\Vehicles_24a\Vehicles\' ...
    'VehicleProjects\Bolt_EV'];

batteryModel = ...
    'EV6_LUT_FourWheel_EV6Battery77p4kWh';

%% Confirm corrected speed input remains available

assert(exist('ts_Run004_VehSpd_mps','var') == 1, ...
    ['The corrected Run 004 input is missing. ' ...
    'Run the 60-second preparation script again.']);

% Compatibility variables
ts_VehSpdDmd = ts_Run004_VehSpd_mps;
ts_VehSpd = ts_Run004_VehSpd_mps;
ts_US06VehSpdDmd = ts_Run004_VehSpd_mps;

% Required torque gains
EV6_TractionTorqueGain = 1.223989;
EV6_RegenTorqueGain = 1.348705;

%% Open model and verify speed source

load_system(batteryModel);

fromBlocks = find_system( ...
    batteryModel, ...
    'SearchDepth',1, ...
    'BlockType','FromWorkspace');

speedBlock = '';

for blockIndex = 1:numel(fromBlocks)

    variableName = string(get_param( ...
        fromBlocks{blockIndex}, ...
        'VariableName'));

    if contains(lower(variableName),"vehspd")
        speedBlock = fromBlocks{blockIndex};
        break
    end
end

assert(~isempty(speedBlock), ...
    'The top-level speed-input block was not found.');

set_param(speedBlock, ...
    'VariableName','ts_Run004_VehSpd_mps');

%% Set full Run 004 stop time

set_param(batteryModel, ...
    'StopTime','619.401');

try
    set_param(batteryModel, ...
        'SimulationCommand','update');

    fprintf('\n77.4-kWh full-run model update = SUCCESS\n');

catch updateError

    fprintf('\n%s\n',getReport( ...
        updateError,'extended', ...
        'hyperlinks','off'));

    error('Stop here. Do not run the simulation.');
end

%% Start simulation

runIDsBefore = Simulink.sdi.getAllRunIDs;

fprintf('\n===== STARTING FULL 2023 EV6 RUN 004 =====\n');
fprintf('Model = %s\n',batteryModel);
fprintf('Stop time = 619.401 seconds\n');
fprintf('Previous full-run runtime was about 28 minutes.\n');
fprintf('===========================================\n');

simulationTimer = tic;

out004EV6Battery77p4Full = sim( ...
    batteryModel, ...
    'ReturnWorkspaceOutputs','on');

runtimeMinutes = toc(simulationTimer)/60;

%% Rename new SDI run

runIDsAfter = Simulink.sdi.getAllRunIDs;

newRunIDs = runIDsAfter( ...
    ~ismember(runIDsAfter,runIDsBefore));

assert(~isempty(newRunIDs), ...
    'No new SDI run was created.');

newRunID = newRunIDs(end);
newRun = Simulink.sdi.getRun(newRunID);

newRun.Name = ...
    'Run004_EV6Battery77p4kWh_Corrected_Full';

%% Save SimulationOutput

outputFile = fullfile( ...
    projectRoot, ...
    'EV6_Run004_77p4kWh_Corrected_Full_Output.mat');

save(outputFile, ...
    'out004EV6Battery77p4Full', ...
    '-v7.3');

fprintf('\n===== FULL 2023 EV6 RUN 004 COMPLETE =====\n');
fprintf('Runtime = %.2f minutes\n',runtimeMinutes);
fprintf('SDI run = %s\n',string(newRun.Name));
fprintf('Stop time = %s seconds\n', ...
    get_param(batteryModel,'StopTime'));
fprintf('\nSimulation output saved to:\n%s\n', ...
    outputFile);
fprintf('===========================================\n');