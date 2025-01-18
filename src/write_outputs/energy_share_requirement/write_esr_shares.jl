@doc raw"""
	write_esr_revenue(path::AbstractString, inputs::Dict, setup::Dict, dfPower::DataFrame, dfESR::DataFrame, EP::Model)

Function for reporting the renewable/clean credit revenue earned by each generator listed in the input file. GenX will print this file only when RPS/CES is modeled and the shadow price can be obtained form the solver. Each row corresponds to a generator, and each column starting from the 6th to the second last is the total revenue earned from each RPS constraint. The revenue is calculated as the total annual generation (if elgible for the corresponding constraint) multiplied by the RPS/CES price. The last column is the total revenue received from all constraint. The unit is \$.
"""
function write_esr_resource_shares(path::AbstractString,
        inputs::Dict,
        setup::Dict,
        EP::Model)
        gen = inputs["RESOURCES"]
        SOLAR = inputs["VS_SOLAR"]                                      # Set of VRE-STOR generators with solar-component
        WIND = inputs["VS_WIND"]                                        # Set of VRE-STOR generators with wind-component
        gen_VRE_STOR = gen.VreStorage                                   # Set of VRE-STOR generators (objects)
        by_rid(rid, sym) = GenX.by_rid_res(rid, sym, gen_VRE_STOR)
        
        G = inputs["G"]
    
    total_demand = Dict(i => sum(inputs["pD"][:,i]) for i in 1:inputs["Z"])
    df = DataFrame(
    resource = [gen[y].resource for y in 1:G],
    zone = [gen[y].zone for y in 1:G],
    energy = [sum(value.(EP[:vP][g,:]) .* inputs["omega"]) for g in 1:G],
    energy_vrestor = zeros(G) )

    for y in SOLAR 
        df[!, "energy_vrestor"][y] += sum(inputs["omega"] .* value.(EP[:vP_SOLAR][y, :])) *
        by_rid(y, :etainverter) 
    end
    
    for y in WIND
        df[!, "energy_vrestor"][y] += sum(inputs["omega"] .* value.(EP[:vP_WIND][y, :]))
    end

 
    for i in 1:inputs["nESR"]
        df[!,"participate_in_esr_$i"] = [GenX.esr(gen[y], tag = i) for y in 1:G]
        df[!,"participate_in_esr_vrestor_$i"] = [GenX.esr_vrestor(gen[y], tag = i) for y in 1:G]
        tmp_demand = sum(inputs["dfESR"][z,i] * total_demand[z] for z in 1:inputs["Z"])

        df[!,"percentage_of_esr_$i"] .= (df[!,"energy"] .* df[!,"participate_in_esr_$i"] ./ 
            tmp_demand * 100) +
            (df[!,"energy_vrestor"] .* df[!,"participate_in_esr_vrestor_$i"] ./ 
            tmp_demand * 100) + 
            (df[!,"energy_vrestor"] .* df[!,"participate_in_esr_vrestor_$i"] ./ 
            tmp_demand * 100)
    end

    CSV.write(joinpath(path, "ESR_resource_shares.csv"), df)

end