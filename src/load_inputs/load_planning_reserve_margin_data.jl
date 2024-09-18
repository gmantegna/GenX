@doc raw"""
    load_planning_reserve_margin!(path::AbstractString, inputs::Dict, setup::Dict)

Read input parameters related to planning reserve margin constraints (e.g. technology specific deployment mandates)
"""
function load_planning_reserve_margin!(setup::Dict, path::AbstractString, inputs::Dict)
    
    filename = "Planning_reserve_margin.csv"
    df = load_dataframe(joinpath(path, filename))

    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    df[!, :Price_Cap] ./= scale_factor 
    inputs["nPRM"] = nrow(df)
    inputs["PRM"] = df

    println(filename * " Successfully Read!")
end
