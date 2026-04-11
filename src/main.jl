# src/main.jl
include("structures.jl")
include("utils.jl")
include("algorithm/hmine.jl")     # File của bạn
include("algorithm/hmine_optimized.jl") # File tối ưu mới

using .Structures
using .Utils

function run_hmine(input_path, min_sup_percent, output_path; optimized=false)
    raw_db = Utils.read_spmf(input_path)
    n_trans = length(raw_db)
    min_sup_value = Int(ceil(n_trans * min_sup_percent / 100))
    
    # 2. Xây dựng F-list
    counts = Dict{Int, Int}()
    for trans in raw_db
        for item in trans
            counts[item] = get(counts, item, 0) + 1
        end
    end
    f_list = sort([it for (it, c) in counts if c >= min_sup_value])
    item_to_idx = Dict(it => i for (i, it) in enumerate(f_list))
    
    # 3. Khởi tạo HeaderTable và Filtered Database
    header = HeaderTable(f_list, [counts[it] for it in f_list], fill(nothing, length(f_list)))
    filtered_db = Vector{Vector{Int}}()
    
    for (t_idx, trans) in enumerate(raw_db)
        f_trans = sort!([it for it in trans if haskey(item_to_idx, it)], by=it->item_to_idx[it])
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



