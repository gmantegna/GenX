using GenX
using Gurobi

run_genx_case!(dirname(@__FILE__), Gurobi.Optimizer)

# using CPLEX

# run_genx_case!(dirname(@__FILE__), CPLEX.Optimizer)