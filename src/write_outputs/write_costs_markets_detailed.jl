# @doc raw"""
# 	write_costs(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

# Function for writing the costs pertaining to the objective function (fixed, variable O&M etc.).
# """

# mutable struct CostComponent
#     cost_category::String
#     total_cost::Union{Float64, Missing}
#     zonal_cost::Vector{Union{Float64, Missing}}
    
#     function CostComponent(cost_category = "tmp", total_cost = missing, z = 1)
#         new(cost_category, total_cost, zeros(z))#
#     end
# end

# function write_costs_markets_detailed(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
#     Z = inputs["Z"]     # Number of zones
#     gen = inputs["RESOURCES"]
#     VRE = inputs["VRE"]
#     VRE_STOR = inputs["VRE_STOR"]
#     VS_ELEC = !isempty(VRE_STOR) ? inputs["VS_ELEC"] : Vector{Int}[]
#     ELECTROLYZER_ALL = !isempty(VS_ELEC) ? union(VS_ELEC, inputs["ELECTROLYZER"]) :
#                        inputs["ELECTROLYZER"]

#     cost_dict = Dict()
#     cost_dict["Total"] = CostComponent("Total", value(EP[:eObj]), Z)
#     cost_dict["NSE"] = CostComponent("NSE", value(EP[:eTotalCNSE]), Z)

#     cFuel = value.(EP[:eTotalCFuelOut])
#     cost_dict["Fuel"] = CostComponent("Fuel",cFuel, Z)

#     cVar = value(EP[:eTotalCVarOut]) +
#            (!isempty(inputs["STOR_ALL"]) ? value(EP[:eTotalCVarIn]) : 0.0) +
#            (!isempty(inputs["FLEX"]) ? value(EP[:eTotalCVarFlexIn]) : 0.0)

#     cost_dict["Var_Out"] = CostComponent("Variable", value(EP[:eTotalCVarOut]), Z) 
#     cost_dict["Var_STOR_ALL"] = CostComponent("Variable", (!isempty(inputs["STOR_ALL"]) ? value(EP[:eTotalCVarIn]) : 0.0), Z)
#     cost_dict["Var_FLEX"] = CostComponent("Variable", (!isempty(inputs["FLEX"]) ? value(EP[:eTotalCVarFlexIn]) : 0.0), Z)

#     cFix = value(EP[:eTotalCFix]) +
#            (!isempty(inputs["STOR_ALL"]) ? value(EP[:eTotalCFixEnergy]) : 0.0) +
#            (!isempty(inputs["STOR_ASYMMETRIC"]) ? value(EP[:eTotalCFixCharge]) : 0.0)

#     cost_dict["Fixed_Total"] = CostComponent("Fixed", value(EP[:eTotalCFix]), Z) 
#     cost_dict["Fixed_STOR_ALL"] = CostComponent("Fixed", (!isempty(inputs["STOR_ALL"]) ? value(EP[:eTotalCFixEnergy]) : 0.0), Z)
#     cost_dict["Fixed_STOR_ASYMMETRIC"] = CostComponent("Fixed", (!isempty(inputs["STOR_ASYMMETRIC"]) ? value(EP[:eTotalCFixCharge]) : 0.0) , Z)

#     cost_dict["Vre_Curtailment"] = !isempty(VRE) ? 
#                                 CostComponent("Curtailment", value(EP[:eTotalCurailmentCostVre]), Z) :
#                                 CostComponent("Curtailment", 0, Z)

#     if !isempty(VRE_STOR)
#         cFix += ((!isempty(inputs["VS_DC"]) ? value(EP[:eTotalCFixDC]) : 0.0) +
#                  (!isempty(inputs["VS_SOLAR"]) ? value(EP[:eTotalCFixSolar]) : 0.0) +
#                  (!isempty(inputs["VS_WIND"]) ? value(EP[:eTotalCFixWind]) : 0.0))
#         cost_dict["Fixed_VS_DC"] = CostComponent("Fixed", (!isempty(inputs["VS_DC"]) ? value(EP[:eTotalCFixDC]) : 0.0), Z) 
#         cost_dict["Fixed_VS_SOLAR"] = CostComponent("Fixed", (!isempty(inputs["VS_SOLAR"]) ? value(EP[:eTotalCFixSolar]) : 0.0), Z)
#         cost_dict["Fixed_VS_WIND"] = CostComponent("Fixed", (!isempty(inputs["VS_WIND"]) ? value(EP[:eTotalCFixWind]) : 0.0) , Z)
    
