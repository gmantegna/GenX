@doc raw"""
	minimum_build_capacity_requirement!(EP::Model, inputs::Dict, setup::Dict)
The minimum build capacity requirement constraint allows for modeling minimum deployment of a certain technology or set of eligible technologies across the eligible model zones and can be used to mimic policies supporting specific technology build out (i.e. capacity deployment targets/mandates for storage, offshore wind, solar etc.). The default unit of the constraint is in MW. For each requirement $p \in \mathcal{P}^{MinCapReq}$, we model the policy with the following constraint.
```math
\begin{aligned}
\sum_{y \in \mathcal{G} } \sum_{z \in \mathcal{Z} } \left( \epsilon_{y,z,p}^{MinBuildCapReq} \times \Delta^{\text{total}}_{y,z} \right) \geq REQ_{p}^{MinCapReq} \hspace{1 cm}  \forall p \in \mathcal{P}^{MinCapReq}
\end{aligned}
```
Note that $\epsilon_{y,z,p}^{MinBuildCapReq}$ is the eligiblity of a generator of technology $y$ in zone $z$ of requirement $p$ and will be equal to $1$ for eligible generators and will be zero for ineligible resources. The dual value of each minimum capacity constraint can be interpreted as the required payment (e.g. subsidy) per MW per year required to ensure adequate revenue for the qualifying resources.

Also note that co-located VRE and storage resources, there are three different components 
	that minimum build capacity requirements can be created for. The capacity of solar PV (in AC terms 
	since the capacity is multiplied by the inverter efficiency), the capacity of wind, and the discharge 
	capacity of storage (power to energy ratio times the energy capacity) can all have minimum capacity 
	requirements.
"""
function minimum_build_capacity_requirement!(EP::Model, inputs::Dict, setup::Dict)
    println("Minimum Build Capacity Requirement Module")
    NumberOfMinBuildCapReqs = inputs["NumberOfMinBuildCapReqs"]

    # if input files are present, add minimum capacity requirement slack variables
    if haskey(inputs, "MinBuildCapPriceCap")
        @variable(EP, vMinBuildCap_slack[mincap = 1:NumberOfMinBuildCapReqs]>=0)
        add_similar_to_expression!(EP[:eMinBuildCapRes], vMinBuildCap_slack)

        @expression(EP,
            eCMinBuildCap_slack[mincap = 1:NumberOfMinBuildCapReqs],
            inputs["MinBuildCapPriceCap"][mincap]*EP[:vMinBuildCap_slack][mincap])
        @expression(EP,
            eTotalCMinBuildCapSlack,
            sum(EP[:eCMinBuildCap_slack][mincap] for mincap in 1:NumberOfMinBuildCapReqs))

        add_to_expression!(EP[:eObj], eTotalCMinBuildCapSlack)
    end

    @constraint(EP,
        cZoneMinBuildCapReq[mincap = 1:NumberOfMinBuildCapReqs],
        EP[:eMinBuildCapRes][mincap]>=inputs["MinBuildCapReq"][mincap])
end
