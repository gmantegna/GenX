#we will have a market for every generator by having a mapping table between generator and markets

function markets!(EP::Model, inputs::Dict, setup::Dict)

    G = inputs["G"]     # Number of generators
    T = inputs["T"]     # Number of time steps
    MZ = inputs["MZ"]     # Number of markets
    Z = inputs["Z"]
   # generators_markets = inputs["Generator_Market"]

    ### Variables ###
    # 1- Amount of energy purchased/imported by each zone z at time t from the associated market
    @variable(EP, vMKT_BUY[m in MZ, t = 1:T] >= 0);   
    @variable(EP, vMKT_SELL[m in MZ, t = 1:T] >= 0);

    # # 3- Amount of energy sold/exported by each zone z at time t to the associated market
    @constraint(EP, cMaxSell[m in MZ, t = 1:T], vMKT_SELL[m,t] <= EP[:eTotalGenerationByZone][1,t])
    
    ### Constraints ###
    # 1. Maximum energy to buy from market or sell to market
    @constraint(EP, cMaxMarketBuy[m in MZ, t = 1:T], vMKT_BUY[m, t] <= inputs["Mrkt_Max_Buy"][m] ) 
    @constraint(EP, cMaxMarketSell_1[m in MZ, t = 1:T], vMKT_SELL[m, t] <= inputs["Mrkt_Max_Sell"][m] )
    
    # 4. Power balance constraint       
    @expression(EP, eZonalNetMarkets[t = 1:T, z =1:Z], 
    if z in MZ
        vMKT_BUY[z,t] - vMKT_SELL[z,t] 
    else
        EP[:vZERO]
    end)

    # Add market purchased and sold energy to power balance expression
    add_similar_to_expression!(EP[:ePowerBalance], eZonalNetMarkets)


    #### Objective function   
    Market_Buy_Prices = inputs["Market_BuyPrices"]
    @expression(EP, eMarketTotalBuy, sum( Market_Buy_Prices[m,t] * vMKT_BUY[m,t] * inputs["omega"][t] for m in MZ, t in 1:T))

    Market_Sell_Prices = inputs["Market_SellPrices"]
    @expression(EP, eMarketTotalSell, -1 * sum( Market_Sell_Prices[m,t] * vMKT_SELL[m,t] * inputs["omega"][t] for m in MZ, t in 1:T))

    add_to_expression!(EP[:eObj], eMarketTotalBuy)
    add_to_expression!(EP[:eObj], eMarketTotalSell)

end

