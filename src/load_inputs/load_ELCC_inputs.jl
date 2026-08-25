@doc raw"""
	load_ELCC_inputs!(setup::Dict, path::AbstractString, inputs::Dict)

Read input parameters related to ELCC version of PRM constraints
"""
function load_ELCC_inputs!(setup::Dict, path::AbstractString, inputs::Dict)

    df_prm = load_dataframe(joinpath(path,"policies","Capres_ELCC.csv"))
    inputs["PRM_target"] = df_prm[1,"CapRes_ELCC"]
    # optional backstop: emergency (deliverability-exempt) capacity at a penalty price;
    # must be priced above the PRM dual of every feasible case so it only activates
    # where the requirement is otherwise unattainable
    inputs["PRM_slack_cost"] = "PRM_Slack_Cost_per_MWyr" in names(df_prm) ?
        Float64(df_prm[1,"PRM_Slack_Cost_per_MWyr"]) : 0.0
    inputs["NQC_derate"] = load_dataframe(joinpath(path,"resources","policy_assignments","Resource_NQC_derate.csv"))
    inputs["ELCC_multipliers"] = load_dataframe(joinpath(path,"resources","policy_assignments","ELCC_multipliers.csv"))
    inputs["ELCC_facets"] = load_dataframe(joinpath(path,"resources","policy_assignments","ELCC_facets.csv"))

    println("ELCC inputs Successfully Read!")
end