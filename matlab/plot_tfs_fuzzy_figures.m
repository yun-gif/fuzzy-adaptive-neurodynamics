function plot_tfs_fuzzy_figures(mode)
%PLOT_TFS_FUZZY_FIGURES IEEE-sized figures for the fuzzy-system evidence.
    if nargin < 1
        mode = "all";
    end

    results_path = fullfile(pwd, 'results', 'tfs_numerical_results.mat');
    if ~exist(results_path, 'file')
        error('Run run_tfs_numerical_metrics first.');
    end
    load(results_path, 'results', 'cfg'); %#ok<LOAD>

    fig_dir = fullfile(pwd, 'results', 'figures');
    if ~exist(fig_dir, 'dir')
        mkdir(fig_dir);
    end

    set(groot, 'defaultAxesFontName', 'Times New Roman');
    set(groot, 'defaultTextFontName', 'Times New Roman');
    set(groot, 'defaultAxesFontSize', 8);
    set(groot, 'defaultTextFontSize', 8);

    if strcmpi(string(mode), "runtime_only")
        warning('Grouped runtime export is disabled; the manuscript uses single-panel exports composed by LaTeX.');
        return;
    end

    if strcmpi(string(mode), "residual_only")
        make_residual_figure(results, fig_dir, true);
        return;
    end

    params = local_fuzzy_params(cfg);
    if strcmpi(string(mode), "regulator_only")
        make_regulator_definition_figure(params, fig_dir);
        return;
    end

    make_regulator_definition_figure(params, fig_dir);
    make_residual_figure(results, fig_dir);
end

function params = local_fuzzy_params(cfg)
    params.delta = cfg.delta;
    params.q_m = 0.5;
    params.q_h = 0.8;
    params.eps_e = 1e-12;
    params.eps_d = 1e-12;
    params.e_ref = 1;
    params.c_r = [0, 0.5, 1];
    params.sigma_r = [0.20, 0.20, 0.20];
    params.c_d = [-1, 0, 1];
    params.sigma_d = [0.35, 0.35, 0.35];
    params.Q = [
        params.delta, params.delta, params.q_m;
        params.q_m,   params.q_m,   params.q_h;
        params.q_h,   1,            1
    ];
end

function make_regulator_definition_figure(params, fig_dir)
    export_regulator_membership_panel(params, fig_dir, 'magnitude');
    export_regulator_membership_panel(params, fig_dir, 'trend');
    export_regulator_surface_panel(params, fig_dir);
end

function export_regulator_membership_panel(params, fig_dir, panel_type)
    labels_r = {'Small', 'Medium', 'Large'};
    labels_d = {'Decreasing', 'Steady', 'Increasing'};
    colors = line_palette();
    fig = figure('Color', 'w', 'Units', 'inches', 'Position', [1, 1, 2.30, 1.65]);
    ax = axes(fig);
    hold(ax, 'on');

    if strcmp(panel_type, 'magnitude')
        x = linspace(0, 1, 300);
        for ii = 1:3
            y = exp(-((x - params.c_r(ii)).^2) ./ (2 * params.sigma_r(ii)^2));
            plot(ax, x, y, 'LineWidth', 1.1, 'Color', colors(ii, :), 'LineStyle', line_style(ii));
        end
        xlabel(ax, 'Residual magnitude r_m');
        text(ax, 0.08, 0.88, labels_r{1}, 'Color', colors(1, :), 'FontSize', 7);
        text(ax, 0.42, 0.84, labels_r{2}, 'Color', colors(2, :), 'FontSize', 7);
        text(ax, 0.78, 0.84, labels_r{3}, 'Color', colors(3, :), 'FontSize', 7);
        basename = 'tfs_regulator_magnitude';
    else
        x = linspace(-1, 1, 300);
        for ii = 1:3
            y = exp(-((x - params.c_d(ii)).^2) ./ (2 * params.sigma_d(ii)^2));
            plot(ax, x, y, 'LineWidth', 1.1, 'Color', colors(ii, :), 'LineStyle', line_style(ii));
        end
        xlabel(ax, 'Residual trend d_m');
        text(ax, -0.86, 0.88, labels_d{1}, 'Color', colors(1, :), 'FontSize', 7);
        text(ax, -0.18, 0.84, labels_d{2}, 'Color', colors(2, :), 'FontSize', 7);
        text(ax, 0.58, 0.84, labels_d{3}, 'Color', colors(3, :), 'FontSize', 7);
        basename = 'tfs_regulator_trend';
    end

    ylabel(ax, 'Membership grade');
    ylim(ax, [0, 1.05]);
    grid(ax, 'on');
    box(ax, 'on');
    export_single_panel(fig, fullfile(fig_dir, basename));
