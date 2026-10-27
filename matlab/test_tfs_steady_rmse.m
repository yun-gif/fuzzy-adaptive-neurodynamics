function test_tfs_steady_rmse()
% Analytical checks cover irregular sampling and common-window boundaries.
    t = [0, 8.9, 9.2, 9.7, 10];
    exact = sqrt((10^3 - 9^3) / 3);
    assert(abs(tfs_steady_rmse(t, t, 10, 0.3, "completed") - exact) < 1e-12);
    assert(abs(tfs_steady_rmse([0, 9, 10], [0, 9, 10], 10, 1, "completed") - exact) < 1e-12);
    [value, info] = tfs_steady_rmse(t, t, 10, 0.3, "completed", 9.5);
    expected = sqrt((9.5^3 - 9^3) / (3 * 0.5));
    assert(abs(value - expected) < 1e-12 && info.endpoint_hold == 0);
    assert(abs(tfs_steady_rmse(t, [t; -2*t], 10, 0.3, "completed") - sqrt(2.5)*exact) < 1e-12);
    assert(isnan(tfs_steady_rmse([0, 9, 9.5], [1, 1, 1], 10, 0.1, "completed", 9.6)));
    assert(isnan(tfs_steady_rmse(t, t, 10, 0.3, "diverged")));
    assert(abs(tfs_steady_rmse(t, ones(size(t))*3, 10, 0.3, "completed") - 3) < 1e-14);
    assert(abs(tfs_steady_rmse([0, 9, 10], [0, -1, 1], 10, 1, "completed") - sqrt(1/3)) < 1e-14);
    assert(isnan(tfs_steady_rmse(t, t, 10, 0.3, "completed", 9)));
    assert(abs(tfs_steady_rmse([0, 9, 9.5], [0, 9, 9.5], 10, 0.5, "completed", 9.5) - value) < 1e-12);
    fprintf('PASS: 10 analytical steady-RMSE checks.\n');
end
