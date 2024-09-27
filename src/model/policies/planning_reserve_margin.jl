@doc raw"""
	planning_reserve_margin!(EP::Model, inputs::Dict, setup::Dict)

\sum_{t \in T} \sum_{g \in G} CAP_{g, z} * ELCC_{t,g,z} \ge RPM_z"""


function planning_reserve_margin!(EP::Model, inputs::Dict, setup::Dict)
    println("Planning Reserve Margin Policies Module")
    gen = inputs["RESOURCES"]
    by_rid(rid, sym) = by_rid_res(rid, sym, gen)
 
    PRM_Z = collect(keys(inputs["PRM"]))

    @expression(EP, ePRM[z in PRM_Z], sum(EP[:eTotalCap][y] * elcc(gen[y], tag = 1) for y in resources_in_zone_by_rid(gen, z)))

    if haskey(inputs, "PRM_slack")
        PRM_SZ = collect(keys(inputs["PRM_slack"]))
        @variable(EP, vPRMSlack[z in PRM_SZ] >=0)
        
        for z in PRM_SZ
            add_to_expression!(ePRM[z], vPRMSlack[z])
        end

        @expression(EP, eCPRMSlack[z in PRM_SZ], vPRMSlack[z] * inputs["PRM_slack"][z])
        add_to_expression!(EP[:eObj], sum(eCPRMSlack[z] for z in PRM_SZ))
    end

    @constraint(EP, cPRM[z in PRM_Z], ePRM[z] >= inputs["PRM"][z])

   
end
