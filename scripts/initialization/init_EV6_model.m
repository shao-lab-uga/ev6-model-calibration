function init_EV6_model(projectRoot)
%INIT_EV6_MODEL Load everything required by the EV6 LUT Simulink model.
%
%   init_EV6_model
%   init_EV6_model('C:\path\to\your\project')
%
% Put this file in the project root containing the Simulink model,
% LUT MAT-file, vehicle support files, and drive-cycle data.
%
% Variables created in the MATLAB base workspace:
%   SupvsryCtrlBus
%   EV6_FinalDriveRatio, DiffRatio
%   accel_bp_mps2, speed_bp_kph
%   traction_torque_bp_Nm
%   front_share_traction_3d
%   rear_share_traction_3d
%   regen_torque_bp_Nm
%   front_share_regen_3d
%   rear_share_regen_3d
%   ts_AccelPedal
%   ts_BrakePedal
%   ts_Steer
%   ts_US06VehSpdDmd
%   ts_VehSpd
%
% IMPORTANT:
% Do not put "clear" inside this function or a model callback.

    %% Determine the project folder

    if nargin < 1 || isempty(projectRoot)
        projectRoot = fileparts(mfilename('fullpath'));
    end

    projectRoot = char(projectRoot);

    if ~isfolder(projectRoot)
        error('EV6Init:BadProjectRoot', ...
            'Project folder does not exist:\n%s', ...
            projectRoot);
    end

    addpath(genpath(projectRoot));
    rehash path;

    fprintf('\nInitializing EV6 model from:\n');
    fprintf('  %s\n',projectRoot);

    %% Use short folders for Simulink-generated files

    userProfile = getenv('USERPROFILE');

    if isempty(userProfile)
        buildRoot = fullfile(tempdir,'MATLABBuild');
    else
        buildRoot = fullfile(userProfile,'MATLABBuild');
    end

    cacheFolder = fullfile(buildRoot,'cache');
    codeGenFolder = fullfile(buildRoot,'codegen');

    if ~exist(cacheFolder,'dir')
        mkdir(cacheFolder);
    end

    if ~exist(codeGenFolder,'dir')
        mkdir(codeGenFolder);
    end

    Simulink.fileGenControl('set', ...
        'CacheFolder',cacheFolder, ...
        'CodeGenFolder',codeGenFolder, ...
        'createDir',true);

    fprintf('Simulink cache folder:\n');
    fprintf('  %s\n',cacheFolder);

    fprintf('Simulink code-generation folder:\n');
    fprintf('  %s\n',codeGenFolder);

    %% 1. Load the bus objects, including SupvsryCtrlBus

    busReady = evalin('base', ...
        ['exist(''SupvsryCtrlBus'',''var'') == 1 && ' ...
         'isa(SupvsryCtrlBus,''Simulink.Bus'')']);

    if busReady
        fprintf(['SupvsryCtrlBus is already present in the ' ...
            'base workspace.\n']);
    else
        % Prefer the dedicated SupvsryCtrlBus.mat file over larger
        % workspace snapshots such as CAVE_driver_inputs.mat.

        busFile = findMatContaining( ...
            projectRoot, ...
            {'SupvsryCtrlBus'}, ...
            'SupvsryCtrlBus.mat', ...
            'bus-object MAT-file');

        busVars = load(busFile);
        copyStructToBase(busVars);

        busReady = evalin('base', ...
            ['exist(''SupvsryCtrlBus'',''var'') == 1 && ' ...
             'isa(SupvsryCtrlBus,''Simulink.Bus'')']);

        if ~busReady
            error('EV6Init:BusLoadFailed', ...
                ['Loaded the following file, but ' ...
                 'SupvsryCtrlBus is not a Simulink.Bus:\n%s'], ...
                busFile);
        end

        fprintf('Bus definitions:\n');
        fprintf('  %s\n',busFile);
    end

    %% 2. Load the EV6 3-D torque-split LUT

    lutFile = findLutFile(projectRoot);
    lutVars = load(lutFile);

    requiredAxes = { ...
        'accel_bp_mps2', ...
        'speed_bp_kph'};

    requireFields(lutVars,requiredAxes,lutFile);

    % Case 1: The MAT-file already contains separate traction and
    % regeneration LUTs.
    if all(isfield(lutVars,{ ...
            'traction_torque_bp_Nm', ...
            'front_share_traction_3d', ...
            'regen_torque_bp_Nm', ...
            'front_share_regen_3d'}))

        tractionTorque = ...
            lutVars.traction_torque_bp_Nm;

        tractionShare = ...
            lutVars.front_share_traction_3d;

        regenTorque = ...
            lutVars.regen_torque_bp_Nm;

        regenShare = ...
            lutVars.front_share_regen_3d;

    % Case 2: The MAT-file contains one combined signed-torque LUT.
    elseif all(isfield(lutVars,{ ...
            'total_torque_bp_Nm', ...
            'front_share_lut_3d'}))

        totalTorque = ...
            lutVars.total_torque_bp_Nm(:).';

        frontShare = ...
            lutVars.front_share_lut_3d;

        tractionMask = totalTorque >= 0;
        regenMask = totalTorque <= 0;

        tractionTorque = totalTorque(tractionMask);
        tractionShare = frontShare(:,:,tractionMask);

        regenTorque = totalTorque(regenMask);
        regenShare = frontShare(:,:,regenMask);

    else
        error('EV6Init:UnsupportedLut', ...
            ['The LUT file does not contain the required separate ' ...
             'traction/regen variables or the combined signed-torque ' ...
             'LUT variables:\n%s'], ...
            lutFile);
    end

    % Make all torque breakpoint vectors row vectors.
    tractionTorque = tractionTorque(:).';
    regenTorque = regenTorque(:).';

    validateLutSize( ...
        lutVars.accel_bp_mps2, ...
        lutVars.speed_bp_kph, ...
        tractionTorque, ...
        tractionShare, ...
        'traction');

    validateLutSize( ...
        lutVars.accel_bp_mps2, ...
        lutVars.speed_bp_kph, ...
        regenTorque, ...
        regenShare, ...
        'regen');

    % Place LUT variables in the base workspace.
    assignin('base', ...
        'accel_bp_mps2', ...
        lutVars.accel_bp_mps2);

    assignin('base', ...
        'speed_bp_kph', ...
        lutVars.speed_bp_kph);

    assignin('base', ...
        'traction_torque_bp_Nm', ...
        tractionTorque);

    assignin('base', ...
        'front_share_traction_3d', ...
        tractionShare);

    assignin('base', ...
        'rear_share_traction_3d', ...
        1 - tractionShare);

    assignin('base', ...
        'regen_torque_bp_Nm', ...
        regenTorque);

    assignin('base', ...
        'front_share_regen_3d', ...
        regenShare);

    assignin('base', ...
        'rear_share_regen_3d', ...
        1 - regenShare);

    fprintf('EV6 LUT:\n');
    fprintf('  %s\n',lutFile);

    fprintf('Acceleration breakpoints: %.3f to %.3f m/s^2\n', ...
        min(lutVars.accel_bp_mps2), ...
        max(lutVars.accel_bp_mps2));

    fprintf('Speed breakpoints: %.3f to %.3f km/h\n', ...
        min(lutVars.speed_bp_kph), ...
        max(lutVars.speed_bp_kph));

    fprintf('Traction torque breakpoints: %.1f to %.1f N*m\n', ...
        min(tractionTorque), ...
        max(tractionTorque));

    fprintf('Regen torque breakpoints: %.1f to %.1f N*m\n', ...
        min(regenTorque), ...
        max(regenTorque));

    %% 3. Find driveData and create the US06 speed-demand timeseries

    driveFile = findMatContaining( ...
        projectRoot, ...
        {'driveData'}, ...
        '', ...
        'MAT-file containing driveData');

    driveVars = load(driveFile,'driveData');
    driveData = driveVars.driveData;

    if ~isstruct(driveData) || ...
            ~isfield(driveData,'US06')

        error('EV6Init:MissingUS06', ...
            ['driveData in the following file does not contain ' ...
             'driveData.US06:\n%s'], ...
            driveFile);
    end

    US06data = driveData.US06;

    if ~isstruct(US06data) || ...
            ~all(isfield(US06data,{'Time','Speed'}))

        error('EV6Init:BadUS06Format', ...
            ['Expected driveData.US06.Time and ' ...
             'driveData.US06.Speed in:\n%s'], ...
            driveFile);
    end

    us06Time = double(US06data.Time(:));
    us06SpeedKph = double(US06data.Speed(:));

    if numel(us06Time) ~= numel(us06SpeedKph) || ...
            numel(us06Time) < 2

        error('EV6Init:BadUS06Size', ...
            ['US06 Time and Speed must have the same length ' ...
             'and contain at least two samples.']);
    end

    if any(~isfinite(us06Time)) || ...
            any(~isfinite(us06SpeedKph))

        error('EV6Init:NonfiniteUS06', ...
            ['US06 Time and Speed must contain only ' ...
             'finite values.']);
    end

    if any(diff(us06Time) <= 0)
        error('EV6Init:NonmonotonicUS06', ...
            'US06 Time must be strictly increasing.');
    end

    % Shift the first time sample to zero.
    us06Time = us06Time - us06Time(1);

    % The US06 speed data reaches approximately 129.23, meaning the
    % original speed data is in km/h.
    us06SpeedMps = us06SpeedKph/3.6;

    ts_US06VehSpdDmd = timeseries( ...
        us06SpeedMps, ...
        us06Time);

    ts_US06VehSpdDmd.Name = ...
        'US06 Vehicle Speed Demand';

    % Zero placeholders allow the top-level From Workspace blocks to
    % compile. The closed-loop Driver block generates the active
    % accelerator and brake commands during the US06 simulation.
    zeroTime = [us06Time(1); us06Time(end)];
    zeroData = [0; 0];

    ts_AccelPedal = timeseries( ...
        zeroData,zeroTime);

    ts_AccelPedal.Name = ...
        'External Accelerator Placeholder';

    ts_BrakePedal = timeseries( ...
        zeroData,zeroTime);

    ts_BrakePedal.Name = ...
        'External Brake Placeholder';

    ts_Steer = timeseries( ...
        zeroData,zeroTime);

    ts_Steer.Name = ...
        'External Steering Placeholder';

    % Compatibility aliases for older copies of the model.
    ts_Steering = ts_Steer;
    ts_VehSpd = ts_US06VehSpdDmd;

    ts_VehSpd.Name = ...
        'Temporary Vehicle Speed Input';

    % Place drive-cycle variables in the base workspace.
    assignin('base','driveData',driveData);
    assignin('base','US06data',US06data);

    assignin('base', ...
        'ts_US06VehSpdDmd', ...
        ts_US06VehSpdDmd);

    assignin('base', ...
        'ts_AccelPedal', ...
        ts_AccelPedal);

    assignin('base', ...
        'ts_BrakePedal', ...
        ts_BrakePedal);

    assignin('base', ...
        'ts_Steer', ...
        ts_Steer);

    assignin('base', ...
        'ts_Steering', ...
        ts_Steering);

    assignin('base', ...
        'ts_VehSpd', ...
        ts_VehSpd);

    %% 4. Create the Kia EV6 drivetrain-ratio variables

    % This value was confirmed using the simulated motor-torque and
    % axle-torque signals.
    EV6_FinalDriveRatio = 10.65;

    % Keep the original DiffRatio name for legacy blocks that still
    % reference it.
    DiffRatio = EV6_FinalDriveRatio;

    % Because init_EV6_model is a function, assignin is required to
    % place these variables in the MATLAB base workspace.
    assignin('base', ...
        'EV6_FinalDriveRatio', ...
        EV6_FinalDriveRatio);

    assignin('base', ...
        'DiffRatio', ...
        DiffRatio);

    fprintf('EV6 final-drive ratio loaded: %.4f\n', ...
        EV6_FinalDriveRatio);

    fprintf('Legacy DiffRatio loaded: %.4f\n', ...
        DiffRatio);

    %% 5. Print final initialization information

    fprintf('driveData:\n');
    fprintf('  %s\n',driveFile);

    fprintf( ...
        'US06: %.1f s, maximum %.2f km/h (%.2f m/s)\n', ...
        us06Time(end), ...
        max(us06SpeedKph), ...
        max(us06SpeedMps));

    fprintf([ ...
        'Compatibility variable ts_VehSpd was created. ' ...
        'Remove its internal From Workspace block before ' ...
        'final validation.\n']);

    fprintf([ ...
        'EV6 initialization complete. ' ...
        'You may now open, update, and run the model.\n\n']);

