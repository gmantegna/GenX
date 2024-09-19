using GenX
using CPLEX

run_genx_case!(dirname(@__FILE__), CPLEX.Optimizer)