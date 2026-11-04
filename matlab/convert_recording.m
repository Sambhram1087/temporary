function outFile = convert_recording(inFile, label, outDir)
% Convert a real backend CSV export to the count-based format (session_YYYYMMDD_HHMMSS.csv + labels.csv entry).
% Input columns: t_ms,ax_g,ay_g,az_g,gx_dps,gy_dps,gz_dps,simulated
% Output columns: seq,t_us,ax,ay,az,gx,gy,gz
% Simulated recordings are deliberately rejected.
if nargin < 2 || strlength(string(label)) == 0
    error('A non-empty session label is required (for example: rest, tremor, voluntary).');
end
if nargin < 3 || isempty(outDir)
    cfg = config(); outDir = cfg.rawDir;
end
T = readtable(inFile);
required = {'t_ms','ax_g','ay_g','az_g','gx_dps','gy_dps','gz_dps'};
if ~all(ismember(required, T.Properties.VariableNames))
    error('CSV does not have the expected backend export columns.');
end
if ismember('simulated', T.Properties.VariableNames)
    sim = T.simulated;
    if islogical(sim) || isnumeric(sim)
        isSim = any(sim ~= 0);
    else
        isSim = any(ismember(lower(string(sim)), ["true","1","yes"]));
    end
    if isSim, error('Simulated data cannot be converted for training.'); end
end
if height(T) < 10, error('Recording is too short.'); end
if (T.t_ms(end) - T.t_ms(1)) < 1000*config().winSec
    error('Recording shorter than the %g s analysis window.', config().winSec);
end
if any(~isfinite(T{:, required}), 'all'), error('Recording contains NaN or Inf values.'); end
if any(diff(T.t_ms) <= 0), error('Timestamps must be strictly increasing.'); end
if ~exist(outDir,'dir'), mkdir(outDir); end
% Label is sanitised, then stored in labels.csv (file name is session_YYYYMMDD_HHMMSS.csv).
label = regexprep(char(string(label)), '[^A-Za-z0-9-]', '-');
if isempty(label), error('Label must contain letters or numbers.'); end
t0 = datetime('now');
while true
    stamp = char(datetime(t0,'Format','yyyyMMdd_HHmmss'));
    outFile = fullfile(outDir, sprintf('session_%s.csv', stamp));
    if ~isfile(outFile), break; end
    t0 = t0 + seconds(1);
end
% Backend times are milliseconds from device uptime. Convert to microseconds.
t_us = round((T.t_ms - T.t_ms(1)) * 1000);
% Reconstruct raw MPU6050 counts using the ranges configured in firmware (+/-4g, +/-500dps).
ax = round(T.ax_g * 8192); ay = round(T.ay_g * 8192); az = round(T.az_g * 8192);
gx = round(T.gx_dps * 65.5); gy = round(T.gy_dps * 65.5); gz = round(T.gz_dps * 65.5);
seq = (0:height(T)-1)';
U = table(seq, t_us, ax, ay, az, gx, gy, gz);
writetable(U, outFile);
% Register the label (file names carry no label): <outDir>/labels.csv with columns session,label
labFile = fullfile(outDir, 'labels.csv');
newFile = ~isfile(labFile);
fid = fopen(labFile, 'a');
if fid < 0, error('Cannot write %s', labFile); end
if newFile, fprintf(fid, 'session,label\n'); end
[~, sessName] = fileparts(outFile);
fprintf(fid, '%s,%s\n', sessName, label);
fclose(fid);
fprintf('Converted real recording to %s\n', outFile);
end
