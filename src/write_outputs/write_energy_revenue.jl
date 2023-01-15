@doc raw"""
	write_energy_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing energy revenue from the different generation technologies.
"""
function write_energy_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"] + (setup["VreStor"]==1 ? inputs["VRE_STOR"] : 0)    # Number of resources (generators, storage, DR, co-located resources, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	FLEX = inputs["FLEX"]
	NONFLEX = setdiff(collect(1:G), FLEX)
	dfEnergyRevenue = DataFrame(Region = dfGen.region, Resource = inputs["RESOURCES"], Zone = dfGen.Zone, Cluster = dfGen.cluster, AnnualSum = Array{Float64}(undef, G),)
	energyrevenue = zeros(G, T)
	energyrevenue[NONFLEX, :] = value.(EP[:vP][NONFLEX, :]) .* transpose(dual.(EP[:cPowerBalance]) ./ inputs["omega"])[dfGen[NONFLEX, :Zone], :]
	if !isempty(FLEX)
		energyrevenue[FLEX, :] = value.(EP[:vCHARGE_FLEX][FLEX, :]).data .* transpose(dual.(EP[:cPowerBalance]) ./ inputs["omega"])[dfGen[FLEX, :Zone], :]
	end
	if setup["VreStor"] == 1
		VRE_STOR = G+1:G
		VRE_STOR_ = inputs["VRE_STOR"]
		dfGen_VRE_STOR = inputs["dfGen_VRE_STOR"]
		energyrevenue[VRE_STOR, :] .= (value.(EP[:vP_DC]).data) .* transpose(dual.(EP[:cPowerBalance]) ./ inputs["omega"])[dfGen_VRE_STOR[VRE_STOR_, :Zone], :]
	end
	if setup["ParameterScale"] == 1
		energyrevenue *= ModelScalingFactor^2
	end
	dfEnergyRevenue.AnnualSum .= energyrevenue * inputs["omega"]
	CSV.write(joinpath(path, "EnergyRevenue.csv"), dfEnergyRevenue)
	return dfEnergyRevenue
end