#         cVar += ((!isempty(inputs["VS_SOLAR"]) ? value(EP[:eTotalCVarOutSolar]) : 0.0) +
#                  (!isempty(inputs["VS_WIND"]) ? value(EP[:eTotalCVarOutWind]) : 0.0))
#         cost_dict["Var_VS_SOLAR"] = CostComponent("Variable", (!isempty(inputs["VS_SOLAR"]) ? value(EP[:eTotalCVarOutSolar]) : 0.0), Z) 
#         cost_dict["Var_VS_WIND"] = CostComponent("Variable", (!isempty(inputs["VS_WIND"]) ? value(EP[:eTotalCVarOutWind]) : 0.0), Z)

#         cost_dict["VS_Curtailment"] = CostComponent("Curtailment", value(EP[:eTotalCurailmentCostVreStore]), Z) 

#         if !isempty(inputs["VS_STOR"])
#             cFix += ((!isempty(inputs["VS_STOR"]) ? value(EP[:eTotalCFixStor]) : 0.0) +
#                      (!isempty(inputs["VS_ASYM_DC_CHARGE"]) ?
#                       value(EP[:eTotalCFixCharge_DC]) : 0.0) +
#                      (!isempty(inputs["VS_ASYM_DC_DISCHARGE"]) ?
#                       value(EP[:eTotalCFixDischarge_DC]) : 0.0) +
#                      (!isempty(inputs["VS_ASYM_AC_CHARGE"]) ?
#                       value(EP[:eTotalCFixCharge_AC]) : 0.0) +
#                      (!isempty(inputs["VS_ASYM_AC_DISCHARGE"]) ?
#                       value(EP[:eTotalCFixDischarge_AC]) : 0.0))
#             cVar += (!isempty(inputs["VS_STOR"]) ? value(EP[:eTotalCVarStor]) : 0.0)

#             cost_dict["Fixed_VS_STOR"] = CostComponent("Fixed", (!isempty(inputs["VS_STOR"]) ? value(EP[:eTotalCFixStor]) : 0.0) , Z)
#             cost_dict["Fixed_VS_ASYM_DC_CHARGE"] = CostComponent("Fixed", (!isempty(inputs["VS_ASYM_DC_CHARGE"]) ? value(EP[:eTotalCFixCharge_DC]) : 0.0) , Z)
#             cost_dict["Fixed_VS_ASYM_DC_DISCHARGE"] = CostComponent("Fixed", (!isempty(inputs["VS_ASYM_DC_DISCHARGE"]) ? value(EP[:eTotalCFixDischarge_DC]) : 0.0) , Z)
#             cost_dict["Fixed_VS_ASYM_AC_CHARGE"] = CostComponent("Fixed", (!isempty(inputs["VS_ASYM_AC_CHARGE"]) ? value(EP[:eTotalCFixCharge_AC]) : 0.0) , Z)
#             cost_dict["Fixed_VS_ASYM_AC_CHARGE"] = CostComponent("Fixed", (!isempty(inputs["VS_ASYM_AC_DISCHARGE"]) ? value(EP[:eTotalCFixDischarge_AC]) : 0.0) , Z)
    
#             cost_dict["Var_VS_STOR"] = CostComponent("Variable", (!isempty(inputs["VS_STOR"]) ? value(EP[:eTotalCVarStor]) : 0.0) , Z)   
#         end
#         cost_dict["Total_Fixed"] = CostComponent("Fixed", cFix, Z) 
#         cost_dict["Total_Variable"] = CostComponent("Variable", cVar, Z) 
#     else       
#         cost_dict["Total_Fixed"] = CostComponent("Fixed", cFix, Z) 
#         cost_dict["Total_Variable"] = CostComponent("Variable", cVar, Z) 
#     end

#     if !isempty(ELECTROLYZER_ALL)
#         cost_dict["Hydrogen_Revenue"] = CostComponent("HydrogenRevenue", -1 * value(EP[:eTotalHydrogenValue]), Z)
#     end

#     if setup["Markets"] == 1   
#         MZ = inputs["MZ"]
#         cost_dict["Market_Purshase"] = CostComponent("Market", sum(value(EP[:eCMarketBuy][m]) for m in MZ), Z)
#         cost_dict["Market_Sales"] = CostComponent("Market", sum(value(EP[:eCMarketSell][m]) for m in MZ), Z)
#     end

#     if setup["UCommit"] >= 1
#         cost_dict["Start"] = CostComponent("UCommit", value(EP[:eTotalCStart]) + value(EP[:eTotalCFuelStart]), Z)
#     end

