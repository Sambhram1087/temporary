% Typical workflow (run from the matlab/ folder):
set_labels();                  % once per new session: writes data/raw/labels.csv
F  = process_all();            % raw CSVs -> features_matlab.csv + QA printout
th = derive_thresholds("tremor");   % thresholds.json / thresholds.h
mdl = train_classifier();      % grouped CV + tree_model.h
% analyse_session(fullfile(config().rawDir, "<some_session>.csv"));
