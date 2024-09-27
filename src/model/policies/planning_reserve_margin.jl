@doc raw"""
	planning_reserve_margin!(EP::Model, inputs::Dict, setup::Dict)

\sum_{t \in T} \sum_{g \in G} CAP_{g, z} * ELCC_{t,g,z} \ge RPM_z"""


function planning_reserve_margin!(EP::Model, inputs::Dict, setup::Dict)
    println("Planning Reserve Margin Policies Module")
    gen = inputs["RESOURCES"]
    by_rid(rid, sym) = by_rid_res(rid, sym, gen)

    prm_zrequirement = Dict(inputs["PRM"].Zone .=> inputs["PRM"].PRM_Requirement_MW)
    prm_zpricecap = Dict(inputs["PRM"].Zone .=> inputs["PRM"].Price_Cap) 
    
    PRM_Z = inputs["PRM"].Zone
    PRM_slack_zones = inputs["PRM"].Zone[inputs["PRM"].Allow_Violation .== 1]

    @expression(EP, ePRM[z in PRM_Z], sum(EP[:eTotalCap][y] * elcc(gen[y], tag = 1) for y in resources_in_zone_by_rid(gen, z)))

    if !isempty(PRM_slack_zones)
        @variable(EP, vPRMSlack[z in PRM_slack_zones] >=0)
        
        for z in PRM_slack_zones
            add_to_expression!(ePRM[z], vPRMSlack[z])
        end

        #@expression(EP, eCPRMSlack[z in PRM_slack_zones], vPRMSlack[z] * prm_zpricecap[z])
        @expression(EP, eCPRMSlack[z in Z], (z in PRM_slack_zones) ? vPRMSlack[z] * prm_zpricecap[z] : EP[:vZERO])
        add_to_expression!(EP[:eObj], sum(eCPRMSlack[z] for z in Z))
    end

    @constraint(EP, cPRM[z in PRM_Z], ePRM[z] >= prm_zrequirement[z])

   
end
