function files = fetch_sessions(baseUrl)
% FETCH_SESSIONS
% Downloads real-hardware recordings from the FastAPI backend,
% asks the user to label each recording, and saves converted CSV files
% inside data/raw.
%
% Simulated recordings are rejected.
% Already imported recordings are skipped.

    if nargin < 1 || isempty(baseUrl)
        baseUrl = 'http://127.0.0.1:8000';
    end

    cfg = config();

    % Create raw data directory if it does not exist
    if ~exist(cfg.rawDir, 'dir')
        mkdir(cfg.rawDir);
    end

    files = strings(0, 1);

    %% 1. Connect to backend
    try
        opts = weboptions('Timeout', 30);
        apiUrl = [char(baseUrl) '/api/recordings'];

        items = webread(apiUrl, opts);

    catch ME
        error(['Could not connect to backend at %s.\n' ...
               'Make sure FastAPI is running without --simulate.\n' ...
               'Error: %s'], char(baseUrl), ME.message);
    end

    %% 2. Check available recordings
    if isempty(items)
        fprintf('\nNo recordings are available on the backend yet.\n');
        fprintf('Start a recording from the dashboard and try again.\n');
        return;
    end

    fprintf('\nFound %d recording(s).\n', numel(items));

    %% 3. Process each recording
    for k = 1:numel(items)

        % Validate recording name
        if ~isfield(items(k), 'name') || isempty(items(k).name)
            warning('Recording %d has no valid name. Skipping.', k);
            continue;
        end

        name = string(items(k).name);
        nameChar = char(name);

        fprintf('\nProcessing recording: %s\n', nameChar);

        % Reject simulated recordings
        if endsWith(name, '_sim.jsonl', 'IgnoreCase', true) || ...
           contains(name, '_sim.', 'IgnoreCase', true)

            fprintf('Skipping simulated recording: %s\n', nameChar);
            continue;
        end

        %% 4. Check whether already imported
        [~, stem] = fileparts(nameChar);

        marker = fullfile(cfg.rawDir, ...
                          ['source_' stem '.txt']);

        if isfile(marker)
            fprintf('Already imported. Skipping: %s\n', nameChar);
            continue;
        end

        %% 5. Ask user to label recording
        prompt = sprintf( ...
            'Enter label for %s (rest, tremor, voluntary):', ...
            nameChar);

        answer = inputdlg( ...
            {prompt}, ...
            'Label Recording', ...
            [1 70], ...
            {'rest'});

        if isempty(answer)
            fprintf('Import cancelled for: %s\n', nameChar);
            continue;
        end

        label = lower(strtrim(answer{1}));

        allowedLabels = ["rest", "tremor", "voluntary"];

        if ~any(strcmpi(label, allowedLabels))
            warning(['Invalid label "%s". ' ...
                     'Allowed labels: rest, tremor, voluntary.'], ...
                     label);
            continue;
        end

        %% 6. Download recording as CSV
        url = [char(baseUrl) ...
               '/api/recordings/' char(name) '?format=csv'];

        tempFile = [tempname(cfg.rawDir) '.csv'];

        try
            fprintf('Downloading recording...\n');

            websave(tempFile, url, opts);

            if ~isfile(tempFile)
                error('Downloaded CSV file was not created.');
            end

            info = dir(tempFile);

            if info.bytes == 0
                error('Downloaded CSV file is empty.');
            end

            %% 7. Convert backend CSV into MATLAB format
            out = convert_recording( ...
                tempFile, ...
                char(label), ...
                cfg.rawDir);

            %% 8. Delete temporary file
            if isfile(tempFile)
                delete(tempFile);
            end

            %% 9. Save import marker only after successful conversion
            fid = fopen(marker, 'w');

            if fid == -1
                warning('Could not create import marker for %s.', nameChar);
            else
                fprintf(fid, '%s\n', char(out));
                fclose(fid);
            end

            files(end + 1, 1) = string(out); %#ok<AGROW>

            fprintf('Successfully imported: %s\n', char(out));

        catch ME

            % Clean up temporary download
            if isfile(tempFile)
                delete(tempFile);
            end

            warning('Failed to import %s: %s', ...
                    nameChar, ME.message);
        end
    end

    %% 10. Final summary
    fprintf('\n====================================\n');
    fprintf('RECORDING IMPORT SUMMARY\n');
    fprintf('====================================\n');
    fprintf('Successfully imported: %d\n', numel(files));
    fprintf('Raw data directory: %s\n', cfg.rawDir);
    fprintf('====================================\n');

    if isempty(files)
        fprintf(['No new recordings were imported.\n' ...
                 'Check whether recordings exist on the backend ' ...
                 'and whether they were already imported.\n']);
    end

end