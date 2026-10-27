function run_tfs_tdoa_metrics(mode)
%RUN_TFS_TDOA_METRICS Reproducible TDOA validation for the TFS manuscript.
%   The script keeps the TDOA geometry used in the manuscript, fixes the
%   sensor seed, and compares the monotone SDRZND step with the proposed
%   Takagi-Sugeno fuzzy step.
    if nargin < 1
        mode = "all";
    end

    cfg = default_tdoa_cfg();
    out_dir = fullfile(fileparts(mfilename('fullpath')), 'results');
    if ~exist(out_dir, 'dir')
        mkdir(out_dir);
    end
    if strcmpi(string(mode), "legacy_summary")
        export_manuscript_panels_if_ready();
        return;
    elseif strcmpi(string(mode), "plot_only")
        export_manuscript_panels_if_ready();
        return;
    end

    rng(cfg.seed, 'twister');
    P = 10 * (rand(3, cfg.num_sensors) - 0.5);
    x0 = initial_tdoa_state(P, cfg);

    methods = ["SDRZND-3D", "F-SDNRZND-3D"];
    noises = ["constant", "time_varying"];
    rows = table();
    activity_rows = table();
    results = struct();

    for ni = 1:numel(noises)
        noise_type = noises(ni);
        noise_key = matlab.lang.makeValidName(noise_type);
        for mi = 1:numel(methods)
            method = methods(mi);
            fprintf('Running TDOA %s under %s noise...\n', method, noise_type);
            result = simulate_tdoa_case(method, noise_type, P, x0, cfg);
            method_key = matlab.lang.makeValidName(method);
            results.(noise_key).(method_key) = result;
            metric = summarize_tdoa_metrics(result, cfg);

            rows = [rows; table( ...
                method, noise_type, string(result.status), ...
                metric.final_residual, metric.steady_residual_rmse, ...
                metric.final_position_error, metric.steady_position_rmse, ...
                metric.max_position_error, metric.mean_phi, ...
                metric.min_tau, metric.max_tau, metric.samples, ...
                'VariableNames', {'method', 'noise', 'status', ...
                'final_residual', 'steady_residual_rmse', ...
                'final_position_error', 'steady_position_rmse', ...
                'max_position_error', 'mean_phi', ...
                'min_tau', 'max_tau', 'samples'})]; %#ok<AGROW>
            activity_rows = [activity_rows; summarize_rule_activity(result)]; %#ok<AGROW>
        end
    end

    writetable(rows, fullfile(out_dir, 'tdoa_metrics.csv'));
    writetable(activity_rows, fullfile(out_dir, 'tdoa_rule_activity.csv'));
    save(fullfile(out_dir, 'tdoa_results.mat'), 'results', 'rows', 'activity_rows', 'P', 'cfg');
    recompute_tfs_metrics(4);
    export_manuscript_panels_if_ready();
end

function export_manuscript_panels_if_ready()
    results_dir = fullfile(fileparts(mfilename('fullpath')), 'results');
    tdoa_path = fullfile(results_dir, 'tdoa_results.mat');
    vehicle_path = fullfile(results_dir, 'vehicle_results.mat');
    if exist(tdoa_path, 'file') && exist(vehicle_path, 'file')
        plot_tfs_embedding_validation();
    else
        warning(['Skipping manuscript-panel export because both TDOA and ', ...
            'vehicle result files are required.']);
    end
end

function cfg = default_tdoa_cfg()
    cfg.seed = 2026;
    cfg.sound_speed = 340.29;
    cfg.num_sensors = 10;
    cfg.t_final = 8;
    cfg.max_iter = 120000;
    cfg.beta = 10;
    cfg.alpha = 0.01;
    cfg.xi = 0.5;
    cfg.delta = 0.1;
    cfg.gamma = 50;
    cfg.diff_step = 1e-5;
    cfg.divergence_limit = 1e8;
    cfg.fuzzy.q_m = 0.5;
    cfg.fuzzy.q_h = 0.8;
    cfg.fuzzy.eps_e = 1e-12;
    cfg.fuzzy.eps_d = 1e-12;
    cfg.fuzzy.c_r = [0, 0.5, 1];
    cfg.fuzzy.sigma_r = [0.20, 0.20, 0.20];
    cfg.fuzzy.c_d = [-1, 0, 1];
    cfg.fuzzy.sigma_d = [0.35, 0.35, 0.35];
    cfg.fuzzy.Q = [
        cfg.delta, cfg.delta, cfg.fuzzy.q_m;
        cfg.fuzzy.q_m, cfg.fuzzy.q_m, cfg.fuzzy.q_h;
        cfg.fuzzy.q_h, 1, 1
    ];
end

function x0 = initial_tdoa_state(P, cfg)
    % Use an independent source estimate rather than the true trajectory state.
    s0 = [0; 5; 0];
    r0 = norm(P(:, 1) - s0);
    x0 = [s0; r0];
end

