# This simple script is to call run.jl to run GenX

# define file path 
root_directory = pwd()
folder_directory = "example_systems\\"
model_name = "5_Ava_updated_3\\"
file_name = "Run.jl"
file_path = joinpath(root_directory, folder_directory, model_name, file_name)

#call GenX
include(file_path)