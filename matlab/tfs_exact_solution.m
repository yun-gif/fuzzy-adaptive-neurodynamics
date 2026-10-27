function x_star = tfs_exact_solution(t_vec)
%TFS_EXACT_SOLUTION Analytical solution for the nonlinear SoNE benchmark.

    t_vec = t_vec(:).';
    x_star = [
        exp(1 ./ (t_vec + 1));
        sin(t_vec);
        2 - exp(2 ./ (t_vec + 1)) + sin(t_vec).^2;
        t_vec - 2
    ];
end
