@doc raw"""
	configure_highs(solver_settings_path::String)

Reads user-specified solver settings from highs\_settings.yml in the directory specified by the string solver\_settings\_path.

Returns a `MathOptInterface.OptimizerWithAttributes` HiGHS optimizer instance to be used in the `GenX.generate_model()` method.

The HiGHS optimizer instance is configured with the following default parameters if a user-specified parameter for each respective field is not provided:
	All the references are in https://github.com/jump-dev/HiGHS.jl, https://github.com/ERGO-Code/HiGHS, and https://highs.dev/

	# HiGHS Solver Parameters
	# Common solver settings
	Feasib_Tol: 1.0e-06        # Primal feasibility tolerance # [type: double, advanced: false, range: [1e-10, inf], default: 1e-07]
	Optimal_Tol: 1.0e-03       # Dual feasibility tolerance # [type: double, advanced: false, range: [1e-10, inf], default: 1e-07]
	TimeLimit: Inf             # Time limit # [type: double, advanced: false, range: [0, inf], default: inf]
	Pre_Solve: choose          # Presolve option: "off", "choose" or "on" # [type: string, advanced: false, default: "choose"]
	Method: ipm #choose        #HiGHS-specific solver settings # Solver option: "simplex", "choose" or "ipm" # [type: string, advanced: false, default: "choose"] In order to run a case when the UCommit is set to 1, i.e. MILP instance, set the Method to choose
	
	# Limit on cost coefficient: values larger than this will be treated as infinite
	# [type: double, advanced: false, range: [1e+15, inf], default: 1e+20]
	infinite_cost: 1e+20
	
	# Limit on |constraint bound|: values larger than this will be treated as infinite
	# [type: double, advanced: false, range: [1e+15, inf], default: 1e+20]
	infinite_bound: 1e+20
	
	# IPM optimality tolerance
	# [type: double, advanced: false, range: [1e-12, inf], default: 1e-08]
	ipm_optimality_tolerance: 1e-08
	
	# Objective bound for termination
	# [type: double, advanced: false, range: [-inf, inf], default: inf]
	objective_bound: Inf
	
	# Objective target for termination
	# [type: double, advanced: false, range: [-inf, inf], default: -inf]
	objective_target: -Inf
"""
function configure_highs(solver_settings_path::String, optimizer::Any)

	solver_settings = YAML.load(open(solver_settings_path))
	solver_settings = convert(Dict{String, Any}, solver_settings)

    default_settings = Dict{String,Any}(
        "Feasib_Tol" => 1e-6,
        "Optimal_Tol" => 1e-4,
        "Pre_Solve" => "choose",
        "TimeLimit" => Inf,
        "Method" => "ipm",
        "infinite_cost" => 1e+20,
        "infinite_bound" => 1e+20,
        "ipm_optimality_tolerance" => 1e-08,
        "objective_bound" => Inf,
        "objective_target" => -Inf,
	"run_crossover" => "off",
    )

    attributes = merge(default_settings, solver_settings)

    key_replacement = Dict("Feasib_Tol" => "primal_feasibility_tolerance",
                           "Optimal_Tol" => "dual_feasibility_tolerance",
                           "TimeLimit" => "time_limit",
                           "Pre_Solve" => "presolve",
                           "Method" => "solver",
                          )

    attributes = rename_keys(attributes, key_replacement)

    attributes::Dict{String, Any}
    return optimizer_with_attributes(optimizer, attributes...)
end
