@doc raw"""
	maximum_build_capacity_requirement!(EP::Model, inputs::Dict, setup::Dict)
The maximum build capacity requirement constraint allows for modeling maximum deployment of a certain technology or set of eligible technologies across the eligible model zones and can be used to mimic policies supporting specific technology build out (i.e. capacity deployment targets/mandates for storage, offshore wind, solar etc.). The default unit of the constraint is in MW. For each requirement $p \in \mathcal{P}^{MaxCapReq}$, we model the policy with the following constraint.
```math
\begin{aligned}
\sum_{y \in \mathcal{G} } \sum_{z \in \mathcal{Z} } \left( \epsilon_{y,z,p}^{MaxCapReq} \times \Delta^{\text{total}}_{y,z} \right) \leq REQ_{p}^{MaxCapReq} \hspace{1 cm}  \forall p \in \mathcal{P}^{MaxCapReq}
\end{aligned}
```
Note that $\epsilon_{y,z,p}^{MaxCapReq}$ is the eligiblity of a generator of technology $y$ in zone $z$ of requirement $p$ and will be equal to $1$ for eligible generators and will be zero for ineligible resources. The dual value of each maximum capacity constraint can be interpreted as the required payment (e.g. subsidy) per MW per year required to ensure adequate revenue for the qualifying resources.
"""
function maximum_build_capacity_requirement!(EP::Model, inputs::Dict, setup::Dict)
    println("Maximum Build Capacity Requirement Module")
    NumberOfMaxBuildCapReqs = inputs["NumberOfMaxBuildCapReqs"]

    # if input files are present, add maximum capacity requirement slack variables
    if haskey(inputs, "MaxBuildCapPriceCap")
        @variable(EP, vMaxBuildCap_slack[maxcap = 1:NumberOfMaxBuildCapReqs]>=0)
        add_similar_to_expression!(EP[:eMaxBuildCapRes], -vMaxBuildCap_slack)

        @expression(EP,
            eCMaxBuildCap_slack[maxcap = 1:NumberOfMaxBuildCapReqs],
            inputs["MaxBuildCapPriceCap"][maxcap]*EP[:vMaxBuildCap_slack][maxcap])
        @expression(EP,
            eTotalCMaxBuildCapSlack,
            sum(EP[:eCMaxBuildCap_slack][maxcap] for maxcap in 1:NumberOfMaxBuildCapReqs))

        add_to_expression!(EP[:eObj], eTotalCMaxBuildCapSlack)
    end

    @constraint(EP,
        cZoneMaxBuildCapReq[maxcap = 1:NumberOfMaxBuildCapReqs],
        EP[:eMaxBuildCapRes][maxcap] <= inputs["MaxBuildCapReq"][maxcap])
end
