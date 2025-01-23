using GenX, HiGHS

run_genx_case!(dirname(@__FILE__), HiGHS.Optimizer)
