function [tau, phi, details] = tau_fuzzy(t, E_curr, E_prev, cfg, params)
%TAU_FUZZY Fuzzy-adaptive implementation step for the SoNE benchmark.

    if nargin < 4 || isempty(cfg)
        cfg = default_tfs_config();
    end
    if nargin < 5
        params = [];
    end

    if isempty(params) && isfield(cfg, 'fuzzy_params')
        params = cfg.fuzzy_params;
    end

    [phi, details] = fuzzy_step_factor(E_curr, E_prev, params);
    Pi_m = tfs_strong_gain(t, cfg);
    tau = cfg.xi * phi / Pi_m;
end

function cfg = default_tfs_config()
    cfg.xi = 0.5;
    cfg.beta = 10;
    cfg.alpha = 0.1;
end
