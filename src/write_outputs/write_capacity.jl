"""
GenX: An Configurable Capacity Expansion Model
Copyright (C) 2021,  Massachusetts Institute of Technology
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
A complete copy of the GNU General Public License v2 (GPLv2) is available
in LICENSE.txt.  Users uncompressing this from an archive may not have
received this license file.  If not, see <http://www.gnu.org/licenses/>.
"""

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
	for i in inputs["VRE_STOR_and_ASYM"]
		if i in inputs["NEW_CAP_CHARGE_VRE_STOR"]
			capcharge[i] = value(EP[:vCAPCHARGE_VRE_STOR][i])
		end
		if i in inputs["RET_CAP_CHARGE_VRE_STOR"]
			retcapcharge[i] = value(EP[:vRETCAPCHARGE_VRE_STOR][i])
		end
		existingcapcharge[i] = dfGen[!,:Existing_Charge_Cap_MW][i] # multistage functionality doesn't exist yet for VRE-storage resources
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
	for i in inputs["VRE_STOR"]
		if i in inputs["NEW_CAP_ENERGY_VRE_STOR"]
			capenergy[i] = value(EP[:vCAPENERGY_VRE_STOR][i])
		end
		if i in inputs["RET_CAP_ENERGY_VRE_STOR"]
			retcapenergy[i] = value(EP[:vRETCAPENERGY_VRE_STOR][i])
		end
		existingcapenergy[i] = dfGen[!,:Existing_Cap_MWh][i] # multistage functionality doesn't exist yet for VRE-storage resources
	end

	dfCap = DataFrame(
		Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone], Resource_Type = dfGen[!,:Resource_Type], Cluster=dfGen[!,:cluster], 
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
		dfVRE_STOR = inputs["dfVRE_STOR"]
		VRE_STOR = size(inputs["VRE_STOR"])[1]

		capgrid = zeros(size(inputs["RESOURCES_GRID"]))
		retcapgrid = zeros(size(inputs["RESOURCES_GRID"]))
		j = 1
		for i in inputs["VRE_STOR"]
			if i in inputs["NEW_CAP_GRID"]
				capgrid[j] = value((EP[:vGRIDCAP])[i])
			end
			if i in inputs["RET_CAP_GRID"]
				retcapgrid[j] = value((EP[:vRETGRIDCAP])[i])
			end
			j += 1
		end

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
