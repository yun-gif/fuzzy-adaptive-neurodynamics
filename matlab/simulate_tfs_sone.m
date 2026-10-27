function result = simulate_tfs_sone(method, noise_type, cfg)
%SIMULATE_TFS_SONE Run one method/noise pair for the nonlinear SoNE benchmark.

    if nargin < 3 || isempty(cfg)
        cfg = default_config();
    else
        cfg = fill_default_config(cfg);
    end

    if isfield(cfg, 'random_seed') && ~isempty(cfg.random_seed)
        rng(cfg.random_seed);
    end

    dim = 4;
    t_k = 0;
    x_k = cfg.x0(:);
    S_m = zeros(dim, 1);
    [E_prev, ~, ~] = tfs_theta_numeric(t_k, x_k);
    cfg.fuzzy_params = local_fuzzy_params(cfg, E_prev);

    t_hist = [];
    x_hist = [];
    x_star_hist = [];
    residual_norm = [];
    error_norm = [];
    tau_hist = [];
    phi_hist = [];
    r_hist = [];
    d_hist = [];
    rule_strengths = zeros(3, 3, 0);
    status = "completed";

    k = 1;
    while t_k <= cfg.t_final + eps && k <= cfg.max_iter
        [E_k, J_k, dotTheta_k, x_star_k] = tfs_theta_numeric(t_k, x_k);

        if any(~isfinite(E_k)) || any(~isfinite(J_k), 'all') || rcond(J_k) < cfg.min_rcond
            status = "stopped_singular_or_nonfinite";
            break;
        end

        rho_k = noise_case(t_k, noise_type, dim, cfg);
        phi_k = NaN;
        details = [];

        switch upper(string(method))
            case "TDZND-E"
                tau_k = cfg.tau;
                Pi_k = cfg.xi / cfg.tau;
                dotx_k = -J_k \ (Pi_k * E_k + dotTheta_k - rho_k);
            case "ADZND-E"
                Pi_k = cfg.xi * (cfg.beta + norm(E_k)) / cfg.alpha;
                tau_k = cfg.xi / Pi_k;
                dotx_k = -J_k \ (Pi_k * E_k + dotTheta_k - rho_k);
            case "DTND"
                tau_k = cfg.tau;
                Pi_k = cfg.xi / cfg.tau;
                dotx_k = -J_k \ (Pi_k * E_k + cfg.gamma * S_m + dotTheta_k - rho_k);
            case {"SDRZND-E", "MONOTONE"}
                Pi_k = tfs_strong_gain(t_k, cfg);
                phi_k = (1 - cfg.delta) * exp(-cfg.beta * t_k) + cfg.delta;
                tau_k = cfg.xi * phi_k / Pi_k;
                dotx_k = -J_k \ (Pi_k * E_k + cfg.gamma * S_m + dotTheta_k - rho_k);
            case {"MATCHED-MEAN", "MATCHED_MEAN"}
                Pi_k = tfs_strong_gain(t_k, cfg);
                if isfield(cfg, 'matched_phi') && ~isempty(cfg.matched_phi)
                    phi_k = min(1, max(cfg.delta, cfg.matched_phi));
                else
                    phi_k = 0.5;
                end
                tau_k = cfg.xi * phi_k / Pi_k;
                dotx_k = -J_k \ (Pi_k * E_k + cfg.gamma * S_m + dotTheta_k - rho_k);
            case {"F-SDNRZND", "FSDNRZND"}
                [tau_k, phi_k, details] = tau_fuzzy(t_k, E_k, E_prev, cfg);
                Pi_k = tfs_strong_gain(t_k, cfg);
                dotx_k = -J_k \ (Pi_k * E_k + cfg.gamma * S_m + dotTheta_k - rho_k);
            case {"F-SDNRZND-R", "FSDNRZND_R", "RESIDUAL-ONLY"}
                residual_cfg = cfg;
                residual_cfg.fuzzy_params.mode = "residual_only";
                [tau_k, phi_k, details] = tau_fuzzy(t_k, E_k, E_prev, residual_cfg);
                Pi_k = tfs_strong_gain(t_k, cfg);
                dotx_k = -J_k \ (Pi_k * E_k + cfg.gamma * S_m + dotTheta_k - rho_k);
            otherwise
                error('Unknown method: %s', method);
        end

        if ~isfinite(tau_k) || tau_k <= 0 || any(~isfinite(dotx_k))
            status = "stopped_invalid_update";
            break;
        end

        t_hist(k) = t_k; %#ok<AGROW>
        x_hist(:, k) = x_k; %#ok<AGROW>
        x_star_hist(:, k) = x_star_k; %#ok<AGROW>
        residual_norm(k) = norm(E_k); %#ok<AGROW>
        error_norm(k) = norm(x_k - x_star_k); %#ok<AGROW>
        tau_hist(k) = tau_k; %#ok<AGROW>
        phi_hist(k) = phi_k; %#ok<AGROW>

        if ~isempty(details)
            r_hist(k) = details.r; %#ok<AGROW>
            d_hist(k) = details.d; %#ok<AGROW>
            rule_strengths(:, :, k) = details.W; %#ok<AGROW>
        else
            r_hist(k) = NaN; %#ok<AGROW>
            d_hist(k) = NaN; %#ok<AGROW>
            rule_strengths(:, :, k) = NaN(3, 3); %#ok<AGROW>
        end

        x_next = x_k + tau_k * dotx_k;
        if any(~isreal(x_next)) || any(~isfinite(x_next)) || x_next(1) <= 0
            status = "stopped_outside_log_domain";
            break;
        end

        % Left-rectangle approximation of the continuous residual integral.
        S_m = S_m + tau_k * E_k;
        E_prev = E_k;
        x_k = x_next;
        t_k = t_k + tau_k;
        k = k + 1;
    end

    if k > cfg.max_iter
        status = "stopped_max_iter";
    end

    result.method = string(method);
    result.noise_type = string(noise_type);
    result.status = status;
    result.t = t_hist;
    result.x = x_hist;
    result.x_star = x_star_hist;
    result.error_series = x_hist - x_star_hist;
    result.residual_norm = residual_norm;
    result.error_norm = error_norm;
    result.tau = tau_hist;
    result.phi = phi_hist;
    result.r = r_hist;
    result.d = d_hist;
    result.rule_strengths = rule_strengths;
    result.cfg = cfg;
