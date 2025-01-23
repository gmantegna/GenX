function write_reserve_margin(path::AbstractString, setup::Dict, EP::Model)
    temp_ResMar = dual.(EP[:cCapacityResMargin])
    if setup["ParameterScale"] == 1
        temp_ResMar = temp_ResMar * ModelScalingFactor # Convert from MillionUS$/GWh to US$/MWh
    end
    dfResMar = DataFrame(temp_ResMar, :auto)
    CSV.write(joinpath(path, "ReserveMargin.csv"), dfResMar)
    return nothing
end

function write_reserve_margin_ELCC(path::AbstractString, setup::Dict, EP::Model)
    PRM_dual = dual.(EP[:cCapacityResMarginELCC])
    PRM_LHS = value.(EP[:cCapacityResMarginELCC])
    dfPRM = DataFrame(
        LHS = [PRM_LHS],
        Dual = [PRM_dual],
    )
    CSV.write(joinpath(path, "PRM.csv"), dfPRM)
    return nothing
end

@doc raw"""
	write_NQC(path::AbstractString, inputs::Dict, setup::Dict, EP::Model))

Function for writing reliability capacity and NQC when using the ELCC/PRM constraints.
"""
function write_NQC(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    df_NQC=inputs["NQC_derate"]
    resource_names = inputs["RESOURCE_NAMES"]

    reliability_capacity = zeros(size(inputs["RESOURCE_NAMES"]))
    nqc = zeros(size(inputs["RESOURCE_NAMES"]))
    for y in 1:inputs["G"]
        if resource_names[y] in df_NQC[!,"Resource"]
            reliability_capacity[y] = value.(EP[:vReliabilityCap][y])
            nqc[y] = value.(EP[:vReliabilityCap][y]) * df_NQC[df_NQC[!,"Resource"].==resource_names[y],"NQC_derate"][1]
        else
            reliability_capacity[y] = value.(EP[:vReliabilityCap][y])
            nqc[y] = 0.0
        end
    end

    dfNQC = DataFrame(Resource = inputs["RESOURCE_NAMES"],
        ReliabilityCapacity = reliability_capacity,
        NQC = nqc)
    CSV.write(joinpath(path, "nqc.csv"), dfNQC)
    return dfNQC
end

