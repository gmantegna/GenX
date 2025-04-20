@doc raw"""
	ro_markets!(EP::Model, inputs::Dict, setup::Dict)
Use RO to model uncertainty in market prices, the following is the dual of the subproblem that calculates the effect of having 
```math
\begin{aligned}
\min \sum_{m \in M} \sum_{t \in T} q^{mB}_t + \sum_{m \in M} \sum_{t \in T} q^{mS}_{m,t} + \Gamma p \\
s.t.\\
q^{mB}_{m,t} + p \ge \Delta BPrice_{m,t}  \times MBUY \quad \forall m\in M, t \in T\\
q^{mS}_{m,t} + p \ge \Delta SPrice_{m,t}  \times MSELL \quad \forall m\in M, t \in T\\
q^{mS}_{m,t},q^{mS}_{m,t}, P \ge 0
\end{aligned}
```

"""
function ro!(EP::Model, inputs::Dict, setup::Dict)
   
    # define dual variables
    if inputs["ro_settings"]["BudgetOfUncertainty"] > 0
        Gamma = inputs["ro_settings"]["BudgetOfUncertainty"] * inputs["count_uncertain_param"]
        @variable(EP, p >= 0)
        @expression(EP, eRODualObj, Gamma * p)
    end

    if inputs["ro_settings"]["FuelsCost"] == 1
        ro_fuels_cost!(EP, inputs, setup)
    end   
    if inputs["ro_settings"]["InvestmentCost"] == 1
        ro_investment_cost!(EP, inputs, setup)
    end
    if inputs["ro_settings"]["FixedOMCost"] == 1
        ro_fixed_om_cost!(EP, inputs, setup)
    end 
    # Add the dual of the maximization subproblem to objective function
    if inputs["ro_settings"]["BudgetOfUncertainty"] > 0
        EP[:eObj] += eRODualObj
    end
end



function ro_fuels_cost!(EP::Model, inputs::Dict, setup::Dict)
    T = inputs["T"]     # Number of time steps
    G = inputs["G"]
    gen = inputs["RESOURCES"]
    Fuels = inputs["fuels"]
    Delta_FuelCost = inputs["fuel_delta_costs"]

    # group resources by fuel type
    resources_by_fuel = Dict{AbstractString, Array{Int}}()

    for g in 1:G
        key = fuel(gen[g])
        if !haskey(resources_by_fuel, key)
            resources_by_fuel[key] = Int[]
        end
        push!(resources_by_fuel[key], g)
    end

    # define dual variables
    if inputs["ro_settings"]["BudgetOfUncertainty"] > 0
        # define dual variables for fuel cost
        @variable(EP, qfc[f in Fuels, t = 1:T] >= 0  )

        # Constraints on the dual variables for the RO formulation
        @constraint(EP, cDualSfc[f in Fuels, t = 1:T], qfc[f, t] + EP[:p] >= Delta_FuelCost[f,t] * sum(EP[:vFuel][y,t] + EP[:vStartFuel][y, t] for y in resources_by_fuel[f]))

        add_to_expression!(EP[:eRODualObj], sum(qfc[f, t] for t in 1:T, f in Fuels))
    elseif inputs["ro_settings"]["BudgetOfUncertainty_FuelPrices"] > 0
        Gamma_fc = inputs["ro_settings"]["BudgetOfUncertainty_FuelPrices"] * inputs["count_uncertain_fuel_param"]
        println("fuel ro",Gamma_fc, "  " , inputs["count_uncertain_fuel_param"])
        @variable(EP, p_fc >= 0)
        @expression(EP, eRODualObj_fc, Gamma_fc * p_fc)
        
        # define dual variables for fuel cost
        @variable(EP, qfc[f in Fuels, t = 1:T] >= 0)

        # Constraints on the dual variables for the RO formulation
        @constraint(EP, cDualSfc[f in Fuels, t = 1:T], qfc[f, t] + p_fc >= Delta_FuelCost[f,t] * sum(EP[:vFuel][y,t] + EP[:vStartFuel][y, t] for y in resources_by_fuel[f]))

        add_to_expression!(EP[:eRODualObj_fc], sum(qfc[f, t] for t in 1:T, f in Fuels))
    end
