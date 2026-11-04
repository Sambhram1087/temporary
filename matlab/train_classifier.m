
function mdl = train_classifier()
    % Session-grouped cross-validation using a shallow decision tree.
    % Train the final model and export it to C++.

    %% 1. Load configuration and feature dataset
    cfg = config();

    F = readtable(fullfile(cfg.procDir, "features_matlab.csv"));
    F = F(string(F.label) ~= "unlabelled", :);
    if isempty(F), error("No labelled windows. Run set_labels(), then process_all(). (labels file: %s, exists: %d)", cfg.labelFile, isfile(cfg.labelFile)); end

    X = F{:, cellstr(cfg.features)};
    y = categorical(string(F.label));
    g = string(F.session);

    %% 2. Validate session data
    sess = unique(g);

    assert(numel(sess) >= 3, ...
        "Need at least 3 sessions for grouped CV (have %d).", ...
        numel(sess));
    assert(numel(categories(y)) >= 2, ...
        "Need at least 2 different labels (found: %s).", ...
        strjoin(string(categories(y)), ", "));
    if numel(sess) < 5
        warning("Only %d sessions: grouped CV results are unreliable. Record more sessions.", numel(sess));
    end

    %% 3. Session-grouped cross-validation
    cv = cvpartition(numel(sess), ...
        "KFold", min(5, numel(sess)));

    pred = y;

    for k = 1:cv.NumTestSets

        % Identify training and testing sessions
        te = ismember(g, sess(test(cv, k)));

        % Train decision tree using training sessions
        m = fitctree(X(~te, :), y(~te), ...
            "MaxNumSplits", 15, ...
            "PredictorNames", cellstr(cfg.features));

        % Predict labels for unseen sessions
        pred(te) = predict(m, X(te, :));

    end

    %% 4. Display confusion matrix
    figure;

    confusionchart(y, pred);
    title("Session-Grouped CV (Decision Tree)");

    %% 5. Calculate classification accuracy
    accuracy = mean(pred == y);

    fprintf("Window Accuracy: %.3f\n", accuracy);

    %% 6. Train final model using the complete dataset
    mdl = fitctree(X, y, ...
        "MaxNumSplits", 15, ...
        "PredictorNames", cellstr(cfg.features));

    %% 7. Create model directory if it does not exist
    if ~exist(cfg.modelDir, "dir")
        mkdir(cfg.modelDir);
    end

    %% 8. Save trained MATLAB model
    save(fullfile(cfg.modelDir, "tree.mat"), "mdl");

    %% 9. Export decision tree to C++ header file
    export_tree_cpp(mdl, ...
        fullfile(cfg.modelDir, "tree_model.h"));

    %% 10. Export model specification
    export_spec(mdl);

    %% 11. Generate confusion matrix and classification metrics
    cm = confusionmat(y, pred);

    tp = diag(cm);

    P = tp ./ sum(cm, 1)';
    R = tp ./ sum(cm, 2);

    F1 = 2 .* P .* R ./ (P + R);

    %% 12. Store evaluation metrics
    metrics = struct( ...
        'accuracy', accuracy, ...
        'precision', mean(P, 'omitnan'), ...
        'recall', mean(R, 'omitnan'), ...
        'f1', mean(F1, 'omitnan'), ...
        'sessions', numel(sess));

    metrics.classes = cellstr(categories(y));

    %% 13. Export metrics as JSON
    fid = fopen(fullfile(cfg.modelDir, "metrics.json"), "w");

    if fid == -1
        error("Could not create metrics.json.");
    end

    fprintf(fid, "%s", jsonencode(metrics, "PrettyPrint", true));

    fclose(fid);

    %% 14. Display completion message
    fprintf("\nModel training completed successfully!\n");
    fprintf("Accuracy: %.3f\n", accuracy);
    fprintf("Number of sessions: %d\n", numel(sess));
    fprintf("Model saved to: %s\n", cfg.modelDir);

end
