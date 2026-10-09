function [signalTime,signalData,matchedName] = ...
    getBatteryCurrentSignal(runID)
%GETBATTERYCURRENTSIGNAL Extract battery current from an SDI run.

runObject = Simulink.sdi.getRun(runID);
signalIDs = getAllSignalIDs(runObject);

preferredNames = [ ...
    "SimMonitor.Veh.Batt.BattCurr"
    "<BattCurr>"
    "BattCurr"];

bestSamples = -1;
signalTime = [];
signalData = [];
matchedName = "";

%% Search exact preferred names

for preferredIndex = 1:numel(preferredNames)

    for signalIndex = 1:numel(signalIDs)

        signalObject = ...
            Simulink.sdi.getSignal(signalIDs(signalIndex));

        if string(signalObject.Name) ~= ...
                preferredNames(preferredIndex)
            continue
        end

        values = signalObject.Values;

        currentTime = double(values.Time(:));
        currentData = double(values.Data);

        if size(currentData,2) > 1
            currentData = currentData(:,1);
        end

        currentData = currentData(:);

        if numel(currentData) > bestSamples
            bestSamples = numel(currentData);
            signalTime = currentTime;
            signalData = currentData;
            matchedName = string(signalObject.Name);
        end
    end

    if bestSamples > 0
        break
    end
end

%% Fallback search

if bestSamples < 0

    for signalIndex = 1:numel(signalIDs)

        signalObject = ...
            Simulink.sdi.getSignal(signalIDs(signalIndex));

        currentName = lower(string(signalObject.Name));

        if ~contains(currentName,"battcurr")
            continue
        end

        values = signalObject.Values;

        currentTime = double(values.Time(:));
        currentData = double(values.Data);

        if size(currentData,2) > 1
            currentData = currentData(:,1);
        end

        currentData = currentData(:);

        if numel(currentData) > bestSamples
            bestSamples = numel(currentData);
            signalTime = currentTime;
            signalData = currentData;
            matchedName = string(signalObject.Name);
        end
    end
end

assert(bestSamples > 0, ...
    'No battery-current signal was found in SDI run %s.', ...
    string(runObject.Name));

validSignal = ...
    isfinite(signalTime) & isfinite(signalData);

signalTime = signalTime(validSignal);
signalData = signalData(validSignal);

[signalTime,uniqueIndices] = ...
    unique(signalTime,'stable');

signalData = signalData(uniqueIndices);

end