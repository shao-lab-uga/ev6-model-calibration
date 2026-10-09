%% RESUME POWER-CORRECTED MODEL BUILD AFTER MISSING-VARIABLE ERROR

projectRoot = [ ...
    'C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
    'OneDrive_1_8-28-2026\Vehicles_24a\Vehicles\' ...
    'VehicleProjects\Bolt_EV'];

targetModel = ...
    'EV6_LUT_FourWheel_EV6Battery77p4kWh_PowerCorrected';

targetFile = fullfile(projectRoot,[targetModel '.slx']);

correctionSubsystem = [targetModel ...
    '/Vehicle Under Test1/Vehicle/Battery/Battery/' ...
    'EV6 Speed Mode Power Correction'];

%% Confirm the unsaved corrected model is still loaded

assert(bdIsLoaded(targetModel), ...
    ['The corrected model is no longer loaded.\n' ...
     'Do not continue with this recovery script.']);

assert(getSimulinkBlockHandle(correctionSubsystem) ~= -1, ...
    ['The correction subsystem is not present in the loaded model.\n' ...
     'Do not continue with this recovery script.']);

fprintf('\nCorrection subsystem is still present.\n');

%% Run normal project initialization

initializationFile = fullfile( ...
    projectRoot,'init_EV6_model.m');

assert(isfile(initializationFile), ...
    'Initialization script was not found.');

run(initializationFile);

%% Load Run 004 dyno input

run004File = [ ...
    'C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
    'OneDrive_1_8-28-2026\EV6_drivecycleData\' ...
    'standards_test_08142026_004.mat'];

assert(isfile(run004File), ...
    'Run 004 MAT-file was not found.');

loadedRun004 = load(run004File);

if isfield(loadedRun004, ...
        'standards_test_08142026_004')

    D004 = loadedRun004. ...
        standards_test_08142026_004;
else
    loadedNames = fieldnames(loadedRun004);

    assert(numel(loadedNames) == 1, ...
        'Could not uniquely identify the Run 004 data variable.');

    D004 = loadedRun004.(loadedNames{1});
end

%% Extract Run 004 vehicle speed

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

% Compatibility aliases used elsewhere in the model
ts_VehSpdDmd = ts_Run004_VehSpd_mps;
ts_VehSpd = ts_Run004_VehSpd_mps;

%% Create zero external commands

ts_AccelPedal = timeseries( ...
    [0;0],[0;run004StopTime_s]);

ts_BrakePedal = timeseries( ...
    [0;0],[0;run004StopTime_s]);

ts_Steer = timeseries( ...
    [0;0],[0;run004StopTime_s]);

ts_Steering = ts_Steer;

%% Correct the top-level speed-input block

speedInputBlock = [targetModel ...
    '/From Workspace3'];

assert(getSimulinkBlockHandle(speedInputBlock) ~= -1, ...
    'Top-level From Workspace3 block was not found.');

set_param(speedInputBlock, ...
    'VariableName','ts_Run004_VehSpd_mps');

fprintf('\n===== RUN 004 INPUT PREPARED =====\n');
fprintf('Samples = %d\n',numel(run004Time_s));
fprintf('Duration = %.3f seconds\n',run004StopTime_s);
fprintf('Speed range = %.3f to %.3f m/s\n', ...
    min(run004Speed_mps),max(run004Speed_mps));
fprintf('==================================\n');

%% Attempt to recover EV6_RegenTorqueGain

gainName = 'EV6_RegenTorqueGain';

gainAlreadyLoaded = evalin( ...
    'base',sprintf('exist(''%s'',''var'')',gainName));

if ~gainAlreadyLoaded

    fprintf('\nSearching MAT-files for %s...\n',gainName);

    matFiles = dir(fullfile( ...
        projectRoot,'**','*.mat'));

    gainFiles = strings(0,1);
    gainObjects = cell(0,1);
    numericGain = [];

    for k = 1:numel(matFiles)

        currentFile = fullfile( ...
            matFiles(k).folder,matFiles(k).name);

        try
            fileVariables = whos('-file',currentFile);
            variableNames = string({fileVariables.name});

            if any(variableNames == gainName)

                loadedGain = load(currentFile,gainName);
                gainObject = loadedGain.(gainName);

                if isa(gainObject,'Simulink.Parameter')
                    numericValue = double(gainObject.Value);
                else
                    numericValue = double(gainObject);
                end

                if isscalar(numericValue) && ...
                        isfinite(numericValue)

                    gainFiles(end+1,1) = ...
                        string(currentFile);

                    gainObjects{end+1,1} = gainObject;
                    numericGainValues(end+1,1) = ...
                        numericValue;
                end
            end
        catch
        end
    end

    if numel(gainFiles) == 1

        EV6_RegenTorqueGain = gainObjects{1};

        fprintf('Loaded %s from:\n%s\n', ...
            gainName,gainFiles(1));

    elseif numel(gainFiles) > 1

        fprintf('\nPossible gain sources:\n');

        for k = 1:numel(gainFiles)
            fprintf('  %.12g  %s\n', ...
                numericGainValues(k),gainFiles(k));
        end

        valuesAgree = max(abs(numericGainValues - numericGainValues(1))) < 1e-5;

        assert(valuesAgree, ...
            ['Multiple different values were found for ' ...
             'EV6_RegenTorqueGain. Stop and send this list.']);

        EV6_RegenTorqueGain = gainObjects{1};

        fprintf(['All saved values agree. ' ...
            'Using %.12g.\n'],numericGainValues(1));

    else

        fprintf('\nNo MAT-file contained %s.\n',gainName);
        fprintf('Searching MATLAB scripts...\n');

        scriptFiles = dir(fullfile( ...
            projectRoot,'**','*.m'));

        scriptMatches = strings(0,1);

        for k = 1:numel(scriptFiles)

            currentScript = fullfile( ...
                scriptFiles(k).folder, ...
                scriptFiles(k).name);

            try
                scriptText = fileread(currentScript);

                if contains(scriptText,gainName)
                    scriptMatches(end+1,1) = ...
                        string(currentScript);
                end
            catch
            end
        end

        fprintf('\nScripts containing %s:\n',gainName);

        for k = 1:numel(scriptMatches)
            fprintf('  %s\n',scriptMatches(k));
        end

        error([gainName ' could not be recovered automatically. ' ...
            'Send the script list shown above.']);
    end
end

fprintf('\n%s is available:\n',gainName);
disp(EV6_RegenTorqueGain);

%% Update target model

set_param(targetModel,'StopTime','60');

try
    set_param(targetModel, ...
        'SimulationCommand','update');

    updateSuccessful = true;

catch updateError
    updateSuccessful = false;

    fprintf('\n===== MODEL UPDATE STILL FAILED =====\n');
    fprintf('%s\n',getReport( ...
        updateError,'extended','hyperlinks','off'));
end

assert(updateSuccessful, ...
    'Stop here. Do not start the simulation.');

%% Save only after successful update

save_system(targetModel,targetFile);

fprintf('\n===== CORRECTED MODEL RECOVERED =====\n');
fprintf('Model update = SUCCESS\n');
fprintf('Stop time = 60 seconds\n');
fprintf('Speed input = ts_Run004_VehSpd_mps\n');
fprintf('Saved to:\n%s\n',targetFile);
fprintf('\nOriginal 77.4-kWh model was not modified.\n');
fprintf('Do not start the full-cycle simulation yet.\n');
fprintf('=====================================\n');