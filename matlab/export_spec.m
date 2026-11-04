function spec = export_spec(mdl, outFile)
% Export a MATLAB ClassificationTree into a JSON contract for backend/ml_online.py.
% The feature order is fixed by config.m. This exports the current repository's
% magnitude-based, 3-12 Hz feature pipeline; it does not alter ESP32 firmware.
if nargin < 1 || isempty(mdl)
    cfg = config(); p = fullfile(cfg.modelDir,'tree.mat');
    if ~isfile(p), error('No trained model at %s. Run train_classifier first.',p); end
    q = load(p,'mdl'); mdl = q.mdl;
end
cfg = config();
if nargin < 2 || isempty(outFile), outFile = fullfile(cfg.modelDir,'spec.json'); end
if ~exist(cfg.modelDir,'dir'), mkdir(cfg.modelDir); end
expected = cellstr(cfg.features);
if ~isequal(string(mdl.PredictorNames), string(expected))
    error('Model predictor order does not match config.features. Retrain with the current feature order.');
end
[z,p,k] = butter(4, cfg.band/(100/2), 'bandpass');
[sos,g] = zp2sos(z,p,k); sos(1,1:3) = sos(1,1:3)*g;
N = numel(mdl.IsBranchNode);
feat = -ones(N,1); cut = zeros(N,1); left = -ones(N,1); right = -ones(N,1); cls = strings(N,1);
for n = 1:N
    if mdl.IsBranchNode(n)
        ix = find(strcmp(mdl.PredictorNames, mdl.CutPredictor{n}),1);
        feat(n) = ix-1; cut(n) = mdl.CutPoint(n);
        left(n) = mdl.Children(n,1)-1; right(n) = mdl.Children(n,2)-1;
    else
        cls(n) = string(mdl.NodeClass{n});
    end
end
spec = struct();
spec.version = ['matlab-' char(datetime('now','Format','yyyyMMdd-HHmmss'))];
spec.source = 'MATLAB fitctree'; spec.fs = 100; spec.band = cfg.band;
spec.win = cfg.winSec; spec.hop = cfg.hopSec; spec.warm = 0;
spec.nfft = cfg.nfft; spec.sos = sos; spec.features = expected;
spec.le = false; % MATLAB branch rule is x < cut.
spec.tree = struct('feat',feat,'cut',cut,'left',left,'right',right,'cls',{cellstr(cls)});
json = jsonencode(spec,'PrettyPrint',true);
fid = fopen(outFile,'w'); if fid < 0, error('Cannot write %s',outFile); end
cleanup = onCleanup(@() fclose(fid)); fwrite(fid,json,'char');
fprintf('Wrote model specification: %s\n',outFile);
end
