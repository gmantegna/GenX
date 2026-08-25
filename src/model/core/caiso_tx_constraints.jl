@doc raw"""
	caiso_tx_constraints!(EP, inputs, setup)

This module adds CAISO transmission deliverability constraints, translated from the
new (2025+) RESOLVE CaisoTxConstraint formulation. For each constraint $c$ and each
enabled constraint type:

```math
\begin{aligned}
	\sum_{r} hsn\_factor_{r,c} \times vReliabilityCap_{r} &\leq hsn\_headroom_{c} \\
	\sum_{r} ssn\_factor_{r,c} \times vReliabilityCap_{r} &\leq ssn\_headroom_{c} \\
	\sum_{r} eods\_factor_{r,c} \times eTotalCap_{r} &\leq eods\_headroom_{c}
\end{aligned}
```

vReliabilityCap corresponds to RESOLVE's reliability_capacity (FCDS capacity counted
toward the PRM), and eTotalCap to operational_capacity: energy-only deliverability
status (EODS) is determined by total operational capacity rather than FCDS capacity,
matching RESOLVE. Constraints are hard: RESOLVE's slack variables are unused in the
benchmark run, so they are not replicated here.
"""
function caiso_tx_constraints!(EP, inputs, setup)
    println("CAISO Tx Deliverability Constraints Module")

    if setup["ParameterScale"] == 1
        throw("CAISO tx constraints with ParameterScale=1 not implemented")
    end

    resource_names = inputs["RESOURCE_NAMES"]
    G = inputs["G"]
    rid_of = Dict(String(resource_names[g]) => g for g in 1:G)
    if length(rid_of) != G
        throw("duplicate resource names found when building CAISO tx constraints")
    end

    df_c = inputs["caiso_tx_constraints"]
    df_f = inputs["caiso_tx_constraint_factors"]

    missing_resources = Set{String}()
    constraint_name_list = []

    for row in eachrow(df_c)
        fac = df_f[df_f.Constraint .== row.Constraint, :]
        for (enable_col, factor_col, headroom_col, var, tag) in (
            ("HSN_enabled", "HSN_factor", "HSN_headroom_MW", :vReliabilityCap, "HSN"),
            ("SSN_enabled", "SSN_factor", "SSN_headroom_MW", :vReliabilityCap, "SSN"),
            ("EODS_enabled", "EODS_factor", "EODS_headroom_MW", :eTotalCap, "EODS"))
            row[enable_col] == 1 || continue
            # accumulate generically: under Plasmo, model variables are NodeVariableRefs,
            # so a plain JuMP.AffExpr cannot be used as the accumulator
            expr = 0.0
            for f in eachrow(fac)
                rname = String(f.Resource)
                if !haskey(rid_of, rname)
                    push!(missing_resources, rname)
                    continue
                end
                if f[factor_col] != 0
                    expr = expr + f[factor_col] * EP[var][rid_of[rname]]
                end
            end
            if !(expr isa Number)
                cname = "cCaisoTx_" * tag * "_" * row.Constraint
                @constraint(EP, expr<=row[headroom_col], base_name=cname)
                push!(constraint_name_list, cname)
            end
        end
    end

    if !isempty(missing_resources)
        println("CAISO tx constraints: skipped $(length(missing_resources)) resources not in this case")
        for r in sort(collect(missing_resources))
            println("  $r")
        end
    end

    inputs["CaisoTxConstraintList"] = constraint_name_list
end
