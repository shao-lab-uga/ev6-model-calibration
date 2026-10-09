%% INSPECT EV6 BATTERY/POWERTRAIN CONNECTIONS
% Read-only diagnostic. No model parameters are changed.

model = 'EV6_LUT_FourWheel_EV6Battery77p4kWh';

load_system(model);

allBlocks = find_system(model, ...
    'LookUnderMasks','all', ...
    'FollowLinks','on', ...
    'Type','Block');

batteryBlocks = strings(0,1);

%% Locate the datasheet battery block

for k = 1:numel(allBlocks)

    block = allBlocks{k};

    referenceBlock = "";
    maskType = "";

    try
        referenceBlock = string(get_param(block,'ReferenceBlock'));
    catch
    end

    try
        maskType = string(get_param(block,'MaskType'));
    catch
    end

    description = lower( ...
        string(block) + " " + referenceBlock + " " + maskType);

    if contains(description,"datasheetbattery") || ...
       contains(description,"datasheet battery")

        batteryBlocks(end+1,1) = string(block);
    end
end

batteryBlocks = unique(batteryBlocks);

fprintf('\n===== DATASHEET BATTERY BLOCKS =====\n');

if isempty(batteryBlocks)
    fprintf('No datasheet battery block was automatically found.\n');
else
    for k = 1:numel(batteryBlocks)
        fprintf('%d. %s\n',k,batteryBlocks(k));
    end
end

%% Trace battery input and output connections

fprintf('\n===== BATTERY CONNECTIONS =====\n');

for k = 1:numel(batteryBlocks)

    batteryBlock = char(batteryBlocks(k));

    fprintf('\nBATTERY BLOCK:\n%s\n',batteryBlock);

    portHandles = get_param(batteryBlock,'PortHandles');

    for j = 1:numel(portHandles.Inport)

        lineHandle = get_param(portHandles.Inport(j),'Line');

        fprintf('\n  Input port %d:\n',j);

        if lineHandle == -1
            fprintf('    Not connected\n');
            continue
        end

        sourceHandle = get_param(lineHandle,'SrcBlockHandle');

        if sourceHandle ~= -1
            fprintf('    Source = %s\n',getfullname(sourceHandle));
            fprintf('    Type   = %s\n', ...
                get_param(sourceHandle,'BlockType'));
        end
    end

    for j = 1:numel(portHandles.Outport)

        lineHandle = get_param(portHandles.Outport(j),'Line');

        fprintf('\n  Output port %d:\n',j);

        if lineHandle == -1
            fprintf('    Not connected\n');
            continue
        end

        destinationHandles = ...
            get_param(lineHandle,'DstBlockHandle');

        destinationHandles = destinationHandles( ...
            destinationHandles ~= -1);

        for n = 1:numel(destinationHandles)
            fprintf('    Destination = %s\n', ...
                getfullname(destinationHandles(n)));
            fprintf('    Type        = %s\n', ...
                get_param(destinationHandles(n),'BlockType'));
        end
    end
end

%% Search near the battery for relevant electrical blocks

fprintf('\n===== NEARBY ELECTRICAL BLOCKS =====\n');

searchWords = [ ...
    "power","current","motor","inverter", ...
    "battery","batt","dc"];

for k = 1:numel(batteryBlocks)

    batteryBlock = char(batteryBlocks(k));
    searchScope = get_param(batteryBlock,'Parent');

    nearbyBlocks = find_system(searchScope, ...
        'LookUnderMasks','all', ...
        'FollowLinks','on', ...
        'SearchDepth',2, ...
        'Type','Block');

    fprintf('\nSearch scope:\n%s\n',searchScope);

    for j = 1:numel(nearbyBlocks)

        block = nearbyBlocks{j};
        referenceBlock = "";
        maskType = "";

        try
            referenceBlock = string( ...
                get_param(block,'ReferenceBlock'));
        catch
        end

        try
            maskType = string(get_param(block,'MaskType'));
        catch
        end

        description = lower( ...
            string(block) + " " + ...
            referenceBlock + " " + maskType);

        if any(contains(description,searchWords))
            fprintf('  %s\n',block);

            if strlength(referenceBlock) > 0
                fprintf('    Reference: %s\n',referenceBlock);
            end

            if strlength(maskType) > 0
                fprintf('    Mask type: %s\n',maskType);
            end
        end
    end
end

fprintf('\n====================================\n');
fprintf('Inspection complete.\n');
fprintf('No model parameters were changed.\n');
fprintf('====================================\n');