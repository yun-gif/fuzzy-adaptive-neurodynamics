function rho = noise_case(t, noise_type, dim, cfg)
%NOISE_CASE Disturbance definitions aligned with the TFS manuscript.

    if nargin < 3 || isempty(dim)
        dim = 4;
    end
    if nargin < 4 || isempty(cfg)
        cfg = struct();
    end
    if ~isfield(cfg, 'random_amplitude')
        cfg.random_amplitude = 2;
    end

    switch lower(string(noise_type))
        case {"none", "noise_free", "nf", "zero"}
            rho = zeros(dim, 1);
        case {"constant", "cn"}
            rho = 100 * ones(dim, 1);
        case {"time_varying", "tvn"}
            rho = (10 * t + 100) * ones(dim, 1);
        case {"random", "bounded_random"}
            rho = cfg.random_amplitude * (2 * rand(dim, 1) - 1);
        otherwise
            error('Unknown noise type: %s', noise_type);
    end
end