end


function lutFile = findLutFile(projectRoot)

gainFile = fullfile(projectRoot,'EV6_TorqueCalibration_Gains.mat');

if isfile(gainFile)
    load(gainFile, ...
        'EV6_TractionTorqueGain', ...
        'EV6_RegenTorqueGain');
end

%FINDLUTFILE Find either a split or combined EV6 LUT MAT-file.

    preferred = fullfile( ...
        projectRoot, ...
        '**', ...
        'EV6_axle_split_LUT_3D.mat');

    preferredFiles = dir(preferred);
    preferredFiles = preferredFiles( ...
        ~[preferredFiles.isdir]);

    if numel(preferredFiles) == 1

        lutFile = fullfile( ...
            preferredFiles(1).folder, ...
            preferredFiles(1).name);

        return

    elseif numel(preferredFiles) > 1

        lutFile = chooseNewest( ...
            preferredFiles, ...
            ['Multiple EV6_axle_split_LUT_3D.mat ' ...
             'files were found']);

        return
    end

    matFiles = dir( ...
        fullfile(projectRoot,'**','*.mat'));

    candidates = strings(0,1);

    for k = 1:numel(matFiles)

        filePath = fullfile( ...
            matFiles(k).folder, ...
            matFiles(k).name);

        try
            names = who('-file',filePath);

            isSplit = all(ismember({ ...
                'accel_bp_mps2', ...
                'speed_bp_kph', ...
                'traction_torque_bp_Nm', ...
                'front_share_traction_3d', ...
                'regen_torque_bp_Nm', ...
                'front_share_regen_3d'}, ...
                names));

            isCombined = all(ismember({ ...
                'accel_bp_mps2', ...
                'speed_bp_kph', ...
                'total_torque_bp_Nm', ...
                'front_share_lut_3d'}, ...
                names));

            if isSplit || isCombined
                candidates(end+1,1) = ...
                    string(filePath); %#ok<AGROW>
            end

        catch
            % Ignore unreadable or invalid MAT-files.
        end
    end

    lutFile = selectCandidate( ...
        candidates, ...
        'EV6 LUT MAT-file');

