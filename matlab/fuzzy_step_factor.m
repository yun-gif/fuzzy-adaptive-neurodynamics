function [phi, details] = fuzzy_step_factor(E_curr, E_prev, params)
%FUZZY_STEP_FACTOR Takagi-Sugeno fuzzy step factor for F-SDNRZND.
%   The output phi is bounded in [delta, 1].

    if nargin < 3 || isempty(params)
        params = default_fuzzy_params();
    end

    e_norm = norm(E_curr);
    e_prev_norm = norm(E_prev);
    delta_e = e_norm - e_prev_norm;

    if ~isfield(params, 'e_ref') || isempty(params.e_ref)
        params.e_ref = max(e_prev_norm, params.eps_e);
    end

    r = e_norm / (e_norm + params.e_ref + params.eps_e);
    d = delta_e / (e_norm + e_prev_norm + params.eps_d);

    mu_r = exp(-((r - params.c_r).^2) ./ (2 * params.sigma_r.^2));
    mu_d = exp(-((d - params.c_d).^2) ./ (2 * params.sigma_d.^2));
    if isfield(params, 'mode') && any(strcmpi(string(params.mode), ["residual_only", "residual-only", "r_only"]))
        mu_d = [0, 1, 0];
    end
    W = mu_r(:) * mu_d(:).';

    denominator = sum(W(:));
    if denominator <= eps
        phi = params.delta;
    else
        phi = sum(sum(W .* params.Q)) / denominator;
    end

    phi = min(1, max(params.delta, phi));

    details.r = r;
    details.d = d;
    details.mu_r = mu_r;
    details.mu_d = mu_d;
    details.W = W;
end

function params = default_fuzzy_params()
    params.delta = 0.1;
    params.q_m = 0.5;
    params.q_h = 0.8;
    params.eps_e = 1e-12;
    params.eps_d = 1e-12;
    params.e_ref = [];
    params.c_r = [0, 0.5, 1];
    params.sigma_r = [0.20, 0.20, 0.20];
    params.c_d = [-1, 0, 1];
    params.sigma_d = [0.35, 0.35, 0.35];
    params.mode = "two_input";
    params.Q = [
        params.delta, params.delta, params.q_m;
        params.q_m,   params.q_m,   params.q_h;
        params.q_h,   1,            1
    ];
end
