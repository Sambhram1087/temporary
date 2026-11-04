function F = extract_features(S, cfg)
% One row per window. Mirrors ml/features.py.
fs = S.fs;
am = vecnorm(S.acc,2,2);  am = am - mean(am);       % orientation-independent
gm = vecnorm(S.gyr,2,2);  gm = gm - mean(gm);
[bb,aa] = butter(4, cfg.band/(fs/2), "bandpass");
ya = filtfilt(bb,aa,am);  yg = filtfilt(bb,aa,gm);
N = round(cfg.winSec*fs);  H = round(cfg.hopSec*fs);
if numel(ya) < N, error("%s: shorter than the %g s window", S.session, cfg.winSec); end
assert(N <= cfg.nfft, "Window (%d samples) > nfft (%d): periodogram would wrap. Raise cfg.nfft.", N, cfg.nfft);
bp = @(P,f,b) sum(P(f>=b(1) & f<=b(2))) * (f(2)-f(1));
rows = [];  tt = [];
for i = 1:H:numel(ya)-N+1
    idx = i:i+N-1;
    [P,f]  = periodogram(ya(idx), hann(N), cfg.nfft, fs);
    [Pr,~] = periodogram(am(idx), hann(N), cfg.nfft, fs);   % unfiltered, for low-band energy
    m = f>=cfg.band(1) & f<=cfg.band(2);  fm = f(m);  [~,k] = max(P(m));
    b46 = bp(P,f,cfg.tremBand);  b312 = bp(P,f,cfg.band);
    rows(end+1,:) = [fm(k), b46, b312, bp(Pr,f,cfg.lowBand), rms(ya(idx)), ...
                     peak2peak(ya(idx)), rms(yg(idx)), b46/max(b312,eps)]; %#ok<AGROW>
    tt(end+1,1) = S.t(i); %#ok<AGROW>
end
F = array2table(rows, "VariableNames", cellstr(cfg.features));
F.t = tt;  F.label = repmat(S.label, height(F), 1);  F.session = repmat(S.session, height(F), 1);
F = movevars(F, "t", "Before", 1);
end
