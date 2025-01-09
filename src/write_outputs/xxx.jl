# @doc raw"""
# 	write_costs(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

# Function for writing the costs pertaining to the objective function (fixed, variable O&M etc.).
# """
# mutable struct dCostComponent
#     cost_category::String
#     total_cost::Union{Float64, Missing}
#     zonal_cost::Vector{Union{Float64, Missing}}
    
#     function dCostComponent(cost_category = "tmp", total_cost = missing, z = 1)
#         new(cost_category, total_cost, zeros(z))#
#     end
# end

# function write_costs(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
#     ## Cost results
#     gen = inputs["RESOURCES"]
#     SEG = inputs["SEG"]  # Number of lines
#     Z = inputs["Z"]     # Number of zones
#     T = inputs["T"]     # Number of time steps (hours)
#     VRE_STOR = inputs["VRE_STOR"]
#     VS_ELEC = !isempty(VRE_STOR) ? inputs["VS_ELEC"] : Vector{Int}[]
#     ELECTROLYZER_ALL = !isempty(VS_ELEC) ? union(VS_ELEC, inputs["ELECTROLYZER"]) :
#                        inputs["ELECTROLYZER"]

#     cost_dict = Dict()
#     cost_dict["Total"] = dCostComponent("Total", value(EP[:eObj]), Z)
#     cost_dict["NSE"] = dCostComponent("NSE", value(EP[:eTotalCNSE]), Z)
#     cost_dict["Fuel"] = dCostComponent("Fuel", value.(EP[:eTotalCFuelOut]), Z)

#     cost_dict["FixedTotal"] = dCostComponent("Fixed", value(EP[:eTotalCFix]), Z)
#     cost_dict["VariableTotal"] = dCostComponent("Variable", value(EP[:eTotalCVarOut]), Z)

#     for z in 1:Z
#         Y_ZONE = resources_in_zone_by_rid(gen, z)
       
#         eCFix = sum(value.(EP[:eCFix][Y_ZONE]))
#         cost_dict["FixedTotal"].zonal_cost[z] += eCFix
#         cost_dict["Total"].zonal_cost[z] += eCFix

#         tempCVar = sum(value.(EP[:eCVar_out][Y_ZONE, :]))
#         cost_dict["VariableTotal"].zonal_cost[z] += tempCVar
#         cost_dict["Total"].zonal_cost[z] += tempCVar

#         tempCFuel = sum(value.(EP[:ePlantCFuelOut][Y_ZONE, :]))
#         cost_dict["Fuel"].zonal_cost[z] += tempCFuel
#         cost_dict["Total"].zonal_cost[z] += tempCFuel

#         tempCNSE = sum(value.(EP[:eCNSE][:, :, z]))
#         cost_dict["NSE"].zonal_cost[z] = tempCNSE
#         cost_dict["Total"].zonal_cost[z] += tempCNSE
#     end    

#     if !isempty(ELECTROLYZER_ALL)
#         cost_dict["HydrogenRevenue"] = dCostComponent("ELECTROLYZER", -1 * value(EP[:eTotalHydrogenValue]), Z)
#         for z in 1:Z
#             Y_ZONE = resources_in_zone_by_rid(gen, z)
#             ELECTROLYZERS_ZONE = intersect(inputs["ELECTROLYZER"], Y_ZONE)
#             if !isempty(ELECTROLYZERS_ZONE)
#                 tempHydrogenValue = sum(value.(EP[:eHydrogenValue][ELECTROLYZERS_ZONE, :]))
#                 cost_dict["Total"].zonal_cost[z] -= tempHydrogenValue
#                 cost_dict["HydrogenRevenue"].zonal_cost[z] -= tempHydrogenValue
#             end
#             if !isempty(VRE_STOR) && !isempty(ELEC_ZONE_VRE_STOR)
#                 tempHydrogenValue = sum(value.(EP[:eHydrogenValue_vs][ELEC_ZONE_VRE_STOR, :]))
#                 cost_dict["Total"].zonal_cost[z] -= tempHydrogenValue
#                 cost_dict["HydrogenRevenue"].zonal_cost[z] -= tempHydrogenValue
#             end
#         end
#     end


