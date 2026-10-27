function tfs_audit_error_axes(fig, name, out_dir)
%TFS_AUDIT_ERROR_AXES Fail export if any positive log-curve value is clipped.
    axes_list = findall(fig, 'Type', 'axes');
    assert(numel(axes_list) == 1, 'Only single-panel figures may be exported.');
    ax = axes_list(1);
    if ~strcmp(ax.YScale, 'log'), return; end
    lines = findall(ax, 'Type', 'line');
    values = [];
    for k = 1:numel(lines)
        y = lines(k).YData;
        values = [values, y(isfinite(y) & y > 0)]; %#ok<AGROW>
    end
    limits = ylim(ax);
    assert(all(values >= limits(1) & values <= limits(2)), 'Clipped error curve: %s', name);
    row = table(string(name), min(values), max(values), limits(1), limits(2), ...
        'VariableNames', {'figure', 'data_min', 'data_max', 'axis_min', 'axis_max'});
    path = fullfile(out_dir, 'error_plot_audit.csv');
    if exist(path, 'file')
        old = readtable(path, 'TextType', 'string');
        old(old.figure == string(name), :) = [];
        row = [old; row];
    end
    writetable(row, path);
end
