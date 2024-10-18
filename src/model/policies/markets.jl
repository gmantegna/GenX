#we will have a market for every generator by having a mapping table between generator and markets

function markets!(EP::Model, inputs::Dict, setup::Dict)

    G = inputs["G"]     # Number of generators
    T = inputs["T"]     # Number of time steps
    MZ = inputs["MZ"]     # Number of markets
    Z = inputs["Z"]
   # generators_markets = inputs["Generator_Market"]

    ### Variables ###
    # 1- Amount of energy purchased/imported by each zone z at time t from the associated market
    @variable(EP, vMBUY[m in MZ, t = 1:T] >= 0);   
    @variable(EP, vMSELL[m in MZ, t = 1:T] >= 0);

    # # 3- Amount of energy sold/exported by each zone z at time t to the associated market   
    LZ = [k for (k, v) in inputs["LZ_Markets"] if !isempty(v)]
    @constraint(EP, cMaxSell[z in LZ, t = 1:T], EP[:eTotalGenerationByZone][z,t] >= sum(vMSELL[m,t] for m in inputs["LZ_Markets"][z] ) )

    ### Constraints ###
    # 1. Maximum energy to buy from market or sell to market
    @constraint(EP, cMaxMarketBuy[m in MZ, t = 1:T], vMBUY[m, t] <= inputs["Mrkt_Max_Buy"][m] ) 
    @constraint(EP, cMaxMarketSell_1[m in MZ, t = 1:T], vMSELL[m, t] <= inputs["Mrkt_Max_Sell"][m] )
    
    # 4. Power balance constraint       
    @expression(EP, eZonalNetMarkets[t = 1:T, z =1:Z], 
    if z in MZ
        vMBUY[z,t] - vMSELL[z,t] 
    else
        EP[:vZERO]
    end)

    # Add market purchased and sold energy to power balance expression
    add_similar_to_expression!(EP[:ePowerBalance], eZonalNetMarkets)


    #### Objective function   
    Market_Buy_Prices = inputs["Market_BuyPrices"]
    @expression(EP, eCMarketBuy[m in MZ], sum( Market_Buy_Prices[m,t] * vMBUY[m,t] * inputs["omega"][t] for t in 1:T))

    Market_Sell_Prices = inputs["Market_SellPrices"]
    @expression(EP, eCMarketSell[m in MZ], -1 * sum( Market_Sell_Prices[m,t] * vMSELL[m,t] * inputs["omega"][t] for t in 1:T))

    add_to_expression!(EP[:eObj], sum(eCMarketBuy[m] for m in MZ))
    add_to_expression!(EP[:eObj], sum(eCMarketSell[m] for m in MZ))

end

