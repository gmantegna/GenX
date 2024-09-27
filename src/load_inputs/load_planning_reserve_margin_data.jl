@doc raw"""
    load_planning_reserve_margin!(path::AbstractString, inputs::Dict, setup::Dict)

Read input parameters related to planning reserve margin constraints (e.g. technology specific deployment mandates)
"""
function load_planning_reserve_margin!(setup::Dict, path::AbstractString, inputs::Dict)
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    filename = "Planning_reserve_margin_slack.csv"
    if isfile(joinpath(path, filename))
        df = load_dataframe(joinpath(path, filename))
        df[!, :PriceCap] ./= scale_factor # million $/GWh if scaled, $/MWh if not scaled
        inputs["PRM_slack"] = Dict(df[!, :Network_zones] .=> df[!, :PriceCap])
    end

    filename = "Planning_reserve_margin.csv"
    df = load_dataframe(joinpath(path, filename))
    df[!, :PRM_Requirement_MW] ./=scale_factor
    inputs["PRM"] = Dict(df[!, :Network_zones] .=> df[!, :PRM_Requirement_MW])

    println(filename * " Successfully Read!")
end
