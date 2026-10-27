function run_tfs_mechanism_ablation()
%RUN_TFS_MECHANISM_ABLATION Mechanism ablations for the fuzzy step regulator.

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

    noise_type = "time_varying";
    out_dir = fullfile(pwd, 'results');
    if ~exist(out_dir, 'dir')
        mkdir(out_dir);
    end

    nominal = simulate_tfs_sone("F-SDNRZND", noise_type, cfg);
    matched_cfg = cfg;
    matched_cfg.matched_phi = mean(nominal.phi(isfinite(nominal.phi)));

    variants = {
        "two-input", "F-SDNRZND", cfg;
        "residual-only", "F-SDNRZND-R", cfg;
        "matched-mean", "Matched-Mean", matched_cfg;
        "narrow-membership", "F-SDNRZND", with_width(cfg, 0.75);
        "wide-membership", "F-SDNRZND", with_width(cfg, 1.25)
    };

    variant_col = strings(0, 1);
    method_col = strings(0, 1);
    samples_col = [];
    mean_phi_col = [];
    steady_residual_rmse_col = [];
    settling_time_col = [];
    final_error_norm_col = [];
    dominant_rule_col = strings(0, 1);
    dominant_strength_col = [];
    results = struct();

    for vi = 1:size(variants, 1)
        variant = variants{vi, 1};
        method = variants{vi, 2};
        variant_cfg = variants{vi, 3};
        fprintf('Running mechanism ablation %s...\n', variant);
        result = simulate_tfs_sone(method, noise_type, variant_cfg);
        metrics = compute_validation_metrics( ...
            result.t, result.residual_norm, result.error_series, cfg.tolerance, ...
            cfg.t_final, result.tau(end), result.status);
        [dominant_rule, dominant_strength] = dominant_rule_summary(result);

        variant_col(vi, 1) = variant;
        method_col(vi, 1) = method;
        samples_col(vi, 1) = numel(result.t);
        mean_phi_col(vi, 1) = mean(result.phi(isfinite(result.phi)));
        steady_residual_rmse_col(vi, 1) = metrics.steady_residual_rmse;
        settling_time_col(vi, 1) = metrics.settling_time;
        final_error_norm_col(vi, 1) = metrics.final_error_norm;
        dominant_rule_col(vi, 1) = dominant_rule;
        dominant_strength_col(vi, 1) = dominant_strength;

        key = matlab.lang.makeValidName(variant);
        results.(key) = result;
    end

    ablation = table(variant_col, method_col, samples_col, mean_phi_col, ...
        steady_residual_rmse_col, settling_time_col, final_error_norm_col, ...
        dominant_rule_col, dominant_strength_col, ...
        'VariableNames', {'variant', 'method', 'samples', 'mean_phi', ...
        'steady_residual_rmse', 'settling_time', 'final_error_norm', ...
        'dominant_rule', 'dominant_strength'});

    writetable(ablation, fullfile(out_dir, 'mechanism_ablation_metrics.csv'));
    save(fullfile(out_dir, 'mechanism_ablation_results.mat'), 'results', 'ablation', 'cfg');
    recompute_tfs_metrics(2);
    load(fullfile(out_dir, 'mechanism_ablation_results.mat'), 'ablation');
    disp(ablation);
end

function cfg = with_width(cfg, scale)
    cfg.fuzzy_width_scale = scale;
end

function [dominant_rule, dominant_strength] = dominant_rule_summary(result)
    labels = ["small-decreasing", "medium-decreasing", "large-decreasing"; ...
              "small-steady", "medium-steady", "large-steady"; ...
              "small-increasing", "medium-increasing", "large-increasing"];
    W = result.rule_strengths;
    if all(isnan(W(:)))
        dominant_rule = "not applicable";
        dominant_strength = NaN;
        return;
    end
    W_mean = mean(W, 3, 'omitnan');
    [dominant_strength, idx] = max(W_mean(:));
    [rr, cc] = ind2sub([3, 3], idx);
    dominant_rule = labels(cc, rr);
end
