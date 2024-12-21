function write_maximum_build_capacity_requirement(path::AbstractString,
        inputs::Dict,
        setup::Dict,
        EP::Model)
    NumberOfMaxBuildCapReqs = inputs["NumberOfMaxBuildCapReqs"]
    dfMaxBuildCapPrice = DataFrame(
        Constraint = [Symbol("MaxBuildCapReq_$maxcap")
                      for maxcap in 1:NumberOfMaxBuildCapReqs],
        Price = -dual.(EP[:cZoneMaxBuildCapReq]))

    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    dfMaxBuildCapPrice.Price *= scale_factor

    if haskey(inputs, "MaxBuildCapPriceCap")
        dfMaxBuildCapPrice[!, :Slack] = convert(Array{Float64}, value.(EP[:vMaxBuildCap_slack]))
        dfMaxBuildCapPrice[!, :Penalty] = convert(Array{Float64}, value.(EP[:eCMaxBuildCap_slack]))
        dfMaxBuildCapPrice.Slack *= scale_factor # Convert GW to MW
        dfMaxBuildCapPrice.Penalty *= scale_factor^2 # Convert Million $ to $
    end
    CSV.write(joinpath(path, "MaxBuildCapReq_prices_and_penalties.csv"), dfMaxBuildCapPrice)
end