end

function export_regulator_surface_panel(params, fig_dir)
    [R, D] = meshgrid(linspace(0, 1, 160), linspace(-1, 1, 160));
    Phi = arrayfun(@(rr, dd) local_phi(rr, dd, params), R, D);
    fig = figure('Color', 'w', 'Units', 'inches', 'Position', [1, 1, 2.30, 1.65]);
    ax = axes(fig);
    contourf(ax, R, D, Phi, 10, 'LineStyle', 'none');
    hold(ax, 'on');
    contour(ax, R, D, Phi, 6, 'LineColor', [0.15, 0.15, 0.15], 'LineWidth', 0.35);
    colormap(ax, blue_gray_map());
    cb = colorbar;
    cb.Label.Interpreter = 'latex';
    cb.Label.String = '$\varphi_f$';
    xlabel(ax, 'Residual magnitude r_m');
    ylabel(ax, 'Residual trend d_m');
    caxis(ax, [params.delta, 1]);
    box(ax, 'on');
    export_single_panel(fig, fullfile(fig_dir, 'tfs_regulator_surface'));
end

function make_membership_figure(params, fig_dir)
    fig = figure('Color', 'w', 'Units', 'inches', 'Position', [1, 1, 7.16, 2.25]);
    tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

    r = linspace(0, 1, 400);
    d = linspace(-1, 1, 400);
    labels_r = {'Small', 'Medium', 'Large'};
    labels_d = {'Decreasing', 'Steady', 'Increasing'};
    colors = okabe_ito();

    nexttile;
    hold on;
    for i = 1:3
        y = exp(-((r - params.c_r(i)).^2) ./ (2 * params.sigma_r(i)^2));
        plot(r, y, 'LineWidth', 1.1, 'Color', colors(i, :), 'LineStyle', line_style(i));
    end
    xlabel('Residual magnitude r_m');
    ylabel('Membership grade');
    legend(labels_r, 'Location', 'southoutside', 'NumColumns', 3, 'Box', 'off');
    ylim([0, 1.05]);
    grid on;
    box on;
    title('(a)');

    nexttile;
    hold on;
    for i = 1:3
        y = exp(-((d - params.c_d(i)).^2) ./ (2 * params.sigma_d(i)^2));
        plot(d, y, 'LineWidth', 1.1, 'Color', colors(i, :), 'LineStyle', line_style(i));
    end
    xlabel('Residual trend d_m');
    ylabel('Membership grade');
    legend(labels_d, 'Location', 'southoutside', 'NumColumns', 3, 'Box', 'off');
    ylim([0, 1.05]);
    grid on;
    box on;
    title('(b)');

    save_ieee(fig, fullfile(fig_dir, 'tfs_membership_functions'));
end

