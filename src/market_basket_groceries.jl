# src/market_basket_groceries.jl
#
# Chương 5 — Ứng dụng thực tế: Phân tích giỏ hàng (Market Basket Analysis)
# Tập dữ liệu: Groceries (data/groceries.txt)
#   9835 giao dịch, 169 loại sản phẩm
#
# Mục tiêu:
#   1. Đọc dữ liệu groceries (CSV: mỗi dòng = 1 giao dịch, item cách nhau bằng dấu phẩy)
#   2. Chạy H-Mine để khai phá frequent itemsets
#   3. Sinh association rules với conf >= minconf
#   4. Hiển thị top-10 luật theo lift và giải thích ý nghĩa kinh doanh
#
# Cách chạy:
#   julia --project=. src/market_basket_groceries.jl
#   julia --project=. src/market_basket_groceries.jl data/groceries/groceries.txt 1.0 0.2 10

using Printf

# 0. LOAD CÁC MODULE NỘI BỘ

include("structures.jl")
include("utils.jl")
include("algorithm/hmine_optimized.jl")
include("algorithm/rules.jl")

using .Structures
using .Rules

# 1. ĐỌC DỮ LIỆU GROCERIES 

"""
    read_groceries(path) -> (db_encoded, item_to_id, id_to_item)

Đọc file groceries: mỗi dòng là 1 giao dịch, các item cách nhau bằng dấu phẩy.
Ví dụ: "whole milk,butter,yogurt"
"""
function read_groceries(path::String)
    item_to_id = Dict{String,Int}()
    id_to_item = Dict{Int,String}()
    db_encoded = Vector{Vector{Int}}()
    nid = Ref(0)

    open(path, "r") do f
        for line in eachline(f)
            stripped = strip(line)
            isempty(stripped) && continue
            items = [strip(x) for x in split(stripped, ',')]
            filter!(!isempty, items)
            isempty(items) && continue
            trans = Int[]
            for item in items
                if !haskey(item_to_id, item)
                    nid[] += 1
                    item_to_id[item] = nid[]
                    id_to_item[nid[]] = item
                end
                push!(trans, item_to_id[item])
            end
            push!(db_encoded, trans)
        end
    end

    return db_encoded, item_to_id, id_to_item
end

# 2. CHẠY H-MINE VÀ THU THẬP FREQUENT ITEMSETS

"""
    run_hmine_collect(raw_db, min_sup_value) -> Dict{Vector{Int}, Int}

Chạy H-Mine tối ưu, trả về Dict: sorted itemset => count.
"""
function run_hmine_collect(raw_db::Vector{Vector{Int}}, min_sup_value::Int)

    # Đếm tần suất 1-item
    counts = Dict{Int,Int}()
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
        f_trans = sort!([it for it in trans if haskey(item_to_idx, it)],
            by=it -> item_to_idx[it])
        push!(filtered_db, f_trans)
        if !isempty(f_trans)
            idx = item_to_idx[f_trans[1]]
            header.links[idx] = HEntry(t_idx, 1, header.links[idx])
        end
    end

    # Thu thập kết quả
    freq_itemsets = Dict{Vector{Int},Int}()

    # Chạy H-Mine, capture output (Hmine Opt đã tự động serialize từ 1-item trở đi)
    buf = IOBuffer()
    mine_h_opt(Int[], header, filtered_db, min_sup_value, buf)
    seekstart(buf)

    for line in eachline(buf)
        isempty(strip(line)) && continue
        # Format: "item1 item2 ... #SUP: count"
        parts = split(strip(line), "#SUP:")
        length(parts) != 2 && continue
        @inbounds item_strs = split(strip(parts[1]))
        @inbounds c = parse(Int, strip(parts[2]))
        itemset = sort([parse(Int, s) for s in item_strs])
        freq_itemsets[itemset] = c
    end

    return freq_itemsets
end

# 3. HAM MAIN

