
@doc raw"""
    load_zones_markets!(setup::Dict, path::AbstractString, inputs::Dict)

Read flags that indicate whether a load zone is a market or not
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

    LZ_Markets = Dict(i => [] for i in 1: inputs["Z"])
    for l in 1:inputs["L"]
        z_source = findfirst(x -> x == 1, inputs["pNet_Map"][l, :])
        z_sink = findfirst(x -> x == -1, inputs["pNet_Map"][l, :])
        if z_source in inputs["MZ"]
            push!(LZ_Markets[z_sink], z_source)
        end    
    end
    inputs["LZ_Markets"] = LZ_Markets
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
