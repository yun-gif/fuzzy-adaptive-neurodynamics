function work = run_reproduction(mode)
%RUN_REPRODUCTION Work on an isolated copy, leaving archived results unchanged.
% Modes: verify (default), figures, or rerun.
    if nargin < 1, mode = "verify"; end
    mode = string(mode);
    assert(ismember(mode, ["verify", "figures", "rerun"]), 'Unknown mode.');
    root = fileparts(mfilename('fullpath'));
    output = fullfile(root, 'runs');
    if ~isfolder(output), mkdir(output); end
    work = tempname(output);
    mkdir(work);
    copyfile(fullfile(root, 'matlab', '*.m'), work);
    copyfile(fullfile(root, 'matlab', 'results'), fullfile(work, 'results'));
    old_dir = pwd;
    old_path = path;
    old_visibility = get(groot, 'defaultFigureVisible');
    cleanup = onCleanup(@() restore_session(old_dir, old_path, old_visibility)); %#ok<NASGU>
    cd(work);
    addpath(work);
    set(groot, 'defaultFigureVisible', 'off');
    test_tfs_steady_rmse();
    files = {'summary_metrics','mechanism_ablation_metrics','tdoa_metrics','vehicle_metrics'};
    original = cellfun(@(n) readtable(fullfile('results', [n '.csv']), ...
        'TextType','string'), files, 'UniformOutput',false);
    if mode == "rerun"
        run_tfs_numerical_metrics();
        run_tfs_mechanism_ablation();
        run_tfs_tdoa_metrics();
        run_tfs_vehicle_metrics();
    end
    recompute_tfs_metrics([1 2 4 5]);
    max_absolute_difference = zeros(1,numel(files));
    exact_numeric_match = true(1,numel(files));
    for i = 1:numel(files)
        actual = readtable(fullfile('results',[files{i} '.csv']),'TextType','string');
        expected = original{i};
        assert(isequal(actual.Properties.VariableNames, expected.Properties.VariableNames));
        assert(height(actual)==height(expected));
        for column = string(expected.Properties.VariableNames)
            a = actual.(column); b = expected.(column);
            if isnumeric(b)
                assert(isequal(isnan(a),isnan(b)) && isequal(isinf(a),isinf(b)));
                finite = isfinite(a) & isfinite(b);
                delta = abs(a(finite)-b(finite));
                max_absolute_difference(i) = max([max_absolute_difference(i);delta(:)]);
                exact_numeric_match(i) = exact_numeric_match(i) && isequaln(a,b);
                assert(all(delta <= 1e-11 + 1e-9*abs(b(finite))), ...
                    'Metric mismatch: %s / %s', files{i}, column);
            else
                assert(isequaln(a,b),'Metadata mismatch: %s / %s',files{i},column);
            end
        end
    end
    if mode == "figures" || mode == "rerun"
        plot_tfs_fuzzy_figures();
        plot_tfs_embedding_validation("all");
        close all;
        assert(numel(dir(fullfile('results','figures','*.pdf'))) == 13);
    end
    report.mode = mode;
    report.matlab_version = version;
    report.platform = computer;
    report.metric_files = files;
    report.max_absolute_difference = max_absolute_difference;
    report.exact_numeric_match = exact_numeric_match;
    report.comparison_tolerance = 'absolute 1e-11 plus relative 1e-9; exact match reported separately';
    report.unit_tests_passed = 10;
    report.full_experiments_rerun = mode == "rerun";
    report.figure_panels_regenerated = mode == "figures" || mode == "rerun";
    fid = fopen('validation_report.json','w');
    closer = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));
    fprintf('PASS: %s. Outputs: %s\n',mode,work);
end

function restore_session(folder, old_path, visibility)
    cd(folder);
    path(old_path);
    set(groot,'defaultFigureVisible',visibility);
end