function result = simulate_tdoa_case(method, noise_type, P, x0, cfg)
    t_k = 0;
    x_k = x0;
    S_m = zeros(cfg.num_sensors - 1, 1);
    E_prev = tdoa_residual(t_k, x_k, P, cfg);
    initial_ref = max(norm(E_prev), cfg.fuzzy.eps_e);

    t_hist = zeros(1, cfg.max_iter);
    x_hist = zeros(4, cfg.max_iter);
    residual_hist = zeros(1, cfg.max_iter);
    pos_error_hist = zeros(1, cfg.max_iter);
    phi_hist = zeros(1, cfg.max_iter);
    tau_hist = zeros(1, cfg.max_iter);
    rule_strengths = NaN(3, 3, cfg.max_iter);
    r_hist = NaN(1, cfg.max_iter);
    d_hist = NaN(1, cfg.max_iter);

    status = "completed";
    k = 1;
    while t_k <= cfg.t_final + eps && k <= cfg.max_iter
        E_k = tdoa_residual(t_k, x_k, P, cfg);
        [tau_k, phi_k, details] = tdoa_step(method, t_k, E_k, E_prev, initial_ref, cfg);
        dotx = tdoa_dotx(t_k, x_k, S_m, noise_type, P, cfg);

        t_hist(k) = t_k;
        x_hist(:, k) = x_k;
        residual_hist(k) = norm(E_k);
        pos_error_hist(k) = norm(x_k(1:3) - target_position(t_k));
        phi_hist(k) = phi_k;
        tau_hist(k) = tau_k;
        if ~isempty(details)
            rule_strengths(:, :, k) = details.W;
            r_hist(k) = details.r;
            d_hist(k) = details.d;
        end

        x_next = x_k + tau_k * dotx;
        if any(~isfinite(x_next)) || norm(x_next) > cfg.divergence_limit
            status = "diverged";
            break;
        end

        % Left-rectangle approximation of the residual integral.
        S_m = S_m + tau_k * E_k;
        E_prev = E_k;
        x_k = x_next;
        t_k = t_k + tau_k;
        k = k + 1;
    end

    last = max(1, k - 1);
    if k > cfg.max_iter && status == "completed"
        status = "stopped_max_iter";
    end

    result.method = string(method);
    result.noise = string(noise_type);
    result.status = status;
    result.t = t_hist(1:last);
    result.x = x_hist(:, 1:last);
    result.residual_norm = residual_hist(1:last);
    result.position_error = pos_error_hist(1:last);
    result.phi = phi_hist(1:last);
    result.tau = tau_hist(1:last);
    result.rule_strengths = rule_strengths(:, :, 1:last);
    result.fuzzy_r = r_hist(1:last);
    result.fuzzy_d = d_hist(1:last);
end

function dotx = tdoa_dotx(t, x, S_m, noise_type, P, cfg)
    [A, b] = tdoa_matrices(t, P, cfg);
    [dotA, dotB] = tdoa_matrix_derivatives(t, P, cfg);
    E = A * x - b;
    mu_t = tdoa_mu(t, cfg);
    rho = noise_value(t, noise_type) * ones(cfg.num_sensors - 1, 1);
    dotx = pinv(A) * (-dotA * x + dotB - mu_t * E - cfg.gamma * S_m + rho);
end

function [tau, phi, details] = tdoa_step(method, t, E_curr, E_prev, initial_ref, cfg)
    method = upper(string(method));
    if method == "F-SDNRZND-3D"
        [phi, details] = tdoa_fuzzy_phi(E_curr, E_prev, initial_ref, cfg);
    else
        phi = (1 - cfg.delta) * exp(-cfg.beta * t) + cfg.delta;
        details = [];
    end
    tau = cfg.xi * phi / tdoa_mu(t, cfg);
end

function mu_t = tdoa_mu(t, cfg)
    lambda = (10^(floor(log10(cfg.beta)) + 1) - cfg.beta) * exp(-cfg.beta * t);
    mu_t = cfg.xi * (lambda + cfg.beta) / cfg.alpha;
end

function [phi, details] = tdoa_fuzzy_phi(E_curr, E_prev, e_ref, cfg)
    e_norm = norm(E_curr);
    e_prev_norm = norm(E_prev);
    r = e_norm / (e_norm + e_ref + cfg.fuzzy.eps_e);
    d = (e_norm - e_prev_norm) / (e_norm + e_prev_norm + cfg.fuzzy.eps_d);
    mu_r = exp(-((r - cfg.fuzzy.c_r).^2) ./ (2 * cfg.fuzzy.sigma_r.^2));
    mu_d = exp(-((d - cfg.fuzzy.c_d).^2) ./ (2 * cfg.fuzzy.sigma_d.^2));
    W = mu_r(:) * mu_d(:).';
    phi = sum(sum(W .* cfg.fuzzy.Q)) / sum(W(:));
    phi = min(1, max(cfg.delta, phi));
    details.r = r;
    details.d = d;
    details.W = W;
