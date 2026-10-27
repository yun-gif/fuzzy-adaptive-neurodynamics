# Model and benchmark attribution

Bibliographic information below is carried over from the accompanying manuscript. This package implements the equations and comparison protocols specified in that manuscript; it does not claim to redistribute the original authors' implementations or reproduce every algorithmic detail of these papers.

- Takagi, T., and Sugeno, M. (1985). Fuzzy identification of systems and its applications to modeling and control. IEEE Transactions on Systems, Man, and Cybernetics, SMC-15(1), 116-132. Background for the rule-based fuzzy regulator.
- Xiao, X., Fu, D., Wang, G., Liao, S., Qi, Y., Huang, H., and Jin, L. (2020). Two neurodynamics approaches for computing system of time-varying nonlinear equations. Neurocomputing, 394, 84-94. Numerical benchmark source.
- Guo, J., and Zhang, Y. (2021). Stepsize Interval Confirmation of General Four-Step DTZN Algorithm Illustrated With Future Quadratic Programming and Tracking Control of Manipulators. IEEE Transactions on Systems, Man, and Cybernetics: Systems, 51(3), 1662-1670. Related discrete neurodynamics.
- Wu, W., and Zhang, Y. (2023). Novel adaptive zeroing neurodynamics schemes for temporally-varying linear equation handling applied to arm path following and target motion positioning. Neural Networks, 165, 435-450. Related adaptive neurodynamics.
- Qi, Y., Jin, L., Wang, Y., Xiao, L., and Zhang, J. (2020). Complex-Valued Discrete-Time Neural Dynamics for Perturbed Time-Dependent Complex Quadratic Programming With Applications. IEEE Transactions on Neural Networks and Learning Systems, 31(9), 3555-3569. Related noise-resistant discrete dynamics.
- Jin, L., Yan, J., Du, X., Xiao, X., and Fu, D. (2020). RNN for Solving Time-Variant Generalized Sylvester Equation With Applications to Robots and Acoustic Source Localization. IEEE Transactions on Industrial Informatics, 16(10), 6359-6369. Related acoustic-localization application.
- Ning, B., Han, Q.-L., Ge, X., and Sanjayan, J. (2024). A Zeroing Neural Network-Based Approach to Parameter-Varying Platooning Control of Connected Automated Vehicles. IEEE Transactions on Intelligent Vehicles, 9(1), 1977-1988. Vehicle formulation followed by the manuscript's solver-embedding experiment.

The numerical Euler comparison implementations and the SDRZND-E baseline are defined in the accompanying manuscript. Application comparisons hold the application equations fixed and compare step schedules. Numerical agreement here concerns those specified implementations, not a benchmark against unmodified external source code.
