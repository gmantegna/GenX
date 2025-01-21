@doc raw"""
	write_custom(path::AbstractString, inputs::Dict, setup::Dict, EP::Model))

Function for writing custom constraint attributes.
"""
function write_custom(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

    constraint_name_list = inputs["CustomConstraintList"]
    lhs=zeros(size(constraint_name_list))
    duals=zeros(size(constraint_name_list))

    i=1
    for name in constraint_name_list
        constraint_i = constraint_by_name(EP,name)
        lhs[i] = value.(constraint_i)
        duals[i] = dual.(constraint_i)
        i+=1
    end
    
    dfCustom = DataFrame(
        Constraint = constraint_name_list,
        LeftHandSide = lhs,
        Dual = duals
    )
    CSV.write(joinpath(path, "custom_constraints.csv"), dfCustom)
    return dfCustom
end
