function plot_tfs_embedding_validation(mode)
%PLOT_TFS_EMBEDDING_VALIDATION Export single-panel application-validation figures.
    if nargin < 1, mode = "revision"; end

    results_dir = fullfile(fileparts(mfilename('fullpath')), 'results');
    tdoa_path = fullfile(results_dir, 'tdoa_results.mat');
    vehicle_path = fullfile(results_dir, 'vehicle_results.mat');
    if ~exist(tdoa_path, 'file') || ~exist(vehicle_path, 'file')
        error('Application result files are missing. Run the application validations first.');
    end

    tdoa_data = load(tdoa_path, 'results', 'P', 'cfg');
    vehicle_data = load(vehicle_path, 'results');
    tdoa = tdoa_data.results.time_varying;
    sdr_tdoa = tdoa.SDRZND_3D;
    fz_tdoa = tdoa.F_SDNRZND_3D;
    sdr_vehicle = vehicle_data.results.SDRZND_CAV;
    fz_vehicle = vehicle_data.results.F_SDNRZND_CAV;

    fig_dir = fullfile(results_dir, 'figures');
    if ~exist(fig_dir, 'dir')
        mkdir(fig_dir);
    end

    set(0, 'DefaultFigureVisible', 'off');
    colors.base = [0.18, 0.18, 0.18];
    colors.base_light = [0.45, 0.45, 0.45];
    colors.fuzzy = [0.00, 0.36, 0.68];
    colors.step = [0.38, 0.38, 0.38];
    colors.sensor = [0.25, 0.25, 0.25];

    export_tdoa_error_panel(sdr_tdoa, fz_tdoa, colors, fig_dir);
    if string(mode) == "all"
        export_tdoa_trajectory_panel(tdoa_data, fz_tdoa, colors, fig_dir);
        export_tdoa_schedule_panel(fz_tdoa, colors, fig_dir);
    end
    export_vehicle_error_panel(sdr_vehicle.t, sdr_vehicle.position_error_norm, ...
        fz_vehicle.t, fz_vehicle.position_error_norm, 'Position-error norm', ...
        'tfs_vehicle_position', colors, fig_dir);
    export_vehicle_error_panel(sdr_vehicle.t, sdr_vehicle.velocity_error_norm, ...
        fz_vehicle.t, fz_vehicle.velocity_error_norm, 'Velocity-error norm', ...
        'tfs_vehicle_velocity', colors, fig_dir);
    export_vehicle_error_panel(sdr_vehicle.t, sdr_vehicle.acceleration_error_norm, ...
        fz_vehicle.t, fz_vehicle.acceleration_error_norm, 'Acceleration-error norm', ...
        'tfs_vehicle_acceleration', colors, fig_dir);
    export_vehicle_schedule_panel(fz_vehicle, colors, fig_dir);
end

