function default_ro_settings()
    Dict{Any, Any}(
        "BudgetOfUncertainty"=> 0.2, # percentage of uncertain parameters that can take their worst case value, -1 if we want to apply budget for each variable separatly
        "BudgetOfUncertainty_FuelPrices" => -1,
        "BudgetOfUncertainty_InvestmentCost" => -1,
        "BudgetOfUncertainty_FixedOMCost"=> -1,
        "FuelsCost" => 0,
        "InvestmentCost" => 0,
        "FixedOMCost" => 0
        )
end

function load_ro_settings(setup::Dict, path::AbstractString, inputs::Dict)
    println("Configuring RO Settings")
    filename = "ro_settings.yml"
    ro_settings = YAML.load(open(joinpath(path, filename)))
    new_ro_settings = default_ro_settings()
    merge!(new_ro_settings, ro_settings)
    inputs["ro_settings"] = new_ro_settings
    inputs["count_uncertain_param"] = 0
end



function load_fuel_bound_data!(setup::Dict, path::AbstractString, inputs::Dict)
    filename = "Fuels_data_bounds.csv"
    df_fuels = load_dataframe(joinpath(path, filename))
    
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    
    if nrow(df_fuels) != inputs["T"]
        @warn """Number of inputs for delta in market hourly fuel prices doesn't match number of hours 
        in the system """ maxlog=1
    end
    
    # Fuel delta costs for each fuel type
    existing_fuels = names(df_fuels)[2:end]
    for f in inputs["fuels"]
        if f ∉ existing_fuels
            df_fuels[!,f] .= 0
        end
    end
    
    fuel_delta_costs = Containers.DenseAxisArray(transpose(Matrix(df_fuels[1:end, 2:end])), inputs["fuels"],1:nrow(df_fuels))
    
    fuel_delta_costs /= scale_factor
    inputs["fuel_delta_costs"] = fuel_delta_costs

    ro_fuels = sum(all(!iszero, fuel_delta_costs[f,:]) for f in axes(fuel_delta_costs, 1))
    inputs["count_uncertain_fuel_param"] = ro_fuels * inputs["T"]
    inputs["count_uncertain_param"] += inputs["count_uncertain_fuel_param"]  

    println(filename * " Successfully Read!")
end


function load_investment_cost_bound_data!(setup::Dict, path::AbstractString, inputs::Dict)
    filename = "Investment_cost_bounds.csv"
    df_costs_bounds = load_dataframe(joinpath(path, filename))
    
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    df_costs_bounds[!,:Inv_Cost_per_MWyr_bounds] ./= scale_factor
    
    # delta investment costs for each fuel type
    existing_resources = df_costs_bounds.Resource
    for f in inputs["RESOURCE_NAMES"]
        if f ∉ existing_resources
            push!(df_costs_bounds, (f, 0))
        end
    end 
    inputs["delta_investment_costs"] = Dict(df_costs_bounds[!,:Resource] .=> df_costs_bounds[!,:Inv_Cost_per_MWyr_bounds])

    inputs["count_uncertain_invest_param"] = inputs["G"]
    inputs["count_uncertain_param"] += inputs["count_uncertain_invest_param"]  

    println(filename * " Successfully Read!")
end


function load_fixed_om_cost_bound_data!(setup::Dict, path::AbstractString, inputs::Dict)
    filename = "Fixed_OM_cost_bounds.csv"
    df_costs_bounds = load_dataframe(joinpath(path, filename))
    
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    df_costs_bounds[!,:Fixed_OM_Cost_per_Mwyr_bound] ./= scale_factor
    
    # delta investment costs for each fuel type
    existing_resources = df_costs_bounds.Resource
    for f in inputs["RESOURCE_NAMES"]
        if f ∉ existing_resources
            push!(df_costs_bounds, (f, 0))
        end
    end  
    inputs["delta_fixed_om_costs"] = Dict(df_costs_bounds[!,:Resource] .=> df_costs_bounds[!,:Fixed_OM_Cost_per_Mwyr_bound])
    
    inputs["count_uncertain_fixedom_param"] = inputs["G"]
    inputs["count_uncertain_param"] += inputs["count_uncertain_fixedom_param"]  

    println(filename * " Successfully Read!")
end

function load_ro_data!(setup::Dict, path::AbstractString, inputs::Dict)

    load_ro_settings(setup, path, inputs)


    if inputs["ro_settings"]["FuelsCost"] == 1
        load_fuel_bound_data!(setup, path, inputs)
    end
    
    if inputs["ro_settings"]["InvestmentCost"] == 1
        load_investment_cost_bound_data!(setup, path, inputs)
    end

    if inputs["ro_settings"]["FixedOMCost"] == 1
        load_fixed_om_cost_bound_data!(setup, path, inputs)
    end
end
