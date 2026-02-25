@doc raw"""
	write_co2(path::AbstractString, inputs::Dict, setup::Dict, EP::AbstractModel)

Function for reporting time-dependent CO2 emissions by zone.

"""
function write_co2(path::AbstractString, inputs::Dict, setup::Dict, EP::AbstractModel)
    write_co2_emissions_plant(path::AbstractString, inputs::Dict, setup::Dict, EP::AbstractModel)
    write_co2_capture_plant(path::AbstractString, inputs::Dict, setup::Dict, EP::AbstractModel)
    #write_co2_emissions_line(path::AbstractString, inputs::Dict, setup::Dict, EP::AbstractModel)
end

function write_co2_emissions_line(path::AbstractString,
    inputs::Dict,
    setup::Dict,
    EP::AbstractModel)

    L = inputs["L"]
    weight = inputs["omega"]
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    emissions_line_forward = value.(EP[:eForwardEmissionsByLine])
    emissions_line_forward *= scale_factor

    df = DataFrame(Line = 1:L,
        Zone = zeros(L)*NaN,
        AnnualSum = zeros(L))
    df.AnnualSum .= emissions_line_forward * weight
    write_temporal_data(df, emissions_line_forward, path, setup, "emissions_line_forward")

    emissions_line_reverse = value.(EP[:eReverseEmissionsByLine])
    emissions_line_reverse *= scale_factor

    df = DataFrame(Line = 1:L,
        Zone = zeros(L)*NaN,
        AnnualSum = zeros(L))
    df.AnnualSum .= emissions_line_reverse * weight
    write_temporal_data(df, emissions_line_reverse, path, setup, "emissions_line_reverse")
    return nothing
end

function write_co2_emissions_plant(path::AbstractString,
        inputs::Dict,
        setup::Dict,
        EP::AbstractModel)

    gen = inputs["RESOURCES"]  # Resources (objects)
    resources = inputs["RESOURCE_NAMES"] # Resource names
    zones = zone_id.(gen)

    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    assets = inputs["GENERIC_ASSETS"]
    generators = setdiff(collect(1:G),assets)

    weight = inputs["omega"]
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    
    emissions_plant = value.(EP[:eEmissionsByPlant]).data
    emissions_plant *= scale_factor

    df = DataFrame(Resource = resources[generators],
        Zone = zones[generators],
        AnnualSum = zeros(length(generators)))
    df.AnnualSum .= emissions_plant * weight

    write_temporal_data(df, emissions_plant, path, setup, "emissions_plant")
    return nothing
end

function write_co2_capture_plant(path::AbstractString, inputs::Dict, setup::Dict, EP::AbstractModel)
    gen = inputs["RESOURCES"]   # Resources (objects)
    CCS = inputs["CCS"]
    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    assets = inputs["GENERIC_ASSETS"]
    generators = setdiff(collect(1:G),assets)

    resources = inputs["RESOURCE_NAMES"][CCS]   # Resource names
    zones = zone_id.(gen[CCS])

    weight = inputs["omega"]
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    df = DataFrame(Resource = resources,
        Zone = zones,
        AnnualSum = zeros(length(CCS)))
    if !isempty(CCS)
        emissions_captured_plant = value.(EP[:eEmissionsCaptureByPlant]).data
        emissions_captured_plant *= scale_factor

        df.AnnualSum .= emissions_captured_plant * weight

        write_temporal_data(
            df, emissions_captured_plant, path, setup, "captured_emissions_plant")
    end
    return nothing
end
