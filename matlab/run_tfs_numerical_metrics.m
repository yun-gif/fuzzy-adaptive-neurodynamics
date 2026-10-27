function run_tfs_numerical_metrics()
%RUN_TFS_NUMERICAL_METRICS Batch metrics for the TFS nonlinear SoNE study.

    cfg.t_final = 10;
    cfg.tau = 0.02;
    cfg.xi = 0.5;
    cfg.beta = 10;
    cfg.alpha = 0.1;
    cfg.delta = 0.1;
    cfg.gamma = 10;
    cfg.x0 = ones(4, 1);
    cfg.tolerance = 1e-3;
    cfg.max_iter = 20000;
    cfg.random_seed = 1;
    cfg.random_amplitude = 2;

    methods = ["TDZND-E", "ADZND-E", "DTND", "SDRZND-E", "F-SDNRZND"];
    noise_cases = ["none", "constant", "time_varying"];

    out_dir = fullfile(pwd, 'results');
    if ~exist(out_dir, 'dir')
        mkdir(out_dir);
    end

    method_col = strings(0, 1);
    noise_col = strings(0, 1);
    status_col = strings(0, 1);
    final_residual = [];
    max_residual = [];
    steady_residual_rmse = [];
    settling_time = [];
    final_error_norm = [];
    steady_error_rmse = [];
    max_error = [];
    samples = [];

    results = struct();
    row = 0;
    for ni = 1:numel(noise_cases)
        noise_type = noise_cases(ni);
        noise_key = matlab.lang.makeValidName(noise_type);
        for mi = 1:numel(methods)
            method = methods(mi);
            fprintf('Running %s under %s noise...\n', method, noise_type);
            result = simulate_tfs_sone(method, noise_type, cfg);
            metrics = compute_validation_metrics( ...
                result.t, result.residual_norm, result.error_series, cfg.tolerance, ...
                cfg.t_final, result.tau(end), result.status);

            method_key = matlab.lang.makeValidName(method);
            results.(noise_key).(method_key) = result;

            row = row + 1;
            method_col(row, 1) = method;
            noise_col(row, 1) = noise_type;
            status_col(row, 1) = result.status;
            final_residual(row, 1) = metrics.final_residual;
            max_residual(row, 1) = metrics.max_residual;
            steady_residual_rmse(row, 1) = metrics.steady_residual_rmse;
            settling_time(row, 1) = metrics.settling_time;
            final_error_norm(row, 1) = metrics.final_error_norm;
            steady_error_rmse(row, 1) = metrics.steady_error_rmse;
            max_error(row, 1) = metrics.max_error;
            samples(row, 1) = numel(result.t);
        end
    end

    summary = table( ...
        method_col, noise_col, status_col, final_residual, max_residual, ...
        steady_residual_rmse, settling_time, final_error_norm, ...
        steady_error_rmse, max_error, samples, ...
        'VariableNames', {'method', 'noise', 'status', 'final_residual', ...
        'max_residual', 'steady_residual_rmse', 'settling_time', ...
        'final_error_norm', 'steady_error_rmse', 'max_error', 'samples'});

    writetable(summary, fullfile(out_dir, 'summary_metrics.csv'));
    save(fullfile(out_dir, 'tfs_numerical_results.mat'), 'results', 'summary', 'cfg');
    recompute_tfs_metrics(1);
    load(fullfile(out_dir, 'tfs_numerical_results.mat'), 'summary');
    disp(summary);
end
