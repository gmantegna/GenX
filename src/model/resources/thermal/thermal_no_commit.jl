@doc raw"""
	thermal_no_commit!(EP::AbstractModel, inputs::Dict, setup::Dict)

This function defines the operating constraints for thermal power plants NOT subject to unit commitment constraints on power plant start-ups and shut-down decisions ($y \in H \setminus UC$).

**Ramping limits**

Thermal resources not subject to unit commitment ($y \in H \setminus UC$) adhere instead to the following ramping limits on hourly changes in power output:

```math
\begin{aligned}
	\Theta_{y,z,t-1} - \Theta_{y,z,t} \leq \kappa_{y,z}^{down} \Delta^{\text{total}}_{y,z} \hspace{1cm} \forall y \in \mathcal{H \setminus UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```

```math
\begin{aligned}
	\Theta_{y,z,t} - \Theta_{y,z,t-1} \leq \kappa_{y,z}^{up} \Delta^{\text{total}}_{y,z} \hspace{1cm} \forall y \in \mathcal{H \setminus UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```
(See Constraints 1-2 in the code)

This set of time-coupling constraints wrap around to ensure the power output in the first time step of each year (or each representative period), $t \in \mathcal{T}^{start}$, is within the eligible ramp of the power output in the final time step of the year (or each representative period), $t+\tau^{period}-1$.

**Minimum and maximum power output**

When not modeling regulation and reserves, thermal units not subject to unit commitment decisions are bound by the following limits on maximum and minimum power output:

```math
\begin{aligned}
	\Theta_{y,z,t} \geq \rho^{min}_{y,z} \times \Delta^{total}_{y,z}
	\hspace{1cm} \forall y \in \mathcal{H \setminus UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```

```math
\begin{aligned}
	\Theta_{y,z,t} \leq \rho^{max}_{y,z,t} \times \Delta^{total}_{y,z}
	\hspace{1cm} \forall y \in \mathcal{H \setminus UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```
(See Constraints 3-4 in the code)
"""
function thermal_no_commit!(EP::AbstractModel, inputs::Dict, setup::Dict)
    println("Thermal (No Unit Commitment) Resources Module")

    gen = inputs["RESOURCES"]

    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones

    p = inputs["hours_per_subperiod"] #total number of hours per subperiod

    THERM_NO_COMMIT = inputs["THERM_NO_COMMIT"]

    THERM_NO_COMMIT_POWER_OUT = intersect(THERM_NO_COMMIT,
        ids_with_positive(gen, num_vre_bins))
    THERM_NO_COMMIT_NO_POWER_OUT = setdiff(THERM_NO_COMMIT, THERM_NO_COMMIT_POWER_OUT)

    # Cluster capacity sum for a first-bin (or singleton) resource y.
    cluster_cap(y) = sum(EP[:eTotalCap][yy] for yy in operational_bins(gen, y))
    cluster_max_capacity(y, t) = sum(inputs["pP_Max"][yy, t] * EP[:eTotalCap][yy]
        for yy in operational_bins(gen, y))

    ### Expressions ###

    ## Power Balance Expressions ##
    @expression(EP, ePowerBalanceThermNoCommit[t = 1:T, z = 1:Z],
        sum(EP[:vP][y, t]
        for y in intersect(THERM_NO_COMMIT, resources_in_zone_by_rid(gen, z))))
    add_similar_to_expression!(EP[:ePowerBalance], ePowerBalanceThermNoCommit)

    ### Constraints ###

    ### Maximum ramp up and down between consecutive hours (Constraints #1-2)
    @constraints(EP,
        begin

            ## Maximum ramp up between consecutive hours
            [y in THERM_NO_COMMIT_POWER_OUT, t in 1:T],
            EP[:vP][y, t] - EP[:vP][y, hoursbefore(p, t, 1)] <=
            ramp_up_fraction(gen[y]) * cluster_cap(y)

            ## Maximum ramp down between consecutive hours
            [y in THERM_NO_COMMIT_POWER_OUT, t in 1:T],
            EP[:vP][y, hoursbefore(p, t, 1)] - EP[:vP][y, t] <=
            ramp_down_fraction(gen[y]) * cluster_cap(y)
        end)

    ### Minimum and maximum power output constraints (Constraints #3-4)
    if setup["OperationalReserves"] == 1
        # If modeling with regulation and reserves, constraints are established by thermal_no_commit_operational_reserves() function below
        thermal_no_commit_operational_reserves!(EP, inputs)
    else
        @constraints(EP,
            begin
                # Minimum stable power generated per technology "y" at hour "t" Min_Power
                [y in THERM_NO_COMMIT_POWER_OUT, t = 1:T],
                EP[:vP][y, t] >= min_power(gen[y]) * cluster_cap(y)

                # Maximum power generated per technology "y" at hour "t"
                [y in THERM_NO_COMMIT_POWER_OUT, t = 1:T],
                EP[:vP][y, t] <= cluster_max_capacity(y, t)
            end)
    end

    # Set power variables for all bins that are not being modeled for hourly output to be zero
    for y in THERM_NO_COMMIT_NO_POWER_OUT
        fix.(EP[:vP][y, :], 0.0, force = true)
    end
    # END Constraints for thermal resources not subject to unit commitment
end

