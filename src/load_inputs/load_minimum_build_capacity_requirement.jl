@doc raw"""
    load_minimum_build_capacity_requirement!(path::AbstractString, inputs::Dict, setup::Dict)

Read input parameters related to minimum capacity requirement constraints (e.g. technology specific deployment mandates)
"""
function load_minimum_build_capacity_requirement!(path::AbstractString, inputs::Dict, setup::Dict)
    filename = "Minimum_build_capacity_requirement.csv"
    df = load_dataframe(joinpath(path, filename))
    inputs["NumberOfMinBuildCapReqs"] = length(df[!, :MinBuildCapReqConstraint])
    inputs["MinBuildCapReq"] = df[!, :Min_MW]
    if setup["ParameterScale"] == 1
        inputs["MinBuildCapReq"] /= ModelScalingFactor # Convert to GW
    end
    if "PriceCap" in names(df)
        inputs["MinBuildCapPriceCap"] = df[!, :PriceCap]
        if setup["ParameterScale"] == 1
            inputs["MinBuildCapPriceCap"] /= ModelScalingFactor # Convert to million $/GW
        end
    end
    println(filename * " Successfully Read!")
end
