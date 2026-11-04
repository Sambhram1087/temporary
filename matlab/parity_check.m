function report = parity_check()
% Compare MATLAB and Python feature extraction on the same real labelled CSV files.
% Requires Python packages numpy, scipy and pandas (ml/requirements.txt).
cfg = config();
rawFiles = dir(fullfile(cfg.rawDir,'*.csv'));
if isempty(rawFiles), error('No recordings found in %s. Run fetch_sessions first.', cfg.rawDir); end
pyOut = fullfile(cfg.procDir,'features_py_parity.csv');
if ~exist(cfg.procDir,'dir'), mkdir(cfg.procDir); end
root = fileparts(fileparts(mfilename('fullpath')));
script = fullfile(root,'ml','features.py');
cmd = sprintf('python "%s" "%s" "%s"', script, cfg.rawDir, pyOut);
[status, msg] = system(cmd);
if status ~= 0, error('Python feature extraction failed. Check Python and ml/requirements.txt.\n%s', msg); end
Fmat = process_all(false); %#ok<NASGU>
Fm = readtable(fullfile(cfg.procDir,'features_matlab.csv'));
Fp = readtable(pyOut);
vars = cellstr(cfg.features);
if height(Fm) ~= height(Fp), error('Feature row counts differ (MATLAB %d, Python %d).',height(Fm),height(Fp)); end
for k = 1:numel(vars)
    a = Fm.(vars{k}); b = Fp.(vars{k});
    scale = max(abs(a),[],'omitnan');
    if isempty(scale) || ~isfinite(scale) || scale == 0, scale = 1; end
    rel = abs(a-b) ./ max(abs(a), 1e-6*scale);
    report.(vars{k}) = struct('maxAbs',max(abs(a-b),[],'omitnan'), ...
        'maxRelative',max(rel,[],'omitnan'), 'maxRelativePercent',100*max(rel,[],'omitnan'));
    fprintf('%-10s max abs=%g, max relative=%g%%\n', vars{k}, report.(vars{k}).maxAbs, report.(vars{k}).maxRelativePercent);
end
fprintf(['NOTE: This compares the repository''s current MATLAB and Python feature implementations. ' ...
         'A mismatch is expected to be investigated, not hidden by a tolerance.\n']);
end