@doc raw"""
	thermal_no_commit_operational_reserves!(EP::AbstractModel, inputs::Dict)

This function is called by the ```thermal_no_commit()``` function when regulation and reserves constraints are active and defines reserve related constraints for thermal power plants not subject to unit commitment constraints on power plant start-ups and shut-down decisions.

**Maximum contributions to frequency regulation and reserves**

Thermal units not subject to unit commitment adhere instead to the following constraints on maximum reserve and regulation contributions:

```math
\begin{aligned}
	f_{y,z,t} \leq \upsilon^{reg}_{y,z} \times \rho^{max}_{y,z,t} \Delta^{\text{total}}_{y,z} \hspace{1cm} \forall y \in \mathcal{H \setminus UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```

```math
\begin{aligned}
	r_{y,z,t} \leq \upsilon^{rsv}_{y,z} \times \rho^{max}_{y,z,t} \Delta^{\text{total}}_{y,z} \hspace{1cm} \forall y \in \mathcal{H \setminus UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```

where $f_{y,z,t}$ is the frequency regulation contribution limited by the maximum regulation contribution $\upsilon^{reg}_{y,z}$, and $r_{y,z,t}$ is the reserves contribution limited by the maximum reserves contribution $\upsilon^{rsv}_{y,z}$. Limits on reserve contributions reflect the maximum ramp rate for the thermal resource in whatever time interval defines the requisite response time for the regulation or reserve products (e.g., 5 mins or 15 mins or 30 mins). These response times differ by system operator and reserve product, and so the user should define these parameters in a self-consistent way for whatever system context they are modeling.

**Minimum and maximum power output**

When modeling regulation and spinning reserves, thermal units not subject to unit commitment are bound by the following limits on maximum and minimum power output:

```math
\begin{aligned}
	\Theta_{y,z,t} - f_{y,z,t} \geq \rho^{min}_{y,z} \times \Delta^{\text{total}}_{y,z}
	\hspace{1cm} \forall y \in \mathcal{H \setminus UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```

```math
\begin{aligned}
	\Theta_{y,z,t} + f_{y,z,t} + r_{y,z,t} \leq \rho^{max}_{y,z,t} \times \Delta^{\text{total}}_{y,z}
	\hspace{1cm} \forall y \in \mathcal{H \setminus UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```

Note there are multiple versions of these constraints in the code in order to avoid creation of unecessary constraints and decision variables for thermal units unable to provide regulation and/or reserves contributions due to input parameters (e.g. ```Reg_Max=0``` and/or ```RSV_Max=0```).
"""
function thermal_no_commit_operational_reserves!(EP::AbstractModel, inputs::Dict)
    println("Thermal No Commit Reserves Module")

    gen = inputs["RESOURCES"]

    T = inputs["T"]     # Number of time steps (hours)

    THERM_NO_COMMIT = setdiff(inputs["THERM_ALL"], inputs["COMMIT"])
    THERM_NO_COMMIT_POWER_OUT = intersect(THERM_NO_COMMIT,
        ids_with_positive(gen, num_vre_bins))
    THERM_NO_COMMIT_NO_POWER_OUT = setdiff(THERM_NO_COMMIT, THERM_NO_COMMIT_POWER_OUT)

    REG = intersect(THERM_NO_COMMIT_POWER_OUT, inputs["REG"]) # Set of thermal resources with regulation reserves
    RSV = intersect(THERM_NO_COMMIT_POWER_OUT, inputs["RSV"]) # Set of thermal resources with spinning reserves

    vP = EP[:vP]
    vREG = EP[:vREG]
    vRSV = EP[:vRSV]
    eTotalCap = EP[:eTotalCap]

    cluster_cap(y) = sum(eTotalCap[yy] for yy in operational_bins(gen, y))
    cluster_max_capacity(y, t) = sum(inputs["pP_Max"][yy, t] * eTotalCap[yy]
        for yy in operational_bins(gen, y))

    # Maximum regulation and reserve contributions
    @constraint(EP,
        [y in REG, t in 1:T],
        vREG[y, t]<=reg_max(gen[y]) * cluster_max_capacity(y, t))
    @constraint(EP,
        [y in RSV, t in 1:T],
        vRSV[y, t]<=rsv_max(gen[y]) * cluster_max_capacity(y, t))

    # Minimum stable power generated per technology "y" at hour "t" and contribution to regulation must be > min power
    expr = extract_time_series_to_expression(vP, THERM_NO_COMMIT_POWER_OUT)
    add_similar_to_expression!(expr[REG, :], -vREG[REG, :])
    @constraint(EP,
        [y in THERM_NO_COMMIT_POWER_OUT, t in 1:T],
        expr[y, t]>=min_power(gen[y]) * cluster_cap(y))

    # Maximum power generated per technology "y" at hour "t"  and contribution to regulation and reserves up must be < max power
    expr = extract_time_series_to_expression(vP, THERM_NO_COMMIT_POWER_OUT)
    add_similar_to_expression!(expr[REG, :], vREG[REG, :])
    add_similar_to_expression!(expr[RSV, :], vRSV[RSV, :])
    @constraint(EP,
        [y in THERM_NO_COMMIT_POWER_OUT, t in 1:T],
        expr[y, t]<=cluster_max_capacity(y, t))

    # Set reserve variables for non-first bins to zero (vP fix happens in caller)
    REG_NO_POWER = intersect(THERM_NO_COMMIT_NO_POWER_OUT, inputs["REG"])
    RSV_NO_POWER = intersect(THERM_NO_COMMIT_NO_POWER_OUT, inputs["RSV"])
    for y in REG_NO_POWER
        fix.(EP[:vREG][y, :], 0.0, force = true)
    end
    for y in RSV_NO_POWER
        fix.(EP[:vRSV][y, :], 0.0, force = true)
    end
end