#     if !isempty(inputs["STOR_ALL"])
#         cost_dict["Var_STOR_ALL"] = dCostComponent("Variable", value(EP[:eTotalCVarIn]), Z) 
#         cost_dict["Fixed_STOR_ALL"] = dCostComponent("Fixed", value(EP[:eTotalCFixEnergy]), Z)

#         for z in 1:Z  
#             Y_ZONE = resources_in_zone_by_rid(gen, z)
#             STOR_ALL_ZONE = intersect(inputs["STOR_ALL"], Y_ZONE)
#             if !isempty(STOR_ALL_ZONE)
#                 eCVar_in = sum(value.(EP[:eCVar_in][STOR_ALL_ZONE, :]))
#                 cost_dict["Var_STOR_ALL"].zonal_cost[z] = eCVar_in
#                 cost_dict["VariableTotal"].zonal_cost[z] += eCVar_in

#                 eCFixEnergy = sum(value.(EP[:eCFixEnergy][STOR_ALL_ZONE]))
#                 cost_dict["Fixed_STOR_ALL"].zonal_cost[z] += eCFixEnergy
#                 cost_dict["FixedTotal"].zonal_cost[z] += eCFixEnergy
#                 cost_dict["Total"].zonal_cost[z] += eCVar_in + eCFixEnergy
#             end
#         end
#     end

#     if !isempty(inputs["STOR_ASYMMETRIC"]) 
#         cost_dict["Fixed_Charge"] = dCostComponent("Fixed", value(EP[:eTotalCFixCharge]), Z)
#         for z in 1:Z
#             Y_ZONE = resources_in_zone_by_rid(gen, z)
#             STOR_ASYMMETRIC_ZONE = intersect(inputs["STOR_ASYMMETRIC"], Y_ZONE)
#             if !isempty(STOR_ASYMMETRIC_ZONE)
#                 eCFixCharge = sum(value.(EP[:eCFixCharge][STOR_ASYMMETRIC_ZONE]))
#                 cost_dict["Fixed_Charge"].zonal_cost[z] += eCFixCharge
#                 cost_dict["FixedTotal"].zonal_cost[z] += eCFixCharge
#                 cost_dict["Total"].zonal_cost[z] += eCFixCharge
#             end
#         end
#     end

#     if !isempty(inputs["FLEX"])
#         cost_dict["Variable_FLEX"] = dCostComponent("FLEX", value(EP[:eTotalCVarFlexIn]), Z)
#         for z in 1:Z  
#             Y_ZONE = resources_in_zone_by_rid(gen, z)
#             FLEX_ZONE = intersect(inputs["FLEX"], Y_ZONE)
#             if !isempty(FLEX_ZONE)
#                 eCVarFlex_in = sum(value.(EP[:eCVarFlex_in][FLEX_ZONE, :]))
#                 cost_dict["Variable_FLEX"].zonal_cost[z] += eCVarFlex_in
#                 cost_dict["VariableTotal"].zonal_cost[z] += eCVarFlex_in
#                 cost_dict["Total"].zonal_cost[z] += eCVarFlex_in
#             end
#         end
#     end
    

#     if !isempty(VRE_STOR)  
#         cost_dict["GridConnection_VS"] = dCostComponent("VRE_STOR", value(EP[:eTotalCGrid]), Z)
#         cost_dict["Fixed_VS"] = dCostComponent("VRE_STOR", 0, Z)
#         cost_dict["Variable_VS"] = dCostComponent("VRE_STOR", 0, Z)