function market_basket_analysis(;
    groceries_path::String="data/groceries/groceries.txt",
    minsup_percent::Float64=1.0,
    minconf::Float64=0.3,
    top_k::Int=10
)
    w = 65
    println("\n" * "="^w)
    println("  MARKET BASKET ANALYSIS - GROCERIES DATASET")
    println("="^w)
    println("  File           : $groceries_path")
    println("  Min Support    : $(minsup_percent)%")
    println("  Min Confidence : $(round(minconf*100, digits=0))%")
    println("  Top-K rules    : $top_k")
    println("="^w)

    # Bước 1: Đọc dữ liệu
    print("  [1/4] Doc du lieu groceries... ")
    db_encoded, item_to_id, id_to_item = read_groceries(groceries_path)
    n_trans = length(db_encoded)
    n_items = length(item_to_id)
    println("xong!")
    println("       -> $n_trans giao dich, $n_items items duy nhat")

    min_sup_value = max(1, Int(ceil(n_trans * minsup_percent / 100.0)))
    println("       -> minsup_count = $min_sup_value giao dich")

    # Bước 2: H-Mine
    print("  [2/4] Chay H-Mine khai pha frequent itemsets... ")
    t0 = time()
    freq_itemsets = run_hmine_collect(db_encoded, min_sup_value)
    elapsed = round(time() - t0, digits=2)
    println("xong! ($elapsed giay)")
    println("       -> $(length(freq_itemsets)) frequent itemsets")

    # Bước 3: Sinh luật
    print("  [3/4] Sinh association rules (minconf=$(round(minconf*100,digits=0))%)... ")
    rules = generate_rules(freq_itemsets, id_to_item, n_trans, minconf, single_consequent=false)
    println("xong!")
    println("       -> $(length(rules)) luat ket hop thoa dieu kien")

    if isempty(rules)
        println("\n[WARN] Khong co luat nao. Thu giam minsup hoac minconf.")
        return nothing
    end

    # Bước 4: Top-K theo lift 
    # (Đã tận dụng module Rules sử dụng hàm top_rules_by_lift được code trong rules.jl tái dụng được)
    println("  [4/4] Loc top-$top_k luat theo lift...")
    top_lift = top_rules_by_lift(rules, top_k)

    Rules.print_rules(top_lift,
        title="TOP-$top_k ASSOCIATION RULES THEO LIFT " *
              "(minsup=$(minsup_percent)%, minconf=$(round(minconf*100,digits=0))%)")


    # Thống kê tổng quát
    all_lifts = [r.lift for r in rules]
    all_confs = [r.confidence for r in rules]
    println("\n" * "="^w)
    println("  THONG KE TONG QUAT")
    println("="^w)
    println("  Tong so luat         : $(length(rules))")
    println("  Lift trung binh      : $(round(sum(all_lifts)/length(all_lifts), digits=3))")
    println("  Lift cao nhat        : $(round(maximum(all_lifts), digits=3))")
    println("  Confidence trung binh: $(round(sum(all_confs)/length(all_confs)*100, digits=1))%")
    println("  Confidence cao nhat  : $(round(maximum(all_confs)*100, digits=1))%")
    println("="^w)

    # Ghi kết quả ra 2 file
    file_items = "data/groceries/frequent_itemsets.txt"
    file_rules = "data/groceries/association_rules.txt"
    print("Ghi ket qua ra cac file trong thu muc data/groceries/... ")

    # FILE 1: Ghi Frequent Itemsets
    open(file_items, "w") do f
        println(f, "=========================================")
        println(f, "           FREQUENT ITEMSETS            ")
        println(f, "=========================================")
        sorted_itemsets = sort(collect(freq_itemsets), by=x -> x[2], rev=true)
        for (itemset, count) in sorted_itemsets
            item_names = [get(id_to_item, i, "item_$i") for i in itemset]
            println(f, "{ " * join(item_names, ", ") * " } #SUP: $count")
        end
    end

    # FILE 2: Ghi Thống kê tổng quát & Association Rules
    open(file_rules, "w") do f
        # Ghi Thống kê tổng quát
        println(f, "=========================================")
        println(f, "           THONG KE TONG QUAT           ")
        println(f, "=========================================")
        println(f, "Tong so luat         : $(length(rules))")
        println(f, "Lift trung binh      : $(round(sum(all_lifts)/length(all_lifts), digits=3))")
        println(f, "Lift cao nhat        : $(round(maximum(all_lifts), digits=3))")
        println(f, "Confidence trung binh: $(round(sum(all_confs)/length(all_confs)*100, digits=1))%")
        println(f, "Confidence cao nhat  : $(round(maximum(all_confs)*100, digits=1))%\n")

        # Ghi toàn bộ luật kết hợp
        println(f, "=========================================")
        println(f, "           ASSOCIATION RULES            ")
        println(f, "=========================================")
        sorted_rules = sort(rules, by=r -> r.lift, rev=true)
        for r in sorted_rules
            ant_str = "{" * join(r.antecedent, ", ") * "}"
            con_str = "{" * join(r.consequent, ", ") * "}"

            support_val = round(r.support, digits=4)
            conf_val = round(r.confidence, digits=4)
            lift_val = round(r.lift, digits=4)
            conv_str = isinf(r.conviction) ? "inf" : string(round(r.conviction, digits=4))

            println(f, "$ant_str => $con_str")
            println(f, "   [ support: $support_val | confidence: $conf_val | lift: $lift_val | conviction: $conv_str ]")
        end
    end
    println("Xong!")

    return (freq_itemsets=freq_itemsets, rules=rules, top_rules=top_lift)
end

# 4. ENTRY POINT

function main()
    groceries_path = "data/groceries/groceries.txt"
    minsup_percent = 1.0
    minconf = 0.2
    top_k = 10

    if length(ARGS) >= 1
        groceries_path = ARGS[1]
    end
    if length(ARGS) >= 2
        minsup_percent = parse(Float64, ARGS[2])
    end
    if length(ARGS) >= 3
        minconf = parse(Float64, ARGS[3])
    end
    if length(ARGS) >= 4
        top_k = parse(Int, ARGS[4])
    end

    market_basket_analysis(
        groceries_path=groceries_path,
        minsup_percent=minsup_percent,
        minconf=minconf,
        top_k=top_k
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
