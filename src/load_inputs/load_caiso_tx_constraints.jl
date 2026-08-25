@doc raw"""
    load_caiso_tx_constraints!(setup::Dict, system_path::AbstractString, inputs::Dict)

Read input parameters related to CAISO transmission deliverability constraints
(HSN/SSN/EODS headrooms and per-resource participation factors), translated from
the new (2025+) RESOLVE CaisoTxConstraint components.
"""
function load_caiso_tx_constraints!(setup::Dict, system_path::AbstractString, inputs::Dict)
    inputs["caiso_tx_constraints"] = load_dataframe(joinpath(system_path,
        "Caiso_tx_constraints.csv"))
    inputs["caiso_tx_constraint_factors"] = load_dataframe(joinpath(system_path,
        "Caiso_tx_constraint_factors.csv"))

    println("Caiso_tx_constraints.csv Successfully Read!")
end

@doc raw"""
    load_fully_deliverable!(setup::Dict, filepath::AbstractString, inputs::Dict)

Read the per-resource fully-deliverable flags (resources whose entire capacity must
count as deliverable, i.e. vReliabilityCap == eTotalCap), matching RESOLVE's
fully_deliverable ReliabilityContribution linkages.
"""
function load_fully_deliverable!(setup::Dict, filepath::AbstractString, inputs::Dict)
    df = load_dataframe(filepath)
    resource_names = inputs["RESOURCE_NAMES"]
    rid_of = Dict(String(resource_names[g]) => g for g in 1:length(resource_names))
    fd = Set{Int}()
    nfd = Set{Int}()
    for row in eachrow(df)
        if !haskey(rid_of, String(row.Resource))
            println("did not find matching resource for fully-deliverable resource $(row.Resource)")
            continue
        end
        if row.FULLY_DELIVERABLE == 1
            push!(fd, rid_of[String(row.Resource)])
        else
            push!(nfd, rid_of[String(row.Resource)])
        end
    end
    inputs["FULLY_DELIVERABLE"] = fd
    inputs["NOT_FULLY_DELIVERABLE"] = nfd

    println("Resource_fully_deliverable.csv Successfully Read!")
end
