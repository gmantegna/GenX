@doc raw"""
	write_charge(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the charging energy values of the different storage technologies.
"""
function write_charge(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	STOR_ALL = inputs["STOR_ALL"]
	FLEX = inputs["FLEX"]
	# Power withdrawn to charge each resource in each time step
	dfCharge = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone], AnnualSum = Array{Union{Missing,Float64}}(undef, G))
	charge = zeros(G,T)

	scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
	if !isempty(STOR_ALL)
	    charge[STOR_ALL, :] = value.(EP[:vCHARGE][STOR_ALL, :]) * scale_factor
	end
	if !isempty(FLEX)
	    charge[FLEX, :] = value.(EP[:vCHARGE_FLEX][FLEX, :]) * scale_factor
	end

	dfCharge.AnnualSum .= charge * inputs["omega"]
	dfCharge = hcat(dfCharge, DataFrame(charge, :auto))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
	rename!(dfCharge,auxNew_Names)

	if setup["VreStor"] == 1
		dfGen_VRE_STOR = inputs["dfGen_VRE_STOR"]
		VRE_STOR = inputs["VRE_STOR"]

		# Power withdrawn to charge each VRE-Storage in each time step (AC grid charging)
		dfChargeVRESTOR = DataFrame(Resource = inputs["RESOURCES_VRE_STOR"], Zone = dfGen_VRE_STOR[!,:Zone], AnnualSum = Array{Union{Missing,Float32}}(undef, VRE_STOR))
		charge_vre_stor = zeros(VRE_STOR, T)
		charge_vre_stor = value.(EP[:vCHARGE_VRE_STOR]) * (setup["ParameterScale"]==1 ? ModelScalingFactor : 1)
		dfChargeVRESTOR.AnnualSum .= charge_vre_stor * inputs["omega"]
		dfChargeVRESTOR = hcat(dfChargeVRESTOR, DataFrame(charge_vre_stor, :auto))
		auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
		rename!(dfChargeVRESTOR,auxNew_Names)
		dfCharge = vcat(dfCharge, dfChargeVRESTOR)
	end

	total = DataFrame(["Total" 0 sum(dfCharge[!,:AnnualSum]) fill(0.0, (1,T))], :auto)

	total[:, 4:T+3] .= sum(charge, dims = 1)
	rename!(total,auxNew_Names)
	dfCharge = vcat(dfCharge, total)
	CSV.write(joinpath(path, "charge.csv"), dftranspose(dfCharge, false), writeheader=false)
	return dfCharge
end
