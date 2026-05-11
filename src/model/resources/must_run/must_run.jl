@doc raw"""
	must_run!(EP::AbstractModel, inputs::Dict, setup::Dict)

This function defines the constraints for operation of `must-run' or non-dispatchable resources, such as rooftop solar systems that do not receive dispatch signals, run-of-river hydroelectric facilities without the ability to spill water, or cogeneration systems that must produce a fixed quantity of heat in each time step. This resource type can also be used to model baseloaded or self-committed thermal generators that do not respond to economic dispatch.

For must-run resources ($y\in \mathcal{MR}$) output in each time period $t$ must exactly equal the available capacity factor times the installed capacity, not allowing for curtailment. These resources are also not eligible for contributing to frequency regulation or operating reserve requirements.

```math
\begin{aligned}
\Theta_{y,z,t} = \rho^{max}_{y,z,t}\times \Delta^{total}_{y,z}
\hspace{4 cm}  \forall y \in \mathcal{MR}, z \in \mathcal{Z},t \in \mathcal{T}
\end{aligned}
```
"""
function must_run!(EP::AbstractModel, inputs::Dict, setup::Dict)
    println("Must-Run Resources Module")

    gen = inputs["RESOURCES"]

    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    G = inputs["G"] # Number of generators
    assets = inputs["GENERIC_ASSETS"]
    generators = setdiff(collect(1:G),assets)

    MUST_RUN = inputs["MUST_RUN"]
    CapacityReserveMargin = setup["CapacityReserveMargin"]

    MUST_RUN_POWER_OUT = intersect(MUST_RUN, ids_with_positive(gen, num_vre_bins))
    MUST_RUN_NO_POWER_OUT = setdiff(MUST_RUN, MUST_RUN_POWER_OUT)

    ### Expressions ###

    ## Power Balance Expressions ##

    @expression(EP, ePowerBalanceNdisp[t = 1:T, z = 1:Z],
        sum(EP[:vP][y, t] for y in intersect(MUST_RUN, resources_in_zone_by_rid(gen, z))))
    add_similar_to_expression!(EP[:ePowerBalance], ePowerBalanceNdisp)

    # Capacity Reserves Margin policy
    if CapacityReserveMargin > 0
        @expression(EP,
            eCapResMarBalanceMustRun[res = 1:inputs["NCapacityReserveMargin"], t = 1:T],
            sum(derating_factor(gen[y], tag = res) * EP[:eTotalCap][y] *
                inputs["pP_Max"][y, t] for y in MUST_RUN))
        add_similar_to_expression!(EP[:eCapResMarBalance], eCapResMarBalanceMustRun)
    end

    ### Constratints ###

    # Output of each first-bin (or singleton) must-run resource equals the sum of
    # availability * capacity across all bins in its operational cluster.
    for y in MUST_RUN_POWER_OUT
        MUST_RUN_BINS = operational_bins(gen, y)
        @constraint(EP,
            [t = 1:T],
            EP[:vP][y, t]==sum(inputs["pP_Max"][yy, t] * EP[:eTotalCap][yy]
            for yy in MUST_RUN_BINS))
    end

    # Set power variables for all bins that are not being modeled for hourly output to be zero
    for y in MUST_RUN_NO_POWER_OUT
        fix.(EP[:vP][y, :], 0.0, force = true)
    end

    ##CO2 Polcy Module Must Run Generation by zone
    @expression(EP, eGenerationByMustRun[z = 1:Z, t = 1:T], # the unit is GW
        sum(EP[:vP][y, t] for y in intersect(MUST_RUN, resources_in_zone_by_rid(gen, z))))
    add_similar_to_expression!(EP[:eGenerationByZone], eGenerationByMustRun)
end
