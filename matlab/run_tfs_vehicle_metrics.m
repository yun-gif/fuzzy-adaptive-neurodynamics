function run_tfs_vehicle_metrics(mode)
%RUN_TFS_VEHICLE_METRICS Reproducible CAV platoon validation for the TFS paper.
%   This script ports the vehicle-platoon model from MATLAB/SD_end into a
%   self-contained experiment and compares the monotone SDRZND step with the
%   Takagi-Sugeno fuzzy-adaptive F-SDNRZND step.
    if nargin < 1
        mode = "all";
    end

    cfg = default_vehicle_cfg();
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

    methods = ["SDRZND-CAV", "F-SDNRZND-CAV"];
    rows = table();
    activity_rows = table();
    results = struct();

    for mi = 1:numel(methods)
        method = methods(mi);
        fprintf('Running vehicle platoon %s...\n', method);
        result = simulate_vehicle_case(method, cfg);
        method_key = matlab.lang.makeValidName(method);
        results.(method_key) = result;
        metric = summarize_vehicle_metrics(result, cfg);

        rows = [rows; table( ...
            method, string(result.status), ...
            metric.final_position_error_norm, metric.steady_position_rmse, ...
            metric.max_position_error_norm, metric.final_velocity_error_norm, ...
            metric.steady_velocity_rmse, metric.max_velocity_error_norm, ...
            metric.final_acceleration_error_norm, metric.steady_acceleration_rmse, ...
            metric.max_acceleration_error_norm, metric.mean_phi, ...
            metric.min_tau, metric.max_tau, metric.samples, ...
            'VariableNames', {'method', 'status', ...
            'final_position_error_norm', 'steady_position_rmse', ...
            'max_position_error_norm', 'final_velocity_error_norm', ...
            'steady_velocity_rmse', 'max_velocity_error_norm', ...
            'final_acceleration_error_norm', 'steady_acceleration_rmse', ...
            'max_acceleration_error_norm', 'mean_phi', ...
            'min_tau', 'max_tau', 'samples'})]; %#ok<AGROW>
        activity_rows = [activity_rows; summarize_rule_activity(result)]; %#ok<AGROW>
    end

    writetable(rows, fullfile(out_dir, 'vehicle_metrics.csv'));
    writetable(activity_rows, fullfile(out_dir, 'vehicle_rule_activity.csv'));
    save(fullfile(out_dir, 'vehicle_results.mat'), 'results', 'rows', 'activity_rows', 'cfg');
    recompute_tfs_metrics(5);
    load(fullfile(out_dir, 'vehicle_results.mat'), 'rows');
    export_manuscript_panels_if_ready();
    disp(rows);
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

function cfg = default_vehicle_cfg()
    cfg.N = 5;
    cfg.t_final = 12;
    cfg.max_iter = 250000;
    cfg.divergence_limit = 1e8;

    cfg.spacing = 6;
    cfg.c1 = 30;
    cfg.c2 = 31;
    cfg.c3 = 10;
    cfg.p1 = 0.8;
    cfg.p2 = 0.85;
    cfg.p3 = 0.9;
    cfg.u0_max = 4;
    cfg.eta_bar = 3;
    cfg.vartheta = 0.01;

    cfg.xi = 0.01;
    cfg.beta = 100;
    cfg.alpha = 0.1;
    cfg.delta = 0.1;

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

    cfg.H = [
         1, -1,  0,  0,  0;
        -1,  2,  0,  0,  0;
         0,  0,  2, -1,  0;
         0,  0, -1,  2, -1;
         0,  0,  0, -1,  1
    ];
    cfg.initial_state = [[-6; -13; -19; -27; -32]; zeros(5 * cfg.N, 1); 5; 0];
end

function result = simulate_vehicle_case(method, cfg)
    N = cfg.N;
    x_k = cfg.initial_state;
    t_k = 0;
    sum_k = zeros(N, 1);
    di = (1:N)' * cfg.spacing;
    [E_prev, ~] = vehicle_residual(x_k, di, N);
    initial_ref = max(norm(E_prev), cfg.fuzzy.eps_e);

    t_hist = zeros(1, cfg.max_iter);
    x_hist = zeros(6 * N + 2, cfg.max_iter);
    leader_acc_hist = zeros(1, cfg.max_iter);
    pos_err_norm = zeros(1, cfg.max_iter);
    vel_err_norm = zeros(1, cfg.max_iter);
    acc_err_norm = zeros(1, cfg.max_iter);
    phi_hist = zeros(1, cfg.max_iter);
    tau_hist = zeros(1, cfg.max_iter);
    rule_strengths = NaN(3, 3, cfg.max_iter);
    r_hist = NaN(1, cfg.max_iter);
    d_hist = NaN(1, cfg.max_iter);

    status = "completed";
    k = 1;
    while t_k <= cfg.t_final + eps && k <= cfg.max_iter
        [E_curr, parts] = vehicle_residual(x_k, di, N);
        [tau_k, phi_k, details] = vehicle_step(method, t_k, E_curr, E_prev, initial_ref, cfg);
        [dotx, ss] = vehicle_dotx(t_k, x_k, sum_k, parts, cfg);

        t_hist(k) = t_k;
        x_hist(:, k) = x_k;
        leader_acc_hist(k) = leader_acceleration(t_k);
        pos_err_norm(k) = norm(parts.ep);
        vel_err_norm(k) = norm(parts.ev);
        acc_err_norm(k) = norm(parts.ea);
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

        sum_k = sum_k + tau_k * ss;
        E_prev = E_curr;
        x_k = x_next;
        t_k = t_k + tau_k;
        k = k + 1;
    end

    last = max(1, k - 1);
    if k > cfg.max_iter && status == "completed"
        status = "stopped_max_iter";
    end

    result.method = string(method);
    result.status = status;
    result.t = t_hist(1:last);
    result.x = x_hist(:, 1:last);
    result.leader_acceleration = leader_acc_hist(1:last);
    result.position_error_norm = pos_err_norm(1:last);
    result.velocity_error_norm = vel_err_norm(1:last);
    result.acceleration_error_norm = acc_err_norm(1:last);
    result.phi = phi_hist(1:last);
    result.tau = tau_hist(1:last);
    result.rule_strengths = rule_strengths(:, :, 1:last);
    result.fuzzy_r = r_hist(1:last);
    result.fuzzy_d = d_hist(1:last);
