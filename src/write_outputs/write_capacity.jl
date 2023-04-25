@doc raw"""
	write_capacity(path::AbstractString, inputs::Dict, setup::Dict, EP::Model))

Function for writing the diferent capacities for the different generation technologies (starting capacities or, existing capacities, retired capacities, and new-built capacities).
"""
function write_capacity(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	# Capacity decisions
	dfGen = inputs["dfGen"]
	MultiStage = setup["MultiStage"]
	
	capdischarge = zeros(size(inputs["RESOURCES"]))
	for i in inputs["NEW_CAP"]
		if i in inputs["COMMIT"]
			capdischarge[i] = value(EP[:vCAP][i])*dfGen[!,:Cap_Size][i]
		else
			capdischarge[i] = value(EP[:vCAP][i])
		end
	end

	retcapdischarge = zeros(size(inputs["RESOURCES"]))
	for i in inputs["RET_CAP"]
		if i in inputs["COMMIT"]
			retcapdischarge[i] = first(value.(EP[:vRETCAP][i]))*dfGen[!,:Cap_Size][i]
		else
			retcapdischarge[i] = first(value.(EP[:vRETCAP][i]))
		end
	end

	capcharge = zeros(size(inputs["RESOURCES"]))
	retcapcharge = zeros(size(inputs["RESOURCES"]))
	existingcapcharge = zeros(size(inputs["RESOURCES"]))
	for i in inputs["STOR_ASYMMETRIC"]
		if i in inputs["NEW_CAP_CHARGE"]
			capcharge[i] = value(EP[:vCAPCHARGE][i])
		end
		if i in inputs["RET_CAP_CHARGE"]
			retcapcharge[i] = value(EP[:vRETCAPCHARGE][i])
		end
		existingcapcharge[i] = MultiStage == 1 ? value(EP[:vEXISTINGCAPCHARGE][i]) : dfGen[!,:Existing_Charge_Cap_MW][i]
	end

	capenergy = zeros(size(inputs["RESOURCES"]))
	retcapenergy = zeros(size(inputs["RESOURCES"]))
	existingcapenergy = zeros(size(inputs["RESOURCES"]))
	for i in inputs["STOR_ALL"]
		if i in inputs["NEW_CAP_ENERGY"]
			capenergy[i] = value(EP[:vCAPENERGY][i])
		end
		if i in inputs["RET_CAP_ENERGY"]
			retcapenergy[i] = value(EP[:vRETCAPENERGY][i])
		end
		existingcapenergy[i] = MultiStage == 1 ? value(EP[:vEXISTINGCAPENERGY][i]) :  dfGen[!,:Existing_Cap_MWh][i]
	end
	for i in inputs["VS_STOR"]
		if i in inputs["NEW_CAP_STOR"]
			capenergy[i] = value(EP[:vCAPENERGY_VS][i])
		end
		if i in inputs["RET_CAP_STOR"]
			retcapenergy[i] = value(EP[:vRETCAPENERGY_VS][i])
		end
		existingcapenergy[i] = dfGen[!,:Existing_Cap_MWh][i] # multistage functionality doesn't exist yet for VRE-storage resources
	end

	dfCap = DataFrame(
		Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone], Resource_Type = dfGen[!,:technology], Cluster=dfGen[!,:cluster], 
		StartCap = MultiStage == 1 ? value.(EP[:vEXISTINGCAP]) : dfGen[!,:Existing_Cap_MW],
		RetCap = retcapdischarge[:],
		NewCap = capdischarge[:],
		EndCap = value.(EP[:eTotalCap]),
		StartEnergyCap = existingcapenergy[:],
		RetEnergyCap = retcapenergy[:],
		NewEnergyCap = capenergy[:],
		EndEnergyCap = existingcapenergy[:] - retcapenergy[:] + capenergy[:],
		StartChargeCap = existingcapcharge[:],
		RetChargeCap = retcapcharge[:],
		NewChargeCap = capcharge[:],
		EndChargeCap = existingcapcharge[:] - retcapcharge[:] + capcharge[:]
	)

	if !isempty(inputs["VRE_STOR"])
		dfGen_VRE_STOR = inputs["dfGen_VRE_STOR"]
		VRE_STOR = inputs["VRE_STOR"]
		dfVRECAP = DataFrame(
			Resource = inputs["RESOURCES_VRE"], Technology = dfGen_VRE_STOR[!,:technology], Cluster=dfGen_VRE_STOR[!,:cluster], Zone = dfGen_VRE_STOR[!,:Zone],
			StartCap = dfGen_VRE_STOR[!,:Existing_Cap_MW],
			RetCap = value.(EP[:vRETCAP_VRE]),
			NewCap = value.(EP[:vCAP_VRE]),
			EndCap = value.(EP[:eTotalCap_VRE]),
			StartEnergyCap = zeros(VRE_STOR),
			RetEnergyCap = zeros(VRE_STOR), 
			NewEnergyCap = zeros(VRE_STOR), 
			EndEnergyCap = zeros(VRE_STOR), 
			StartChargeCap = zeros(VRE_STOR), 
			RetChargeCap = zeros(VRE_STOR), 
			NewChargeCap = zeros(VRE_STOR), 
			EndChargeCap = zeros(VRE_STOR)
		)

		dfSTORCAP = DataFrame(
			Resource = inputs["RESOURCES_STOR"], Technology = dfGen_VRE_STOR[!,:technology], Cluster=dfGen_VRE_STOR[!,:cluster], Zone = dfGen_VRE_STOR[!,:Zone],
			StartCap = dfGen_VRE_STOR[!,:Existing_Cap_MWh] .* dfGen_VRE_STOR[!,:Power_To_Energy_Ratio],
			RetCap = value.(EP[:vRETCAPSTORAGE_VRE_STOR]) .* dfGen_VRE_STOR[!,:Power_To_Energy_Ratio],
			NewCap = value.(EP[:vCAPSTORAGE_VRE_STOR]) .* dfGen_VRE_STOR[!,:Power_To_Energy_Ratio],
			EndCap = value.(EP[:eTotalCap_STOR]) .* dfGen_VRE_STOR[!,:Power_To_Energy_Ratio],
			StartEnergyCap = dfGen_VRE_STOR[!,:Existing_Cap_MWh],
			RetEnergyCap = value.(EP[:vRETCAPSTORAGE_VRE_STOR]), 
			NewEnergyCap = value.(EP[:vCAPSTORAGE_VRE_STOR]), 
			EndEnergyCap = value.(EP[:eTotalCap_STOR]), 
			StartChargeCap = zeros(VRE_STOR), 
			RetChargeCap = zeros(VRE_STOR), 
			NewChargeCap = zeros(VRE_STOR), 
			EndChargeCap = zeros(VRE_STOR)
		)

		dfGRIDCAP = DataFrame(
			Resource = inputs["RESOURCES_GRID"], Resource_Type = dfVRE_STOR[!,:Resource_Type], Cluster=dfVRE_STOR[!,:cluster], Zone = dfVRE_STOR[!,:Zone],
			StartCap = dfVRE_STOR[!,:Existing_Cap_Grid_MW],
			RetCap = retcapgrid[:],
			NewCap = capgrid[:],
			EndCap = dfVRE_STOR[!,:Existing_Cap_Grid_MW] + capgrid[:] - retcapgrid[:],
			StartEnergyCap = zeros(VRE_STOR),
			RetEnergyCap = zeros(VRE_STOR), 
			NewEnergyCap = zeros(VRE_STOR), 
			EndEnergyCap = zeros(VRE_STOR), 
			StartChargeCap = zeros(VRE_STOR), 
			RetChargeCap = zeros(VRE_STOR), 
			NewChargeCap = zeros(VRE_STOR), 
			EndChargeCap = zeros(VRE_STOR)
		)
		vcat(dfCap, dfGRIDCAP)
	end

	if setup["ParameterScale"] ==1
		dfCap.StartCap = dfCap.StartCap * ModelScalingFactor
		dfCap.RetCap = dfCap.RetCap * ModelScalingFactor
		dfCap.NewCap = dfCap.NewCap * ModelScalingFactor
		dfCap.EndCap = dfCap.EndCap * ModelScalingFactor
		dfCap.StartEnergyCap = dfCap.StartEnergyCap * ModelScalingFactor
		dfCap.RetEnergyCap = dfCap.RetEnergyCap * ModelScalingFactor
		dfCap.NewEnergyCap = dfCap.NewEnergyCap * ModelScalingFactor
		dfCap.EndEnergyCap = dfCap.EndEnergyCap * ModelScalingFactor
		dfCap.StartChargeCap = dfCap.StartChargeCap * ModelScalingFactor
		dfCap.RetChargeCap = dfCap.RetChargeCap * ModelScalingFactor
		dfCap.NewChargeCap = dfCap.NewChargeCap * ModelScalingFactor
		dfCap.EndChargeCap = dfCap.EndChargeCap * ModelScalingFactor
	end
	total = DataFrame(
			Resource = "Total", Zone = "n/a", Resource_Type = "Total", Cluster= "n/a", 
			StartCap = sum(dfCap[!,:StartCap]), RetCap = sum(dfCap[!,:RetCap]),
			NewCap = sum(dfCap[!,:NewCap]), EndCap = sum(dfCap[!,:EndCap]),
			StartEnergyCap = sum(dfCap[!,:StartEnergyCap]), RetEnergyCap = sum(dfCap[!,:RetEnergyCap]),
			NewEnergyCap = sum(dfCap[!,:NewEnergyCap]), EndEnergyCap = sum(dfCap[!,:EndEnergyCap]),
			StartChargeCap = sum(dfCap[!,:StartChargeCap]), RetChargeCap = sum(dfCap[!,:RetChargeCap]),
			NewChargeCap = sum(dfCap[!,:NewChargeCap]), EndChargeCap = sum(dfCap[!,:EndChargeCap])
		)

	dfCap = vcat(dfCap, total)
	CSV.write(joinpath(path, "capacity.csv"), dfCap)
	return dfCap
end
