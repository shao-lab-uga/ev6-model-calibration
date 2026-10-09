%% ARCHIVE FINAL EV6 MODEL AND RESULTS

projectDir = ['C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
    'OneDrive_1_8-28-2026\Vehicles_24a\Vehicles\' ...
    'VehicleProjects\Bolt_EV'];

stamp = datestr(now,'yyyymmdd_HHMMSS');

finalDir = fullfile(projectDir, ...
    ['EV6_Final_Deliverables_' stamp]);

mkdir(finalDir);

filesToCopy = {
    'EV6_LUT_FourWheel_EV6Battery77p4kWh_PowerCorrected.slx'
    'EV6_CombinedTrainingCalibration.mat'
    'EV6_Final_Validation_Summary.mat'
    'EV6_Run004_77p4kWh_PowerCorrected_Full_Validation.mat'
    'EV6_Run004_77p4kWh_PowerCorrected_Full_Output.mat'
    'EV6_Run004_PowerCorrection_DynamicsPreservation.mat'
    };

fprintf('\n===== ARCHIVING FINAL EV6 MODEL =====\n');

for k = 1:numel(filesToCopy)
    sourceFile = fullfile(projectDir,filesToCopy{k});

    if isfile(sourceFile)
        copyfile(sourceFile,finalDir);
        fprintf('COPIED  %s\n',filesToCopy{k});
    else
        fprintf('MISSING %s\n',filesToCopy{k});
    end
end

foldersToCopy = {
    fullfile(projectDir,'Run004_Professor_Figures')
    fullfile(projectDir,'Battery_Calibration')
    };

for k = 1:numel(foldersToCopy)
    if isfolder(foldersToCopy{k})
        [~,folderName] = fileparts(foldersToCopy{k});
        copyfile(foldersToCopy{k}, ...
            fullfile(finalDir,folderName));

        fprintf('COPIED  %s folder\n',folderName);
    end
end

fprintf('\nFinal deliverables saved to:\n%s\n',finalDir);
fprintf('=====================================\n');