end

function [E, parts] = vehicle_residual(x, di, N)
    p = x(1:N);
    v = x(N + 1:2 * N);
    a = x(2 * N + 1:3 * N);
    ex_p = x(3 * N + 1:4 * N);
    ex_v = x(4 * N + 1:5 * N);
    ex_a = x(5 * N + 1:6 * N);

    ep = p - ex_p + di;
    ev = v - ex_v;
    ea = a - ex_a;
    E = [ep; ev; ea];

    parts.p = p;
    parts.v = v;
    parts.a = a;
    parts.ex_p = ex_p;
    parts.ex_v = ex_v;
    parts.ex_a = ex_a;
    parts.ep = ep;
    parts.ev = ev;
    parts.ea = ea;
end

function [dotx, ss] = vehicle_dotx(t, x, sum_k, parts, cfg)
    N = cfg.N;
    p0 = x(6 * N + 2);
    v0 = x(6 * N + 1);
    a0 = leader_acceleration(t);

    Pi_t = vehicle_strong_gain(t, cfg);
    theta1 = Pi_t;
    theta2 = theta1;
    theta3 = theta1 + cfg.u0_max;
    theta4 = theta3 + cfg.eta_bar + cfg.vartheta;

    ss = cfg.c1 * (abs(parts.ep) .^ cfg.p1) .* sign(parts.ep) + ...
         cfg.c2 * (abs(parts.ev) .^ cfg.p2) .* sign(parts.ev) + ...
         cfg.c3 * (abs(parts.ea) .^ cfg.p3) .* sign(parts.ea);
    s = parts.ea + sum_k;
    ui = -ss - theta4 * sign(cfg.H * s);

    dotp = parts.ev + parts.ex_v;
    dotv = parts.ea + parts.ex_a;
    dota = ui + vehicle_disturbance(t);
    dotex_p = -theta1 * sign(cfg.H * (parts.ex_p - p0)) + parts.ex_v;
    dotex_v = -theta2 * sign(cfg.H * (parts.ex_v - v0)) + parts.ex_a;
    dotex_a = -theta3 * sign(cfg.H * (parts.ex_a - a0));
    dotx = [dotp; dotv; dota; dotex_p; dotex_v; dotex_a; a0; v0];

end

function [tau, phi, details] = vehicle_step(method, t, E_curr, E_prev, initial_ref, cfg)
    method = upper(string(method));
    if method == "F-SDNRZND-CAV"
        [phi, details] = vehicle_fuzzy_phi(E_curr, E_prev, initial_ref, cfg);
    else
        phi = (1 - cfg.delta) * exp(-cfg.beta * t) + cfg.delta;
        details = [];
    end
    tau = cfg.xi * phi / vehicle_strong_gain(t, cfg);
end

function Pi_t = vehicle_strong_gain(t, cfg)
    Lambda_t = (10^(floor(log10(cfg.beta)) + 1) - cfg.beta) * exp(-cfg.beta * t);
    Pi_t = cfg.xi * (Lambda_t + cfg.beta) / cfg.alpha;
end

function [phi, details] = vehicle_fuzzy_phi(E_curr, E_prev, e_ref, cfg)
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
    row = table(result.method, string(result.status), phase, ...
        t_start, t_end, mean_phi, mean_tau, mean_r, mean_d, dominant_strength, dominant_rule, ...
        'VariableNames', {'method', 'status', 'phase', ...
        't_start', 't_end', 'mean_phi', 'mean_tau', 'mean_r', 'mean_d', ...
        'dominant_strength', 'dominant_rule'});
end

function a0 = leader_acceleration(t)
    a0 = 4 * t ./ exp(0.5 * t) + 0.2;
end

function w = vehicle_disturbance(t)
    w = 2 * sin(2 * pi * t);
end

function metric = summarize_vehicle_metrics(result, cfg)
    metric.final_position_error_norm = result.position_error_norm(end);
    metric.steady_position_rmse = tfs_steady_rmse(result.t, result.position_error_norm, cfg.t_final, result.tau(end), result.status);
    metric.max_position_error_norm = max(result.position_error_norm);
    metric.final_velocity_error_norm = result.velocity_error_norm(end);
    metric.steady_velocity_rmse = tfs_steady_rmse(result.t, result.velocity_error_norm, cfg.t_final, result.tau(end), result.status);
    metric.max_velocity_error_norm = max(result.velocity_error_norm);
    metric.final_acceleration_error_norm = result.acceleration_error_norm(end);
    metric.steady_acceleration_rmse = tfs_steady_rmse(result.t, result.acceleration_error_norm, cfg.t_final, result.tau(end), result.status);
    metric.max_acceleration_error_norm = max(result.acceleration_error_norm);
    metric.mean_phi = mean(result.phi(:));
    metric.min_tau = min(result.tau(:));
    metric.max_tau = max(result.tau(:));
    metric.samples = numel(result.t);
end


function idx = sparse_markers(t)
    n = numel(t);
    if n < 20
        idx = 1:n;
    else
        idx = unique(round(linspace(1, n, 16)));
    end
end
