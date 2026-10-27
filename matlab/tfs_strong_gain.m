function Pi_m = tfs_strong_gain(t, cfg)
%TFS_STRONG_GAIN Strong-initial-state coefficient Pi(t).

    lambda_m = (10^(floor(log10(cfg.beta)) + 1) - cfg.beta) * exp(-cfg.beta * t);
    Pi_m = cfg.xi * (lambda_m + cfg.beta) / cfg.alpha;
end