function export_tdoa_error_panel(sdr_tdoa, fz_tdoa, colors, fig_dir)
    fig = single_panel_figure(3.50, 1.82);
    ax = axes(fig);
    y_sdr = log_plot_values(sdr_tdoa.position_error);
    y_fuzzy = log_plot_values(fz_tdoa.position_error);
    h1 = semilogy(ax, sdr_tdoa.t, y_sdr, '--', ...
        'LineWidth', 1.05, 'Color', colors.base_light, 'Marker', 's', ...
        'MarkerSize', 3.0, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', colors.base_light);
    hold(ax, 'on');
    h2 = semilogy(ax, fz_tdoa.t, y_fuzzy, '-', ...
        'LineWidth', 1.20, 'Color', colors.fuzzy, 'Marker', 'o', ...
        'MarkerSize', 3.0, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', colors.fuzzy);
    apply_marker_spacing(h1, numel(sdr_tdoa.t), 8);
    apply_marker_spacing(h2, numel(fz_tdoa.t), 8);
    xlabel(ax, 'Time (s)');
    ylabel(ax, 'Localization error (m)');
    legend(ax, {'SDRZND-3D', 'F-SDNRZND-3D'}, 'Location', 'northeast', ...
        'FontSize', 7.0, 'Box', 'off');
    set_log_ylim_from_data(ax, y_sdr, y_fuzzy);
    style_axis(ax);
    export_panel(fig, fig_dir, 'tfs_tdoa_error');
end

function export_tdoa_trajectory_panel(tdoa_data, fz_tdoa, colors, fig_dir)
    fig = single_panel_figure(3.50, 2.12);
    ax = axes(fig);
    t_truth = linspace(0, tdoa_data.cfg.t_final, 520);
    truth = arrayfun(@target_position, t_truth, 'UniformOutput', false);
    truth = cell2mat(truth);
    idx = unique(round(linspace(1, numel(fz_tdoa.t), min(72, numel(fz_tdoa.t)))));
    plot3(ax, truth(1, :), truth(2, :), truth(3, :), 'k-', 'LineWidth', 1.05);
    hold(ax, 'on');
    plot3(ax, fz_tdoa.x(1, idx), fz_tdoa.x(2, idx), fz_tdoa.x(3, idx), 'o', ...
        'MarkerSize', 2.5, 'MarkerEdgeColor', colors.fuzzy, 'MarkerFaceColor', 'w', ...
        'LineStyle', 'none');
    plot3(ax, tdoa_data.P(1, :), tdoa_data.P(2, :), tdoa_data.P(3, :), '^', ...
        'MarkerSize', 3.4, 'MarkerEdgeColor', colors.sensor, 'MarkerFaceColor', 'w', ...
        'LineStyle', 'none');
    xlabel(ax, 'x (m)');
    ylabel(ax, 'y (m)');
    zlabel(ax, 'z (m)');
    z_values = [truth(3, :), fz_tdoa.x(3, :), tdoa_data.P(3, :)];
    z_span = max(z_values) - min(z_values);
    zlim(ax, [min(z_values) - 0.04 * z_span, max(z_values) + 0.50 * z_span]);
    zticks(ax, [-5, 0, 5]);
    legend(ax, {'True trajectory', 'F-SDNRZND estimate', 'Sensors'}, ...
        'Location', 'northeast', 'FontSize', 6.4, 'Box', 'off');
    view(ax, 42, 22);
    style_axis(ax);
    ax.Box = 'off';
    export_panel(fig, fig_dir, 'tfs_tdoa_trajectory');
end

function export_tdoa_schedule_panel(fz_tdoa, colors, fig_dir)
    fig = single_panel_figure(3.50, 1.56);
    ax = axes(fig);
    plot(ax, fz_tdoa.t, fz_tdoa.phi, '-', 'LineWidth', 1.20, 'Color', colors.fuzzy);
    hold(ax, 'on');
    plot(ax, fz_tdoa.t, fz_tdoa.tau ./ max(fz_tdoa.tau), '--', ...
        'LineWidth', 1.05, 'Color', colors.step);
    xlabel(ax, 'Time (s)');
    ylabel(ax, 'Normalized value');
    ylim(ax, [0, 1.05]);
    legend(ax, {'\phi_f', '\tau_m / max(\tau_m)'}, 'Location', 'east', ...
        'FontSize', 7.0, 'Box', 'off');
    style_axis(ax);
    export_panel(fig, fig_dir, 'tfs_tdoa_schedule');
end

function export_vehicle_error_panel(t_base, e_base, t_fuzzy, e_fuzzy, y_label, basename, colors, fig_dir)
    fig = single_panel_figure(3.50, 1.56);
    ax = axes(fig);
    y_base = log_plot_values(e_base);
    y_fuzzy = log_plot_values(e_fuzzy);
    h1 = semilogy(ax, t_base, y_base, '--', ...
        'LineWidth', 1.05, 'Color', colors.base_light, 'Marker', 's', ...
        'MarkerSize', 3.0, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', colors.base_light);
    hold(ax, 'on');
    h2 = semilogy(ax, t_fuzzy, y_fuzzy, '-', ...
        'LineWidth', 1.20, 'Color', colors.fuzzy, 'Marker', 'o', ...
        'MarkerSize', 3.0, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', colors.fuzzy);
    apply_marker_spacing(h1, numel(t_base), 9);
    apply_marker_spacing(h2, numel(t_fuzzy), 9);
    xlabel(ax, 'Time (s)');
    ylabel(ax, y_label);
    legend(ax, {'SDRZND-CAV', 'F-SDNRZND-CAV'}, 'Location', 'northeast', ...
        'FontSize', 6.8, 'Box', 'off');
    set_log_ylim_from_data(ax, y_base, y_fuzzy);
    style_axis(ax);
    export_panel(fig, fig_dir, basename);
end

function export_vehicle_schedule_panel(fz_vehicle, colors, fig_dir)
    fig = single_panel_figure(3.50, 1.56);
    ax = axes(fig);
    plot(ax, fz_vehicle.t, fz_vehicle.phi, '-', 'LineWidth', 1.20, 'Color', colors.fuzzy);
    hold(ax, 'on');
    plot(ax, fz_vehicle.t, fz_vehicle.tau ./ max(fz_vehicle.tau), '--', ...
        'LineWidth', 1.05, 'Color', colors.step);
    xlabel(ax, 'Time (s)');
    ylabel(ax, 'Normalized value');
    ylim(ax, [0, 1.05]);
    legend(ax, {'\phi_f', '\tau_m / max(\tau_m)'}, 'Location', 'northeast', ...
        'FontSize', 7.0, 'Box', 'off');
    style_axis(ax);
    export_panel(fig, fig_dir, 'tfs_vehicle_schedule');
end

function fig = single_panel_figure(width, height)
    fig = figure('Color', 'w', 'Units', 'inches', 'Position', [1, 1, width, height]);
end

function export_panel(fig, fig_dir, basename)
    prepare_fig(fig);
    set(findall(fig, 'Type', 'legend'), 'Color', 'none', 'Box', 'off');
    tfs_audit_error_axes(fig, basename, fileparts(fig_dir));
    exportgraphics(fig, fullfile(fig_dir, [basename '.pdf']), 'ContentType', 'vector');
    exportgraphics(fig, fullfile(fig_dir, [basename '.png']), 'Resolution', 180);
    close(fig);
end

function y = log_plot_values(raw)
    y = raw;
    y(~isfinite(y) | y <= 0) = NaN;
end

function set_log_ylim_from_data(ax, varargin)
    vals = [];
    for ii = 1:numel(varargin)
        data = varargin{ii};
        vals = [vals; data(:)]; %#ok<AGROW>
    end
    vals = vals(isfinite(vals) & vals > 0);
    if isempty(vals)
        return;
    end
    lo = min(vals) / 1.05;
    hi = max(vals) * 1.05;
    lower = 10 ^ floor(log10(lo));
    upper = 10 ^ ceil(log10(hi));
    if upper <= lower
        upper = lower * 10;
    end
    ylim(ax, [lower, upper]);
end

function apply_marker_spacing(line_handle, n_points, n_markers)
    if isprop(line_handle, 'MarkerIndices') && n_points > 1
        line_handle.MarkerIndices = unique(round(linspace(1, n_points, min(n_markers, n_points))));
    end
end

function style_axis(ax)
    grid(ax, 'on');
    ax.GridLineStyle = ':';
    ax.GridAlpha = 0.22;
    ax.FontName = 'Times New Roman';
    ax.FontSize = 8.0;
    ax.LineWidth = 0.65;
    ax.Box = 'on';
    ax.TickDir = 'out';
    if isprop(ax, 'Toolbar')
        ax.Toolbar.Visible = 'off';
    end
end

function prepare_fig(fig)
    set(fig, 'PaperUnits', 'inches');
    set(fig, 'PaperPositionMode', 'auto');
    axes_handles = findall(fig, 'Type', 'axes');
    for aa = 1:numel(axes_handles)
        axes_handles(aa).FontName = 'Times New Roman';
        axes_handles(aa).FontSize = 8.0;
        axes_handles(aa).LineWidth = 0.65;
    end
end

function s = target_position(t)
    s = [5 * cos(t); 5 * sin(t); 5 * cos(4 * t)];
end
