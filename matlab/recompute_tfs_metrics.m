function recompute_tfs_metrics(selection)
%RECOMPUTE_TFS_METRICS Refresh tables only; recorded trajectories stay intact.
    out = fullfile(fileparts(mfilename('fullpath')), 'results');
    files = {'tfs_numerical_results', 'mechanism_ablation_results', ...
        'matched_ablation_results', 'tdoa_results', 'vehicle_results'};
    csvs = {'summary_metrics', 'mechanism_ablation_metrics', ...
        'matched_ablation_metrics', 'tdoa_metrics', 'vehicle_metrics'};
    table_names = {'summary', 'ablation', 'ablation', 'rows', 'rows'};
    if nargin < 1, selection = 1:numel(files); end
    for f = selection
        path = fullfile(out, [files{f} '.mat']);
        data = load(path);
        tab = data.(table_names{f});
        records = cell(height(tab), 1);
        for i = 1:height(tab)
            if f == 2
                r = data.results.(matlab.lang.makeValidName(tab.variant(i)));
            elseif f == 5
                r = data.results.(matlab.lang.makeValidName(tab.method(i)));
            else
                r = data.results.(matlab.lang.makeValidName(tab.noise(i))). ...
                    (matlab.lang.makeValidName(tab.method(i)));
            end
            records{i} = r;
        end
        if ismember('noise', tab.Properties.VariableNames)
            groups = string(tab.noise);
        else
            groups = repmat("all", height(tab), 1);
        end
        ends = cellfun(@(r) r.t(end), records);
        for i = 1:height(tab)
            r = records{i};
            T = data.cfg.t_final;
            Tcap = min([T; ends(groups == groups(i))]);
            if f <= 3
                m = compute_validation_metrics(r.t, r.residual_norm, r.error_series, ...
                    data.cfg.tolerance, T, r.tau(end), r.status, Tcap);
                tab.steady_residual_rmse(i) = m.steady_residual_rmse;
                if f == 1, tab.steady_error_rmse(i) = m.steady_error_rmse; end
                info = m.window;
            elseif f == 4
                [tab.steady_residual_rmse(i), info] = tfs_steady_rmse( ...
                    r.t, r.residual_norm, T, r.tau(end), r.status, Tcap);
                tab.steady_position_rmse(i) = tfs_steady_rmse( ...
                    r.t, r.position_error, T, r.tau(end), r.status, Tcap);
            else
                kinds = {'position', 'velocity', 'acceleration'};
                for k = 1:numel(kinds)
                    [value, info] = tfs_steady_rmse(r.t, r.([kinds{k} '_error_norm']), ...
                        T, r.tau(end), r.status, Tcap);
                    tab.(['steady_' kinds{k} '_rmse'])(i) = value;
                end
            end
            tab.steady_window_start(i) = info.window_start;
            tab.steady_window_end(i) = info.window_end;
            tab.nominal_T(i) = T;
            tab.steady_group(i) = groups(i);
            tab.record_end(i) = info.record_end;
            tab.endpoint_hold_seconds(i) = info.endpoint_hold;
            tab.steady_metric_valid(i) = info.valid;
            tab.steady_metric_definition(i) = "PL-error-exact-square-integral;common-record-end;no-extrapolation";
        end
        updated = struct();
        updated.(table_names{f}) = tab;
        save(path, '-struct', 'updated', '-append');
        % Round-trip precision in CSV, independent of display format.
        output = tab;
        for name = string(output.Properties.VariableNames)
            if isa(output.(name), 'double')
                output.(name) = compose('%.17g', output.(name));
            end
        end
        writetable(output, fullfile(out, [csvs{f} '.csv']));
        fprintf('Updated %s (%d rows)\n', csvs{f}, height(tab));
    end
end
