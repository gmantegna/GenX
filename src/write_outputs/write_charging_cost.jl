function write_charging_cost(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	STOR_ALL = inputs["STOR_ALL"]
	FLEX = inputs["FLEX"]
	dfChargingcost = DataFrame(Region = dfGen[!, :region], Resource = inputs["RESOURCES"], Zone = dfGen[!, :Zone], Cluster = dfGen[!, :cluster], AnnualSum = Array{Float64}(undef, G),)
	chargecost = zeros(G, T)
	if !isempty(STOR_ALL)
	    chargecost[STOR_ALL, :] .= (value.(EP[:vCHARGE][STOR_ALL, :]).data) .* transpose(dual.(EP[:cPowerBalance]) ./ inputs["omega"])[dfGen[STOR_ALL, :Zone], :]
	end
	if !isempty(FLEX)
	    chargecost[FLEX, :] .= value.(EP[:vP][FLEX, :]) .* transpose(dual.(EP[:cPowerBalance]) ./ inputs["omega"])[dfGen[FLEX, :Zone], :]
	end
	if setup["ParameterScale"] == 1
	    chargecost *= ModelScalingFactor^2
	end
	dfChargingcost.AnnualSum .= chargecost * inputs["omega"]

	if setup["VreStor"] == 1
		VRE_STOR = inputs["VRE_STOR"]
		dfGen_VRE_STOR = inputs["dfGen_VRE_STOR"]

		dfChargingcost_VRE_STOR = DataFrame(Region = dfGen_VRE_STOR.region, Resource = inputs["RESOURCES_VRE_STOR"], Zone = dfGen_VRE_STOR.Zone, Cluster = dfGen_VRE_STOR.cluster, AnnualSum = Array{Float64}(undef, VRE_STOR),)
		chargecost_vre_stor = zeros(VRE_STOR, T)
		chargecost_vre_stor = value.(EP[:vCHARGE_VRE_STOR]) .* transpose(dual.(EP[:cPowerBalance]) ./ inputs["omega"])[dfGen_VRE_STOR[:, :Zone], :]
		if setup["ParameterScale"] == 1
			chargecost_vre_stor *= ModelScalingFactor^2
		end
		dfChargingcost_VRE_STOR.AnnualSum .= chargecost_vre_stor * inputs["omega"]
		dfChargingcost = vcat(dfChargingcost, dfChargingcost_VRE_STOR)
	end

	CSV.write(joinpath(path, "ChargingCost.csv"), dfChargingcost)
	return dfChargingcost
end