end

function activity = summarize_rule_activity(result)
    phases = ["early", "middle", "late"];
    activity = table();
    W_all = result.rule_strengths;
    if all(isnan(W_all(:)))
        for pi = 1:numel(phases)
            activity = [activity; rule_activity_row(result, phases(pi), NaN, NaN, NaN, NaN, NaN, NaN, NaN, "not_applicable")]; %#ok<AGROW>
        end
        return;
    end

    n = numel(result.t);
    edges = round(linspace(1, n + 1, numel(phases) + 1));
    magnitude_labels = ["small", "medium", "large"];
    trend_labels = ["decreasing", "steady", "increasing"];
    for pi = 1:numel(phases)
        idx = edges(pi):max(edges(pi), edges(pi + 1) - 1);
        idx(idx > n) = [];
        W_mean = mean(W_all(:, :, idx), 3, 'omitnan');
        [dominant_strength, flat_idx] = max(W_mean(:));
        [mag_idx, trend_idx] = ind2sub([3, 3], flat_idx);
        dominant_rule = magnitude_labels(mag_idx) + "-" + trend_labels(trend_idx);
        activity = [activity; rule_activity_row(result, phases(pi), ...
            result.t(idx(1)), result.t(idx(end)), mean(result.phi(idx), 'omitnan'), ...
            mean(result.tau(idx), 'omitnan'), mean(result.fuzzy_r(idx), 'omitnan'), ...
            mean(result.fuzzy_d(idx), 'omitnan'), dominant_strength, dominant_rule)]; %#ok<AGROW>
    end
end

function row = rule_activity_row(result, phase, t_start, t_end, mean_phi, mean_tau, mean_r, mean_d, dominant_strength, dominant_rule)
    row = table(result.method, result.noise, string(result.status), phase, ...
        t_start, t_end, mean_phi, mean_tau, mean_r, mean_d, dominant_strength, dominant_rule, ...
        'VariableNames', {'method', 'noise', 'status', 'phase', ...
        't_start', 't_end', 'mean_phi', 'mean_tau', 'mean_r', 'mean_d', ...
        'dominant_strength', 'dominant_rule'});
end

function E = tdoa_residual(t, x, P, cfg)
    [A, b] = tdoa_matrices(t, P, cfg);
    E = A * x - b;
end

function [dotA, dotB] = tdoa_matrix_derivatives(t, P, cfg)
    h = cfg.diff_step;
    [A_plus, b_plus] = tdoa_matrices(t + h, P, cfg);
    [A_minus, b_minus] = tdoa_matrices(t - h, P, cfg);
    dotA = (A_plus - A_minus) / (2 * h);
    dotB = (b_plus - b_minus) / (2 * h);
end

function [A, b] = tdoa_matrices(t, P, cfg)
    s = target_position(t);
    M = cfg.num_sensors;
    travel_times = zeros(1, M);
    for ii = 1:M
        travel_times(ii) = norm(s - P(:, ii)) / cfg.sound_speed;
    end
    tau = travel_times - travel_times(1);
    tau(1) = [];
    range_diffs = cfg.sound_speed * tau(:);

    d = P - repmat(P(:, 1), 1, M);
    d(:, 1) = [];
    d = d.';

    A = [d, range_diffs];
    b = zeros(M - 1, 1);
    for ii = 1:M - 1
        b(ii) = 0.5 * (norm(P(:, ii + 1))^2 - norm(P(:, 1))^2 - range_diffs(ii)^2);
    end
end

function s = target_position(t)
    s = [5 * cos(t); 5 * sin(t); 5 * cos(4 * t)];
end

function rho = noise_value(t, noise_type)
    switch lower(string(noise_type))
        case "constant"
            rho = 100;
        case "time_varying"
            rho = 10 * t + 100;
        otherwise
            rho = 0;
    end
end

function metric = summarize_tdoa_metrics(result, cfg)
    residual = result.residual_norm(:);
    pos_error = result.position_error(:);
    metric.final_residual = residual(end);
    metric.steady_residual_rmse = tfs_steady_rmse(result.t, residual, cfg.t_final, result.tau(end), result.status);
    metric.final_position_error = pos_error(end);
    metric.steady_position_rmse = tfs_steady_rmse(result.t, pos_error, cfg.t_final, result.tau(end), result.status);
    metric.max_position_error = max(pos_error);
    metric.mean_phi = mean(result.phi(:));
    metric.min_tau = min(result.tau(:));
    metric.max_tau = max(result.tau(:));
    metric.samples = numel(result.t);
    if result.status ~= "completed"
        warning('TDOA run %s/%s ended with status %s after %d samples.', ...
            result.method, result.noise, result.status, metric.samples);
    end
    if result.t(end) < cfg.t_final
        warning('TDOA run %s/%s ended at t=%g before t_final=%g.', ...
            result.method, result.noise, result.t(end), cfg.t_final);
    end
end
