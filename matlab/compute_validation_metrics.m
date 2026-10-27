function metrics = compute_validation_metrics(t_vec, residual_norm, error_series, tolerance, T, last_step, status, Tcap)
%COMPUTE_VALIDATION_METRICS Metrics used by the TFS validation tables.

    if nargin < 4 || isempty(tolerance)
        tolerance = 1e-3;
    end

    residual_norm = residual_norm(:).';
    t_vec = t_vec(:).';
    if nargin < 8, Tcap = min(T, t_vec(end)); end

    metrics.final_residual = residual_norm(end);
    metrics.max_residual = max(residual_norm);

    [metrics.steady_residual_rmse, metrics.window] = ...
        tfs_steady_rmse(t_vec, residual_norm, T, last_step, status, Tcap);

    below = residual_norm <= tolerance;
    metrics.settling_iteration = NaN;
    metrics.settling_time = NaN;
    for idx = 1:numel(below)
        if all(below(idx:end))
            metrics.settling_iteration = idx;
            metrics.settling_time = t_vec(idx);
            break;
        end
    end

    if nargin >= 3 && ~isempty(error_series)
        if isvector(error_series)
            e = error_series(:).';
            metrics.final_error_norm = abs(e(end));
            metrics.steady_error_rmse = tfs_steady_rmse(t_vec, e, T, last_step, status, Tcap);
            metrics.max_error = max(abs(e));
        else
            error_norm = sqrt(sum(error_series.^2, 1));
            metrics.final_error_norm = error_norm(end);
            metrics.steady_error_rmse = tfs_steady_rmse(t_vec, error_series, T, last_step, status, Tcap);
            metrics.max_error = max(abs(error_series(:)));
        end
    else
        metrics.final_error_norm = NaN;
        metrics.steady_error_rmse = NaN;
        metrics.max_error = NaN;
    end
end
