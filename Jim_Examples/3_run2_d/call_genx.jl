# This simple script is to call run.jl, which will run GenX

# define file path 
root_directory = pwd()
folder_directory = "Jim_Examples\\"
model_name = "3_run2_d\\"
file_name = "Run.jl"
file_path = joinpath(root_directory, folder_directory, model_name, file_name)

#call GenX
include(file_path)