function write_esr_prices(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    dfESR = DataFrame(ESR_Price = convert(Array{Float64}, dual.(EP[:cESRShare])))
    if setup["ParameterScale"] == 1
        dfESR[!, :ESR_Price] = dfESR[!, :ESR_Price] * ModelScalingFactor # Converting MillionUS$/GWh to US$/MWh
    end

    if haskey(inputs, "dfESR_slack")
        dfESR[!, :ESR_AnnualSlack] = convert(Array{Float64}, value.(EP[:vESR_slack]))
        dfESR[!, :ESR_AnnualPenalty] = convert(Array{Float64}, value.(EP[:eCESRSlack]))
        if setup["ParameterScale"] == 1
            dfESR[!, :ESR_AnnualSlack] *= ModelScalingFactor # Converting GWh to MWh
            dfESR[!, :ESR_AnnualPenalty] *= (ModelScalingFactor^2) # Converting MillionUSD to USD
        end
    end
    CSV.write(joinpath(path, "ESR_prices_and_penalties.csv"), dfESR)
    return dfESR
end

function write_esr_detailed(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    gen = inputs["RESOURCES"]
    SOLAR = inputs["VS_SOLAR"]                                      # Set of VRE-STOR generators with solar-component
    WIND = inputs["VS_WIND"]                                        # Set of VRE-STOR generators with wind-component
    gen_VRE_STOR = gen.VreStorage                                   # Set of VRE-STOR generators (objects)
    by_rid(rid, sym) = GenX.by_rid_res(rid, sym, gen_VRE_STOR)
    
    scale_factor = setup["ParameterScale"] == 1 ? GenX.ModelScalingFactor : 1
       
    dfESR = DataFrame(ESR = ["ESR_$i" for i in 1:inputs["nESR"]])
    
    for z in 1:inputs["Z"]
        dfESR[!,"ESR_Req_z$z"] = inputs["dfESR"][z,:] * sum(inputs["pD"][t, z] * inputs["omega"][t] for t in 1: inputs["T"]) * scale_factor
    end
    
    dfESR[!,:ESR_met] = zeros(inputs["nESR"])
    for i in 1:inputs["nESR"]
        tmp_ids1 = GenX.ids_with_policy(gen, GenX.esr, tag = i)
        tmp_ids2 = intersect(SOLAR, GenX.ids_with_policy(gen, GenX.esr_vrestor, tag = i))
        tmp_ids3 = intersect(WIND, GenX.ids_with_policy(gen, GenX.esr_vrestor, tag = i))
        dfESR[!, :ESR_met][i] = 0
       
        # First sum
        dfESR[!, :ESR_met][i] += isempty(tmp_ids1) ? 0 :
            sum(inputs["omega"][t] * GenX.esr(gen[y], tag = i) * value(EP[:vP][y, t])
                for y in tmp_ids1, t in 1:inputs["T"])
        
        # Second sum
        dfESR[!, :ESR_met][i] += isempty(tmp_ids2) ? 0 :
            sum(inputs["omega"][t] * GenX.esr_vrestor(gen[y], tag = i) * value(EP[:vP_SOLAR][y, t])
                for y in tmp_ids2, t in 1:inputs["T"])
        
        # Third sum
        dfESR[!, :ESR_met][i] += isempty(tmp_ids3) ? 0 :
            sum(inputs["omega"][t] * GenX.esr_vrestor(gen[y], tag = i) * value(EP[:vP_WIND][y, t])
                for y in tmp_ids3, t in 1:inputs["T"])    
        
        dfESR[!, :ESR_met][i] *= scale_factor
    end
    
    if setup["IncludeLossesInESR"] == 1
        dfESR[!, :ESR_transmission_Losses] = value.(EP[:eESRTran])  
        dfESR[!, :ESR_Stor_Losses] = value.(EP[:eESRStor])
        if !isempty(inputs["VRE_STOR"])
            dfESR[!, :ESR_VreStor_Losses] = value.(EP[:eESRVREStorLosses])  
        end
    end
    
    if haskey(inputs, "dfESR_slack")
        dfESR[!, :ESR_AnnualSlack] = convert(Array{Float64}, value.(EP[:vESR_slack]) * scale_factor) # Converting GWh to MWh
        dfESR[!, :ESR_Price] = convert(Array{Float64}, dual.(EP[:cESRShare]) * scale_factor) 
        dfESR[!, :ESR_AnnualPenalty] = convert(Array{Float64}, value.(EP[:eCESRSlack]) * (scale_factor^2))  # Converting MillionUSD to USD
    end
    CSV.write(joinpath(path, "ESR_prices_and_penalties_detailed.csv"), dfESR)
    return dfESR
end