#     if setup["OperationalReserves"] == 1
#         cost_dict["Unmet_Reserves"] = CostComponent("OperationalReserves", value(EP[:eTotalCRsvPen]), Z)
#     end

#     if setup["NetworkExpansion"] == 1 && Z > 1
#         cost_dict["Network_Expansion"] = CostComponent("NetworkExpansion", value(EP[:eTotalCNetworkExp]), Z)
#     end

#     cost_dict["cUnmetPolicyPenalty"] = CostComponent(0, Z)
#     if haskey(inputs, "dfCapRes_slack")
#         cost_dict["cUnmetPolicyPenalty"].total_cost += value(EP[:eCTotalCapResSlack])
#         cost_dict["Capacity Reserve"] = CostComponent("PolicyPenalty", value(EP[:eCTotalCapResSlack]), Z)

#     end

#     if haskey(inputs, "dfESR_slack")
#         cost_dict["cUnmetPolicyPenalty"].total_cost += value(EP[:eCTotalESRSlack])
#         cost_dict["ESR"] = CostComponent("PolicyPenalty", value(EP[:eCTotalESRSlack]), Z)
#     end

#     if haskey(inputs, "dfCO2Cap_slack")
#         cost_dict["cUnmetPolicyPenalty"].total_cost += value(EP[:eCTotalCO2CapSlack])
#         cost_dict["CO2_Cap"] = CostComponent("PolicyPenalty", value(EP[:eCTotalCO2CapSlack]), Z)
#     end

#     if haskey(inputs, "MinCapPriceCap")
#         cost_dict["cUnmetPolicyPenalty"].total_cost += value(EP[:eTotalCMinCapSlack])
#         cost_dict["Min_Capacity"] = CostComponent("PolicyPenalty", value(EP[:eTotalCMinCapSlack]), Z)
#     end

#     if haskey(inputs, "MaxCapPriceCap")
#         cost_dict["cUnmetPolicyPenalty"].total_cost += value(EP[:eTotalCMaxCapSlack])
#         cost_dict["Max_Capacity"] = CostComponent("PolicyPenalty", value(EP[:eTotalCMaxCapSlack]), Z)
#     end

#     if haskey(inputs, "MinBuildCapPriceCap")
#         cost_dict["cUnmetPolicyPenalty"].total_cost += value(EP[:eTotalCMinBuildCapSlack])
#         cost_dict["Min_Build_Capacity"] = CostComponent("PolicyPenalty", value(EP[:eTotalCMinBuildCapSlack]), Z)
#     end

#     if haskey(inputs, "MaxBuildCapPriceCap")
#         cost_dict["cUnmetPolicyPenalty"].total_cost += value(EP[:eTotalCMaxBuildCapSlack])
#         cost_dict["Max_Build_Capacity"] = CostComponent("PolicyPenalty", value(EP[:eTotalCMaxBuildCapSlack]), Z)
#     end

#     if haskey(inputs, "H2DemandPriceCap")
#         cost_dict["cUnmetPolicyPenalty"].total_cost += value(EP[:eTotalCH2DemandSlack])
#         cost_dict["H2_Demand"] = CostComponent("PolicyPenalty", value(EP[:eTotalCH2DemandSlack]), Z)
#     end

#     if haskey(inputs, "PRM_slack")
#         cost_dict["cUnmetPolicyPenalty"].total_cost += sum(value.(EP[:eCPRMSlack]))
#         cost_dict["PRM"] = CostComponent("PolicyPenalty", value(EP[:eCPRMSlack]), Z)
#     end

#     if !isempty(VRE_STOR)
#         cost_dict["cGridConnection"] = CostComponent("VRE_STOR_Grid_connection", value(EP[:eTotalCGrid]), Z)
#     end

#     if any(co2_capture_fraction.(gen) .!= 0)
#         cost_dict["CO2_Sequestration"] = CostComponent("CO2", value(EP[:eTotaleCCO2Sequestration]), Z)
#     end
    
