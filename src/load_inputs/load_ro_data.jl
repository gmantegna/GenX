function default_ro_settings()
    Dict{Any, Any}(
        "UncertaintyBudget" => 0, # percentage of uncertain parameters that can take their worst case value
        "MarketBuyPrices" => 0,
        "MarketSellPrices" => 0,
        "FuelsCost" => 0
        )
end

function load_ro_settings(setup::Dict, path::AbstractString, inputs::Dict)
    println("Configuring RO Settings")
    filename = "ro_settings.yml"
    ro_settings = YAML.load(open(joinpath(path, filename)))

    merge!(default_ro_settings(), ro_settings)

    inputs["ro_settings"] = ro_settings
    inputs["count_uncertain_param"] = 0
end

function load_market_buy_price_bound_data!(setup::Dict, path::AbstractString, inputs::Dict)
    filename = "Market_buy_price_bounds.csv"
    bprice_df = load_dataframe(joinpath(path, filename))
    # should we add a validation that number of rows = # of prices in t

    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    bprice_df ./= scale_factor
    if nrow(bprice_df) != inputs["T"]
        @warn """Number of inputs for delta in market hourly prices doesn't match number of hours 
        in the system """ maxlog=1
    end
      
    delta_buy_price_mat = extract_matrix_from_dataframe(bprice_df, "BuyPriceDelta")

    #insure that we have price value for every market
    if size(delta_buy_price_mat, 2) != inputs["Z"]
        @warn """Hourly buy prices should be provided for every market""" maxlog=1
    end

    inputs["Market_SellPrices_Delta"] = transpose(delta_buy_price_mat)
    #only include markets that have non zero columns
    nmarkets = count(!all(iszero, col) for col in eachcol(bprice_df))
    inputs["count_uncertain_param"] += nmarkets * inputs["T"]
    
    println(filename * " Successfully Read!")
end


function load_market_sell_price_bound_data!(setup::Dict, path::AbstractString, inputs::Dict)
    filename = "Market_sell_price_bounds.csv"
    sprice_df = load_dataframe(joinpath(path, filename))
    # should we add a validation that number of rows = # of prices in t

    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    sprice_df ./= scale_factor

    if nrow(sprice_df) != inputs["T"]
        @warn """Number of inputs for delta in market hourly prices doesn't match number of hours 
        in the system """ maxlog=1
    end
      
    delta_sell_price_mat = extract_matrix_from_dataframe(sprice_df, "SellPriceDelta")

    #insure that we have price value for every market
    if size(delta_sell_price_mat, 2) != inputs["Z"]
        @warn """Hourly sell prices should be provided for every market""" maxlog=1
    end

    inputs["Market_SellPrices_Delta"] = transpose(delta_sell_price_mat)
    #only include markets that have non zero columns
    nmarkets = count(!all(iszero, col) for col in eachcol(sprice_df))
    inputs["count_uncertain_param"] += nmarkets * inputs["T"]
    
    println(filename * " Successfully Read!")
end


function load_fuel_bound_data!(setup::Dict, path::AbstractString, inputs::Dict)
    filename = "Fuels_data_bounds.csv"
    df_fuels = load_dataframe(joinpath(path, filename))

    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    df_fuels ./= scale_factor

    if nrow(df_fuels) != inputs["T"]
        @warn """Number of inputs for delta in market hourly fuel prices doesn't match number of hours 
        in the system """ maxlog=1
    end

    nfuels = count(!all(iszero, col) for col in eachcol(df_fuels))
    inputs["count_uncertain_param"] += nfuels * inputs["T"]

    # Fuel delta costs for each fuel type
    existing_fuels = names(df_fuels)[2:end]
    for f in inputs["fuels"]
        if f ∉ existing_fuels
            df_fuels[!,f] .= 0
        end
    end

    delta_costs = Matrix(df_fuels[1:end, 2:end])
    fuel_delta_costs = Dict{AbstractString, Array{Float64}}()

    for i in 1:length(inputs["fuels"])
        # fuel delta cost is in $/MMBTU w/o scaling, $/Billon BTU w/ scaling
        fuel_delta_costs[inputs["fuels"][i]] = delta_costs[:, i]
    end
   
    inputs["fuel_delta_costs"] = fuel_delta_costs

    println(filename * " Successfully Read!")
end

function load_ro_data!(setup::Dict, path::AbstractString, inputs::Dict)

    load_ro_settings(setup, path, inputs)

    if inputs["ro_settings"]["MarketBuyPrices"] == 1
        load_market_buy_price_bound_data!(setup, path, inputs)
    end

    if inputs["ro_settings"]["MarketSellPrices"] == 1
        load_market_sell_price_bound_data!(setup, path, inputs)
    end

    if inputs["ro_settings"]["FuelsCost"] == 1
        load_fuel_bound_data!(setup, path, inputs)
    end
end
