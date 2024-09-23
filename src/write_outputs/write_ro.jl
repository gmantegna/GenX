@doc raw"""
	write_nse(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting non-served energy for every model zone, time step and cost-segment.
"""


function write_ro(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    df_duals = DataFrame()

    if inputs["ro_settings"]["MarketBuyPrices"] == 1
        MZ = inputs["MZ"]
        for i in 1:length(MZ)
            df_duals[!, "S_MarketBuy_$(i)"] =  vec(dual.(EP[:cDualSmb]).data[i,:])
        end
    end
    if inputs["ro_settings"]["MarketSellPrices"] == 1
        MZ = inputs["MZ"]
        for i in 1:length(MZ)
            df_duals[!, "S_MarketSell_$(i)"] = vec(dual.(EP[:cDualSms]).data[i,:])
        end
    end
    if inputs["ro_settings"]["FuelsCost"] == 1
        fuels = inputs["fuels"]
        for i in 1:length(fuels)
            df_duals[!,"S_"*fuels[i]] = dual.(EP[:cDualSfc]).data[i,:]
        end
    end   
    CSV.write(joinpath(path, "ro_dual.csv"), df_duals)
    
    return nothing
end