#     if setup["RO"] == 1 
#         if inputs["ro_settings"]["BudgetOfUncertainty"] > 0
#             cost_dict["RO_Total"] = CostComponent("RO", value.(EP[:eRODualObj]), Z)
#         else
#             if inputs["ro_settings"]["BudgetOfUncertainty_MarketBuyPrices"] > 0
#                 cost_dict["RO_MBUY_Price"] = CostComponent("RO", value.(EP[:eRODualObj_mb]), Z)
#             end    
#             if inputs["ro_settings"]["BudgetOfUncertainty_MarketSellPrices"] > 0
#                 cost_dict["RO_MSELL_Price"] = CostComponent("RO", value.(EP[:eRODualObj_ms]), Z)
#             end
#             if inputs["ro_settings"]["BudgetOfUncertainty_FuelPrices"] > 0
#                 cost_dict["RO_Fuel_Price"] = CostComponent("RO", value.(EP[:eRODualObj_fc]), Z)
#             end  
#             if inputs["ro_settings"]["BudgetOfUncertainty_InvestmentCost"] > 0
#                 cost_dict["RO_Investment_Cost"] = CostComponent("RO", value.(EP[:eRODualObj_ic]), Z)
#             end    
#             if inputs["ro_settings"]["BudgetOfUncertainty_FixedOMCost"] > 0
#                 cost_dict["RO_Fixed_Cost"] = CostComponent("RO", value.(EP[:eRODualObj_fxc]), Z)
#             end
#         end              
#     end

#     for z in 1:Z
#         Y_ZONE = resources_in_zone_by_rid(gen, z)
#         VRE_ZONE = intersect(VRE, Y_ZONE)
#         STOR_ALL_ZONE = intersect(inputs["STOR_ALL"], Y_ZONE)
#         STOR_ASYMMETRIC_ZONE = intersect(inputs["STOR_ASYMMETRIC"], Y_ZONE)
#         FLEX_ZONE = intersect(inputs["FLEX"], Y_ZONE)
#         COMMIT_ZONE = intersect(inputs["COMMIT"], Y_ZONE)
#         ELECTROLYZERS_ZONE = intersect(inputs["ELECTROLYZER"], Y_ZONE)
#         CCS_ZONE = intersect(inputs["CCS"], Y_ZONE)

#         eCFix = sum(value.(EP[:eCFix][Y_ZONE]))
#         cost_dict["Fixed_Total"].zonal_cost[z] += eCFix

#         cost_dict["Var_Out"].zonal_cost[z] = sum(value.(EP[:eCVar_out][Y_ZONE, :]))
#         cost_dict["Total"].zonal_cost[z] = sum(value.(EP[:eCVar_out][Y_ZONE, :]))
#         cost_dict["Total"].zonal_cost[z] += sum(value.(EP[:ePlantCFuelOut][Y_ZONE, :]))
#         cost_dict["Total"].zonal_cost[z] += eCFix
#         cost_dict["Fuel"].zonal_cost[z] = sum(value.(EP[:ePlantCFuelOut][Y_ZONE, :]))

#         if !isempty(VRE_ZONE)
#             cost_dict["Vre_Curtailment"].zonal_cost[z] += sum(value.(EP[:eCurailmentCostVre][VRE_ZONE,:]))
#         end
#         if !isempty(STOR_ALL_ZONE)
#             eCVar_in = sum(value.(EP[:eCVar_in][STOR_ALL_ZONE, :]))
#             cost_dict["Var_STOR_ALL"].zonal_cost[z] += eCVar_in
#             eCFixEnergy = sum(value.(EP[:eCFixEnergy][STOR_ALL_ZONE]))
#             cost_dict["Fixed_STOR_ALL"].zonal_cost[z] += eCFixEnergy
#             cost_dict["Total"].zonal_cost[z] += eCVar_in + eCFixEnergy
#         end
#         if !isempty(STOR_ASYMMETRIC_ZONE)
#             eCFixCharge = sum(value.(EP[:eCFixCharge][STOR_ASYMMETRIC_ZONE]))
#             cost_dict["Fixed_STOR_ASYMMETRIC"].zonal_cost[z] += eCFixCharge
#             cost_dict["Total"].zonal_cost[z] += eCFixCharge
#         end
#         if !isempty(FLEX_ZONE)
#             eCVarFlex_in = sum(value.(EP[:eCVarFlex_in][FLEX_ZONE, :]))
#             cost_dict["Var_FLEX"].zonal_cost[z] += eCVarFlex_in
#             cost_dict["Total"].zonal_cost[z] += eCVarFlex_in
#         end

#         if !isempty(VRE_STOR)
#             gen_VRE_STOR = gen.VreStorage
#             Y_ZONE_VRE_STOR = resources_in_zone_by_rid(gen_VRE_STOR, z)

