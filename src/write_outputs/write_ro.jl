@doc raw"""
	write_nse(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting non-served energy for every model zone, time step and cost-segment.
"""


function write_ro_investment_cost(path::AbstractString, inputs::Dict, setup::Dict, EP::AbstractModel)
    G = inputs["G"]
    gen = inputs["RESOURCES"]
    by_rid(rid, sym) = by_rid_res(rid, sym, gen)

    df_cost = DataFrame(Resource = inputs["RESOURCE_NAMES"])
    gen = inputs["RESOURCES"]
    df_cost[!, :StartCapacity] = [existing_cap_mw(gen[i]) for i in 1:G]
    df_cost[!, :EndCapacity] = value.(EP[:eTotalCap])
    df_cost[!, :InvestmentCost]= [inv_cost_per_mwyr(gen[i]) for i in 1:G]
    df_cost[!, :DeltaInvestmentCost]= [inputs["delta_investment_costs"][by_rid(i, :resource)] for i in 1:G]
    df_cost[!, :SIC] = dual.(EP[:cDualSic])
   
    CSV.write(joinpath(path, "ro_investment_cost.csv"), df_cost)
end

function write_ro_fixed_om_cost(path::AbstractString, inputs::Dict, setup::Dict, EP::AbstractModel)
    G = inputs["G"]
    gen = inputs["RESOURCES"]
    by_rid(rid, sym) = by_rid_res(rid, sym, gen)

    df_cost = DataFrame(Resource = inputs["RESOURCE_NAMES"])
    gen = inputs["RESOURCES"]
    df_cost[!, :StartCapacity] = [existing_cap_mw(gen[i]) for i in 1:G]
    df_cost[!, :EndCapacity] = value.(EP[:eTotalCap])
    df_cost[!, :FixedOMCost]= [fixed_om_cost_per_mwyr(gen[i]) for i in 1:G]
    df_cost[!, :DeltaFixedOMCost]= [inputs["delta_fixed_om_costs"][by_rid(i, :resource)] for i in 1:G]
    df_cost[!, :SFX] = dual.(EP[:cDualSfxc])
  
    CSV.write(joinpath(path, "ro_fixed_om_cost.csv"), df_cost)
end

function write_ro(path::AbstractString, inputs::Dict, setup::Dict, EP::AbstractModel)
    df_duals = DataFrame()
    T = inputs["T"]


    if inputs["ro_settings"]["FuelsCost"] == 1
        fuels = inputs["fuels"]
        for i in fuels
            df_duals[!,"S_"*i] = dual.(EP[:cDualSfc][i,:]).data
        end
    end 
    if inputs["ro_settings"]["InvestmentCost"] == 1
        write_ro_investment_cost(path, inputs, setup, EP)
        sic_col = dual.(EP[:cDualSic])
        if inputs["ro_settings"]["FuelsCost"] == 0
            df_duals[!, :S_IC] = sic_col
        else
            df_duals[!, :S_IC] = [sic_col; fill(missing, nrow(df_duals) - length(sic_col))]
        end
    end
    if inputs["ro_settings"]["FixedOMCost"] == 1
        write_ro_fixed_om_cost(path, inputs, setup, EP)
        sfxc_col = dual.(EP[:cDualSfxc])
        df_duals[!, :S_FX] = [sfxc_col; fill(missing, nrow(df_duals) - length(sfxc_col))]
    end 
    
    CSV.write(joinpath(path, "ro_dual.csv"), df_duals)  
    return nothing
end
