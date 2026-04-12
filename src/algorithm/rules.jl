# src/algorithm/rules.jl
#
# Module sinh luật kết hợp (Association Rules) từ tập frequent itemsets
# Luật dạng: X => Y với sup(X∪Y) >= minsup và conf(X=>Y) >= minconf
#
# Sử dụng:
#   include("algorithm/rules.jl")
#   using .Rules

module Rules

export AssocRule, generate_rules, top_rules_by_lift, print_rules

using Printf

# CẤU TRÚC DỮ LIỆU

"""
    AssocRule

Biểu diễn một luật kết hợp X => Y cùng các chỉ số đo lường.

Fields:
- `antecedent`  : Vector{String} — tập điều kiện X (vế trái)
- `consequent`  : Vector{String} — tập kết quả Y (vế phải)
- `support`     : Float64 — tỷ lệ giao dịch chứa cả X và Y
- `confidence`  : Float64 — P(Y|X) = sup(X∪Y) / sup(X)
- `lift`        : Float64 — conf / sup(Y) — lift > 1 là quan hệ thuận chiều
- `conviction`  : Float64 — (1 − sup(Y)) / (1 − conf)
"""
struct AssocRule
    antecedent::Vector{String}
    consequent::Vector{String}
    support::Float64
    confidence::Float64
    lift::Float64
    conviction::Float64
end

# ============================================================
# SINH LUẬT KẾT HỢP
# ============================================================

"""
    generate_rules(freq_itemsets, id_to_item, n_trans, minconf; single_consequent=true)

Sinh tất cả association rules từ tập frequent itemsets.

# Arguments
- `freq_itemsets`     : Dict{Vector{Int}, Int} — itemset (sorted) => count
- `id_to_item`        : Dict{Int, String}       — id => tên item
- `n_trans`           : Int                     — tổng số giao dịch
- `minconf`           : Float64                 — ngưỡng confidence tối thiểu [0, 1]
- `single_consequent` : Bool (default true)     — chỉ sinh luật X=>{y} (1 item vế phải)

# Returns
- `Vector{AssocRule}`
"""
function generate_rules(
    freq_itemsets::Dict{Vector{Int}, Int},
    id_to_item::Dict{Int, String},
    n_trans::Int,
    minconf::Float64;
    single_consequent::Bool = true
)::Vector{AssocRule}

    rules = Vector{AssocRule}()

    for (itemset, xy_count) in freq_itemsets
        length(itemset) < 2 && continue

        sup_xy = xy_count / n_trans

        if single_consequent
            # Sinh luật X => {y} với mỗi y trong itemset
            for j in 1:length(itemset)
                y   = @inbounds itemset[j]

                ant = [@inbounds itemset[i] for i in 1:length(itemset) if i != j]

                x_count = get(freq_itemsets, ant, 0)
                x_count == 0 && continue

                conf = xy_count / x_count
                conf < minconf && continue

                y_count = get(freq_itemsets, [y], 0)
                y_count == 0 && continue
                sup_y = y_count / n_trans

                lift       = conf / sup_y
                conviction = (conf >= 1.0 - 1e-9) ? Inf : (1.0 - sup_y) / (1.0 - conf)

                ant_names = [get(id_to_item, i, "item_$i") for i in ant]
                con_name  = get(id_to_item, y, "item_$y")

                push!(rules, AssocRule(ant_names, [con_name], sup_xy, conf, lift, conviction))
            end
        else
            # Sinh mọi tập con X -> Y
            n = length(itemset)
            for mask in 1:(2^n - 2)
                # Vì b chỉ chạy từ 0 đến n-1, b+1 chắc chắn chỉ chạy từ 1 đến n
                ant_idx = Int[@inbounds itemset[b+1] for b in 0:n-1 if (mask >> b) & 1 == 1]
                con_idx = Int[@inbounds itemset[b+1] for b in 0:n-1 if (mask >> b) & 1 == 0]


                x_count = get(freq_itemsets, ant_idx, 0)
                x_count == 0 && continue
                conf = xy_count / x_count
                conf < minconf && continue

                y_count = get(freq_itemsets, con_idx, 0)
                y_count == 0 && continue
                sup_y = y_count / n_trans

                lift       = conf / sup_y
                conviction = (conf >= 1.0 - 1e-9) ? Inf : (1.0 - sup_y) / (1.0 - conf)

                ant_names = [get(id_to_item, i, "item_$i") for i in ant_idx]
                con_names = [get(id_to_item, i, "item_$i") for i in con_idx]

                push!(rules, AssocRule(ant_names, con_names, sup_xy, conf, lift, conviction))
            end
        end
    end

    return rules
end

# LỌC VÀ SẮP XẾP

"""Trả về top-k luật sắp xếp giảm dần theo lift."""
function top_rules_by_lift(rules::Vector{AssocRule}, k::Int)::Vector{AssocRule}
    first(sort(rules, by = r -> r.lift, rev = true), k)
end

# IN KẾT QUẢ

"""
    print_rules(rules; io=stdout, title="ASSOCIATION RULES")

In bảng các luật kết hợp với đầy đủ chỉ số sup / conf / lift / conviction.
"""
function print_rules(rules::Vector{AssocRule};
                     io::IO    = stdout,
                     title::String = "ASSOCIATION RULES")
    if isempty(rules)
        println(io, "Không có luật nào thỏa điều kiện.")
        return
    end

    w = 105
    println(io, "\n" * "="^w)
    println(io, "  $title")
    println(io, "="^w)
    println(io,
        rpad("#",    4) *
        rpad("Antecedent (X)", 36) *
        rpad("=> Consequent (Y)", 36) *
        rpad("Support",  10) *
        rpad("Confidence", 12) *
        rpad("Lift",  8) *
        "Conviction"
    )
    println(io, "-"^w)

    for (i, r) in enumerate(rules)
        ant_str  = "{" * join(r.antecedent, ", ") * "}"
        con_str  = "=> {" * join(r.consequent, ", ") * "}"
        conv_str = isinf(r.conviction) ? "    inf" : @sprintf("%8.4f", r.conviction)

        println(io,
            rpad(string(i),  4) *
            rpad(ant_str,   36) *
            rpad(con_str,   36) *
            rpad(@sprintf("%.4f", r.support),     10) *
            rpad(@sprintf("%.4f", r.confidence),  12) *
            rpad(@sprintf("%.4f", r.lift),          8) *
            conv_str
        )
    end
    println(io, "="^w)
end

end # module Rules
