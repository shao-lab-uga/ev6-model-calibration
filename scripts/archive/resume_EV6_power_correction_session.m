%% RESUME EV6 POWER-CORRECTION SESSION

clearvars
clc

projectRoot = [ ...
    'C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
    'OneDrive_1_8-28-2026\Vehicles_24a\Vehicles\' ...
    'VehicleProjects\Bolt_EV'];

batteryCalibrationFolder = fullfile( ...
    projectRoot,'Battery_Calibration');

correctedModel = ...
    'EV6_LUT_FourWheel_EV6Battery77p4kWh_PowerCorrected';

correctedModelFile = fullfile( ...
    projectRoot,[correctedModel '.slx']);

gainFile = fullfile( ...
    projectRoot,'EV6_CombinedTrainingCalibration.mat');

mapFile = fullfile( ...
    batteryCalibrationFolder, ...
    'EV6_SpeedMode_PowerCorrection_Results.mat');

correctedCompactFile = fullfile( ...
    projectRoot, ...
    'EV6_Run004_77p4kWh_PowerCorrected_60s.mat');

correctedFullFile = fullfile( ...
    projectRoot, ...
    'EV6_Run004_77p4kWh_PowerCorrected_60s_FullOutput.mat');

original60File = fullfile( ...
    projectRoot, ...
    'EV6_Run004_77p4kWh_Corrected_60s_Battery.mat');

run004File = [ ...
    'C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
    'OneDrive_1_8-28-2026\EV6_drivecycleData\' ...
    'standards_test_08142026_004.mat'];

%% Verify required files

requiredFiles = { ...
    correctedModelFile
    gainFile
    mapFile
    correctedCompactFile
    original60File
    run004File};

fprintf('\n===== REQUIRED FILE CHECK =====\n');

for k = 1:numel(requiredFiles)

    if isfile(requiredFiles{k})
        fprintf('FOUND   %s\n',requiredFiles{k});
    else
        fprintf('MISSING %s\n',requiredFiles{k});
    end
end

assert(isfile(correctedModelFile), ...
    'Corrected Simulink model is missing.');

assert(isfile(gainFile), ...
    'Torque-gain file is missing.');

assert(isfile(mapFile), ...
    'Power-correction map is missing.');

assert(isfile(correctedCompactFile), ...
    'Corrected compact 60-second result is missing.');

assert(isfile(original60File), ...
    'Original 77.4-kWh 60-second result is missing.');

assert(isfile(run004File), ...
    'Run 004 dyno file is missing.');

fprintf('================================\n');

%% Configure MATLAB folders

cd(projectRoot);

addpath(projectRoot);
addpath(batteryCalibrationFolder);

%% Run normal initialization

run(fullfile(projectRoot,'init_EV6_model.m'));

%% Reload calibrated torque gains

gainData = load(gainFile);

EV6_RegenTorqueGain = ...
    gainData.EV6_RegenTorqueGain;

EV6_TractionTorqueGain = ...
    gainData.EV6_TractionTorqueGain;

fprintf('\n===== TORQUE GAINS =====\n');
fprintf('Traction gain = %.12f\n', ...
    double(EV6_TractionTorqueGain));
fprintf('Regen gain = %.12f\n', ...
    double(EV6_RegenTorqueGain));
fprintf('========================\n');

%% Reload correction map

PowerCorrectionMapData = load(mapFile);

fprintf('\n===== POWER-CORRECTION MAP =====\n');
fprintf('Candidate passed = %d\n', ...
    PowerCorrectionMapData.candidatePasses);

fprintf('Mode threshold = %.3f kW\n', ...
    PowerCorrectionMapData.modeThreshold_kW);

fprintf('Speed points = %d\n', ...
    numel(PowerCorrectionMapData.speedCenters_mps));
fprintf('================================\n');

%% Reload Run 004 dyno data

loadedRun004 = load(run004File);

if isfield(loadedRun004, ...
        'standards_test_08142026_004')

    D004 = loadedRun004. ...
        standards_test_08142026_004;
else
    run004Fields = fieldnames(loadedRun004);

    assert(numel(run004Fields) == 1, ...
        'Could not uniquely identify Run 004 data.');

    D004 = loadedRun004.(run004Fields{1});
end

%% Recreate Run 004 speed input

channelNames004 = erase( ...
    string({D004.Y.Name}),["<",">"]);

speedIndex = find( ...
    channelNames004 == "VEH_vEgo",1,'first');

assert(~isempty(speedIndex), ...
    'VEH_vEgo was not found.');

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