#             # Fixed Costs
#             eCFix_VRE_STOR = 0.0
#             SOLAR_ZONE_VRE_STOR = intersect(Y_ZONE_VRE_STOR, inputs["VS_SOLAR"])
#             if !isempty(SOLAR_ZONE_VRE_STOR)
#                 eCFix_VRE_STOR += sum(value.(EP[:eCFixSolar][SOLAR_ZONE_VRE_STOR]))
#                 cost_dict["Fixed_VS_SOLAR"].zonal_cost[z]+= sum(value.(EP[:eCFixSolar][SOLAR_ZONE_VRE_STOR]))
#             end
#             WIND_ZONE_VRE_STOR = intersect(Y_ZONE_VRE_STOR, inputs["VS_WIND"])
#             if !isempty(WIND_ZONE_VRE_STOR)
#                 eCFix_VRE_STOR += sum(value.(EP[:eCFixWind][WIND_ZONE_VRE_STOR]))
#                 cost_dict["Fixed_VS_WIND"].zonal_cost[z] += sum(value.(EP[:eCFixWind][WIND_ZONE_VRE_STOR]))
#             end
#             ELEC_ZONE_VRE_STOR = intersect(Y_ZONE_VRE_STOR, inputs["VS_ELEC"])
#             if !isempty(ELEC_ZONE_VRE_STOR)
#                 eCFix_VRE_STOR += sum(value.(EP[:eCFixElec][ELEC_ZONE_VRE_STOR]))
#                 cost_dict["Fixed_VS_ELEC"].zonal_cost[z] += sum(value.(EP[:eCFixElec][ELEC_ZONE_VRE_STOR]))

#             end
#             DC_ZONE_VRE_STOR = intersect(Y_ZONE_VRE_STOR, inputs["VS_DC"])
#             if !isempty(DC_ZONE_VRE_STOR)
#                 eCFix_VRE_STOR += sum(value.(EP[:eCFixDC][DC_ZONE_VRE_STOR]))
#             end
#             STOR_ALL_ZONE_VRE_STOR = intersect(inputs["VS_STOR"], Y_ZONE_VRE_STOR)
#             if !isempty(STOR_ALL_ZONE_VRE_STOR)
#                 eCFix_VRE_STOR += sum(value.(EP[:eCFixEnergy_VS][STOR_ALL_ZONE_VRE_STOR]))
#                 DC_CHARGE_ALL_ZONE_VRE_STOR = intersect(inputs["VS_ASYM_DC_CHARGE"],
#                     Y_ZONE_VRE_STOR)
#                 if !isempty(DC_CHARGE_ALL_ZONE_VRE_STOR)
#                     eCFix_VRE_STOR += sum(value.(EP[:eCFixCharge_DC][DC_CHARGE_ALL_ZONE_VRE_STOR]))
#                 end
#                 DC_DISCHARGE_ALL_ZONE_VRE_STOR = intersect(inputs["VS_ASYM_DC_DISCHARGE"],
#                     Y_ZONE_VRE_STOR)
#                 if !isempty(DC_DISCHARGE_ALL_ZONE_VRE_STOR)
#                     eCFix_VRE_STOR += sum(value.(EP[:eCFixDischarge_DC][DC_DISCHARGE_ALL_ZONE_VRE_STOR]))
#                 end
#                 AC_DISCHARGE_ALL_ZONE_VRE_STOR = intersect(inputs["VS_ASYM_AC_DISCHARGE"],
#                     Y_ZONE_VRE_STOR)
#                 if !isempty(AC_DISCHARGE_ALL_ZONE_VRE_STOR)
#                     eCFix_VRE_STOR += sum(value.(EP[:eCFixDischarge_AC][AC_DISCHARGE_ALL_ZONE_VRE_STOR]))
#                 end
#                 AC_CHARGE_ALL_ZONE_VRE_STOR = intersect(inputs["VS_ASYM_AC_CHARGE"], Y_ZONE_VRE_STOR)
#                 if !isempty(AC_CHARGE_ALL_ZONE_VRE_STOR)
#                     eCFix_VRE_STOR += sum(value.(EP[:eCFixCharge_AC][AC_CHARGE_ALL_ZONE_VRE_STOR]))
#                 end
#             end
#             cost_dict["cFix"].zonal_cost[z] += eCFix_VRE_STOR

