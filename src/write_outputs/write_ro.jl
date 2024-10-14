@doc raw"""
	write_nse(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting non-served energy for every model zone, time step and cost-segment.
"""

function write_ro_market_buy(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    MZ = inputs["MZ"]
    T = inputs["T"]
    cols_list = ["BuyPrice", "DeltaBuyPrice", "Smb",
                "ActualBuyPrice", "MPurchases", "BasicPurchasesCost", "TotalPurchasesCost"]
    
    L = length(cols_list)
    dfmarkets = DataFrame(Component = repeat(cols_list, outer = length(MZ)),
        Zone = repeat(MZ, inner = L),
        AnnualSum = zeros(L * length(MZ)))
    
    cols = vcat([cols_list .* "_$z" for z in MZ]...)
    mtx_markets = Containers.DenseAxisArray(zeros(length(MZ) * L, T), cols, 1:T)
    
    for z in MZ
        mtx_markets["BuyPrice_$z",:] = inputs["Market_BuyPrices"][z,:]   
        mtx_markets["DeltaBuyPrice_$z",:] = inputs["Market_BuyPrices_Delta"][z,:]
        mtx_markets["Smb_$z",:] = vec(dual.(EP[:cDualSmb][z,:]).data)
        mtx_markets["ActualBuyPrice_$z",:] =  mtx_markets["BuyPrice_$z",:] + mtx_markets["DeltaBuyPrice_$z",:] .* mtx_markets["Smb_$z",:]
        mtx_markets["MPurchases_$z",:] = value.(EP[:vMBUY][z,:]).data
        mtx_markets["BasicPurchasesCost_$z",:] = mtx_markets["MPurchases_$z",:] .* mtx_markets["BuyPrice_$z",:]
        mtx_markets["TotalPurchasesCost_$z",:] = mtx_markets["MPurchases_$z",:] .* mtx_markets["ActualBuyPrice_$z",:]
    end 
    
    dfmarkets.AnnualSum .= mtx_markets.data * inputs["omega"]
    dfmarkets = hcat(dfmarkets, DataFrame(mtx_markets.data, :auto))
    auxNew_Names = [Symbol("Component");
                        Symbol("Zone");
                        Symbol("AnnualSum");
                        [Symbol("t$t") for t in 1:T]]
    rename!(dfmarkets, auxNew_Names)
    CSV.write(joinpath(path, "ro_market_buy.csv"), dftranspose(dfmarkets, false), writeheader = false)
end

function write_ro_market_sell(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    MZ = inputs["MZ"]
    T = inputs["T"]
    cols_list = ["SellPrice", "DeltaSellPrice", "Sms",
                "ActualSellPrice", "MSales", "BasicSalesCost", "TotalSalesCost"]
    
    L = length(cols_list)
    dfmarkets = DataFrame(Component = repeat(cols_list, outer = length(MZ)),
        Zone = repeat(MZ, inner = L),
        AnnualSum = zeros(L * length(MZ)))
    
    cols = vcat([cols_list .* "_$z" for z in MZ]...)
    mtx_markets = Containers.DenseAxisArray(zeros(length(MZ) * L, T), cols, 1:T)
    
    for z in MZ
        mtx_markets["SellPrice_$z",:] = inputs["Market_SellPrices"][z,:]   
        mtx_markets["DeltaSellPrice_$z",:] = inputs["Market_SellPrices_Delta"][z,:]
        mtx_markets["Sms_$z",:] = vec(dual.(EP[:cDualSms][z,:]).data)
        mtx_markets["ActualSellPrice_$z",:] =  mtx_markets["SellPrice_$z",:] + mtx_markets["DeltaSellPrice_$z",:] .* mtx_markets["Sms_$z",:]
        mtx_markets["MSales_$z",:] = value.(EP[:vMSELL][z,:]).data
        mtx_markets["BasicSalesCost_$z",:] = mtx_markets["MSales_$z",:] .* mtx_markets["SellPrice_$z",:]
        mtx_markets["TotalSalesCost_$z",:] = mtx_markets["MSales_$z",:] .* mtx_markets["ActualSellPrice_$z",:]
    end 
    
    dfmarkets.AnnualSum .= mtx_markets.data * inputs["omega"]
    dfmarkets = hcat(dfmarkets, DataFrame(mtx_markets.data, :auto))
    auxNew_Names = [Symbol("Component");
                        Symbol("Zone");
                        Symbol("AnnualSum");
                        [Symbol("t$t") for t in 1:T]]
    rename!(dfmarkets, auxNew_Names)
    CSV.write(joinpath(path, "ro_market_sell.csv"), dftranspose(dfmarkets, false), writeheader = false)
end



function write_ro_investment_cost(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
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

function write_ro_fixed_om_cost(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
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

function write_ro(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    df_duals = DataFrame()
    T = inputs["T"]

    if inputs["ro_settings"]["MarketBuyPrices"] == 1
        Z = inputs["Z"] 
        MZ = inputs["MZ"]
        write_ro_market_buy(path, inputs, setup, EP)

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
        write_ro_market_sell(path, inputs, setup, EP)

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
            df_duals[!,"S_"*i] = dual.(EP[:cDualSfc][i,:]).data
        end
    end 
    if inputs["ro_settings"]["InvestmentCost"] == 1
        write_ro_investment_cost(path, inputs, setup, EP)
        sic_col = dual.(EP[:cDualSic])
        df_duals[!, :S_IC] = [sic_col; fill(missing, nrow(df_duals) - length(sic_col))]
    end
    if inputs["ro_settings"]["FixedOMCost"] == 1
        write_ro_fixed_om_cost(path, inputs, setup, EP)
        sfxc_col = dual.(EP[:cDualSfxc])
        df_duals[!, :S_FX] = [sfxc_col; fill(missing, nrow(df_duals) - length(sfxc_col))]
    end 
    
    CSV.write(joinpath(path, "ro_dual.csv"), df_duals)  
    return nothing
end