fprintf('\n===== RUN 004 INPUT =====\n');
fprintf('Samples = %d\n',numel(run004Time_s));
fprintf('Duration = %.3f seconds\n',run004StopTime_s);
fprintf('Speed range = %.3f to %.3f m/s\n', ...
    min(run004Speed_mps),max(run004Speed_mps));
fprintf('=========================\n');

%% Load corrected model

load_system(correctedModel);

speedInputBlock = [correctedModel ...
    '/From Workspace3'];

set_param(speedInputBlock, ...
    'VariableName','ts_Run004_VehSpd_mps');

set_param(correctedModel,'StopTime','60');

correctionSubsystem = [correctedModel ...
    '/Vehicle Under Test1/Vehicle/Battery/Battery/' ...
    'EV6 Speed Mode Power Correction'];

batteryCurrentSum = [correctedModel ...
    '/Vehicle Under Test1/Vehicle/Battery/Battery/Sum'];

assert(getSimulinkBlockHandle(correctionSubsystem) ~= -1, ...
    'Correction subsystem is missing.');

assert(strcmp(get_param(batteryCurrentSum,'Inputs'),'|+++'), ...
    'Battery Sum does not contain the correction-current input.');

try
    set_param(correctedModel,'SimulationCommand','update');
    fprintf('\nCorrected model update = SUCCESS\n');
catch updateError
    fprintf('%s\n',getReport( ...
        updateError,'extended','hyperlinks','off'));
    error('Corrected model update failed.');
end

%% Load saved 60-second results

CorrectedCompactData = load(correctedCompactFile);
Original60Data = load(original60File);

if isfile(correctedFullFile)

    correctedFullData = load( ...
        correctedFullFile,'outPowerCorrected60');

    outPowerCorrected60 = ...
        correctedFullData.outPowerCorrected60;

    correctedFullOutputAvailable = true;
else
    correctedFullOutputAvailable = false;
end

%% Display saved variable contents

fprintf('\n===== ORIGINAL 60-SECOND FILE VARIABLES =====\n');

originalFileInfo = whos('-file',original60File);

for k = 1:numel(originalFileInfo)
    fprintf('%s | %s | %s\n', ...
        originalFileInfo(k).name, ...
        mat2str(originalFileInfo(k).size), ...
        originalFileInfo(k).class);
end

fprintf('\n===== CORRECTED COMPACT FILE VARIABLES =====\n');

correctedFileInfo = whos('-file',correctedCompactFile);

for k = 1:numel(correctedFileInfo)
    fprintf('%s | %s | %s\n', ...
        correctedFileInfo(k).name, ...
        mat2str(correctedFileInfo(k).size), ...
        correctedFileInfo(k).class);
end

fprintf('\n===== FULL OUTPUT CHECK =====\n');
fprintf('Corrected full output available = %d\n', ...
    correctedFullOutputAvailable);

if correctedFullOutputAvailable

    correctedOutputNames = string( ...
        who(outPowerCorrected60));

    fprintf('SimulationOutput variables:\n');
    disp(correctedOutputNames');
end

%% Search full output for battery-related logged signals

if correctedFullOutputAvailable && ...
        any(correctedOutputNames == "logsout")

    correctedLogsout = ...
        outPowerCorrected60.get('logsout');

    fprintf('\nBattery-related logsout signals:\n');

    for k = 1:correctedLogsout.numElements

        currentElement = ...
            correctedLogsout.getElement(k);

        currentName = string(currentElement.Name);
        lowerName = lower(currentName);

        if contains(lowerName,"batt") || ...
           contains(lowerName,"battery")

            fprintf('%d. %s\n',k,currentName);
        end
    end
end

%% Session state summary

EV6SessionState = struct;

EV6SessionState.ProjectRoot = projectRoot;
EV6SessionState.Model = correctedModel;
EV6SessionState.Run = "Run004";
EV6SessionState.StopTime_s = 60;
EV6SessionState.FullOutputAvailable = ...
    correctedFullOutputAvailable;

fprintf('\n====================================\n');
fprintf('EV6 POWER-CORRECTION SESSION READY\n');
fprintf('====================================\n');
fprintf('Corrected model loaded and updated.\n');
fprintf('Run 004 input recreated.\n');
fprintf('Original 60-second data loaded.\n');
fprintf('Corrected compact data loaded.\n');

if correctedFullOutputAvailable
    fprintf('Corrected full output loaded.\n');
else
    fprintf(['Corrected full output was not found. ' ...
        'The 60-second simulation may need to be rerun.\n']);
end

fprintf('\nDo not run the full cycle yet.\n');
fprintf('====================================\n');