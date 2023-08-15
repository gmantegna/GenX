@doc raw"""
	write_costs(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the costs pertaining to the objective function (fixed, variable O&M etc.).
"""
function write_costs(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	## Cost results
	dfGen = inputs["dfGen"]
	SEG = inputs["SEG"]  # Number of lines
	Z = inputs["Z"]     # Number of zones
	T = inputs["T"]     # Number of time steps (hours)
	VRE_STOR = inputs["VRE_STOR"]

	if !isempty(VRE_STOR)
		dfCost = DataFrame(Costs = ["cTotal", "cFix", "cVar", "cNSE", "cStart", "cUnmetRsv", "cNetworkExp", "cUnmetPolicyPenalty", "cGridConnection"])
	else
		dfCost = DataFrame(Costs = ["cTotal", "cFix", "cVar", "cNSE", "cStart", "cUnmetRsv", "cNetworkExp", "cUnmetPolicyPenalty"])
	end

	cVar = value(EP[:eTotalCVarOut]) + (!isempty(inputs["STOR_ALL"]) ? value(EP[:eTotalCVarIn]) : 0.0) + (!isempty(inputs["FLEX"]) ? value(EP[:eTotalCVarFlexIn]) : 0.0) 
	cFix = value(EP[:eTotalCFix]) + (!isempty(inputs["STOR_ALL"]) ? value(EP[:eTotalCFixEnergy]) : 0.0) + (!isempty(inputs["STOR_ASYMMETRIC"]) ? value(EP[:eTotalCFixCharge]) : 0.0)
	if !isempty(VRE_STOR) 
		cFix += ((!isempty(inputs["VS_DC"]) ? value(EP[:eTotalCFixDC]) : 0.0) + (!isempty(inputs["VS_SOLAR"]) ? value(EP[:eTotalCFixSolar]) : 0.0) + (!isempty(inputs["VS_WIND"]) ? value(EP[:eTotalCFixWind]) : 0.0))
		cVar += ((!isempty(inputs["VS_SOLAR"]) ? value(EP[:eTotalCVarOutSolar]) : 0.0) + (!isempty(inputs["VS_WIND"]) ? value(EP[:eTotalCVarOutWind]) : 0.0))
		if !isempty(inputs["VS_STOR"])
			cFix += ((!isempty(inputs["VS_STOR"]) ? value(EP[:eTotalCFixStor]) : 0.0) + (!isempty(inputs["VS_ASYM_DC_CHARGE"]) ? value(EP[:eTotalCFixCharge_DC]) : 0.0) + (!isempty(inputs["VS_ASYM_DC_DISCHARGE"]) ? value(EP[:eTotalCFixDischarge_DC]) : 0.0) + (!isempty(inputs["VS_ASYM_AC_CHARGE"]) ? value(EP[:eTotalCFixCharge_AC]) : 0.0) + (!isempty(inputs["VS_ASYM_AC_DISCHARGE"]) ? value(EP[:eTotalCFixDischarge_AC]) : 0.0)) 
			cVar += (!isempty(inputs["VS_STOR"]) ? value(EP[:eTotalCVarStor]) : 0.0)
		end
		dfCost[!,Symbol("Total")] = [objective_value(EP), cFix, cVar, value(EP[:eTotalCNSE]), 0.0, 0.0, 0.0, 0.0, 0.0]
	else
		dfCost[!,Symbol("Total")] = [objective_value(EP), cFix, cVar, value(EP[:eTotalCNSE]), 0.0, 0.0, 0.0, 0.0]
	end

	if setup["ParameterScale"] == 1
		dfCost.Total *= ModelScalingFactor^2
	end

	if setup["UCommit"]>=1
		dfCost[5,2] = value(EP[:eTotalCStart])
	end

	if setup["Reserves"]==1
		dfCost[6,2] = value(EP[:eTotalCRsvPen])
	end

	if setup["NetworkExpansion"] == 1 && Z > 1
		dfCost[7,2] = value(EP[:eTotalCNetworkExp])
	end

	if haskey(inputs, "dfCapRes_slack")
		dfCost[8,2] += value(EP[:eCTotalCapResSlack])
	end

	if haskey(inputs, "dfESR_slack")
		dfCost[8,2] += value(EP[:eCTotalESRSlack])
	end
	
	if haskey(inputs, "dfCO2Cap_slack")
		dfCost[8,2] += value(EP[:eCTotalCO2CapSlack])
	end
	
	if haskey(inputs, "MinCapPriceCap")
		dfCost[8,2] += value(EP[:eTotalCMinCapSlack])
	end	
	
	if !isempty(VRE_STOR)
		dfCost[!,2][9] = value(EP[:eTotalCGrid]) * (setup["ParameterScale"] == 1 ? ModelScalingFactor^2 : 1)
	end

	if setup["ParameterScale"] == 1
		dfCost[5,2] *= ModelScalingFactor^2
		dfCost[6,2] *= ModelScalingFactor^2
		dfCost[7,2] *= ModelScalingFactor^2
		dfCost[8,2] *= ModelScalingFactor^2
	end

	for z in 1:Z
		tempCTotal = 0.0
		tempCFix = 0.0
		tempCVar = 0.0
		tempCStart = 0.0
		tempCNSE = 0.0

		Y_ZONE = dfGen[dfGen[!,:Zone].==z,:R_ID]
		STOR_ALL_ZONE = intersect(inputs["STOR_ALL"], Y_ZONE)
		STOR_ASYMMETRIC_ZONE = intersect(inputs["STOR_ASYMMETRIC"], Y_ZONE)
		FLEX_ZONE = intersect(inputs["FLEX"], Y_ZONE)
		COMMIT_ZONE = intersect(inputs["COMMIT"], Y_ZONE)

		eCFix = sum(value.(EP[:eCFix][Y_ZONE]))
		tempCFix += eCFix
		tempCTotal += eCFix

		tempCVar = sum(value.(EP[:eCVar_out][Y_ZONE,:]))
		tempCTotal += tempCVar

		if !isempty(STOR_ALL_ZONE)
			eCVar_in = sum(value.(EP[:eCVar_in][STOR_ALL_ZONE,:]))
			tempCVar += eCVar_in
			eCFixEnergy = sum(value.(EP[:eCFixEnergy][STOR_ALL_ZONE]))
			tempCFix += eCFixEnergy

			tempCTotal += eCVar_in + eCFixEnergy
		end
		if !isempty(STOR_ASYMMETRIC_ZONE)
			eCFixCharge = sum(value.(EP[:eCFixCharge][STOR_ASYMMETRIC_ZONE]))
			tempCFix += eCFixCharge
			tempCTotal += eCFixCharge
		end
		if !isempty(FLEX_ZONE)
			eCVarFlex_in = sum(value.(EP[:eCVarFlex_in][FLEX_ZONE,:]))
			tempCVar += eCVarFlex_in
			tempCTotal += eCVarFlex_in
		end
		if !isempty(VRE_STOR)
			dfVRE_STOR = inputs["dfVRE_STOR"]
			Y_ZONE_VRE_STOR = dfVRE_STOR[dfVRE_STOR[!,:Zone].==z,:R_ID]

			# Fixed Costs
			eCFix_VRE_STOR = 0.0
			SOLAR_ZONE_VRE_STOR = intersect(Y_ZONE_VRE_STOR, inputs["VS_SOLAR"])
			if !isempty(SOLAR_ZONE_VRE_STOR)
				eCFix_VRE_STOR += sum(value.(EP[:eCFixSolar][SOLAR_ZONE_VRE_STOR]))
			end
			WIND_ZONE_VRE_STOR = intersect(Y_ZONE_VRE_STOR, inputs["VS_WIND"])
			if !isempty(WIND_ZONE_VRE_STOR)
				eCFix_VRE_STOR += sum(value.(EP[:eCFixWind][WIND_ZONE_VRE_STOR]))
			end
			DC_ZONE_VRE_STOR = intersect(Y_ZONE_VRE_STOR, inputs["VS_DC"])
			if !isempty(DC_ZONE_VRE_STOR)
				eCFix_VRE_STOR += sum(value.(EP[:eCFixDC][DC_ZONE_VRE_STOR]))
			end
			STOR_ALL_ZONE_VRE_STOR = intersect(inputs["VS_STOR"], Y_ZONE_VRE_STOR)
			if !isempty(STOR_ALL_ZONE_VRE_STOR)
				eCFix_VRE_STOR += sum(value.(EP[:eCFixEnergy_VS][STOR_ALL_ZONE_VRE_STOR]))
				DC_CHARGE_ALL_ZONE_VRE_STOR = intersect(inputs["VS_ASYM_DC_CHARGE"], Y_ZONE_VRE_STOR)
				if !isempty(DC_CHARGE_ALL_ZONE_VRE_STOR)
					eCFix_VRE_STOR += sum(value.(EP[:eCFixCharge_DC][DC_CHARGE_ALL_ZONE_VRE_STOR]))
				end
				DC_DISCHARGE_ALL_ZONE_VRE_STOR = intersect(inputs["VS_ASYM_DC_DISCHARGE"], Y_ZONE_VRE_STOR)
				if !isempty(DC_DISCHARGE_ALL_ZONE_VRE_STOR)
					eCFix_VRE_STOR += sum(value.(EP[:eCFixDischarge_DC][DC_DISCHARGE_ALL_ZONE_VRE_STOR]))
				end
				AC_DISCHARGE_ALL_ZONE_VRE_STOR = intersect(inputs["VS_ASYM_AC_DISCHARGE"], Y_ZONE_VRE_STOR)
				if !isempty(AC_DISCHARGE_ALL_ZONE_VRE_STOR)
					eCFix_VRE_STOR += sum(value.(EP[:eCFixDischarge_AC][AC_DISCHARGE_ALL_ZONE_VRE_STOR]))
				end
				AC_CHARGE_ALL_ZONE_VRE_STOR = intersect(inputs["VS_ASYM_AC_CHARGE"], Y_ZONE_VRE_STOR)
				if !isempty(AC_CHARGE_ALL_ZONE_VRE_STOR)
					eCFix_VRE_STOR += sum(value.(EP[:eCFixCharge_AC][AC_CHARGE_ALL_ZONE_VRE_STOR]))
				end
			end
			tempCFix += eCFix_VRE_STOR

			# Variable Costs
			eCVar_VRE_STOR = 0.0
			if !isempty(SOLAR_ZONE_VRE_STOR)
				eCVar_VRE_STOR += sum(value.(EP[:eCVarOutSolar][SOLAR_ZONE_VRE_STOR,:]))
			end
			if !isempty(WIND_ZONE_VRE_STOR)
				eCVar_VRE_STOR += sum(value.(EP[:eCVarOutWind][WIND_ZONE_VRE_STOR, :]))
			end
			if !isempty(STOR_ALL_ZONE_VRE_STOR)
				if !isempty(DC_CHARGE_ALL_ZONE_VRE_STOR)
					eCVar_VRE_STOR += sum(value.(EP[:eCVar_Charge_DC][DC_CHARGE_ALL_ZONE_VRE_STOR, :]))
				end
				if !isempty(DC_DISCHARGE_ALL_ZONE_VRE_STOR)
					eCVar_VRE_STOR += sum(value.(EP[:eCVar_Discharge_DC][DC_DISCHARGE_ALL_ZONE_VRE_STOR, :]))
				end
				if !isempty(AC_DISCHARGE_ALL_ZONE_VRE_STOR)
					eCVar_VRE_STOR += sum(value.(EP[:eCVar_Discharge_AC][AC_DISCHARGE_ALL_ZONE_VRE_STOR, :]))
				end
				if !isempty(AC_CHARGE_ALL_ZONE_VRE_STOR)
					eCVar_VRE_STOR += sum(value.(EP[:eCVar_Charge_AC][AC_CHARGE_ALL_ZONE_VRE_STOR, :]))
				end
			end
			tempCVar += eCVar_VRE_STOR

			# Total Added Costs
			tempCTotal += (eCFix_VRE_STOR + eCVar_VRE_STOR)
		end

		if setup["UCommit"] >= 1 && !isempty(COMMIT_ZONE)
			eCStart = sum(value.(EP[:eCStart][COMMIT_ZONE,:]))
			tempCStart += eCStart
			tempCTotal += eCStart
		end

		tempCNSE = sum(value.(EP[:eCNSE][:,:,z]))
		tempCTotal += tempCNSE

		if setup["ParameterScale"] == 1
			tempCTotal *= ModelScalingFactor^2
			tempCFix *= ModelScalingFactor^2
			tempCVar *= ModelScalingFactor^2
			tempCNSE *= ModelScalingFactor^2
			tempCStart *= ModelScalingFactor^2
		end
		if !isempty(VRE_STOR)
			dfCost[!,Symbol("Zone$z")] = [tempCTotal, tempCFix, tempCVar, tempCNSE, tempCStart, "-", "-", "-", "-"]
		else
			dfCost[!,Symbol("Zone$z")] = [tempCTotal, tempCFix, tempCVar, tempCNSE, tempCStart, "-", "-", "-"]
		end
	end
	CSV.write(joinpath(path, "costs.csv"), dfCost)
end
