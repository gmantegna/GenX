using YAML

# Load the YAML file
example_path = "..\\example_systems\\20_run16_single2016_ro"
settings_path = joinpath(example_path,"settings\\genx_settings.yml")
ro_settings_path = joinpath(example_path,"tools\\ro_settings.yml")  # Change this to your actual file path

settings = YAML.load_file(settings_path)
ro_settings = YAML.load_file(ro_settings_path)

# Modify a parameter, e.g., changing `BudgetOfUncertainty` to 0.1
Gamma = [0.2, 0.4, 0.6, 0.8, 1.0]
for g in Gamma
    ro_settings["BudgetOfUncertainty"] = g

    # Overwrite the file with the modified content
    open(ro_settings_path, "w") do f
        YAML.write(f, ro_settings)
    end

    settings["OutputFolder"] = "results$g"
    open(settings_path, "w") do f
        YAML.write(f, settings)
    end
    include(joinpath(example_path, "Run.jl"))

end