function make_control_surface_figure(params, fig_dir)
    r = linspace(0, 1, 180);
    d = linspace(-1, 1, 180);
    [R, D] = meshgrid(r, d);
    Phi = arrayfun(@(rr, dd) local_phi(rr, dd, params), R, D);

    fig = figure('Color', 'w', 'Units', 'inches', 'Position', [1, 1, 3.5, 2.65]);
    contourf(R, D, Phi, 12, 'LineStyle', 'none');
    hold on;
    contour(R, D, Phi, 6, 'LineColor', [0.15, 0.15, 0.15], 'LineWidth', 0.35);
    colormap(cividis_map());
    cb = colorbar;
    cb.Label.Interpreter = 'latex';
    cb.Label.String = 'Fuzzy step factor $\varphi_f$';
    xlabel('Residual magnitude r_m');
    ylabel('Residual trend d_m');
    caxis([params.delta, 1]);
    box on;
    save_ieee(fig, fullfile(fig_dir, 'tfs_control_surface'));
end

function make_residual_figure(results, fig_dir, pdf_only)
    if nargin < 3
        pdf_only = false;
    end
    methods = ["TDZND_E", "ADZND_E", "DTND", "SDRZND_E", "F_SDNRZND"];
    labels = ["TDZND-E", "ADZND-E", "DTND", "SDRZND-E", "F-SDNRZND"];
    noises = ["none", "constant", "time_varying"];
    noise_labels = ["noise-free", "constant", "time-varying"];
    panel_names = ["tfs_residuals_nf", "tfs_residuals_cn", "tfs_residuals_tvn"];
    % Match the blue and neutral tones used by the application panels.
    colors = [0.18, 0.18, 0.18; 0.38, 0.38, 0.38; ...
        0.25, 0.25, 0.25; 0.45, 0.45, 0.45; 0.00, 0.36, 0.68];

    for ni = 1:numel(noises)
        fig = figure('Color', 'w', 'Units', 'inches', 'Position', [1, 1, 2.30, 2.18]);
        ax = axes(fig);
        hold(ax, 'on');
        noise_key = matlab.lang.makeValidName(noises(ni));
        y_limits = residual_y_limits(results, noises(ni), labels);
        curve_handles = gobjects(numel(methods), 1);
        for mi = 1:numel(methods)
            method_key = matlab.lang.makeValidName(labels(mi));
            if isfield(results.(noise_key), method_key)
                res = results.(noise_key).(method_key);
                y = max(res.residual_norm, 1e-15);
                curve_idx = 1:numel(res.t);
                marker_idx = sparse_markers(res.t(curve_idx));
                curve_handles(mi) = semilogy(ax, res.t(curve_idx), y(curve_idx), ...
                    'DisplayName', char(labels(mi)), ...
                    'LineWidth', residual_line_width(mi), ...
                    'Color', colors(mi, :), ...
                    'LineStyle', line_style(mi), ...
                    'Marker', marker_style(mi), ...
                    'MarkerSize', residual_marker_size(mi), ...
                    'MarkerIndices', marker_idx, ...
                    'MarkerFaceColor', 'w', ...
                    'MarkerEdgeColor', colors(mi, :));
            end
        end
        xlabel(ax, 'Time (s)');
        ylabel(ax, 'Residual norm (log)');
        set(ax, 'YScale', 'log');
        ylim(ax, y_limits);
        grid(ax, 'on');
        ax.GridAlpha = 0.16;
        ax.MinorGridAlpha = 0.08;
        ax.YMinorGrid = 'on';
        valid_handles = isgraphics(curve_handles);
        legend(ax, curve_handles(valid_handles), cellstr(labels(valid_handles)), ...
            'Location', 'northoutside', 'Orientation', 'vertical', ...
            'NumColumns', 1, 'Box', 'off', 'FontSize', 5.6);
        box(ax, 'on');
        export_single_panel(fig, fullfile(fig_dir, panel_names(ni)));
    end

end