#             # Variable Costs
#             eCVar_VRE_STOR = 0.0
#             if !isempty(SOLAR_ZONE_VRE_STOR)
#                 eCVar_VRE_STOR += sum(value.(EP[:eCVarOutSolar][SOLAR_ZONE_VRE_STOR, :]))
#             end
#             if !isempty(WIND_ZONE_VRE_STOR)
#                 eCVar_VRE_STOR += sum(value.(EP[:eCVarOutWind][WIND_ZONE_VRE_STOR, :]))
#             end
#             if !isempty(STOR_ALL_ZONE_VRE_STOR)
#                 vom_map = Dict(DC_CHARGE_ALL_ZONE_VRE_STOR => :eCVar_Charge_DC,
#                     DC_DISCHARGE_ALL_ZONE_VRE_STOR => :eCVar_Discharge_DC,
#                     AC_DISCHARGE_ALL_ZONE_VRE_STOR => :eCVar_Discharge_AC,
#                     AC_CHARGE_ALL_ZONE_VRE_STOR => :eCVar_Charge_AC)
#                 for (set, symbol) in vom_map
#                     if !isempty(set)
#                         eCVar_VRE_STOR += sum(value.(EP[symbol][set, :]))
#                     end
#                 end
#             end
#             cost_dict["cVar"].zonal_cost[z] += eCVar_VRE_STOR

#             # Total Added Costs
#             cost_dict["cTotal"].zonal_cost[z] += (eCFix_VRE_STOR + eCVar_VRE_STOR)

#             # Curtailment cost
#             if !isempty(Y_ZONE_VRE_STOR)
#                 cost_dict["cCurtailment"].zonal_cost[z] += sum(value.(EP[:eCurailmentCostVreStore][Y_ZONE_VRE_STOR,:]))
#             end
#         end

#         if setup["UCommit"] >= 1 && !isempty(COMMIT_ZONE)
#             eCStart = sum(value.(EP[:eCStart][COMMIT_ZONE, :])) +
#                       sum(value.(EP[:ePlantCFuelStart][COMMIT_ZONE, :]))
#             cost_dict["cStart"].zonal_cost[z] += eCStart
#             cost_dict["cTotal"].zonal_cost[z] += eCStart
#         end

#         if !isempty(ELECTROLYZER_ALL) # both electrolyzers and VRE+storage with electrolyzer component
#             if !isempty(ELECTROLYZERS_ZONE)
#                 cost_dict["cHydrogenRevenue"].zonal_cost[z] -= sum(value.(EP[:eHydrogenValue][ELECTROLYZERS_ZONE, :]))
#             end
#             if !isempty(VRE_STOR) && !isempty(ELEC_ZONE_VRE_STOR)
#                 cost_dict["cHydrogenRevenue"].zonal_cost[z] -= sum(value.(EP[:eHydrogenValue_vs][ELEC_ZONE_VRE_STOR, :]))
#             end
#             cost_dict["cTotal"].zonal_cost[z] += cost_dict["cHydrogenRevenue"].zonal_cost[z] 
#         end



#         cost_dict["cNSE"].zonal_cost[z] = sum(value.(EP[:eCNSE][:, :, z]))
#         cost_dict["cTotal"].zonal_cost[z] += sum(value.(EP[:eCNSE][:, :, z]))

#         # if any(dfGen.CO2_Capture_Fraction .!=0)
#         if !isempty(CCS_ZONE)
#             cost_dict["cCO2"].zonal_cost[z]  = sum(value.(EP[:ePlantCCO2Sequestration][CCS_ZONE]))
#             cost_dict["cTotal"].zonal_cost[z] += cost_dict["cCO2"].zonal_cost[z]
#         end

#         if setup["Markets"] == 1   
#             if z in inputs["MZ"] 
#                 cost_dict["cMarketPurshase"].zonal_cost[z] = value(EP[:eCMarketBuy][z])
#                 cost_dict["cMarketSales"].zonal_cost[z] = value(EP[:eCMarketSell][z])
#             end
#         end

#     end

#     scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

#     for k in collect(keys(cost_dict))
#         cost_dict[k].total_cost *= scale_factor^2
#         for z in Z
#             cost_dict[k].zonal_cost[z] *= scale_factor^2
#         end
#     end
    
#     basic_costs = ["cTotal", "cFix", "cVar", "cFuel", "cNSE"]
#     all_costs = collect(keys(cost_dict))
#     basic_costs = append!(basic_costs, setdiff(all_costs, basic_costs))

#     dfCost = DataFrame( Costs = basic_costs,
#                         Total = [cost_dict[v].total_cost for v in basic_costs]  )
#     for z in 1:Z
#         dfCost[!, "Zone$(z)"] = [cost_dict[v].zonal_cost[z] for v in basic_costs]
#     end
#     CSV.write(joinpath(path, "costs_markets.csv"), dfCost)
# end
