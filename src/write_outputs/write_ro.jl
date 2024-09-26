@doc raw"""
	write_nse(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting non-served energy for every model zone, time step and cost-segment.
"""


function write_ro(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    df_duals = DataFrame()
    T = inputs["T"]

    if inputs["ro_settings"]["MarketBuyPrices"] == 1
        Z = inputs["Z"] 
        MZ = inputs["MZ"]
        for i in 1:Z
            if i in MZ
                df_duals[!, "S_MarketBuy_$(i)"] =  vec(dual.(EP[:cDualSmb][i,:]).data)
            else
                df_duals[!, "S_MarketBuy_$(i)"] = zeros(T)
            end
        end
    end

    if inputs["ro_settings"]["MarketSellPrices"] == 1
        Z = inputs["Z"] 
        MZ = inputs["MZ"]
        for i in Z
            if i in MZ
                df_duals[!, "S_MarketSell_$(i)"] = vec(dual.(EP[:cDualSms][i,:]).data)
            else
                df_duals[!, "S_MarketSell_$(i)"] = zeros(T)
            end
        end
    end

    if inputs["ro_settings"]["FuelsCost"] == 1
        fuels = inputs["fuels"]
        for i in fuels
            df_duals[!,"S_"*fuels] = dual.(EP[:cDualSfc][i,:]).data
        end
    end   
    CSV.write(joinpath(path, "ro_dual.csv"), df_duals)
    
    return nothing
end
