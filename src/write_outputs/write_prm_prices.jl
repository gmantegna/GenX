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

function write_prm_resource_capacity(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    gen = inputs["RESOURCES"]
    G = inputs["G"]

    resources = [gen[y].resource for y in 1:G]
    resource_zone = [gen[y].zone for y in 1:G]
    resource_elcc = [elcc(gen[y], tag = 1) for y in 1:G]

    EndCap = value.(EP[:eTotalCap])
    PRMCap = resource_elcc .* EndCap
    Percentage_PRM_Req = [PRMCap[i] /inputs["PRM"][gen[i].zone] for i in 1:G] .* 100


    df_resource_prm = DataFrame(
        Resource = resources,
        Zone = resource_zone,
        ELCC = resource_elcc,
        End_Capacity = EndCap,
        PRM_Capacity = PRMCap,
        Per_Zonal_PRM_Req = Percentage_PRM_Req
    )
    CSV.write(joinpath(path, "PRM_resource_capacity.csv"), df_resource_prm)
end