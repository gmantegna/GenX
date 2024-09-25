@doc raw"""
	write_nse(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting non-served energy for every model zone, time step and cost-segment.
"""


function write_market(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    Z = inputs["Z"]
    MZ = inputs["MZ"] 
    T = inputs["T"] 
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    
    col_names = String[]
    zones = Int[]
    for i in 1:Z
        push!(col_names, "Market_Buy_$i")
        push!(zones, i)
        push!(col_names, "Market_Sell_$i")
        push!(zones, i)
    end
    
    dfmarkets = DataFrame(Market = col_names,
    Zone = zones,
    AnnualSum = Array{Union{Missing, Float64}}(undef, length(col_names)))
    markets = Matrix{Float64}(undef, length(col_names), T)
        
    # Fill the matrix with zeros
    fill!(markets, 0.0)
    
    for i in 1:Z
        if i in MZ
            markets[2*i-1, :] = value.(EP[:vMKT_BUY][i,:]).data
            markets[2*i, :] = value.(EP[:vMKT_SELL][i,:]).data
        else
            markets[2*i-1, :] = zeros(T)
            markets[2*i, :] = zeros(T)
        end
    end
    markets .*=scale_factor
    dfmarkets.AnnualSum .= markets * inputs["omega"]
    
    filepath = joinpath(path, "market.csv")
    if setup["WriteOutputs"] == "annual"
        GenX.write_annual(filepath, dfmarkets)
    else # setup["WriteOutputs"] == "full"
        dfmarkets = GenX.write_fulltimeseries(filepath, markets, dfmarkets)
        if setup["OutputFullTimeSeries"] == 1 && setup["TimeDomainReduction"] == 1
            GenX.write_full_time_series_reconstruction(path, setup, dfmarkets, "market")
            @info("Writing Full Time Series for markets")
        end
    end

    return nothing
end
