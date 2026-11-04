function S = load_session(file, cfg)
% Reads one session CSV. Accepts either
%   (a) count format:  seq,t_us,ax,ay,az,gx,gy,gz
%   (b) backend export: t_ms,ax_g,ay_g,az_g,gx_dps,gy_dps,gz_dps[,simulated]
% Label comes from cfg.labelFile (columns session,label), else from a legacy
% YYYYMMDD_HHMMSS_label.csv file name, else "unlabelled".
T  = readtable(file);
vn = T.Properties.VariableNames;
if all(ismember({'t_us','ax','ay','az','gx','gy','gz'}, vn))
    t  = T.t_us;
    t  = t + [0; cumsum(diff(t) < 0)] * 2^32;        % unwrap 32-bit microsecond counter
    t  = (t - t(1)) / 1e6;
    acc = [T.ax T.ay T.az] / cfg.accScale;           % g
    gyr = [T.gx T.gy T.gz] / cfg.gyrScale;           % deg/s
    satFrac = mean(abs([T.ax T.ay T.az T.gx T.gy T.gz]) >= 32767, 'all');
elseif all(ismember({'t_ms','ax_g','ay_g','az_g','gx_dps','gy_dps','gz_dps'}, vn))
    if ismember('simulated', vn)
        sim = T.simulated;
        if islogical(sim) || isnumeric(sim), isSim = any(sim ~= 0);
        else, isSim = any(ismember(lower(string(sim)), ["true","1","yes"])); end
        if isSim, error('Simulated recording cannot be used.'); end
    end
    t  = (T.t_ms - T.t_ms(1)) / 1e3;
    acc = [T.ax_g T.ay_g T.az_g];
    gyr = [T.gx_dps T.gy_dps T.gz_dps];
    satFrac = mean([abs(acc)*cfg.accScale, abs(gyr)*cfg.gyrScale] >= 32767, 'all');
else
    error('Unrecognised columns: %s', strjoin(vn, ','));
end
dt = diff(t);
S.t = t;  S.fs = 1/median(dt);  S.maxGap = max(dt);  S.jitter = std(dt);
S.acc = acc;  S.gyr = gyr;  S.satFrac = satFrac;
[~, name] = fileparts(file);
S.session = string(name);
S.label   = lookup_label(S.session, cfg);
end

function lab = lookup_label(session, cfg)
% Label for one session from labels.csv (columns session,label). Parsed as plain text on purpose:
% readtable can mistake an all-text CSV's header row for data. Tolerates BOM, CRLF, quotes, ; or tab delimiters.
lab = "unlabelled";
if isfile(cfg.labelFile)
    txt  = erase(string(fileread(cfg.labelFile)), string(char(65279)));
    rows = splitlines(txt);
    for r = numel(rows):-1:1                                   % last matching entry wins
        parts = strip(split(strip(rows(r)), [",", ";", string(char(9))]));
        if numel(parts) >= 2
            nm = erase(strip(parts(1), '"'), ".csv");
            if nm == session
                v = lower(strip(parts(2), '"'));
                if strlength(v) > 0, lab = v; return; end
            end
        end
    end
end
tok = regexp(char(session), '^\d{8}_\d{6}_([A-Za-z0-9-]+)$', 'tokens', 'once');   % legacy name
if ~isempty(tok), lab = lower(string(tok{1})); end
end