end


function filePath = findMatContaining( ...
        projectRoot,requiredNames,preferredName,description)
%FINDMATCONTAINING Find a MAT-file containing required variables.

    if ~isempty(preferredName)

        preferredFiles = dir( ...
            fullfile(projectRoot,'**',preferredName));

        preferredFiles = preferredFiles( ...
            ~[preferredFiles.isdir]);

        if numel(preferredFiles) == 1

            candidate = fullfile( ...
                preferredFiles(1).folder, ...
                preferredFiles(1).name);

            names = who('-file',candidate);

            if all(ismember(requiredNames,names))
                filePath = candidate;
                return
            end
        end
    end

    matFiles = dir( ...
        fullfile(projectRoot,'**','*.mat'));

    candidates = strings(0,1);

    for k = 1:numel(matFiles)

        candidate = fullfile( ...
            matFiles(k).folder, ...
            matFiles(k).name);

        try
            names = who('-file',candidate);

            if all(ismember(requiredNames,names))
                candidates(end+1,1) = ...
                    string(candidate); %#ok<AGROW>
            end

        catch
            % Continue past unreadable MAT-files.
        end
    end

    filePath = selectCandidate( ...
        candidates,description);

end


function filePath = selectCandidate(candidates,description)
%SELECTCANDIDATE Return one unambiguous file candidate.

    if isempty(candidates)

        error('EV6Init:FileNotFound', ...
            ['No %s was found under the project folder.\n' ...
             'Copy the required MAT-file into the project, ' ...
             'or run the original project initialization ' ...
             'script that creates it.'], ...
            description);
    end

    if numel(candidates) > 1

        fprintf('Found multiple candidates for %s:\n', ...
            description);

        for k = 1:numel(candidates)
            fprintf('  %d. %s\n', ...
                k,candidates(k));
        end

        error('EV6Init:MultipleFiles', ...
            ['Keep one correct copy under projectRoot, ' ...
             'or call init_EV6_model with a narrower ' ...
             'project folder.']);
    end

    filePath = char(candidates(1));

