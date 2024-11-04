@doc raw"""
	load_custom_constraints!(setup::Dict, custom_constraint_path::AbstractString, inputs::Dict)

Read custom constraints
"""
function load_custom_constraints!(setup::Dict, custom_constraint_path::AbstractString, inputs::Dict)
    inputs["custom_constraints"]=Dict()
    for constraint in readdir(custom_constraint_path)
        inputs["custom_constraints"][constraint] = Dict()
        current_constraint_path = joinpath(custom_constraint_path,constraint)
        for file in readdir(current_constraint_path)
            inputs["custom_constraints"][constraint][splitext(file)[1]]=load_dataframe(current_constraint_path, file)
        end
    end
    println("hi")
end
