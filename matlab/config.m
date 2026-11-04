function cfg = config()
% Single place for every constant. Keep in sync with firmware and ml/features.py.
cfg.accScale   = 8192;          % LSB per g   (MPU6050 +-4 g)
cfg.gyrScale   = 65.5;          % LSB per deg/s (+-500 dps)
cfg.band       = [3 12];        % analysis band, Hz (review against literature + your data)
cfg.tremBand   = [4 6];         % narrow band often reported for PD rest tremor (verify)
cfg.lowBand    = [0.5 2];       % voluntary-movement / walking energy, unfiltered signal
cfg.winSec     = 4;             % window length, s
cfg.hopSec     = 1;             % hop, s
cfg.nfft       = 512;
cfg.features   = ["domfreq","bp_4_6","bp_3_12","bp_low","rms_acc","p2p_acc","rms_gyr","conc"];
root           = fileparts(fileparts(mfilename('fullpath')));
cfg.rawDir     = fullfile(root,"data","raw");
cfg.procDir    = fullfile(root,"data","processed");
cfg.labelFile  = fullfile(cfg.rawDir,"labels.csv");   % columns: session,label (e.g. session_20261104_022139)
cfg.modelDir   = fullfile(root,"models");
cfg.firmwareDir= fullfile(root,"firmware_snippets");
end
