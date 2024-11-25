function get_elcc_multiplier(df_elcc_multipliers,elcc_surface_names,resource_names,s,rid,axis_num)
    multiplier = df_elcc_multipliers[
        (
            (df_elcc_multipliers[!,"ELCC_Surface"].==elcc_surface_names[s])
            .& (df_elcc_multipliers[!,"Resource"].==resource_names[rid])
            .& (df_elcc_multipliers[!,"ELCC_Axis_Index"].==axis_num)
        ),
        "ELCC_Axis_Multiplier"
    ]
    if isempty(multiplier)
        return 0.0
    else
        return multiplier[1]
    end
end

@doc raw"""
	capres_ELCC!(EP::Model, inputs::Dict, setup::Dict)
Model capacity reserve margin with ELCC-type constraints
"""
function capres_ELCC!(EP::Model, inputs::Dict, setup::Dict)
    # capacity reserve margin constraint
    println("ELCC Module")
    G = inputs["G"]
    resource_names = inputs["RESOURCE_NAMES"]

    # get total NQC, eNQC
    create_empty_expression!(EP, :eNQC)
    df_NQC=inputs["NQC_derate"]
    for resource in df_NQC[:,"Resource"]
        matching_rids = findall(>(0),[String(x)==resource for x in resource_names])
        if length(matching_rids) > 1
            throw("more than one matching RID found for resource $resource")
        end
        if length(matching_rids) == 0
            println("did  not find matching resource for resource $resource")
        else
            rid=matching_rids[1]
            if rid in axes(EP[:eTotalCap])[1]
                EP[:eNQC] += EP[:eTotalCap][rid] * df_NQC[df_NQC[!,"Resource"].==resource,"NQC_derate"][1]
            else
                println("did not find eTotalCap for resource $resource")
            end
        end
    end

    # create vELCC_MW and constrain by all facets
    df_facets = inputs["ELCC_facets"]
    df_elcc_multipliers = inputs["ELCC_multipliers"]

    elcc_surface_names=unique(df_facets[!,"ELCC_Surface"])
    ELCC_SURFACES=1:length(elcc_surface_names)

    elcc_facet_names=unique(df_facets[!,"Facet"])
    ELCC_FACETS=1:length(elcc_facet_names)

    elcc_facet_dict=Dict()
    for s in ELCC_SURFACES
        elcc_facet_dict[s]=unique(df_facets[df_facets[!,"ELCC_Surface"].==elcc_surface_names[s],"Facet"])
    end

    @variable(EP, vELCC_MW[s in ELCC_SURFACES]>=0)

    @constraint(
        EP,
        cELCC_Facet_Constraint[s in ELCC_SURFACES, f in ELCC_FACETS; f in elcc_facet_dict[s]],
        EP[:vELCC_MW][s]<=(
            df_facets[(df_facets[!,"ELCC_Surface"].==elcc_surface_names[s]) .& (df_facets[!,"Facet"].==elcc_facet_names[f]),"Axis_0"][1]
            + (
                df_facets[(df_facets[!,"ELCC_Surface"].==elcc_surface_names[s]) .& (df_facets[!,"Facet"].==elcc_facet_names[f]),"Axis_1"][1]
                * sum(
                    get_elcc_multiplier(df_elcc_multipliers,elcc_surface_names,resource_names,s,g,1)
                    * EP[:eTotalCap][g]
                    for g in 1:G
                )
            )
            + (
                df_facets[(df_facets[!,"ELCC_Surface"].==elcc_surface_names[s]) .& (df_facets[!,"Facet"].==elcc_facet_names[f]),"Axis_2"][1]
                * sum(
                    get_elcc_multiplier(df_elcc_multipliers,elcc_surface_names,resource_names,s,g,2)
                    * EP[:eTotalCap][g]
                    for g in 1:G
                )
            )
        )
    )
    @constraint(EP,cCapacityResMarginELCC,EP[:eNQC]+sum(EP[:vELCC_MW][s] for s in ELCC_SURFACES)>=inputs["PRM_target"])
end
