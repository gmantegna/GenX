function write_minimum_build_capacity_requirement(path::AbstractString,
        inputs::Dict,
        setup::Dict,
        EP::Model)
    NumberOfMinBuildCapReqs = inputs["NumberOfMinBuildCapReqs"]
    dfMinBuildCapPrice = DataFrame(
        Constraint = [Symbol("MinBuildCapReq_$mincap")
                      for mincap in 1:NumberOfMinBuildCapReqs],
        Price = dual.(EP[:cZoneMinBuildCapReq]))

    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    dfMinBuildCapPrice.Price *= scale_factor # Convert Million $/GW to $/MW

    if haskey(inputs, "MinBuildCapPriceCap")
        dfMinBuildCapPrice[!, :Slack] = convert(Array{Float64}, value.(EP[:vMinBuildCap_slack]))
        dfMinBuildCapPrice[!, :Penalty] = convert(Array{Float64}, value.(EP[:eCMinBuildCap_slack]))
        dfMinBuildCapPrice.Slack *= scale_factor # Convert GW to MW
        dfMinBuildCapPrice.Penalty *= scale_factor^2 # Convert Million $ to $
    end
    CSV.write(joinpath(path, "MinBuildCapReq_prices_and_penalties.csv"), dfMinBuildCapPrice)
end
