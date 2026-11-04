function set_labels(labels)
% Assign a label (rest / tremor / voluntary) to every session_YYYYMMDD_HHMMSS.csv in data/raw
% and write data/raw/labels.csv. Prompts in the Command Window (no dialog boxes).
%   set_labels()                                         % asks for each session
%   set_labels(["rest","tremor","tremor","voluntary"])   % or give all labels in sorted session order
cfg  = config();
opts = ["rest","tremor","voluntary"];
files = dir(fullfile(cfg.rawDir, "session_*.csv"));
if isempty(files), error("No session_*.csv files in %s", cfg.rawDir); end
names = sort(string(erase({files.name}, ".csv")));
names = names(~cellfun(@isempty, regexp(cellstr(names), '^session_\d{8}_\d{6}$', 'once')));
names = names(:);
if isempty(names), error("No files named session_YYYYMMDD_HHMMSS.csv in %s", cfg.rawDir); end

if nargin >= 1
    labels = lower(string(labels(:)));
    if numel(labels) ~= numel(names)
        error("Got %d labels for %d sessions:\n%s", numel(labels), numel(names), strjoin(names, newline));
    end
else
    labels = strings(numel(names), 1);
    fprintf("Label each session:  1 = rest   2 = tremor   3 = voluntary\n");
    for k = 1:numel(names)
        while true
            r = lower(strtrim(string(input(sprintf("  %s : ", names(k)), "s"))));
            n = str2double(r);
            if ~isnan(n) && any(n == 1:3)
                labels(k) = opts(n);  break
            elseif any(r == opts)
                labels(k) = r;  break
            end
            fprintf("  Enter 1, 2, 3, rest, tremor or voluntary.\n");
        end
    end
end
bad = ~ismember(labels, opts);
if any(bad), error("Invalid label(s): %s. Allowed: %s", strjoin(labels(bad), ", "), strjoin(opts, ", ")); end

T = table(names, labels, 'VariableNames', {'session','label'});
writetable(T, cfg.labelFile);
fprintf("Wrote %s\n", cfg.labelFile);
disp(T);
end
