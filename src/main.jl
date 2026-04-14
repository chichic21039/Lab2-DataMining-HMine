# src/main.jl
include("structures.jl")
include("utils.jl")
include("algorithm/hmine.jl")
include("algorithm/hmine_optimized.jl")

using .Structures
using .Utils

function run_hmine(input_path::String, min_sup_percent::Real, output_path::String; optimized::Bool=false)
    raw_db = Utils.read_spmf(input_path)
    n_trans = length(raw_db)
    min_sup_value = Int(ceil(n_trans * min_sup_percent / 100))

    counts = Dict{Int, Int}()
    for trans in raw_db
        for item in trans
            counts[item] = get(counts, item, 0) + 1
        end
    end

    f_list = sort([it for (it, c) in counts if c >= min_sup_value])
    item_to_idx = Dict(it => i for (i, it) in enumerate(f_list))

    header = HeaderTable(
        f_list,
        [counts[it] for it in f_list],
        fill(nothing, length(f_list))
    )

    filtered_db = Vector{Vector{Int}}()
    for (t_idx, trans) in enumerate(raw_db)
        f_trans = sort!([it for it in trans if haskey(item_to_idx, it)], by = it -> item_to_idx[it])
        push!(filtered_db, f_trans)

        if !isempty(f_trans)
            idx = item_to_idx[f_trans[1]]
            header.links[idx] = HEntry(t_idx, 1, header.links[idx])
        end
    end

    open(output_path, "w") do out
        if optimized
            mine_h_opt(Int[], header, filtered_db, min_sup_value, out)
        else
            mine_h(Int[], header, filtered_db, min_sup_value, out)
        end
    end
end

function parse_bool_flag(s::String)
    s = lowercase(strip(s))
    return s in ["1", "true", "yes", "y", "opt", "optimized"]
end

function main()
    if length(ARGS) < 3
        println("Cách dùng:")
        println("  julia --project=. src/main.jl <input_path> <minsup_percent> <output_path> [optimized]")
        println("Ví dụ:")
        println("  julia --project=. src/main.jl data/benchmark/mushrooms.txt 50 output.txt true")
        return
    end

    input_path = ARGS[1]
    minsup_percent = parse(Float64, ARGS[2])
    output_path = ARGS[3]
    optimized = length(ARGS) >= 4 ? parse_bool_flag(ARGS[4]) : false

    run_hmine(input_path, minsup_percent, output_path; optimized=optimized)

    println("Hoàn tất khai phá.")
    println("Input     : $input_path")
    println("Minsup(%) : $minsup_percent")
    println("Output    : $output_path")
    println("Optimized : $optimized")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end