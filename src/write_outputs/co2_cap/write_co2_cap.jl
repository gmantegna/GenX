@doc raw"""
	write_co2_cap(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting carbon price associated with carbon cap constraints.

"""
function write_co2_cap(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    dfCO2Price = DataFrame(
        CO2_Cap = [Symbol("CO2_Cap_$cap") for cap in 1:inputs["NCO2Cap"]],
        CO2_Price = (-1) * (dual.(EP[:cCO2Emissions_systemwide])))
    if setup["ParameterScale"] == 1
        dfCO2Price.CO2_Price .*= ModelScalingFactor # Convert Million$/kton to $/ton
    end
    if haskey(inputs, "dfCO2Cap_slack")
        dfCO2Price[!, :CO2_Mass_Slack] = convert(Array{Float64}, value.(EP[:vCO2Cap_slack]))
        dfCO2Price[!, :CO2_Penalty] = convert(Array{Float64}, value.(EP[:eCCO2Cap_slack]))
        if setup["ParameterScale"] == 1
            dfCO2Price.CO2_Mass_Slack .*= ModelScalingFactor # Convert ktons to tons
            dfCO2Price.CO2_Penalty .*= ModelScalingFactor^2 # Convert Million$ to $
        end
    end

    CSV.write(joinpath(path, "CO2_prices_and_penalties.csv"), dfCO2Price)

    return nothing
end

function write_co2_cap_detailed(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    SEG = inputs["SEG"]
    T = inputs["T"]
    Z = inputs["Z"]
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    scale_factor /= 1e6
    dfCO2Price = DataFrame(
        CO2_Cap = [Symbol("CO2_Cap_$cap") for cap in 1:inputs["NCO2Cap"]],
        CO2_Price = (-1) * (dual.(EP[:cCO2Emissions_systemwide])) .* scale_factor)

    for z in 1:Z
        dfCO2Price[!, "TotalEmissions_z$z"] = inputs["dfCO2CapZones"][z, :] .*
                                             scale_factor .*
                                             sum(inputs["omega"][t] *
                                                 value(EP[:eTotalEmissionsByZone][z, t])
        for t in 1:T)
    end
    dfCO2Price[!, "CO2_Mass_Slack"] = convert(Array{Float64}, value.(EP[:vCO2Cap_slack]))
    dfCO2Price[!, "CO2_Mass_Slack"] .*= scale_factor
    if haskey(inputs, "dfCO2Cap_slack")
        dfCO2Price[!, "CO2_Penalty"] = convert(Array{Float64}, value.(EP[:eCCO2Cap_slack]))
        dfCO2Price[!, "CO2_Penalty"] .*= scale_factor
    end
    if setup["CO2Cap"] == 1
        for z in 1:Z
            dfCO2Price[!, "MaxCO2_z$z"] = inputs["dfCO2CapZones"][z, :] .*
                                         inputs["dfMaxCO2"][z, :] .* scale_factor
        end
    elseif setup["CO2Cap"] == 2 
        for z in 1:Z
            dfCO2Price[!, "MaxCO2Rate_z$z"] = inputs["dfCO2CapZones"][z, :] .*
                                               inputs["dfMaxCO2Rate"][z, :]

            dfCO2Price[!, "Demand_z$z"] = inputs["dfCO2CapZones"][z, :] .* scale_factor .*
                                         sum(inputs["omega"][t] * inputs["pD"][t, z]
            for t in 1:T)

            dfCO2Price[!, "NSE_z$z"] = inputs["dfCO2CapZones"][z, :] .* scale_factor .*
                                      sum(inputs["omega"][t] *
                                          sum(value(EP[:vNSE][s, t, z]) for s in 1:SEG)
            for t in 1:T)

            dfCO2Price[!, "Losses_z$z"] = inputs["dfCO2CapZones"][z, :] .*
                                         setup["StorageLosses"] .* scale_factor .*
                                         value(EP[:eELOSSByZone][z])
        end
    elseif setup["CO2Cap"] == 3
        for z in 1:Z
            dfCO2Price[!, "MaxCO2Rate_z$z"] = inputs["dfCO2CapZones"][z, cap] .*
                                               inputs["dfMaxCO2Rate"][z, cap]

            dfCO2Price[!, "Genertation_z$z"] = inputs["dfCO2CapZones"][z, :] .* scale_factor .*
                                              sum(inputs["omega"][t] *
                                                  value(EP[:eGenerationByZone][z, t])
            for t in 1:T)
        end
    end

    CSV.write(joinpath(path, "CO2_prices_and_penalties_detailed.csv"), dfCO2Price)

    return nothing
end