@doc raw"""
	load_ELCC_inputs!(setup::Dict, path::AbstractString, inputs::Dict)

Read input parameters related to ELCC version of PRM constraints
"""
function load_ELCC_inputs!(setup::Dict, path::AbstractString, inputs::Dict)

    inputs["PRM_target"] = load_dataframe(joinpath(path,"policies","Capres_ELCC.csv"))[1,"CapRes_ELCC"]
    inputs["NQC_derate"] = load_dataframe(joinpath(path,"resources","policy_assignments","Resource_NQC_derate.csv"))
    inputs["ELCC_multipliers"] = load_dataframe(joinpath(path,"resources","policy_assignments","ELCC_multipliers.csv"))
    inputs["ELCC_facets"] = load_dataframe(joinpath(path,"resources","policy_assignments","ELCC_facets.csv"))

    println("ELCC inputs Successfully Read!")
end