#         if !isempty(inputs["VS_DC"])
#             cost_dict["Fixed_VS_DC"] = dCostComponent("VRE_STOR", value(EP[:eTotalCFixDC]), Z)
#             for z in 1:Z
#                 Y_ZONE = resources_in_zone_by_rid(gen, z)
#                 DC_ZONE_VRE_STOR = intersect(Y_ZONE, inputs["VS_DC"])
#                 if !isempty(DC_ZONE_VRE_STOR)
#                     eCFix_VRE_STOR = sum(value.(EP[:eCFixDC][DC_ZONE_VRE_STOR]))
#                     cost_dict["Fixed_VS"].total_cost += eCFix_VRE_STOR
#                     cost_dict["Fixed_VS_DC"].zonal_cost[z] = eCFix_VRE_STOR
#                 end
#             end
#         end
    
    
#         if !isempty(inputs["VS_SOLAR"])
#             cost_dict["Fixed_VS_SOLAR"] = dCostComponent("VRE_STOR", value(EP[:eTotalCFixSolar]), Z)
#             cost_dict["Variable_VS_SOLAR"] = dCostComponent("VRE_STOR", value(EP[:eTotalCVarOutSolar]), Z)
#             for z in 1:Z
#                 Y_ZONE = resources_in_zone_by_rid(gen, z)
#                 SOLAR_ZONE_VRE_STOR = intersect(Y_ZONE, inputs["VS_SOLAR"])
#                 if !isempty(SOLAR_ZONE_VRE_STOR)
#                     eCFix_VRE_STOR = sum(value.(EP[:eCFixSolar][SOLAR_ZONE_VRE_STOR]))
#                     cost_dict["Fixed_VS_SOLAR"].zonal_cost[z] = eCFix_VRE_STOR
#                     cost_dict["Fixed_VS"].total_cost += eCFix_VRE_STOR

#                     eCVar_VRE_STOR += sum(value.(EP[:eCVarOutSolar][SOLAR_ZONE_VRE_STOR, :]))
#                     cost_dict["Variable_VS_SOLAR"].zonal_cost[z] = eCVar_VRE_STOR
#                     cost_dict["Variable_VS"].total_cost += eCVar_VRE_STOR
#                 end
#             end
#         end

#         if !isempty(inputs["VS_WIND"])
#             cost_dict["Fixed_VS_WIND"] = dCostComponent("VRE_STOR", value(EP[:eTotalCFixWind]), Z)
#             cost_dict["Variable_VS_WIND"] = dCostComponent("VRE_STOR", value(EP[:eTotalCVarOutWind]), Z)
#             for z in 1:Z
#                 Y_ZONE = resources_in_zone_by_rid(gen, z)
#                 WIND_ZONE_VRE_STOR = intersect(Y_ZONE, inputs["VS_WIND"])
#                 if !isempty(WIND_ZONE_VRE_STOR)
#                     eCFix_VRE_STOR = sum(value.(EP[:eCFixWind][WIND_ZONE_VRE_STOR]))
#                     cost_dict["Fixed_VS_WIND"].zonal_cost[z] = eCFix_VRE_STOR
#                     cost_dict["Fixed_VS"].total_cost += eCFix_VRE_STOR

#                     eCVar_VRE_STOR = sum(value.(EP[:eCVarOutWind][WIND_ZONE_VRE_STOR, :]))
#                     cost_dict["Variable_VS_WIND"].zonal_cost[z] = eCVar_VRE_STOR
#                     cost_dict["Variable_VS"].total_cost += eCVar_VRE_STOR                    
#                 end
#             end
#         end

#         if !isempty(inputs["VS_STOR"])
#             cost_dict["Fixed_VS_STOR"] = dCostComponent("VRE_STOR", value(EP[:eTotalCFixStor]), Z)
#             cost_dict["Variable_VS_STOR"] = dCostComponent("VRE_STOR", value(EP[:eTotalCVarStor]), Z)

