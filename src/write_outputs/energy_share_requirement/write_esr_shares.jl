@doc raw"""
	write_esr_revenue(path::AbstractString, inputs::Dict, setup::Dict, dfPower::DataFrame, dfESR::DataFrame, EP::Model)

Function for reporting the renewable/clean credit revenue earned by each generator listed in the input file. GenX will print this file only when RPS/CES is modeled and the shadow price can be obtained form the solver. Each row corresponds to a generator, and each column starting from the 6th to the second last is the total revenue earned from each RPS constraint. The revenue is calculated as the total annual generation (if elgible for the corresponding constraint) multiplied by the RPS/CES price. The last column is the total revenue received from all constraint. The unit is \$.
"""
function write_esr_resource_shares(path::AbstractString,
        inputs::Dict,
        setup::Dict,
        EP::Model)
    gen = inputs["RESOURCES"]
    G = inputs["G"]
    
    total_demand = Dict(i => sum(inputs["pD"][:,i]) for i in 1:inputs["Z"])
    df = DataFrame(
        resource = [gen[y].resource for y in 1:G],
        zone = [gen[y].zone for y in 1:G],
        energy = [sum(value.(EP[:vP][g,:])) for g in 1:G]    )
    
    for i in 1:inputs["nESR"]
        df[!,"participate_in_esr$i"] = [GenX.esr(gen[y], tag = i) for y in 1:G]
        df[!,"percentage_of_esr_$i"] .= df[!,"energy"] .* df[!,"participate_in_esr$i"] ./ 
            sum(inputs["dfESR"][z,i] * total_demand[z] for z in 1:inputs["Z"]) * 100  
    end

    CSV.write(joinpath(path, "ESR_resource_shares.csv"), df)

end