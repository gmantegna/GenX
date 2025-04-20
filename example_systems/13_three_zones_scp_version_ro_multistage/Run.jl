using GenX
using Gurobi
using Plasmo

run_genx_case!(dirname(@__FILE__),Gurobi.Optimizer);