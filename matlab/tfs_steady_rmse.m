function [rmse, info] = tfs_steady_rmse(t, error, T, last_step, status, Tcap)
%TFS_STEADY_RMSE Time RMS on [0.9*T,Tcap], preserving recorded samples.
% Scalar inputs interpolate the recorded norm; matrix inputs interpolate
% signed components and average their squared integrals over components.
% Tcap is the common last recorded time of the comparison group. No extrapolation.
% last_step is retained for caller compatibility; it does not extend the data.
    t = t(:).';
    if isvector(error), error = error(:).'; end
    assert(numel(t) >= 2 && all(isfinite(t)) && all(diff(t) > 0));
    assert(size(error, 2) == numel(t) && isfinite(T) && T > 0);
    if nargin < 6, Tcap = min(T, t(end)); end
    info.window_start = 0.9 * T;
    info.window_end = Tcap;
    info.record_end = t(end);
    info.endpoint_hold = 0;
    info.valid = string(status) == "completed" && t(1) <= info.window_start ...
        && Tcap > info.window_start && Tcap <= min(T, t(end)) ...
        && all(isfinite(error), 'all');
    rmse = NaN;
    if ~info.valid, return; end
    knots = [info.window_start, t(t > info.window_start & t < Tcap), Tcap];
    values = interp1(t.', error.', knots.', 'linear').';
    a = values(:, 1:end-1);
    b = values(:, 2:end);
    integral = sum(diff(knots) .* sum((a.^2 + a.*b + b.^2) / 3, 1));
    rmse = sqrt(integral / ((Tcap - info.window_start) * size(error, 1)));
end
