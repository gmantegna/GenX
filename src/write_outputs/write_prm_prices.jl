function write_prm_prices(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    Z = collect(keys(inputs["PRM_slack"]))
    columns  = [:Zone, :PRM_Price, :PRM_AnnualSlack, :PRM_AnnualPenalty]
    
    dfPRM = DataFrame([name => [] for name in columns])
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    for z in Z
        push!(dfPRM, [z, dual.(EP[:cPRM][z]),value.(EP[:vPRMSlack][z]),  value.(EP[:eCPRMSlack][z])])    
    end

    dfPRM .*= scale_factor
    CSV.write(joinpath(path, "PRM_prices_and_penalties.csv"), dfPRM)
end