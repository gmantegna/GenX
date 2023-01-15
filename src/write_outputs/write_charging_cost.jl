function write_charging_cost(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"] + (setup["VreStor"]==1 ? inputs["VRE_STOR"] : 0)    # Number of resources (generators, storage, DR, co-located resources, and DERs)
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
	if setup["VreStor"] == 1
		VRE_STOR = G+1:G
		VRE_STOR_ = inputs["VRE_STOR"]
		dfGen_VRE_STOR = inputs["dfGen_VRE_STOR"]
		chargecost[VRE_STOR, :] .= (value.(EP[:vCHARGE_VRE_STOR]).data) .* transpose(dual.(EP[:cPowerBalance]) ./ inputs["omega"])[dfGen_VRE_STOR[VRE_STOR_, :Zone], :]
	end
	if setup["ParameterScale"] == 1
	    chargecost *= ModelScalingFactor^2
	end
	dfChargingcost.AnnualSum .= chargecost * inputs["omega"]
	CSV.write(joinpath(path, "ChargingCost.csv"), dfChargingcost)
	return dfChargingcost
end
