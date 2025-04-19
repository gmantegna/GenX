function define_multi_stage_linking_constraints!(graph::Plasmo.OptiGraph,setup::Dict,inputs::Dict)
    
    start_cap_d, cap_track_d = configure_ddp_dicts(setup, inputs[1])


    for t in 2:setup["MultiStageSettingsDict"]["NumStages"]

        ALL_CAP = union(inputs[t]["RET_CAP"], inputs[t]["NEW_CAP"]) # Set of all resources subject to inter-stage capacity tracking

        EP_cur = graph.optinodes[t];
        EP_prev = graph.optinodes[t-1];

        for (e,c) in start_cap_d
            for y in keys(EP_cur[c])
                if c == :cExistingTransCap
                    cobj = constraint_object(EP_cur[c][y])
                    @linkconstraint(graph, cobj.func == EP_prev[e][y])
                    delete(EP_cur ,EP_cur[c][y])
                else
                    if y[1] in ALL_CAP # extract resource integer index value from key
                        cobj = constraint_object(EP_cur[c][y])
                        @linkconstraint(graph, cobj.func == EP_prev[e][y])
                        delete(EP_cur,EP_cur[c][y[1]])
                    end
                end
            end   
        end

        for (v, c) in cap_track_d

            # Tracking variables and constraints for retired capacity are named identicaly to those for newly
            # built capacity, except have the prefex "vRET" and "cRet", accordingly
            rv = Symbol("vRET", string(v)[2:end]) # Retired capacity tracking variable name (rv)
            rc = Symbol("cRet", string(c)[2:end]) # Retired capacity tracking constraint name (rc)
    
            for y in keys(EP_cur[c])
                y = y[1] # Extract integer index value from keys tuple - corresponding to generator index
    
                # For all previous stages, set the right hand side value of the tracking constraint in the current
                # stage to the value of the tracking constraint observed in the previous stage
                for p in 1:(t - 1)
                    # Tracking newly buily capacity over all previous stages
                    cobj = constraint_object(EP_cur[c][y,p])
                    @linkconstraint(graph, cobj.func == EP_prev[v][y,p])
                    # Tracking retired capacity over all previous stages
                    rcobj = constraint_object(EP_cur[rc][y,p])
                    @linkconstraint(graph, rcobj.func == EP_prev[rv][y,p])
                end
            end
            for k in keys(EP_cur[c])
                delete(EP_cur,EP_cur[c][k])
                delete(EP_cur,EP_cur[rc][k])
            end

        end
    
        
        
    end

    return nothing



end

@doc raw"""
	discount_objective_function!(EP::AbstractModel, settings_d::Dict, inputs::Dict)
This function scales the model objective function so that costs are consistent with multi-stage modeling and introduces a cost-to-go function variable to the objective function.

    The updated objective function $OBJ^{*}$ returned by this method takes the form:
    ```math
    \begin{aligned}
        OBJ^{*} = DF * OPEXMULT * OBJ
    \end{aligned}
    ```
    where $OBJ$ is the original objective function. $OBJ$ is scaled by two terms. The first is a discount factor (applied only in the non-myopic case), which discounts costs associated with the model stage $p$ to year-0 dollars:
    ```math
    \begin{aligned}
        DF = \frac{1}{(1+WACC)^{\sum^{(p-1)}_{k=0}L_{k}}}
    \end{aligned}
    ```
    where $WACC$ is the weighted average cost of capital, and $L_{p}$ is the length of each stage in years (both set in multi\_stage\_settings.yml)
    
    The second term is a discounted sum of annual operational expenses incurred each year of a multi-year model stage:
    ```math
    \begin{aligned}
        & OPEXMULT = \sum^{L}_{l=1}\frac{1}{(1+WACC)^{l-1}}
    \end{aligned}
    ```
    Note that although the objective function contains investment costs, which occur only once and thus do not need to be scaled by OPEXMULT, these costs are multiplied by a factor of $\frac{1}{WACC}$ before being added to the objective function in investment\_discharge\_multi\_stage(), investment\_charge\_multi\_stage(), investment\_energy\_multi\_stage(), and transmission\_multi\_stage(). Thus, this step scales these costs back to their correct value.
"""    
function discount_objective_function!(EP::AbstractModel, settings::Dict, inputs::Dict)
    settings_d = settings["MultiStageSettingsDict"]
    cur_stage = settings_d["CurStage"] # Current DDP Investment Planning Stage
    cum_years = 0
    for stage_count in 1:(cur_stage - 1)
        cum_years += settings_d["StageLengths"][stage_count]
    end
    stage_len = settings_d["StageLengths"][cur_stage]
    wacc = settings_d["WACC"] # Interest Rate  and also the discount rate unless specified other wise
    myopic = settings_d["Myopic"] == 1 # 1 if myopic (only one forward pass), 0 if full DDP
    OPEXMULT = inputs["OPEXMULT"] # OPEX multiplier to count multiple years between two model stages, set in configure_multi_stage_inputs.jl


    if myopic
        ### Do nothing: no discount factor or OPEX multiplier applied in myopic case as costs are left annualized.
    else
        # Multiply discount factor to all terms except the alpha term or the cost-to-go function
        # All OPEX terms get an additional adjustment factor

        DF = 1 / (1 + wacc)^(cum_years)  # Discount factor applied all to costs in each stage ###
        # Initialize the cost-to-go variable
        EP[:eDiscountedObj] = DF * OPEXMULT * EP[:eObj];
    end

    return nothing
end