end


function filePath = chooseNewest(files,messageText)
%CHOOSENEWEST Select the newest file from multiple preferred files.

    [~,newest] = max([files.datenum]);

    filePath = fullfile( ...
        files(newest).folder, ...
        files(newest).name);

    warning('EV6Init:MultiplePreferredFiles', ...
        '%s. Using the newest one:\n%s', ...
        messageText,filePath);

end


function copyStructToBase(values)
%COPYSTRUCTTOBASE Copy every structure field into the base workspace.

    names = fieldnames(values);

    for k = 1:numel(names)
        assignin( ...
            'base', ...
            names{k}, ...
            values.(names{k}));
    end

end


function requireFields(values,requiredNames,sourceFile)
%REQUIREFIELDS Confirm that required fields exist in a structure.

    missing = requiredNames( ...
        ~isfield(values,requiredNames));

    if ~isempty(missing)

        error('EV6Init:MissingLutVariables', ...
            'Missing variable(s) %s in:\n%s', ...
            strjoin(missing,', '), ...
            sourceFile);
    end

end


function validateLutSize( ...
        accelAxis,speedAxis,torqueAxis,tableData,modeName)
%VALIDATELUTSIZE Verify LUT dimensions against breakpoint lengths.

    expected = [ ...
        numel(accelAxis), ...
        numel(speedAxis), ...
        numel(torqueAxis)];

    actual = size(tableData);
    actual(end+1:3) = 1;

    if ~isequal(actual(1:3),expected)

        error('EV6Init:BadLutSize', ...
            ['%s LUT size is [%s], but its breakpoint ' ...
             'lengths require [%s].'], ...
            modeName, ...
            num2str(actual(1:3)), ...
            num2str(expected));
    end

end