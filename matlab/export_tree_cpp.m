function export_tree_cpp(mdl, outFile)
% Writes the trained tree as plain C++ if/else. Feature order = cfg.features. Returns class index.
fid = fopen(outFile, "w");
fprintf(fid, "// auto-generated. feature order: %s\n", strjoin(string(mdl.PredictorNames), ", "));
fprintf(fid, "// classes: %s\n", strjoin(string(mdl.ClassNames), ", "));
fprintf(fid, "inline int predict_tree(const float* x) {\n");
emit(1, 1);
fprintf(fid, "}\n");  fclose(fid);
    function emit(node, ind)
        pad = blanks(2*ind);
        if mdl.IsBranchNode(node)
            idx = find(strcmp(mdl.PredictorNames, mdl.CutPredictor{node}));
            fprintf(fid, "%sif (x[%d] < %.7gf) {\n", pad, idx-1, mdl.CutPoint(node));
            emit(mdl.Children(node,1), ind+1);
            fprintf(fid, "%s} else {\n", pad);
            emit(mdl.Children(node,2), ind+1);
            fprintf(fid, "%s}\n", pad);
        else
            cls = find(string(mdl.ClassNames) == string(mdl.NodeClass{node}));
            fprintf(fid, "%sreturn %d;  // %s\n", pad, cls-1, string(mdl.NodeClass{node}));
        end
    end
end