#             if !isempty(inputs["VS_ASYM_DC_CHARGE"])
#                 cost_dict["Fixed_VS_ASYM_DC_CHARGE"] = dCostComponent("VS_STOR", value(EP[:eTotalCFixCharge_DC]), Z)
#             end
#             if !isempty(inputs["VS_ASYM_DC_DISCHARGE"])
#                 cost_dict["Fixed_VS_ASYM_DC_DISCHARGE"] = dCostComponent("VS_STOR", value(EP[:eTotalCFixDischarge_DC]), Z)
#             end  
#             if !isempty(inputs["VS_ASYM_AC_CHARGE"])
#                 cost_dict["Fixed_VS_ASYM_AC_CHARGE"] = dCostComponent("VS_STOR", value(EP[:eTotalCFixCharge_AC]), Z)
#             end 
#             if !isempty(inputs["VS_ASYM_AC_DISCHARGE"])
#                 cost_dict["Fixed_VS_ASYM_AC_DISCHARGE"] = dCostComponent("VS_STOR", value(EP[:eTotalCFixDischarge_AC]), Z)
#             end 
#             if !isempty(inputs["VS_ELEC"])
#                 eCFix_VRE_STOR += sum(value.(EP[:eCFixElec][ELEC_ZONE_VRE_STOR]))
#                 cost_dict["Fixed_VS_ELEC"] = dCostComponent("VS_STOR", value(EP[:eTotalCFixElec]), Z)
#             end
#             if !isempty(ELECTROLYZER_ALL)
#                 cost_dict["TotalHydrogen"] = dCostComponent("Hydrogen", -1 * value(EP[:eTotalHydrogenValue]), Z)
#             end


#             for z in 1:Z
#                 Y_ZONE = resources_in_zone_by_rid(gen, z)
#                 STOR_ALL_ZONE_VRE_STOR = intersect(Y_ZONE, inputs["VS_STOR"])
#                 if !isempty(STOR_ALL_ZONE_VRE_STOR)
#                     eCFix_VRE_STOR = sum(value.(EP[:eCFixEnergy_VS][STOR_ALL_ZONE_VRE_STOR]))
#                     cost_dict["Fixed_VS_STOR"].zonal_cost[z] += eCFix_VRE_STOR
#                     cost_dict["Fixed_VS"].total_cost += eCFix_VRE_STOR

#                     DC_CHARGE_ALL_ZONE_VRE_STOR = intersect(Y_ZONE, inputs["VS_ASYM_DC_CHARGE"])
#                     if !isempty(DC_CHARGE_ALL_ZONE_VRE_STOR)
#                         eCFix_VRE_STOR = sum(value.(EP[:eCFixCharge_DC][DC_CHARGE_ALL_ZONE_VRE_STOR]))
#                         cost_dict["Fixed_VS_ASYM_DC_CHARGE"].zonal_cost[z] += eCFix_VRE_STOR
#                         cost_dict["Fixed_VS_STOR"].zonal_cost[z] += eCFix_VRE_STOR
#                         cost_dict["Fixed_VS"].total_cost += eCFix_VRE_STOR

#                         eCVar_VRE_STOR += sum(value.(EP[:eCVar_Charge_DC][DC_CHARGE_ALL_ZONE_VRE_STOR, :]))

#                     end

#                     DC_DISCHARGE_ALL_ZONE_VRE_STOR = intersect(Y_ZONE, inputs["VS_ASYM_DC_DISCHARGE"])
#                     if !isempty(DC_DISCHARGE_ALL_ZONE_VRE_STOR)
#                         eCFix_VRE_STOR = sum(value.(EP[:eCFixDischarge_DC][DC_DISCHARGE_ALL_ZONE_VRE_STOR]))
#                         cost_dict["Fixed_VS_ASYM_DC_DISCHARGE"].zonal_cost[z] += eCFix_VRE_STOR
#                         cost_dict["Fixed_VS_STOR"].zonal_cost[z] += eCFix_VRE_STOR
#                         cost_dict["Fixed_VS"].total_cost += eCFix_VRE_STOR

#                         eCVar_VRE_STOR = sum(value.(EP[:eCVar_Discharge_DC][DC_DISCHARGE_ALL_ZONE_VRE_STOR, :]))
#                         cost_dict["Variable_VS_ASYM_DC_DISCHARGE"].zonal_cost[z] += eCVar_VRE_STOR
#                         cost_dict["Variable_VS_STOR"].zonal_cost[z] += eCVar_VRE_STOR
#                         cost_dict["Variable_VS"].total_cost += eCVar_VRE_STOR
                       
