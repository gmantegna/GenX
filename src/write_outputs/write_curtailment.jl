@doc raw"""
	write_curtailment(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the curtailment values of the different variable renewable resources.
"""
function write_curtailment(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	VRE = inputs["VRE"]
	VRE_STOR = inputs["VRE_STOR"]
	if !isempty(VRE_STOR)
        SOLAR = inputs["VS_SOLAR"]
        WIND = inputs["VS_WIND"]
    end
	dfCurtailment = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!, :Zone], AnnualSum = Array{Union{Missing,Float64}}(undef, G))
	curtailment = zeros(G, T)
	if setup["ParameterScale"] == 1
		curtailment[VRE, :] = ModelScalingFactor * value.(EP[:eTotalCap][VRE]) .* inputs["pP_Max"][VRE, :] .- value.(EP[:vP][VRE, :])
		if !isempty(VRE_STOR)
			if !isempty(SOLAR)
				curtailment[SOLAR, :] = ModelScalingFactor * (value.(EP[:eTotalCap_SOLAR][SOLAR]) .* inputs["pP_Max_Solar"][SOLAR, :] .- value.(EP[:vP_SOLAR][SOLAR, :])) .* inputs["dfVRE_STOR"][!, :EtaInverter]
			end
			if !isempty(WIND)
				curtailment[WIND, :] = ModelScalingFactor * (value.(EP[:eTotalCap_WIND][WIND]) .* inputs["pP_Max_Wind"][WIND, :] .- value.(EP[:vP_WIND][WIND, :]))
			end
		end
	else
		curtailment[VRE, :] = value.(EP[:eTotalCap][VRE]) .* inputs["pP_Max"][VRE, :] .- value.(EP[:vP][VRE, :])
		if !isempty(VRE_STOR)
			if !isempty(SOLAR)
				curtailment[SOLAR, :] = (value.(EP[:eTotalCap_SOLAR][SOLAR]) .* inputs["pP_Max_Solar"][SOLAR, :] .- value.(EP[:vP_SOLAR][SOLAR, :])) .* inputs["dfVRE_STOR"][!, :EtaInverter]
			end
			if !isempty(WIND)
				curtailment[WIND, :] = (value.(EP[:eTotalCap_WIND][WIND]) .* inputs["pP_Max_Wind"][WIND, :] .- value.(EP[:vP_WIND][WIND, :]))
			end
		end
	end
	dfCurtailment.AnnualSum = curtailment * inputs["omega"]
	dfCurtailment = hcat(dfCurtailment, DataFrame(curtailment, :auto))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
	rename!(dfCurtailment,auxNew_Names)

	total = DataFrame(["Total" 0 sum(dfCurtailment[!,:AnnualSum]) fill(0.0, (1,T))], :auto)
	total[:, 4:T+3] .= sum(curtailment, dims = 1)
	rename!(total,auxNew_Names)
	dfCurtailment = vcat(dfCurtailment, total)
	CSV.write(joinpath(path, "curtail.csv"), dftranspose(dfCurtailment, false), writeheader=false)
	return dfCurtailment
end