end

function cfg = default_config()
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
    cfg.min_rcond = 1e-12;
    cfg.random_seed = 1;
    cfg.random_amplitude = 2;
end

function params = local_fuzzy_params(cfg, E_initial)
    params.delta = cfg.delta;
    params.q_m = 0.5;
    params.q_h = 0.8;
    params.eps_e = 1e-12;
    params.eps_d = 1e-12;
    params.e_ref = max(norm(E_initial), params.eps_e);
    params.c_r = [0, 0.5, 1];
    params.sigma_r = [0.20, 0.20, 0.20];
    params.c_d = [-1, 0, 1];
    params.sigma_d = [0.35, 0.35, 0.35];
    params.mode = "two_input";
    if isfield(cfg, 'fuzzy_mode') && ~isempty(cfg.fuzzy_mode)
        params.mode = string(cfg.fuzzy_mode);
    end
    if isfield(cfg, 'fuzzy_width_scale') && ~isempty(cfg.fuzzy_width_scale)
        params.sigma_r = params.sigma_r * cfg.fuzzy_width_scale;
        params.sigma_d = params.sigma_d * cfg.fuzzy_width_scale;
    end
    params.Q = [
        params.delta, params.delta, params.q_m;
        params.q_m,   params.q_m,   params.q_h;
        params.q_h,   1,            1
    ];
end

function cfg = fill_default_config(cfg)
    defaults = default_config();
    names = fieldnames(defaults);
    for i = 1:numel(names)
        if ~isfield(cfg, names{i}) || isempty(cfg.(names{i}))
            cfg.(names{i}) = defaults.(names{i});
        end
    end
end