function export_metric_matrix_panel(T, labels, fig_dir)
    metric_names = ["steady_residual_rmse", "settling_time", "final_error_norm"];
    metric_labels = ["RMSE", "Settling", "Final error"];
    noise_names = ["none", "constant", "time_varying"];
    noise_labels = ["free", "constant", "time-varying"];
    display_labels = ["M1", "M2", "M3", "M4", "M5"];

    n_metrics = numel(metric_names);
    n_methods = numel(labels);
    n_noises = numel(noise_names);
    Z = nan(n_noises * n_metrics, n_methods);
    row_labels = strings(n_noises * n_metrics, 1);

    for ni = 1:n_noises
        for qi = 1:n_metrics
            row_idx = (ni - 1) * n_metrics + qi;
            row_labels(row_idx) = noise_labels(ni) + " | " + metric_labels(qi);
        end
        for mi = 1:numel(labels)
            for qi = 1:n_metrics
                row_idx = (ni - 1) * n_metrics + qi;
                row = T.method == labels(mi) & T.noise == noise_names(ni);
                if ~any(row)
                    continue;
                end
                val = T.(metric_names(qi))(find(row, 1));
                if isfinite(val) && val > 0
                    Z(row_idx, mi) = log10(val);
                end
            end
        end
    end

    finite_vals = Z(isfinite(Z));
    if isempty(finite_vals)
        finite_vals = 0;
    end
    fig = figure('Color', 'w', 'Units', 'inches', 'Position', [1, 1, 6.90, 1.28]);
    ax = axes(fig);
    imagesc(ax, Z, 'AlphaData', isfinite(Z));
    hold(ax, 'on');
    set(ax, 'Color', [0.92, 0.92, 0.92]);
    colormap(ax, blue_gray_map());
    caxis(ax, [min(finite_vals), max(finite_vals)]);
    cb = colorbar;
    cb.Label.String = 'log_{10}(metric)';
    xticks(ax, 1:n_methods);
    xticklabels(ax, display_labels);
    yticks(ax, 1:(n_noises * n_metrics));
    yticklabels(ax, row_labels);
    set(ax, 'TickLength', [0, 0]);
    for ni = 1:(n_noises - 1)
        yline(ax, ni * n_metrics + 0.5, '-', 'Color', [1, 1, 1], 'LineWidth', 1.0);
    end
    for mi = 1:(n_methods - 1)
        xline(ax, mi + 0.5, '-', 'Color', [1, 1, 1], 'LineWidth', 0.6);
    end
    for row_idx = 1:size(Z, 1)
        for mi = 1:size(Z, 2)
            if ~isfinite(Z(row_idx, mi))
                text(ax, mi, row_idx, 'x', 'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'middle', 'FontSize', 8.5, ...
                    'FontWeight', 'bold', 'Color', [0.10, 0.10, 0.10]);
            end
        end
    end
    box(ax, 'on');
    export_single_panel(fig, fullfile(fig_dir, 'tfs_residuals_summary'));
end

function make_runtime_fuzzy_figure(results, fig_dir)
    res = results.time_varying.F_SDNRZND;
    fig = figure('Color', 'w', 'Units', 'inches', 'Position', [1, 1, 3.5, 3.0]);
    tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

    nexttile;
    plot(res.t, res.phi, 'LineWidth', 1.1, 'Color', [0, 0.45, 0.70]);
    ylabel('$\varphi_f(m)$', 'Interpreter', 'latex');
    title('(a)');
    grid on;
    box on;

    nexttile;
    plot(res.t, res.tau, 'LineWidth', 1.1, 'Color', [0.80, 0.40, 0]);
    xlabel('Time (s)');
    ylabel('\tau_m');
    title('(b)');
    grid on;
    box on;

    save_ieee(fig, fullfile(fig_dir, 'tfs_runtime_phi_tau'));
end