#                     end

#                     AC_CHARGE_ALL_ZONE_VRE_STOR = intersect(Y_ZONE, inputs["VS_ASYM_AC_CHARGE"])
#                     if !isempty(AC_CHARGE_ALL_ZONE_VRE_STOR)
#                         eCFix_VRE_STOR = sum(value.(EP[:eCFixCharge_AC][AC_CHARGE_ALL_ZONE_VRE_STOR]))
#                         cost_dict["Fixed_VS_ASYM_AC_CHARGE"].zonal_cost[z] += eCFix_VRE_STOR
#                         cost_dict["Fixed_VS_STOR"].zonal_cost[z] += eCFix_VRE_STOR
#                         cost_dict["Fixed_VS"].total_cost += eCFix_VRE_STOR

#                         eCVar_VRE_STOR = sum(value.(EP[:eCVar_Charge_AC][AC_CHARGE_ALL_ZONE_VRE_STOR, :]))
#                         cost_dict["Variable_VS_ASYM_AC_CHARGE"].zonal_cost[z] += eCVar_VRE_STOR
#                         cost_dict["Variable_VS_STOR"].zonal_cost[z] += eCVar_VRE_STOR
#                         cost_dict["Variable_VS"].total_cost += eCVar_VRE_STOR
#                     end

#                     AC_DISCHARGE_ALL_ZONE_VRE_STOR = intersect(Y_ZONE, inputs["VS_ASYM_AC_DISCHARGE"])
#                     if !isempty(AC_DISCHARGE_ALL_ZONE_VRE_STOR)
#                         eCFix_VRE_STOR = sum(value.(EP[:eCFixDischarge_AC][AC_DISCHARGE_ALL_ZONE_VRE_STOR]))
#                         cost_dict["Fixed_VS_ASYM_AC_DISCHARGE"].zonal_cost[z] += eCFix_VRE_STOR
#                         cost_dict["Fixed_VS_STOR"].zonal_cost[z] += eCFix_VRE_STOR
#                         cost_dict["Fixed_VS"].total_cost += eCFix_VRE_STOR

#                         eCVar_VRE_STOR += sum(value.(EP[:eCVar_Discharge_AC][AC_DISCHARGE_ALL_ZONE_VRE_STOR, :]))
#                         cost_dict["Variable_VS_ASYM_AC_DISCHARGE"].zonal_cost[z] += eCVar_VRE_STOR
#                         cost_dict["Variable_VS_STOR"].zonal_cost[z] += eCVar_VRE_STOR
#                         cost_dict["Variable_VS"].total_cost += eCVar_VRE_STOR
#                     end

                                               
#                     ELEC_ZONE_VRE_STOR = intersect(Y_ZONE, inputs["VS_ELEC"])
#                     if !isempty(ELEC_ZONE_VRE_STOR)
#                         eCFix_VRE_STOR = sum(value.(EP[:eCFixElec][ELEC_ZONE_VRE_STOR]))
#                         cost_dict["Fixed_VS_ELEC"].zonal_cost[z] += eCFix_VRE_STOR
#                     end
#                 end
#             end        
#         end

#     end
    
#     if setup["UCommit"] >= 1
#         cost_dict["Start"] = dCostComponent("Start", value(EP[:eTotalCStart]) + value(EP[:eTotalCFuelStart]), Z)
#         for z in 1:Z
#             Y_ZONE = resources_in_zone_by_rid(gen, z)
#             COMMIT_ZONE = intersect(Y_ZONE, inputs["COMMIT"])
#             if !isempty(COMMIT_ZONE)
#                 eCStart = sum(value.(EP[:eCStart][COMMIT_ZONE, :])) +
#                           sum(value.(EP[:ePlantCFuelStart][COMMIT_ZONE, :]))
                
#                 cost_dict["Start"].zonal_cost[z] += eCStart
#                 cost_dict["Total"].zonal_cost[z] += eCStart
#             end
#         end
#     end

