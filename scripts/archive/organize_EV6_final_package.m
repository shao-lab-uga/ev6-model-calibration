%% ORGANIZE FINAL EV6 MODEL AND RESULTS

projectDir = ['C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
    'OneDrive_1_8-28-2026\Vehicles_24a\Vehicles\' ...
    'VehicleProjects\Bolt_EV'];

packageDir = fullfile(projectDir, ...
    'EV6_Final_Package_2023_Wind_AWD');

% Avoid overwriting an existing package
if isfolder(packageDir)
    packageDir = [packageDir '_' datestr(now,'yyyymmdd_HHMMSS')];
end

modelDir       = fullfile(packageDir,'01_Final_Model');
calibrationDir = fullfile(packageDir,'02_Calibration');
validationDir  = fullfile(packageDir,'03_Validation_Results');
figureDir      = fullfile(packageDir,'04_Figures_and_Metrics');
scriptDir      = fullfile(packageDir,'05_MATLAB_Scripts');

mkdir(modelDir);
mkdir(calibrationDir);
mkdir(validationDir);
mkdir(figureDir);
mkdir(scriptDir);

%% Final model files

modelFiles = {
    'EV6_LUT_FourWheel_EV6Battery77p4kWh_PowerCorrected.slx'
    'init_EV6_model.m'
    'EV6_axle_split_LUT_3D.mat'
    'EV6_CombinedTrainingCalibration.mat'
    };

for k = 1:numel(modelFiles)
    sourceFile = fullfile(projectDir,modelFiles{k});

    if isfile(sourceFile)
        copyfile(sourceFile,modelDir);
        fprintf('COPIED MODEL: %s\n',modelFiles{k});
    else
        fprintf('MISSING MODEL FILE: %s\n',modelFiles{k});
    end
end

%% Calibration folder

sourceCalibration = fullfile(projectDir,'Battery_Calibration');

if isfolder(sourceCalibration)
    copyfile(sourceCalibration,calibrationDir);
    fprintf('COPIED CALIBRATION FOLDER\n');
end

%% Final validation MAT files

validationFiles = {
    'EV6_Final_Validation_Summary.mat'
    'EV6_Run004_77p4kWh_PowerCorrected_Full_Validation.mat'
    'EV6_Run004_PowerCorrection_DynamicsPreservation.mat'
    'EV6_Run004_77p4kWh_PowerCorrected_Full_Output.mat'
    'EV6_Run004_77p4kWh_Corrected_Full_Output.mat'
    };

for k = 1:numel(validationFiles)
    sourceFile = fullfile(projectDir,validationFiles{k});

    if isfile(sourceFile)
        copyfile(sourceFile,validationDir);
        fprintf('COPIED RESULT: %s\n',validationFiles{k});
    else
        fprintf('MISSING RESULT: %s\n',validationFiles{k});
    end
end

%% Figures and CSV metrics

sourceFigures = fullfile(projectDir,'Run004_Professor_Figures');

if isfolder(sourceFigures)
    copyfile(sourceFigures,figureDir);
    fprintf('COPIED FIGURES AND METRICS\n');
end

%% Save all MATLAB scripts for reproducibility

scriptFiles = dir(fullfile(projectDir,'*.m'));

for k = 1:numel(scriptFiles)
    copyfile(fullfile(scriptFiles(k).folder,scriptFiles(k).name), ...
        scriptDir);
end

fprintf('COPIED %d MATLAB SCRIPTS\n',numel(scriptFiles));

%% Create short README

readmeFile = fullfile(packageDir,'README_EV6_FINAL.txt');
fileID = fopen(readmeFile,'w');

fprintf(fileID,'2023 KIA EV6 WIND AWD FINAL MODEL\n');
fprintf(fileID,'=================================\n\n');

fprintf(fileID,'Final model:\n');
fprintf(fileID, ...
    'EV6_LUT_FourWheel_EV6Battery77p4kWh_PowerCorrected.slx\n\n');

fprintf(fileID,'Vehicle configuration:\n');
fprintf(fileID,'2023 Kia EV6 Wind AWD dual motor\n');
fprintf(fileID,'Battery energy: 77.4 kWh\n');
fprintf(fileID,'Nominal voltage: 697 V\n\n');

fprintf(fileID,'Run004 development-validation results:\n');
fprintf(fileID,'Dyno net energy: 0.28431 kWh\n');
fprintf(fileID,'Final model energy: 0.27917 kWh\n');
fprintf(fileID,'Final energy error: -1.8076 percent\n');
fprintf(fileID,'Battery-current MAE: 0.97128 A\n');
fprintf(fileID,'Battery-current correlation: 0.97840\n');
fprintf(fileID,'Four-wheel torque MAE: 91.373 N*m\n');
fprintf(fileID,'Vehicle-speed RMSE: 0.33211 m/s\n\n');

fprintf(fileID,'Training runs: Run001, Run002, Run003\n');
fprintf(fileID,'Development-validation run: Run004\n');
fprintf(fileID,'The original supplied model was not modified.\n');

fclose(fileID);

fprintf('\n========================================\n');
fprintf('FINAL EV6 PACKAGE CREATED\n');
fprintf('%s\n',packageDir);
fprintf('========================================\n');