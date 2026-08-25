@doc raw"""
	capres_ELCC!(EP::Model, inputs::Dict, setup::Dict)
Model capacity reserve margin with ELCC-type constraints.

The PRM constraint is
```math
eNQC + \sum_{s} vELCC\_MW_{s} \geq PRM\_target
```
where eNQC sums NQC-derated reliability capacity and each surface's vELCC_MW is bounded
above by every facet of the surface:
```math
vELCC\_MW_{s} \leq Axis\_0_{s,f} + \sum_{k \geq 1} Axis\_k_{s,f} \times \sum_{g} mult_{s,g,k} \times vReliabilityCap_{g}
```
The number of axes is inferred from the Axis_k columns present in ELCC_facets.csv.
"""
function capres_ELCC!(EP::AbstractModel, inputs::Dict, setup::Dict)
    # capacity reserve margin constraint
    println("ELCC Module")
    G = inputs["G"]
    resource_names = inputs["RESOURCE_NAMES"]
    rid_of = Dict(String(resource_names[g]) => g for g in 1:G)

    # get total NQC, eNQC
    create_empty_expression!(EP, :eNQC)
    df_NQC = inputs["NQC_derate"]
    for row in eachrow(df_NQC)
        rname = String(row.Resource)
        if !haskey(rid_of, rname)
            println("did  not find matching resource for resource $rname")
            continue
        end
        EP[:eNQC] += EP[:vReliabilityCap][rid_of[rname]] * row.NQC_derate
    end

    # create vELCC_MW and constrain by all facets
    df_facets = inputs["ELCC_facets"]
    df_elcc_multipliers = inputs["ELCC_multipliers"]

    elcc_surface_names = String.(unique(df_facets[!, "ELCC_Surface"]))
    ELCC_SURFACES = 1:length(elcc_surface_names)
    surface_num = Dict(elcc_surface_names[s] => s for s in ELCC_SURFACES)

    axis_nums = sort([parse(Int, split(c, "_")[2])
                      for c in names(df_facets)
                      if startswith(c, "Axis_") && c != "Axis_0"])

    # per-surface, per-axis capacity expressions shared by all facets of the surface
    # (accumulated generically: under Plasmo, model variables are NodeVariableRefs,
    # so a plain JuMP.AffExpr cannot be used as the accumulator)
    axis_expr = Dict{Tuple{Int, Int}, Any}((s, k) => 0.0
    for s in ELCC_SURFACES for k in axis_nums)
    for row in eachrow(df_elcc_multipliers)
        rname = String(row.Resource)
        if !haskey(rid_of, rname)
            println("did  not find matching resource for resource $rname")
            continue
        end
        if !haskey(surface_num, String(row.ELCC_Surface))
            println("did not find ELCC surface $(row.ELCC_Surface) in ELCC_facets")
            continue
        end
        s = surface_num[String(row.ELCC_Surface)]
        k = row.ELCC_Axis_Index
        if !(k in axis_nums)
            throw("ELCC axis index $k for resource $rname not among facet axis columns $axis_nums")
        end
        if row.ELCC_Axis_Multiplier != 0
            axis_expr[(s, k)] = axis_expr[(s, k)] +
                                row.ELCC_Axis_Multiplier * EP[:vReliabilityCap][rid_of[rname]]
        end
    end

    @variable(EP, vELCC_MW[s in ELCC_SURFACES]>=0)

    for s in ELCC_SURFACES
        facets_s = df_facets[df_facets[!, "ELCC_Surface"] .== elcc_surface_names[s], :]
        for row in eachrow(facets_s)
            @constraint(EP,
                EP[:vELCC_MW][s]<=row.Axis_0 +
                                  sum(row[Symbol("Axis_$k")] * axis_expr[(s, k)]
                    for k in axis_nums),
                base_name="cELCC_Facet_" * String(row.Facet))
        end
    end

    slack_cost = get(inputs, "PRM_slack_cost", 0.0)
    if slack_cost > 0
        @variable(EP, vPRMSlack>=0)
        EP[:eObj] = EP[:eObj] + slack_cost * EP[:vPRMSlack]
        @constraint(EP,
            cCapacityResMarginELCC,
            EP[:eNQC] + sum(EP[:vELCC_MW][s] for s in ELCC_SURFACES) +
            EP[:vPRMSlack]>=inputs["PRM_target"])
    else
        @constraint(EP,
            cCapacityResMarginELCC,
            EP[:eNQC] + sum(EP[:vELCC_MW][s] for s in ELCC_SURFACES)>=inputs["PRM_target"])
    end
end
