@doc raw"""
	write_nse(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting non-served energy for every model zone, time step and cost-segment.
"""


function write_market(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    MZ = inputs["MZ"]     # Number of zones
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    # Non-served energy/demand curtailment by segment in each time step
    MSell =  transpose(value.(EP[:vMKT_SELL]).data)
    MSell = MSell .*scale_factor
    dfMarketSell = DataFrame(MSell, ["Market_Sell_$z" for z in MZ])


    MBuy =  transpose(value.(EP[:vMKT_BUY]).data)
    MBuy = MBuy .*scale_factor
    dfMarketBuy = DataFrame(MBuy, ["Market_Buy_$z" for z in MZ])

    CSV.write(joinpath(path, "market.csv"), hcat(dfMarketBuy, dfMarketSell))

    return nothing
end
