function [Theta, J, dotTheta, x_star] = tfs_theta_numeric(t, x)
%TFS_THETA_NUMERIC Numeric residual, Jacobian, and partial time derivative.
%   This function matches hanshu.m without symbolic evaluation overhead.

    x = x(:);
    x1 = x(1);
    x2 = x(2);
    x3 = x(3);
    x4 = x(4);

    exp_term = exp(1 / (t + 1));
    sin_t = sin(t);
    cos_t = cos(t);

    Theta = [
        log(x1) - 1 / (t + 1);
        x1 * x2 - exp_term * sin_t;
        x1^2 - sin_t * x2 + x3 - 2;
        x1^2 - x2^2 + x3 + x4 - t
    ];

    J = [
        1 / x1, 0, 0, 0;
        x2, x1, 0, 0;
        2 * x1, -sin_t, 1, 0;
        2 * x1, -2 * x2, 1, 1
    ];

    dotTheta = [
        1 / (t + 1)^2;
        exp_term * sin_t / (t + 1)^2 - exp_term * cos_t;
        -cos_t * x2;
        -1
    ];

    x_star = tfs_exact_solution(t);
end
