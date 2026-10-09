%% RUN 004: POWER-CORRECTED 77.4-kWh MODEL, 60 SECONDS

projectRoot = [ ...
    'C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
    'OneDrive_1_8-28-2026\Vehicles_24a\Vehicles\' ...
    'VehicleProjects\Bolt_EV'];

model = ...
    'EV6_LUT_FourWheel_EV6Battery77p4kWh_PowerCorrected';

modelFile = fullfile(projectRoot,[model '.slx']);

gainFile = fullfile( ...
    projectRoot,'EV6_CombinedTrainingCalibration.mat');

run004File = [ ...
    'C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
    'OneDrive_1_8-28-2026\EV6_drivecycleData\' ...
    'standards_test_08142026_004.mat'];

resultFile = fullfile( ...
    projectRoot, ...
    'EV6_Run004_77p4kWh_PowerCorrected_60s.mat');

runName = ...
    'Run004_EV6Battery77p4kWh_PowerCorrected_60s';

assert(isfile(modelFile), ...
    'Power-corrected model was not found.');

assert(isfile(gainFile), ...
    'Training-calibration file was not found.');

assert(isfile(run004File), ...
    'Run 004 data file was not found.');

%% Normal initialization

run(fullfile(projectRoot,'init_EV6_model.m'));

%% Load the Runs 001-003 torque calibration

gainData = load(gainFile);

assert(isfield(gainData,'EV6_RegenTorqueGain'), ...
    'EV6_RegenTorqueGain was not found.');

assert(isfield(gainData,'EV6_TractionTorqueGain'), ...
    'EV6_TractionTorqueGain was not found.');

EV6_RegenTorqueGain = ...
    gainData.EV6_RegenTorqueGain;

EV6_TractionTorqueGain = ...
    gainData.EV6_TractionTorqueGain;

fprintf('\n===== TORQUE GAINS LOADED =====\n');
fprintf('Traction gain = %.12f\n', ...
    double(EV6_TractionTorqueGain));
fprintf('Regen gain = %.12f\n', ...
    double(EV6_RegenTorqueGain));
fprintf('===============================\n');

%% Prepare Run 004 speed input

loadedRun004 = load(run004File);

if isfield(loadedRun004, ...
        'standards_test_08142026_004')

    D004 = loadedRun004. ...
        standards_test_08142026_004;
else
    loadedNames = fieldnames(loadedRun004);

    assert(numel(loadedNames) == 1, ...
        'Could not uniquely identify Run 004 data.');

    D004 = loadedRun004.(loadedNames{1});
end

channelNames004 = erase( ...
    string({D004.Y.Name}),["<",">"]);

speedIndex = find( ...
    channelNames004 == "VEH_vEgo",1,'first');

assert(~isempty(speedIndex), ...
    'VEH_vEgo was not found in Run 004.');

speedTimeIndex = D004.Y(speedIndex).XIndex;

run004Time_s = double( ...
    D004.X(speedTimeIndex).Data(:));

run004Speed_mps = double( ...
    D004.Y(speedIndex).Data(:));

validSpeed = ...
    isfinite(run004Time_s) & ...
    isfinite(run004Speed_mps);

run004Time_s = run004Time_s(validSpeed);
run004Speed_mps = run004Speed_mps(validSpeed);

run004Speed_mps = max(run004Speed_mps,0);

run004StopTime_s = run004Time_s(end);

ts_Run004_VehSpd_mps = timeseries( ...
    run004Speed_mps,run004Time_s);

ts_VehSpdDmd = ts_Run004_VehSpd_mps;
ts_VehSpd = ts_Run004_VehSpd_mps;

ts_AccelPedal = timeseries( ...
    [0;0],[0;run004StopTime_s]);

ts_BrakePedal = timeseries( ...
    [0;0],[0;run004StopTime_s]);

ts_Steer = timeseries( ...
    [0;0],[0;run004StopTime_s]);

ts_Steering = ts_Steer;

fprintf('\n===== RUN 004 INPUT READY =====\n');
fprintf('Samples = %d\n',numel(run004Time_s));
fprintf('Duration = %.3f seconds\n',run004StopTime_s);
fprintf('Speed range = %.3f to %.3f m/s\n', ...
    min(run004Speed_mps),max(run004Speed_mps));
fprintf('================================\n');

%% Load and configure corrected model

load_system(model);

speedInputBlock = [model '/From Workspace3'];

set_param(speedInputBlock, ...
    'VariableName','ts_Run004_VehSpd_mps');

set_param(model,'StopTime','60');

%% Verify correction subsystem and Sum configuration

correctionSubsystem = [model ...
    '/Vehicle Under Test1/Vehicle/Battery/Battery/' ...
    'EV6 Speed Mode Power Correction'];

batteryCurrentSum = [model ...
    '/Vehicle Under Test1/Vehicle/Battery/Battery/Sum'];

assert(getSimulinkBlockHandle(correctionSubsystem) ~= -1, ...
    'Power-correction subsystem was not found.');

