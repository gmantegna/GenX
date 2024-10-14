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
    Gamma = inputs["ro_settings"]["BudgetOfUncertainty"] * inputs["count_uncertain_param"]
   
    # define dual variables
    @variable(EP, p >= 0)
    @expression(EP, eRODualObj, Gamma * p)
    
    println("inputs[ro_settings]")
    if inputs["ro_settings"]["MarketBuyPrices"] == 1
        ro_markets_buy!(EP, inputs, setup)
    end
    if inputs["ro_settings"]["MarketSellPrices"] == 1
        ro_markets_sell!(EP, inputs, setup)
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
    EP[:eObj] += eRODualObj
end


function ro_markets_buy!(EP::Model, inputs::Dict, setup::Dict)
    println("Consider robustness in market buy prices")
    T = inputs["T"]     # Number of time steps
    MZ = inputs["MZ"] 

    Delta_BuyPrice = inputs["Market_BuyPrices_Delta"] 

    # define dual variables
    @variable(EP, qmb[m in MZ, t = 1:T] >= 0)   # q for market buy

    # Constraints on the dual variables for the RO formulation
    @constraint(EP, cDualSmb[m in MZ, t = 1:T], qmb[m, t] + EP[:p] >= Delta_BuyPrice[m,t] * EP[:vMBUY][m, t])

    add_to_expression!(EP[:eRODualObj], sum(qmb[m, t] for t in 1:T, m in MZ))
end


function ro_markets_sell!(EP::Model, inputs::Dict, setup::Dict)
    println("Consider robustness in market sell prices")
    T = inputs["T"]     # Number of time steps
    MZ = inputs["MZ"] 

    Delta_SellPrice = inputs["Market_SellPrices_Delta"] 

    # define dual variables
    @variable(EP, qms[m in MZ, t = 1:T] >= 0 ) # q for market sell

    # Constraints on the dual variables for the RO formulation
    @constraint(EP, cDualSms[m in MZ, t = 1:T], qms[m, t] + EP[:p] >= Delta_SellPrice[m,t] * EP[:vMSELL][m, t] )

    add_to_expression!(EP[:eRODualObj], sum(qms[m, t] for t in 1:T, m in MZ))
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


    # define dual variables for fuel cost
    @variables(EP, begin
        qfc[f in Fuels, t = 1:T] >= 0  
    end)

    # Constraints on the dual variables for the RO formulation
    @constraint(EP, cDualSfc[f in Fuels, t = 1:T], qfc[f, t] + EP[:p] >= Delta_FuelCost[f,t] * sum(EP[:vFuel][y,t] + EP[:vStartFuel][y, t] for y in resources_by_fuel[f]))

    add_to_expression!(EP[:eRODualObj], sum(qfc[f, t] for t in 1:T, f in Fuels))
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

    # define dual variables for fuel cost
    @variable(EP, qic[y in 1:G] >= 0)

    # Constraints on the dual variables for the RO formulation
    @constraint(EP, cDualSic[y in 1:G], qic[y] + EP[:p] >=
     Delta_InvestmentCost[by_rid(y, :resource)] * EP[:eCapacity][y])

    add_to_expression!(EP[:eRODualObj], sum(qic[y] for y in 1:G))
    return nothing
end

function ro_fixed_om_cost!(EP::Model, inputs::Dict, setup::Dict)
    println("ro fixed om cost")

    G = inputs["G"]
    gen = inputs["RESOURCES"]
    Delta_FixedOMCost = inputs["delta_fixed_om_costs"]

    by_rid(rid, sym) = by_rid_res(rid, sym, gen)
    
    # define dual variables for fuel cost
    @variable(EP, qfxc[y in 1:G] >= 0)

    # Constraints on the dual variables for the RO formulation
    @constraint(EP, cDualSfxc[y in 1:G], qfxc[y] + EP[:p] >=
    Delta_FixedOMCost[by_rid(y, :resource)] * EP[:eTotalCap][y])

    add_to_expression!(EP[:eRODualObj], sum(qfxc[y] for y in 1:G))
    return nothing
end