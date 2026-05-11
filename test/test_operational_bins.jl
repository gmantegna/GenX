module TestOperationalBins

using Test
using GenX

# Build a small synthetic vector of resources covering each binnable type, then
# verify the accessor defaults and operational_bins helper behave correctly.
# This test does not exercise the full input loader; it constructs resources
# directly so the binning machinery can be checked in isolation.

function make_resource(T::Type, id::Int, attrs::Pair{Symbol,<:Any}...)
    return T(Dict{Symbol,Any}(:id => id, :resource => "r$(id)", attrs...))
end

@testset "num_vre_bins default per type" begin
    # Each newly-supported resource type defaults to 1 (single bin) when the
    # column is missing from the loaded input. This preserves existing behavior
    # for inputs that don't use the Num_VRE_bins feature.
    therm = make_resource(GenX.Thermal, 1)
    stor  = make_resource(GenX.Storage, 2)
    mr    = make_resource(GenX.MustRun, 3)
    flex  = make_resource(GenX.FlexDemand, 4)
    elec  = make_resource(GenX.Electrolyzer, 5)
    vre   = make_resource(GenX.Vre, 6)
    hyd   = make_resource(GenX.Hydro, 7)

    @test GenX.num_vre_bins(therm) == 1
    @test GenX.num_vre_bins(stor) == 1
    @test GenX.num_vre_bins(mr) == 1
    @test GenX.num_vre_bins(flex) == 1
    @test GenX.num_vre_bins(elec) == 1
    @test GenX.num_vre_bins(vre) == 1
    # Hydro is excluded from the binning feature; abstract default applies.
    @test GenX.num_vre_bins(hyd) == 0
end

@testset "num_vre_bins reads CSV value when present" begin
    # When the column IS present in the input, the stored value is used and the
    # default is ignored. This is the multi-bin cluster declaration path.
    therm_first = make_resource(GenX.Thermal, 1, :num_vre_bins => 3)
    therm_2nd   = make_resource(GenX.Thermal, 2, :num_vre_bins => 0)
    therm_3rd   = make_resource(GenX.Thermal, 3, :num_vre_bins => 0)

    @test GenX.num_vre_bins(therm_first) == 3
    @test GenX.num_vre_bins(therm_2nd) == 0
    @test GenX.num_vre_bins(therm_3rd) == 0
end

@testset "operational_bins range" begin
    # A 3-bin thermal cluster starting at RID 1.
    gen = GenX.AbstractResource[
        make_resource(GenX.Thermal, 1, :num_vre_bins => 3),
        make_resource(GenX.Thermal, 2, :num_vre_bins => 0),
        make_resource(GenX.Thermal, 3, :num_vre_bins => 0),
        # A singleton storage resource (no explicit num_vre_bins -> defaults to 1).
        make_resource(GenX.Storage, 4),
    ]

    @test GenX.operational_bins(gen, 1) == [1, 2, 3]
    # Singleton: bin is itself.
    @test GenX.operational_bins(gen, 4) == [4]
end

@testset "ids_with_positive picks first bins / singletons" begin
    gen = GenX.AbstractResource[
        make_resource(GenX.Thermal, 1, :num_vre_bins => 2),
        make_resource(GenX.Thermal, 2, :num_vre_bins => 0),
        make_resource(GenX.Storage, 3),  # default 1
    ]
    # First bins/singletons own operations; non-first bins (== 0) do not.
    @test GenX.ids_with_positive(gen, GenX.num_vre_bins) == [1, 3]
end

@testset "explicit num_vre_bins=1 equals missing column" begin
    # Existing inputs without the column and explicit 1 must produce identical
    # accessor results — the backward-compat guarantee.
    therm_implicit = make_resource(GenX.Thermal, 1)
    therm_explicit = make_resource(GenX.Thermal, 1, :num_vre_bins => 1)

    @test GenX.num_vre_bins(therm_implicit) == GenX.num_vre_bins(therm_explicit)
    # operational_bins() assumes id == array index (enforced by the loader).
    @test GenX.operational_bins([therm_implicit], 1) == [1]
    @test GenX.operational_bins([therm_explicit], 1) == [1]
end

@testset "2-bin cluster (smallest non-trivial case)" begin
    gen = GenX.AbstractResource[
        make_resource(GenX.Storage, 1, :num_vre_bins => 2),
        make_resource(GenX.Storage, 2, :num_vre_bins => 0),
    ]
    @test GenX.operational_bins(gen, 1) == [1, 2]
    # Non-first bin with num_vre_bins == 0 yields an empty bin range when
    # queried directly. Production code never queries this — it only calls
    # operational_bins(gen, y) for y in *_POWER_OUT (first bins).
    @test isempty(GenX.operational_bins(gen, 2))
    @test GenX.ids_with_positive(gen, GenX.num_vre_bins) == [1]
end

@testset "non-binnable types stay at default 0" begin
    # Hydro is excluded; abstract default applies even with consecutive RIDs.
    gen = GenX.AbstractResource[
        make_resource(GenX.Hydro, 1),
        make_resource(GenX.Hydro, 2),
    ]
    @test GenX.num_vre_bins(gen[1]) == 0
    @test GenX.num_vre_bins(gen[2]) == 0
    # ids_with_positive excludes them all (no clustering applies).
    @test isempty(GenX.ids_with_positive(gen, GenX.num_vre_bins))
end

end # module
