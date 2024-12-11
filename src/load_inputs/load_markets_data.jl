
@doc raw"""
    load_zones_markets!(setup::Dict, path::AbstractString, inputs::Dict)

Function for reading flags that indicate whether a load zone is a market or not
"""
function load_zones_markets!(setup::Dict, path::AbstractString, inputs::Dict)
    filename = "Zones_markets.csv"
    zones_markets = load_dataframe(joinpath(path, filename))    
    inputs["MZ"] = findall(zones_markets.Market .== 1)

    inputs["Mrkt_Max_Buy"] = Dict(
        row.Zone => row.Market_Max_Buy 
        for row in eachrow(zones_markets) 
        if row.Market == 1   )

    inputs["Mrkt_Max_Sell"] = Dict(
        row.Zone => row.Market_Max_Sell 
        for row in eachrow(zones_markets) 
        if row.Market == 1   )

    println(filename * " Successfully Read!")
end

function load_market_price_data!(setup::Dict, path::AbstractString, inputs::Dict)
    
    filename = "Market_price.csv"
    price_df = load_dataframe(joinpath(path, filename))
    # should we add a validation that number of rows = # of prices in t

    if nrow(price_df) != inputs["T"]
        @warn """Number of inputs for market selling hourly prices doesn't match number of hours 
        in the system """ maxlog=1
    end
      
    sell_price_mat = extract_matrix_from_dataframe(price_df, "SellPrice")
    buy_price_mat = extract_matrix_from_dataframe(price_df, "BuyPrice")

    #insure that we have price value for every market
    if size(sell_price_mat, 2) != inputs["Z"]
        @warn """Hourly sell prices should be provided for every market""" maxlog=1
    end

    #insure that we have price value for every market
    if size(buy_price_mat, 2) != inputs["Z"]
        @warn """Hourly buy prices should be provided for every market""" maxlog=1
    end

    
    inputs["Market_SellPrices"] = transpose(sell_price_mat)
    inputs["Market_BuyPrices"] = transpose(buy_price_mat)

    println(filename * " Successfully Read!")

end

@doc raw"""
    function load_market_purchase_emissions_data!(setup::Dict, path::AbstractString, inputs::Dict)

    Function loads and processes CO2 emissions data for all network transmission lines from the Network_emissions.csv file.
"""
function load_market_purchase_emissions_data!(setup::Dict, path::AbstractString, inputs::Dict)
    filename = "Network_emissions.csv"
    emissions_df = load_dataframe(joinpath(path, filename))

    co2_emissions_mat = extract_matrix_from_dataframe(emissions_df, "CO2_tons_MWh")

    if size(co2_emissions_mat, 2) != inputs["L"]
        @warn """Hourly CO2 emissions should be provided for every network line""" maxlog=1
    end

    inputs["Line_CO2_tons_MWh"] = transpose(co2_emissions_mat)
    println(filename * " Successfully Read!")
end

function load_market_purchase_emissions_data_m!(setup::Dict, path::AbstractString, inputs::Dict)
    filename = "Market_emissions.csv"
    emissions_df = load_dataframe(joinpath(path, filename))

    co2_emissions_mat = extract_matrix_from_dataframe(emissions_df, "CO2_tons_MWh")

    if size(co2_emissions_mat, 2) != inputs["L"]
        @warn """Hourly CO2 emissions should be provided for every network line""" maxlog=1
    end

    inputs["Market_CO2_tons_MWh"] = transpose(co2_emissions_mat)
    println(filename * " Successfully Read!")
end

@doc raw"""
    set_market_network!(setup::Dict, path::AbstractString, inputs::Dict)

Function for creating a dictionary to identify the markets associated with each load zone,and another dicionary for network lines associated with each zone
"""
function set_market_network!(setup::Dict, path::AbstractString, inputs::Dict)
    LZ_Markets = Dict(i => [] for i in 1: inputs["Z"])
    for l in 1:inputs["L"]
        z_source = findfirst(x -> x == 1, inputs["pNet_Map"][l, :])
        z_sink = findfirst(x -> x == -1, inputs["pNet_Map"][l, :])
        if z_source in inputs["MZ"]
            push!(LZ_Markets[z_sink], z_source)
        end    
    end
    inputs["LZ_Markets"] = LZ_Markets

    
    Market_Line = Dict()
    for l in 1:inputs["L"] 
        if findfirst(isequal(1), inputs["pNet_Map"][l,:]) in inputs["MZ"]
            Market_Line[findfirst(isequal(1), inputs["pNet_Map"][l,:])] = l
        end
    end
    inputs["Market_Line"] = Market_Line
end