@doc raw"""
    configure_ddp_dicts(setup::Dict, inputs::Dict)

This function instantiates Dictionary objects containing the names of linking expressions, constraints, and variables used in multi-stage modeling.

inputs:

* setup - Dictionary object containing GenX settings and key parameters.
* inputs – Dictionary of inputs for each model period, generated by the load\_inputs() method.

returns:

* start\_cap\_d – Dictionary which contains linking expression names as keys and linking constraint names as values, used for setting the end capacity in stage $p$ to the starting capacity in stage $p+1$.
* cap\_track\_d – Dictionary which contains linking variable names as keys and linking constraint names as values, used for enforcing endogenous retirements.
"""
function configure_ddp_dicts(setup::Dict, inputs::Dict)

    # start_cap_d dictionary contains key-value pairs of available capacity investment expressions
    # as keys and their corresponding linking constraints as values
    start_cap_d = Dict([(Symbol("eTotalCap"), Symbol("cExistingCap"))])

    if !isempty(inputs["STOR_ALL"])
        start_cap_d[Symbol("eTotalCapEnergy")] = Symbol("cExistingCapEnergy")
    end

    if !isempty(inputs["STOR_ASYMMETRIC"])
        start_cap_d[Symbol("eTotalCapCharge")] = Symbol("cExistingCapCharge")
    end

    if setup["NetworkExpansion"] == 1 && inputs["Z"] > 1
        start_cap_d[Symbol("eAvail_Trans_Cap")] = Symbol("cExistingTransCap")
    end

    if !isempty(inputs["VRE_STOR"])
        if !isempty(inputs["VS_DC"])
            start_cap_d[Symbol("eTotalCap_DC")] = Symbol("cExistingCapDC")
        end

        if !isempty(inputs["VS_SOLAR"])
            start_cap_d[Symbol("eTotalCap_SOLAR")] = Symbol("cExistingCapSolar")
        end

        if !isempty(inputs["VS_WIND"])
            start_cap_d[Symbol("eTotalCap_WIND")] = Symbol("cExistingCapWind")
        end

        if !isempty(inputs["VS_ELEC"])
            start_cap_d[Symbol("eTotalCap_ELEC")] = Symbol("cExistingCapElec")
        end

        if !isempty(inputs["VS_STOR"])
            start_cap_d[Symbol("eTotalCap_STOR")] = Symbol("cExistingCapEnergy_VS")
        end

        if !isempty(inputs["VS_ASYM_DC_DISCHARGE"])
            start_cap_d[Symbol("eTotalCapDischarge_DC")] = Symbol("cExistingCapDischargeDC")
        end

        if !isempty(inputs["VS_ASYM_DC_CHARGE"])
            start_cap_d[Symbol("eTotalCapCharge_DC")] = Symbol("cExistingCapChargeDC")
        end

        if !isempty(inputs["VS_ASYM_AC_DISCHARGE"])
            start_cap_d[Symbol("eTotalCapDischarge_AC")] = Symbol("cExistingCapDischargeAC")
        end

        if !isempty(inputs["VS_ASYM_AC_CHARGE"])
            start_cap_d[Symbol("eTotalCapCharge_AC")] = Symbol("cExistingCapChargeAC")
        end
    end

    # This dictionary contains the endogenous retirement constraint name as a key,
    # and a tuple consisting of the associated tracking array constraint and variable as the value
    cap_track_d = Dict([(Symbol("vCAPTRACK"), Symbol("cCapTrack"))])

    if !isempty(inputs["STOR_ALL"])
        cap_track_d[Symbol("vCAPTRACKENERGY")] = Symbol("cCapTrackEnergy")
    end

    if !isempty(inputs["STOR_ASYMMETRIC"])
        cap_track_d[Symbol("vCAPTRACKCHARGE")] = Symbol("cCapTrackCharge")
    end

    if !isempty(inputs["VRE_STOR"])
        if !isempty(inputs["VS_DC"])
            cap_track_d[Symbol("vCAPTRACKDC")] = Symbol("cCapTrackDC")
        end

        if !isempty(inputs["VS_SOLAR"])
            cap_track_d[Symbol("vCAPTRACKSOLAR")] = Symbol("cCapTrackSolar")
        end

        if !isempty(inputs["VS_WIND"])
            cap_track_d[Symbol("vCAPTRACKWIND")] = Symbol("cCapTrackWind")
        end

        if !isempty(inputs["VS_ELEC"])
            cap_track_d[Symbol("vCAPTRACKELEC")] = Symbol("cCapTrackElec")
        end

        if !isempty(inputs["VS_STOR"])
            cap_track_d[Symbol("vCAPTRACKENERGY_VS")] = Symbol("cCapTrackEnergy_VS")
        end

        if !isempty(inputs["VS_ASYM_DC_DISCHARGE"])
            cap_track_d[Symbol("vCAPTRACKDISCHARGEDC")] = Symbol("cCapTrackDischargeDC")
        end

        if !isempty(inputs["VS_ASYM_DC_CHARGE"])
            cap_track_d[Symbol("vCAPTRACKCHARGEDC")] = Symbol("cCapTrackChargeDC")
        end

        if !isempty(inputs["VS_ASYM_AC_DISCHARGE"])
            cap_track_d[Symbol("vCAPTRACKDISCHARGEAC")] = Symbol("cCapTrackDischargeAC")
        end

        if !isempty(inputs["VS_ASYM_AC_CHARGE"])
            cap_track_d[Symbol("vCAPTRACKCHARGEAC")] = Symbol("cCapTrackChargeAC")
        end
    end

    return start_cap_d, cap_track_d
end

function JuMP.has_duals(model::Plasmo.OptiGraph; result::Int = 1)
    return dual_status(model; result = result) != MOI.NO_SOLUTION
end

function JuMP.has_duals(model::Plasmo.OptiNode; result::Int = 1)
    return has_duals(model.source_graph[]; result = result)
end

function Plasmo.termination_status(EP::Plasmo.OptiNode)
    return termination_status(EP.source_graph[])
end
