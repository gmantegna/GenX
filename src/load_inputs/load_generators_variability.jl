@doc raw"""
	load_generators_variability!(setup::Dict, path::AbstractString, inputs::Dict)

Read input parameters related to hourly maximum capacity factors for generators, storage, and flexible demand resources
"""
function load_generators_variability!(setup::Dict, path::AbstractString, inputs::Dict)

    # Hourly capacity factors
    TDR_directory = joinpath(path, setup["TimeDomainReductionFolder"])
    # if TDR is used, my_dir = TDR_directory, else my_dir = "system"
    my_dir = get_systemfiles_path(setup, TDR_directory, path)

    filename = "Generators_variability.csv"
    gen_var = load_dataframe(joinpath(my_dir, filename))
    
    assets = inputs["GENERIC_ASSETS"]
    generators = setdiff(collect(1:inputs["G"]),assets)
    all_resources = inputs["RESOURCE_NAMES"][generators]

    existing_variability = names(gen_var)
    for r in all_resources
        if r ∉ existing_variability
            @info "assuming availability of 1.0 for resource $r."
            ensure_column!(gen_var, r, 1.0)
        end
    end

    # Reorder DataFrame to R_ID order
    select!(gen_var, [:Time_Index; Symbol.(all_resources)])

    # Maximum power output and variability of each energy resource
    inputs["pP_Max"] = transpose(Matrix{Float64}(gen_var[1:inputs["T"],
        2:(length(generators) + 1)]))

    println(filename * " Successfully Read!")
end

@doc raw"""
	load_generators_pmin!(setup::Dict, path::AbstractString, inputs::Dict)

Read input parameters related to hourly minimum generation
"""
function load_generators_pmin!(setup::Dict, path::AbstractString, inputs::Dict)

    # Hourly capacity factors
    TDR_directory = joinpath(path, setup["TimeDomainReductionFolder"])
    # if TDR is used, my_dir = TDR_directory, else my_dir = "system"
    my_dir = get_systemfiles_path(setup, TDR_directory, path)

    filename = "Generators_Pmin.csv"
    gen_var = load_dataframe(joinpath(my_dir, filename))
    
    assets = inputs["GENERIC_ASSETS"]
    generators = setdiff(collect(1:inputs["G"]),assets)
    all_resources = inputs["RESOURCE_NAMES"][generators]

    existing_variability = names(gen_var)
    for r in all_resources
        if r ∉ existing_variability
            @info "assuming minimum gen of 0.0 for resource $r."
            ensure_column!(gen_var, r, 0.0)
        end
    end

    # Reorder DataFrame to R_ID order
    select!(gen_var, [:Time_Index; Symbol.(all_resources)])

    # Maximum power output and variability of each energy resource
    inputs["pP_Min"] = transpose(Matrix{Float64}(gen_var[1:inputs["T"],
        2:(length(generators) + 1)]))

    println(filename * " Successfully Read!")
end

@doc raw"""
	load_generators_fixed_dispatch!(setup::Dict, path::AbstractString, inputs::Dict)

Read input parameters related to hourly fixed dispatch
"""
function load_generators_fixed_dispatch!(setup::Dict, path::AbstractString, inputs::Dict)

    # Hourly capacity factors
    TDR_directory = joinpath(path, setup["TimeDomainReductionFolder"])
    # if TDR is used, my_dir = TDR_directory, else my_dir = "system"
    my_dir = get_systemfiles_path(setup, TDR_directory, path)

    filename = "Generators_fixed_dispatch.csv"

    inputs["df_fixed_dispatch"] = load_dataframe(joinpath(my_dir, filename))
    println(filename * " Successfully Read!")
end