function make_runtime_rule_summary_figure(results, fig_dir, pdf_only)
    if nargin < 3
        pdf_only = false;
    end
    res = results.time_varying.F_SDNRZND;
    W = reshape(res.rule_strengths, 9, []).';
    [~, dominant] = max(W, [], 2);
    params = local_fuzzy_params(res.cfg);
    r_grid = linspace(0, 1, 120);
    d_grid = linspace(-1, 1, 120);
    [R, D] = meshgrid(r_grid, d_grid);
    Phi = arrayfun(@(rr, dd) local_phi(rr, dd, params), R, D);

    fig = figure('Color', 'w', 'Units', 'inches', 'Position', [1, 1, 7.16, 4.25]);
    tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    colors = okabe_ito();

    nexttile;
    contourf(R, D, Phi, 10, 'LineStyle', 'none');
    hold on;
    contour(R, D, Phi, 5, 'LineColor', [0.15, 0.15, 0.15], 'LineWidth', 0.30);
    curve_idx = sparse_curve_indices(res.t);
    scatter(res.r(curve_idx), res.d(curve_idx), 8, res.t(curve_idx), ...
        'filled', 'MarkerFaceAlpha', 0.55, 'MarkerEdgeAlpha', 0.55);
    colormap(gca, cividis_map());
    cb = colorbar;
    cb.Label.String = 'Time (s)';
    xlabel('Residual magnitude r_m');
    ylabel('Residual trend d_m');
    title('(a) Antecedent trajectory on rule surface');
    xlim([0, 1]);
    ylim([-1, 1]);
    box on;

    nexttile;
    plot(res.t, res.phi, 'LineWidth', 1.15, 'Color', [0.00, 0.45, 0.70]);
    hold on;
    y_band = 0.035 + 0.012 * dominant(:);
    scatter(res.t, y_band, 6, dominant, 's', 'filled', ...
        'MarkerFaceAlpha', 0.45, 'MarkerEdgeAlpha', 0.45);
    colormap(gca, cividis_map());
    cb = colorbar;
    cb.Label.String = 'Dominant rule index';
    cb.Ticks = 1:2:9;
    labels = rule_labels();
    cb.TickLabels = labels(1:2:9);
    xlim([res.t(1), res.t(end)]);
    ylim([0, 1.02]);
    xlabel('Time (s)');
    ylabel('$\varphi_f(m)$', 'Interpreter', 'latex');
    title('(b) Step factor with dominant-rule strip', 'Interpreter', 'latex');
    grid on;
    box on;

    nexttile;
    occ_edges = linspace(res.t(1), res.t(end), 55);
    occ_mid = 0.5 * (occ_edges(1:end-1) + occ_edges(2:end));
    occ = zeros(3, numel(occ_mid));
    for kk = 1:numel(occ_mid)
        in_bin = res.t >= occ_edges(kk) & res.t < occ_edges(kk + 1);
        if kk == numel(occ_mid)
            in_bin = res.t >= occ_edges(kk) & res.t <= occ_edges(kk + 1);
        end
        if any(in_bin)
            occ(:, kk) = mean(squeeze(sum(res.rule_strengths(:, :, in_bin), 2)), 2);
        end
    end
    colororder(colors(1:3, :));
    area(occ_mid, occ.', 'LineStyle', 'none');
    xlabel('Time (s)');
    ylabel('Occupancy');
    title('(c) Residual-magnitude occupancy');
    legend({'Small', 'Medium', 'Large'}, 'Location', 'northoutside', ...
        'Orientation', 'horizontal', 'Box', 'off');
    xlim([res.t(1), res.t(end)]);
    ylim([0, 1]);
    grid on;
    box on;

    nexttile;
    W_mean = mean(res.rule_strengths, 3);
    imagesc(W_mean, [0, max(0.05, max(W_mean(:)))]);
    axis image;
    colormap(gca, cividis_map());
    cb = colorbar;
    cb.Label.String = 'Mean firing strength';
    xlabel('Trend');
    ylabel('Magnitude');
    xticks(1:3);
    yticks(1:3);
    xticklabels({'Dec.', 'Steady', 'Inc.'});
    yticklabels({'Small', 'Med.', 'Large'});
    for rr = 1:3
        for cc = 1:3
            txt_color = [0, 0, 0];
            if W_mean(rr, cc) > 0.55 * max(W_mean(:))
                txt_color = [1, 1, 1];
            end
            text(cc, rr, sprintf('%.2f', W_mean(rr, cc)), ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle', ...
                'FontSize', 7.0, ...
                'Color', txt_color);
        end
    end
    title('(d) Aggregate rule firing');
    box on;

    if pdf_only
        save_ieee_pdf(fig, fullfile(fig_dir, 'tfs_runtime_rule_summary'));
    else
        save_ieee(fig, fullfile(fig_dir, 'tfs_runtime_rule_summary'));
    end
end

function make_rule_heatmap_figure(results, fig_dir)
    res = results.time_varying.F_SDNRZND;
    n = numel(res.t);
    idx = unique(max(1, min(n, [2, round(0.5 * n), n])));
    while numel(idx) < 3
        idx(end + 1) = idx(end); %#ok<AGROW>
    end

    fig = figure('Color', 'w', 'Units', 'inches', 'Position', [1, 1, 7.16, 2.1]);
    tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    for ii = 1:3
        nexttile;
        W = res.rule_strengths(:, :, idx(ii));
        imagesc(W, [0, 1]);
        axis image;
        colormap(cividis_map());
        cb = colorbar;
        cb.Label.String = 'Rule-firing strength';
        xlabel('Trend rule');
        ylabel('Magnitude rule');
        xticks(1:3);
        yticks(1:3);
        xticklabels({'Dec.', 'Steady', 'Inc.'});
        yticklabels({'Small', 'Med.', 'Large'});
        for rr = 1:3
            for cc = 1:3
                txt_color = [0, 0, 0];
                if W(rr, cc) > 0.55
                    txt_color = [1, 1, 1];
                end
                text(cc, rr, sprintf('%.2f', W(rr, cc)), ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'middle', ...
                    'FontSize', 6.5, ...
                    'Color', txt_color);
            end
        end
        title(sprintf('(%c) t=%.2f s', char('a' + ii - 1), res.t(idx(ii))));
        box on;
    end
    save_ieee(fig, fullfile(fig_dir, 'tfs_rule_firing_heatmaps'));
end

function phi = local_phi(r, d, params)
    mu_r = exp(-((r - params.c_r).^2) ./ (2 * params.sigma_r.^2));
    mu_d = exp(-((d - params.c_d).^2) ./ (2 * params.sigma_d.^2));
    W = mu_r(:) * mu_d(:).';
    phi = sum(sum(W .* params.Q)) / sum(W(:));
    phi = min(1, max(params.delta, phi));
end

function save_ieee(fig, base_path)
    prepare_fig(fig);
    exportgraphics(fig, [base_path '.pdf'], 'ContentType', 'vector');
end

function save_ieee_pdf(fig, base_path)
    prepare_fig(fig);
    exportgraphics(fig, [base_path '.pdf'], 'ContentType', 'vector');
end

function export_single_panel(fig, base_path)
    prepare_fig(fig);
    set(findall(fig, 'Type', 'legend'), 'Color', 'none', 'Box', 'off');
    [folder, name] = fileparts(base_path);
    tfs_audit_error_axes(fig, name, fileparts(folder));
    exportgraphics(fig, char(base_path + ".pdf"), 'ContentType', 'vector');
    close(fig);
end

function prepare_fig(fig)
    set(fig, 'PaperUnits', 'inches');
    set(fig, 'PaperPositionMode', 'auto');
    axes_handles = findall(fig, 'Type', 'axes');
    for aa = 1:numel(axes_handles)
        if isprop(axes_handles(aa), 'Toolbar')
            axes_handles(aa).Toolbar.Visible = 'off';
        end
        axes_handles(aa).FontName = 'Times New Roman';
        axes_handles(aa).FontSize = 8;
        axes_handles(aa).LineWidth = 0.6;
    end
end

function colors = line_palette()
    colors = [
        0.20, 0.20, 0.20;  % dark gray
        0.55, 0.55, 0.55;  % medium gray
        0.05, 0.05, 0.05;  % near black
        0.68, 0.68, 0.68;  % light gray
        0.00, 0.36, 0.68;  % proposed method
        0.62, 0.62, 0.62
    ];
end

function labels = rule_labels()
    labels = {'S-D', 'M-D', 'L-D', 'S-S', 'M-S', 'L-S', 'S-I', 'M-I', 'L-I'};
end

function colors = okabe_ito()
    colors = [
        0.00, 0.45, 0.70;
        0.90, 0.62, 0.00;
        0.00, 0.62, 0.45;
        0.80, 0.47, 0.65;
        0.84, 0.37, 0.00;
        0.35, 0.70, 0.90
    ];
end

function cmap = cividis_map()
    anchors = [
        0.0000, 0.1262, 0.3015;
        0.0000, 0.2117, 0.4388;
        0.2300, 0.2820, 0.4180;
        0.3720, 0.3650, 0.4160;
        0.4820, 0.4550, 0.3860;
        0.6030, 0.5480, 0.2990;
        0.7350, 0.6540, 0.2020;
        0.8690, 0.7530, 0.1170;
        0.9960, 0.9090, 0.2180
    ];
    x = linspace(0, 1, size(anchors, 1));
    xi = linspace(0, 1, 256);
    cmap = interp1(x, anchors, xi, 'linear');
end

function cmap = blue_gray_map()
    anchors = [
        0.96, 0.97, 0.98;
        0.80, 0.85, 0.90;
        0.58, 0.68, 0.78;
        0.34, 0.50, 0.66;
        0.12, 0.32, 0.52;
        0.04, 0.18, 0.32
    ];
    x = linspace(0, 1, size(anchors, 1));
    xi = linspace(0, 1, 256);
    cmap = interp1(x, anchors, xi, 'linear');
end

function s = line_style(i)
    styles = {'-', '--', ':', '-.', '-'};
    s = styles{mod(i - 1, numel(styles)) + 1};
end

function m = marker_style(i)
    markers = {'o', 's', '^', 'd', 'p'};
    m = markers{mod(i - 1, numel(markers)) + 1};
end

function idx = sparse_markers(t)
    n = numel(t);
    if n < 20
        idx = 1:n;
    else
        idx = round(linspace(1, n, 9));
    end
end

function idx = sparse_curve_indices(t)
    n = numel(t);
    max_points = 650;
    if n <= max_points
        idx = 1:n;
    else
        idx = unique(round(linspace(1, n, max_points)));
    end
end

function yl = residual_y_limits(results, noises, labels)
    y_min = inf;
    y_max = 0;
    for ni = 1:numel(noises)
        noise_key = matlab.lang.makeValidName(noises(ni));
        for mi = 1:numel(labels)
            method_key = matlab.lang.makeValidName(labels(mi));
            if isfield(results.(noise_key), method_key)
                y = max(results.(noise_key).(method_key).residual_norm, 1e-15);
                y = y(isfinite(y) & y > 0);
                if ~isempty(y)
                    y_min = min(y_min, min(y));
                    y_max = max(y_max, max(y));
                end
            end
        end
    end
    if ~isfinite(y_min) || y_max <= 0
        yl = [1e-12, 1];
    else
        log_lo = log10(y_min);
        log_hi = log10(y_max);
        log_margin = max(0.08, 0.05 * (log_hi - log_lo));
        yl = 10 .^ [log_lo - log_margin, log_hi + log_margin];
    end
end

function lw = residual_line_width(i)
    widths = [0.85, 0.85, 0.90, 1.05, 1.20];
    lw = widths(mod(i - 1, numel(widths)) + 1);
end

function ms = residual_marker_size(i)
    sizes = [2.6, 2.6, 2.8, 3.0, 3.0];
    ms = sizes(mod(i - 1, numel(sizes)) + 1);
end