#     if setup["Markets"] == 1   
#         MZ = inputs["MZ"]
#         cost_dict["cMarketPurshase"] = CostComponent(sum(value(EP[:eCMarketBuy][m]) for m in MZ), Z)
#         cost_dict["cMarketSales"] = CostComponent(sum(value(EP[:eCMarketSell][m]) for m in MZ), Z)
#         for z in MZ
#             cost_dict["cMarketPurshase"].zonal_cost[z] = value(EP[:eCMarketBuy][z])
#             cost_dict["cMarketSales"].zonal_cost[z] = value(EP[:eCMarketSell][z])
#         end
#     end

#     ############# Fill RO
#     if setup["RO"] == 1   
#         (inputs["ro_settings"]["MarketBuyPrices"] == 1) && push!(cost_list, "cROMarketPurshase")
#         (inputs["ro_settings"]["MarketSellPrices"] == 1) && push!(cost_list, "cROMarketSales")
#         (inputs["ro_settings"]["FuelsCost"] == 1) && push!(cost_list, "cROFuel")
#     end

#     if setup["OperationalReserves"] == 1
#         cost_dict["UnmetReserves"] = dCostComponent("OperationalReserves", value(EP[:eTotalCRsvPen]), Z)
#     end

#     if setup["NetworkExpansion"] == 1 && Z > 1
#         cost_dict["NetworkExpansion"] = dCostComponent("NetworkExpansion", value(EP[:eTotalCNetworkExp]), Z)
#     end

#     if haskey(inputs, "dfCapRes_slack")
#         cost_dict["CapRes"] = dCostComponent("PolicyPenalty", value(EP[:eCTotalCapResSlack]), Z)
#     end

#     if haskey(inputs, "dfESR_slack")
#         cost_dict["ESR"] = dCostComponent("PolicyPenalty", value(EP[:eCTotalESRSlack]), Z)
#     end

#     if haskey(inputs, "dfCO2Cap_slack")
#         cost_dict["CO2Cap"] = dCostComponent("PolicyPenalty", value(EP[:eCTotalCO2CapSlack]), Z)
#     end

#     if haskey(inputs, "MinCapPriceCap")
#         cost_dict["MinCap"] = dCostComponent("PolicyPenalty", value(EP[:eTotalCMinCapSlack]), Z)
#     end

#     if haskey(inputs, "MaxCapPriceCap")
#         cost_dict["MaxCap"] = dCostComponent("PolicyPenalty", value(EP[:eTotalCMaxCapSlack]), Z)
#     end

#     if haskey(inputs, "MinBuildCapPriceCap")
#         cost_dict["MinBuildCap"].total_cost += value(EP[:eTotalCMinBuildCapSlack])
#     end

#     if haskey(inputs, "MaxBuildCapPriceCap")
#         cost_dict["cUnmetPolicyPenalty"].total_cost += value(EP[:eTotalCMaxBuildCapSlack])
#     end


#     if haskey(inputs, "H2DemandPriceCap")
#         cost_dict["H2DemandPrice"] = dCostComponent("PolicyPenalty", value(EP[:eTotalCH2DemandSlack]), Z)
#     end

#     if any(co2_capture_fraction.(gen) .!= 0)
#         cost_dict["CO2Sequestration"] = dCostComponent("CO2", value(EP[:eTotaleCCO2Sequestration]), Z)
#         for z in 1:Z
#             Y_ZONE = resources_in_zone_by_rid(gen, z)
#             CCS_ZONE = intersect(inputs["CCS"], Y_ZONE)
    
#             if !isempty(CCS_ZONE)
#                 tempCCO2 = sum(value.(EP[:ePlantCCO2Sequestration][CCS_ZONE]))
#                 cost_dict["CO2Sequestration"].zonal_cost[z] += tempCCO2
#                 cost_dict["Total"].zonal_cost[z] += tempCCO2
#             end
#         end            
#     end

    
    
#     CSV.write(joinpath(path, "costs.csv"), dfCost)
# end
