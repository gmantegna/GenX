@doc raw"""
	write_energy_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing energy revenue from the different generation technologies.
"""
function write_energy_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]    # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	FLEX = inputs["FLEX"]
	NONFLEX = setdiff(collect(1:G), FLEX)
	dfEnergyRevenue = DataFrame(Region = dfGen.region, Resource = inputs["RESOURCES"], Zone = dfGen.Zone, Cluster = dfGen.cluster, AnnualSum = Array{Float64}(undef, G),)
	energyrevenue = zeros(G, T)
	energyrevenue[NONFLEX, :] = value.(EP[:vP][NONFLEX, :]) .* transpose(dual.(EP[:cPowerBalance]) ./ inputs["omega"])[dfGen[NONFLEX, :Zone], :]
	if !isempty(FLEX)
		energyrevenue[FLEX, :] = value.(EP[:vCHARGE_FLEX][FLEX, :]).data .* transpose(dual.(EP[:cPowerBalance]) ./ inputs["omega"])[dfGen[FLEX, :Zone], :]
	end
	if setup["ParameterScale"] == 1
		energyrevenue *= ModelScalingFactor^2
	end
	dfEnergyRevenue.AnnualSum .= energyrevenue * inputs["omega"]

	if setup["VreStor"] == 1
		VRE_STOR = inputs["VRE_STOR"]
		dfGen_VRE_STOR = inputs["dfGen_VRE_STOR"]

		dfEnergyRevenue_VRE_STOR = DataFrame(Region = dfGen_VRE_STOR.region, Resource = inputs["RESOURCES_VRE_STOR"], Zone = dfGen_VRE_STOR.Zone, Cluster = dfGen_VRE_STOR.cluster, AnnualSum = Array{Float64}(undef, VRE_STOR),)
		energyrevenue_vre_stor = zeros(VRE_STOR, T)
		energyrevenue_vre_stor = value.(EP[:vP_DC]) .* transpose(dual.(EP[:cPowerBalance]) ./ inputs["omega"])[dfGen_VRE_STOR[:, :Zone], :]
		if setup["ParameterScale"] == 1
			energyrevenue_vre_stor *= ModelScalingFactor^2
		end
		dfEnergyRevenue_VRE_STOR.AnnualSum .= energyrevenue_vre_stor * inputs["omega"]
		dfEnergyRevenue = vcat(dfEnergyRevenue, dfEnergyRevenue_VRE_STOR)
	end

	CSV.write(joinpath(path, "EnergyRevenue.csv"), dfEnergyRevenue)
	return dfEnergyRevenue
end