end


function ro_investment_cost!(EP::Model, inputs::Dict, setup::Dict)
    println("ro investment cost")
    G = inputs["G"]
    gen = inputs["RESOURCES"]
    Delta_InvestmentCost = inputs["delta_investment_costs"]
    NEW_CAP = inputs["NEW_CAP"] # Set of all resources eligible for new capacity
    COMMIT = inputs["COMMIT"]

    by_rid(rid, sym) = by_rid_res(rid, sym, gen)
    
    @expression(EP, eCapacity[y in 1:G],
    if y in NEW_CAP # Resources eligible for new capacity (Non-Retrofit)
        if y in COMMIT
            cap_size(gen[y]) * EP[:vCAP][y] 
        else
            EP[:vCAP][y] 
        end
    else
        EP[:vZERO]
    end)

    if inputs["ro_settings"]["BudgetOfUncertainty"] > 0
        # define dual variables for fuel cost
        @variable(EP, qic[y in 1:G] >= 0)

        # Constraints on the dual variables for the RO formulation
        @constraint(EP, cDualSic[y in 1:G], qic[y] + EP[:p] >=
        Delta_InvestmentCost[by_rid(y, :resource)] * EP[:eCapacity][y])

        add_to_expression!(EP[:eRODualObj], sum(qic[y] for y in 1:G))
    elseif inputs["ro_settings"]["BudgetOfUncertainty_MarketSellPrices"] > 0
        Gamma_ic = inputs["ro_settings"]["BudgetOfUncertainty_InvestmentCost"] * inputs["count_uncertain_invest_param"]
        @variable(EP, p_ic >= 0)
        @expression(EP, eRODualObj_ic, Gamma_ic * p_ic) 

        # define dual variables for fuel cost
        @variable(EP, qic[y in 1:G] >= 0)

        # Constraints on the dual variables for the RO formulation
        @constraint(EP, cDualSic[y in 1:G], qic[y] + p_ic >=
        Delta_InvestmentCost[by_rid(y, :resource)] * EP[:eCapacity][y])

        add_to_expression!(EP[:eRODualObj_ic], sum(qic[y] for y in 1:G))
    end
    return nothing
end

function ro_fixed_om_cost!(EP::Model, inputs::Dict, setup::Dict)
    println("ro fixed om cost")

    G = inputs["G"]
    gen = inputs["RESOURCES"]
    Delta_FixedOMCost = inputs["delta_fixed_om_costs"]

    by_rid(rid, sym) = by_rid_res(rid, sym, gen)
    
    # define dual variables for fuel cost
    if inputs["ro_settings"]["BudgetOfUncertainty"] > 0
        @variable(EP, qfxc[y in 1:G] >= 0)

        # Constraints on the dual variables for the RO formulation
        @constraint(EP, cDualSfxc[y in 1:G], qfxc[y] + EP[:p] >=
        Delta_FixedOMCost[by_rid(y, :resource)] * EP[:eTotalCap][y])

        add_to_expression!(EP[:eRODualObj], sum(qfxc[y] for y in 1:G))
    elseif inputs["ro_settings"]["BudgetOfUncertainty_FixedOMCost"] > 0
        Gamma_fxc = inputs["ro_settings"]["BudgetOfUncertainty_FixedOMCost"] * inputs["count_uncertain_fixedom_param"]
        @variable(EP, p_fxc >= 0)
        @expression(EP, eRODualObj_fxc, Gamma_fxc * p_fxc) 

        @variable(EP, qfxc[y in 1:G] >= 0)

        # Constraints on the dual variables for the RO formulation
        @constraint(EP, cDualSfxc[y in 1:G], qfxc[y] + p_fxc >=
        Delta_FixedOMCost[by_rid(y, :resource)] * EP[:eTotalCap][y])

        add_to_expression!(EP[:eRODualObj_fxc], sum(qfxc[y] for y in 1:G))
    end
    return nothing
end