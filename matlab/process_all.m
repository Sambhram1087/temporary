function F = process_all(autoLabel)
% Batch: every session CSV in data/raw -> one feature table -> data/processed/features_matlab.csv
% Labels come from data/raw/labels.csv (create it with set_labels()).
if nargin < 1, autoLabel = true; end
cfg = config();
if ~isfolder(cfg.rawDir), error("Raw folder not found: %s", cfg.rawDir); end
files = dir(fullfile(cfg.rawDir, "*.csv"));
% Only session files: session_YYYYMMDD_HHMMSS.csv (label from labels.csv) or legacy YYYYMMDD_HHMMSS_label.csv.
files = files(~cellfun(@isempty, regexp({files.name}, '^(session_)?\d{8}_\d{6}(_[A-Za-z0-9-]+)?\.csv$', 'once')));
if isempty(files), error("No session CSVs in %s (run fetch_sessions first).", cfg.rawDir); end
F = table();  unlabelled = strings(0,1);
for k = 1:numel(files)
    try
        S = load_session(fullfile(files(k).folder, files(k).name), cfg);
        fprintf("%-30s label=%-10s fs=%.2f Hz  maxGap=%.1f ms  jitter=%.2f ms  sat=%.4f\n", files(k).name, S.label, ...
                S.fs, 1e3*S.maxGap, 1e3*S.jitter, S.satFrac);
        if S.maxGap > 3/S.fs, warning("Gaps in %s: check serial rate / I2C", files(k).name); end
        if S.label == "unlabelled", unlabelled(end+1,1) = string(files(k).name); end %#ok<AGROW>
        F = [F; extract_features(S, cfg)]; %#ok<AGROW>
    catch ME
        warning("Skipping %s: %s", files(k).name, ME.message);
    end
end
if isempty(F), error("All %d session(s) failed; no features produced.", numel(files)); end
if ~exist(cfg.procDir,"dir"), mkdir(cfg.procDir); end
writetable(F, fullfile(cfg.procDir, "features_matlab.csv"));
fprintf("%d windows from %d sessions saved.\n", height(F), numel(unique(F.session)));
if ~isempty(unlabelled) && autoLabel && usejava('desktop')
    r = lower(strtrim(input(sprintf('%d session(s) have no label. Label them now? [y/n]: ', numel(unlabelled)), 's')));
    if startsWith(r, "y")
        set_labels();                 % writes data/raw/labels.csv
        F = process_all(false);       % rerun with labels (no second prompt)
        return
    end
end
if ~isempty(unlabelled)
    warning("%d session(s) unlabelled (labels file %s: %s). Run set_labels() and then process_all() again.", ...
            numel(unlabelled), cfg.labelFile, ternary(isfile(cfg.labelFile), "present but no match/blank", "NOT FOUND"));
end
end

function out = ternary(c, a, b)
if c, out = a; else, out = b; end
end