assert(strcmp(get_param(batteryCurrentSum,'Inputs'),'|+++'), ...
    'Battery-current Sum does not have three positive inputs.');

%% Update before simulation

try
    set_param(model,'SimulationCommand','update');

    fprintf('\nPower-corrected model update = SUCCESS\n');

catch updateError
    fprintf('\nPower-corrected model update = FAILED\n\n');
    fprintf('%s\n',getReport( ...
        updateError,'extended','hyperlinks','off'));

    error('Stop here. Do not start the simulation.');
end

%% Record existing SDI runs

runIDsBefore = Simulink.sdi.getAllRunIDs;

%% Run 60-second simulation

fprintf('\nStarting 60-second power-corrected simulation...\n');

simulationTimer = tic;

outPowerCorrected60 = sim( ...
    model, ...
    'StopTime','60', ...
    'ReturnWorkspaceOutputs','on');

runtime_minutes = toc(simulationTimer)/60;

%% Identify and name new SDI run

runIDsAfter = Simulink.sdi.getAllRunIDs;

newRunIDs = setdiff( ...
    runIDsAfter,runIDsBefore,'stable');

powerCorrectedRunID = [];

if ~isempty(newRunIDs)

    powerCorrectedRunID = newRunIDs(end);
    currentRun = Simulink.sdi.getRun( ...
        powerCorrectedRunID);

    currentRun.Name = runName;

elseif ~isempty(runIDsAfter)

    powerCorrectedRunID = runIDsAfter(end);
    currentRun = Simulink.sdi.getRun( ...
        powerCorrectedRunID);

    currentRun.Name = runName;
end

%% Retrieve direct and correction outputs

batteryCurrent60 = getOutputValue( ...
    outPowerCorrected60,'battery_current');

batteryPower60 = getOutputValue( ...
    outPowerCorrected60,'battery_power');

batterySoc60 = getOutputValue( ...
    outPowerCorrected60,'battery_soc');

correctionCurrent60 = getOutputValue( ...
    outPowerCorrected60,'EV6CurrentCorrection_A');

correctionPower60 = getOutputValue( ...
    outPowerCorrected60,'EV6PowerCorrection_kW');

basePower60 = getOutputValue( ...
    outPowerCorrected60,'EV6BasePower_kW');

%% Display range checks

fprintf('\n===== POWER-CORRECTION OUTPUT CHECK =====\n');

printSignalRange( ...
    'Battery current',batteryCurrent60,'A');

printSignalRange( ...
    'Battery power',batteryPower60,'raw units');

printSignalRange( ...
    'Battery SOC',batterySoc60,'');

printSignalRange( ...
    'Current correction',correctionCurrent60,'A');

printSignalRange( ...
    'Power correction',correctionPower60,'kW');

printSignalRange( ...
    'Base motor power',basePower60,'kW');

fprintf('=========================================\n');

%% Save compact results

PowerCorrected60Results = struct;

PowerCorrected60Results.Model = model;
PowerCorrected60Results.SDIRunName = runName;
PowerCorrected60Results.Runtime_minutes = ...
    runtime_minutes;
PowerCorrected60Results.StopTime_s = 60;
PowerCorrected60Results.BatteryCurrent = ...
    batteryCurrent60;
PowerCorrected60Results.BatteryPower = ...
    batteryPower60;
PowerCorrected60Results.BatterySOC = ...
    batterySoc60;
PowerCorrected60Results.CurrentCorrection = ...
    correctionCurrent60;
PowerCorrected60Results.PowerCorrection = ...
    correctionPower60;
PowerCorrected60Results.BasePower = ...
    basePower60;

save(resultFile, ...
    'PowerCorrected60Results','-v7.3');

fprintf('\n===== 60-SECOND CORRECTED RUN COMPLETE =====\n');
fprintf('Runtime = %.2f minutes\n',runtime_minutes);
fprintf('SDI run = %s\n',runName);
fprintf('Saved compact results:\n%s\n',resultFile);
fprintf('==============================================\n');

%% Local functions

function value = getOutputValue(simulationOutput,name)

    value = [];

    outputNames = string(who(simulationOutput));

    if any(outputNames == string(name))
        value = simulationOutput.get(name);
        return
    end

    variableExists = evalin( ...
        'base',sprintf('exist(''%s'',''var'')',name));

    if variableExists
        value = evalin('base',name);
    end
end

function printSignalRange(label,signal,unit)

    if isempty(signal)
        fprintf('%s: NOT FOUND\n',label);
        return
    end

    if isa(signal,'timeseries')
        values = double(signal.Data(:));
    elseif isnumeric(signal)
        values = double(signal(:));
    elseif isstruct(signal) && isfield(signal,'signals')
        values = double(signal.signals.values(:));
    else
        fprintf('%s: unsupported class %s\n', ...
            label,class(signal));
        return
    end

    values = values(isfinite(values));

    if isempty(values)
        fprintf('%s: no finite data\n',label);
    else
        fprintf('%s range = %.6f to %.6f %s\n', ...
            label,min(values),max(values),unit);
    end
end