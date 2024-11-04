@doc raw"""
	custom_constraints!(EP, inputs, setup)

This module adds any custom constraints defined by the user.
"""
function custom_constraints!(EP, inputs, setup)
    println("Custom Constraints")

    gen = inputs["RESOURCES"]
    resource_names = inputs["RESOURCE_NAMES"]
    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    assets = inputs["GENERIC_ASSETS"]
    generators = setdiff(collect(1:G),assets)

    for (constraint_type,contents) in inputs["custom_constraints"]
        println(constraint_type)
        target=contents["target"]
        operator=contents["operator"]
        for constraint in operator[!,"Sum Range ID"]

            exp_name = Symbol(constraint*"_LHS")
            create_empty_expression!(EP, exp_name)
            constraint_equality_type = operator[operator[!,"Sum Range ID"].==constraint,"Operator"][1]
            constraint_target = target[target[!,"Sum Range ID"].==constraint,"Target"][1]
            if haskey(contents,"vCAP")
                vCAP=contents["vCAP"]
                vCAP_cur = vCAP[vCAP[!,"Sum Range ID"].==constraint,:]
                for resource in vCAP_cur[:,"Index 1"]
                    matching_rids = findall(>(0),[String(x)==resource for x in resource_names])
                    if length(matching_rids) > 1
                        throw("more than one matching RID found for resource $resource")
                    end
                    if length(matching_rids) == 0
                        println("did  not find matching resource for resource $resource")
                    else
                        rid=matching_rids[1]
                        if rid in axes(EP[:vCAP])[1]
                            EP[exp_name] += EP[:vCAP][rid] * vCAP_cur[vCAP_cur[!,"Index 1"].==resource,"Multiplier"][1]
                        end
                    end
                end
            end

            if EP[exp_name] != 0
                if constraint_equality_type == "=="
                    @constraint(EP,EP[exp_name] == constraint_target)
                elseif constraint_equality_type == "<="
                    @constraint(EP,EP[exp_name] <= constraint_target)
                elseif constraint_equality_type == ">="
                    @constraint(EP,EP[exp_name] >= constraint_target)
                else
                    throw("not a valid constraint equality type")
                end
            end
        end
    end

end