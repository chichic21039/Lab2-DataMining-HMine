# # src/algorithm/hmine_optimized.jl
# using .Structures
# using .Utils

# function mine_h_opt(prefix::Vector{Int}, header::HeaderTable, database::Vector{Vector{Int}}, min_sup::Int, out::IO)
#     local_header_map = Dict(it => i for (i, it) in enumerate(header.items))

#     for i in 1:length(header.items)
#         item = header.items[i]
#         support = header.counts[i]
        
#         # Generator: Tránh tạo mảng tạm nhiều lần
#         new_prefix = [prefix; item]
#         Utils.write_result(out, new_prefix, support)

#         # 1. Tìm locally frequent items dùng Generator & Views
#         local_counts = Dict{Int, Int}()
#         curr = header.links[i]
#         while curr !== nothing
#             # Dùng view để tránh copy mảng khi duyệt giao dịch
#             trans_view = @view database[curr.t_idx][(curr.pos + 1):end]
#             for it in trans_view
#                 local_counts[it] = get(local_counts, it, 0) + 1
#             end
#             curr = curr.next
#         end

#         local_f_items = [it for it in header.items[i+1:end] if get(local_counts, it, 0) >= min_sup]
        
#         if !isempty(local_f_items)
#             l_header = HeaderTable(local_f_items, [local_counts[it] for it in local_f_items], fill(nothing, length(local_f_items)))
#             l_map = Dict(it => k for (k, it) in enumerate(local_f_items))
            
#             curr_proj = header.links[i]
#             while curr_proj !== nothing
#                 trans = database[curr_proj.t_idx]
#                 # Sử dụng generator để tìm item phổ biến tiếp theo
#                 for p in (curr_proj.pos + 1):length(trans)
#                     it = trans[p]
#                     if haskey(l_map, it)
#                         idx = l_map[it]
#                         l_header.links[idx] = HEntry(curr_proj.t_idx, p, l_header.links[idx])
#                         break
#                     end
#                 end
#                 curr_proj = curr_proj.next
#             end
#             mine_h_opt(new_prefix, l_header, database, min_sup, out)
#         end

#         # 2. Link Adjustment (Giữ nguyên logic hmine.jl nhưng dùng map nhanh)
#         curr_adj = header.links[i]
#         while curr_adj !== nothing
#             next_in_q = curr_adj.next
#             trans = database[curr_adj.t_idx]
#             for p in (curr_adj.pos + 1):length(trans)
#                 it = trans[p]
#                 if haskey(local_header_map, it) && local_header_map[it] > i
#                     target_idx = local_header_map[it]
#                     curr_adj.pos = p
#                     curr_adj.next = header.links[target_idx]
#                     header.links[target_idx] = curr_adj
#                     break
#                 end
#             end
#             curr_adj = next_in_q
#         end
#         header.links[i] = nothing
#     end
# end














# using .Structures
# using .Utils

# # ===== ĐỊNH NGHĨA POOL BỘ NHỚ DÙNG CHUNG =====
# # Giúp đệ quy không bao giờ phải cấp phát thêm RAM cho các mảng tạm
# struct HMineBuffers
#     counts_pool::Vector{Vector{Int}}
#     map_pool::Vector{Vector{Int}}
# end

# function mine_h_hybrid(prefix::Vector{Int},
#                        header::HeaderTable,
#                        database::Vector{Vector{Int}},
#                        min_sup::Int,
#                        out::IO,
#                        max_db_item::Int, # Truyền max_item lớn nhất của toàn bộ DB vào đây
#                        depth::Int = 1,
#                        buffers::Union{HMineBuffers, Nothing} = nothing)

#     n = length(header.items)
#     if n == 0 return end

#     # Khởi tạo Buffer Pool ở lần gọi đầu tiên (Độ sâu tối đa giả định là 1000)
#     if buffers === nothing
#         counts_pool = [zeros(Int, max_db_item) for _ in 1:1000]
#         map_pool = [zeros(Int, max_db_item) for _ in 1:1000]
#         buffers = HMineBuffers(counts_pool, map_pool)
#     end

#     # Lấy mảng tạm từ Pool theo độ sâu hiện tại (O(1), không cấp phát RAM)
#     local_counts = buffers.counts_pool[depth]
#     parent_idx_to_local_idx = buffers.map_pool[depth]

#     # Tìm max_item thực tế trong header hiện tại để mapping
#     max_item = 0
#     @inbounds for x in header.items
#         if x > max_item
#             max_item = x
#         end
#     end

#     item2idx = zeros(Int, max_item)
#     @inbounds for i in 1:n
#         item2idx[header.items[i]] = i
#     end

#     @inbounds for i in 1:n
#         item = header.items[i]
#         support = header.counts[i]

#         # ===== Output =====
#         push!(prefix, item)
#         Utils.write_result(out, prefix, support)

#         # Reset mảng đếm của pool (chỉ reset vùng cần thiết để cực nhanh)
#         for j in 1:n
#             local_counts[j] = 0
#         end

#         # ===== Step 1: Local counting & Đếm số lượng Transaction =====
#         curr = header.links[i]
#         num_trans = 0
#         while curr !== nothing
#             num_trans += 1
#             trans = database[curr.t_idx]

#             @inbounds for p in (curr.pos + 1):length(trans)
#                 it = trans[p]
#                 if it <= max_item
#                     idx = item2idx[it]
#                     if idx > i 
#                         local_counts[idx] += 1
#                     end
#                 end
#             end
#             curr = curr.next
#         end

#         # ===== Step 2: Tính toán Mật độ (Density Analysis) =====
#         m = 0
#         total_local_support = 0
#         @inbounds for j in (i+1):n
#             if local_counts[j] >= min_sup
#                 m += 1
#                 total_local_support += local_counts[j]
#             end
#         end

#         if m > 0
#             # Công thức đo mật độ từ Section 3.2 của bài báo
#             density = total_local_support / (num_trans * m)

#             # SWAPPING CONDITION: Nếu mật độ > 10% VÀ số transaction đủ lớn
#             if density > 0.10 && num_trans > 50 
#                 # -------------------------------------------------------------
#                 # GỌI FP-GROWTH Ở ĐÂY
#                 # Bạn sẽ cần phải thiết kế hàm build_fp_tree và mine_fp_tree 
#                 # để nhận vào 'curr' (danh sách hyper-link) và xây cây.
#                 # -------------------------------------------------------------
#                 # fp_tree = build_fp_tree(database, header.links[i], item2idx, local_counts, min_sup, i)
#                 # mine_fp_tree(prefix, fp_tree, min_sup, out)
                
#                 # Ghi chú: Vì tôi không có file định nghĩa FPTree của bạn, 
#                 # phần này được để lại dạng comment. Nếu bạn chưa code FP-Tree,
#                 # cứ bỏ qua khối lệnh IF này. Bản thân H-Mine tối ưu đằng sau đã rất nhanh.
#             else
#                 # -------------------------------------------------------------
#                 # TIẾP TỤC BẰNG H-MINE THÔNG THƯỜNG
#                 # -------------------------------------------------------------
#                 local_items = Vector{Int}(undef, m)
#                 counts_vec  = Vector{Int}(undef, m)
#                 l_links     = Vector{Union{HEntry, Nothing}}(undef, m)
#                 fill!(l_links, nothing)

#                 for j in 1:n
#                     parent_idx_to_local_idx[j] = 0
#                 end

#                 idx_local = 1
#                 @inbounds for j in (i+1):n
#                     if local_counts[j] >= min_sup
#                         local_items[idx_local] = header.items[j]
#                         counts_vec[idx_local] = local_counts[j]
#                         parent_idx_to_local_idx[j] = idx_local
#                         idx_local += 1
#                     end
#                 end

#                 # ===== Step 3: Virtual projection =====
#                 curr = header.links[i]
#                 while curr !== nothing
#                     trans = database[curr.t_idx]
#                     @inbounds for p in (curr.pos + 1):length(trans)
#                         it = trans[p]
#                         if it <= max_item
#                             p_idx = item2idx[it]
#                             if p_idx > i
#                                 l_idx = parent_idx_to_local_idx[p_idx]
#                                 if l_idx != 0
#                                     l_links[l_idx] = HEntry(curr.t_idx, p, l_links[l_idx])
#                                     break
#                                 end
#                             end
#                         end
#                     end
#                     curr = curr.next
#                 end

#                 new_header = HeaderTable(local_items, counts_vec, l_links)
                
#                 # Gọi đệ quy, tăng depth lên 1
#                 mine_h_hybrid(prefix, new_header, database, min_sup, out, max_db_item, depth + 1, buffers)
#             end
#         end

#         # ===== Step 4: Link adjustment =====
#         curr = header.links[i]
#         while curr !== nothing
#             next_node = curr.next
#             trans = database[curr.t_idx]

#             @inbounds for p in (curr.pos + 1):length(trans)
#                 it = trans[p]
#                 if it <= max_item
#                     idx = item2idx[it]
#                     if idx > i
#                         curr.pos = p
#                         curr.next = header.links[idx]
#                         header.links[idx] = curr
#                         break
#                     end
#                 end
#             end
#             curr = next_node
#         end

#         header.links[i] = nothing
#         pop!(prefix)
#     end
# end













# # src/algorithm/hmine_optimized.jl
# using .Structures
# using .Utils

# function mine_h_opt(prefix::Vector{Int},
#                     header::HeaderTable,
#                     database::Vector{Vector{Int}},
#                     min_sup::Int,
#                     out::IO)

#     n = length(header.items)
#     if n == 0 return end

#     # 1. Tìm max_item thực tế trong header hiện tại để mapping
#     max_item = 0
#     @inbounds for x in header.items
#         if x > max_item
#             max_item = x
#         end
#     end

#     # Mapping từ Item thực tế -> index (1..n)
#     item2idx = zeros(Int, max_item)
#     @inbounds for i in 1:n
#         item2idx[header.items[i]] = i
#     end

#     # ==============================================================
#     # TỐI ƯU CỐT LÕI: Cấp phát RA NGOÀI vòng lặp và thu nhỏ size = n
#     # ==============================================================
#     local_counts = Vector{Int}(undef, n)
#     parent_idx_to_local = Vector{Int}(undef, n)

#     @inbounds for i in 1:n
#         item = header.items[i]
#         support = header.counts[i]

#         # ===== Output =====
#         push!(prefix, item)
#         Utils.write_result(out, prefix, support)

#         # Reset mảng đếm (Cực nhanh, 0 allocations)
#         fill!(local_counts, 0)

#         # ===== Step 1: Local counting =====
#         curr = header.links[i]
#         while curr !== nothing
#             trans = database[curr.t_idx]
#             @inbounds for p in (curr.pos + 1):length(trans)
#                 it = trans[p]
#                 if it <= max_item
#                     idx = item2idx[it]
#                     if idx > i 
#                         local_counts[idx] += 1
#                     end
#                 end
#             end
#             curr = curr.next
#         end

#         # ===== Step 2: Tính m và Build Local Items =====
#         m = 0
#         @inbounds for j in (i+1):n
#             if local_counts[j] >= min_sup
#                 m += 1
#             end
#         end

#         if m > 0
#             # Chỉ cấp phát mảng chính xác size m cho node con
#             local_items = Vector{Int}(undef, m)
#             counts_vec  = Vector{Int}(undef, m)
#             l_links     = Vector{Union{HEntry, Nothing}}(undef, m)
#             fill!(l_links, nothing)
#             fill!(parent_idx_to_local, 0)

#             idx_local = 1
#             @inbounds for j in (i+1):n
#                 if local_counts[j] >= min_sup
#                     local_items[idx_local] = header.items[j]
#                     counts_vec[idx_local] = local_counts[j]
#                     parent_idx_to_local[j] = idx_local
#                     idx_local += 1
#                 end
#             end

#             # ===== Step 3: Virtual projection =====
#             curr = header.links[i]
#             while curr !== nothing
#                 trans = database[curr.t_idx]
#                 @inbounds for p in (curr.pos + 1):length(trans)
#                     it = trans[p]
#                     if it <= max_item
#                         p_idx = item2idx[it]
#                         if p_idx > i
#                             # Lookup 2 bước cực nhanh, O(1)
#                             l_idx = parent_idx_to_local[p_idx]
#                             if l_idx != 0
#                                 l_links[l_idx] = HEntry(curr.t_idx, p, l_links[l_idx])
#                                 break
#                             end
#                         end
#                     end
#                 end
#                 curr = curr.next
#             end

#             new_header = HeaderTable(local_items, counts_vec, l_links)
#             mine_h_opt(prefix, new_header, database, min_sup, out)
#         end

#         # ===== Step 4: Link adjustment =====
#         curr = header.links[i]
#         while curr !== nothing
#             next_node = curr.next
#             trans = database[curr.t_idx]

#             @inbounds for p in (curr.pos + 1):length(trans)
#                 it = trans[p]
#                 if it <= max_item
#                     idx = item2idx[it]
#                     if idx > i
#                         curr.pos = p
#                         curr.next = header.links[idx]
#                         header.links[idx] = curr
#                         break
#                     end
#                 end
#             end
#             curr = next_node
#         end

#         header.links[i] = nothing
#         pop!(prefix)
#     end
# end









# src/algorithm/hmine_optimized.jl
using ..Structures: HEntry, HeaderTable
using ..Utils

# ==============================================================================
# PHẦN 1: CẤU TRÚC VÀ HÀM TRỢ GIÚP CHO FP-TREE (Dành cho dữ liệu Dày Đặc)
# ==============================================================================
mutable struct FPNode
    item::Int
    count::Int
    parent::Union{Nothing, FPNode}
    children::Vector{FPNode} # Dùng Vector thay vì Dict để lặp nhanh hơn
    link::Union{Nothing, FPNode}
end

function add_child!(parent::FPNode, item::Int, count::Int)
    # Tìm xem child đã có chưa (vì Vector nhỏ nên linear search cực nhanh)
    for child in parent.children
        if child.item == item
            child.count += count
            return child, false
        end
    end
    # Chưa có thì tạo mới
    new_node = FPNode(item, count, parent, FPNode[], nothing)
    push!(parent.children, new_node)
    return new_node, true
end

function mine_fp_tree(tree_root::FPNode, header_table::Vector{Int}, header_links::Vector{Union{Nothing, FPNode}}, prefix::Vector{Int}, min_sup::Int, out::IO)
    # Duyệt từ dưới lên (Bottom-up)
    for i in length(header_table):-1:1
        item = header_table[i]
        
        # 1. Tính tổng support của item này
        curr_node = header_links[i]
        support = 0
        while curr_node !== nothing
            support += curr_node.count
            curr_node = curr_node.link
        end
        
        if support < min_sup
            continue
        end

        # 2. Xuất pattern
        push!(prefix, item)
        Utils.write_result(out, prefix, support)

        # 3. Tạo Conditional Pattern Base (CPB)
        local_item_counts = Dict{Int, Int}()
        curr_node = header_links[i]
        paths = Vector{Tuple{Vector{Int}, Int}}()
        
        while curr_node !== nothing
            path = Int[]
            p = curr_node.parent
            while p !== nothing && p.item != -1
                push!(path, p.item)
                local_item_counts[p.item] = get(local_item_counts, p.item, 0) + curr_node.count
                p = p.parent
            end
            if !isempty(path)
                # Đảo ngược path vì ta đi từ lá lên rễ
                reverse!(path)
                push!(paths, (path, curr_node.count))
            end
            curr_node = curr_node.link
        end

        # 4. Lọc item phổ biến trong CPB và tạo Header Table mới
        local_frequent = [it for (it, c) in local_item_counts if c >= min_sup]
        if !isempty(local_frequent)
            # Sắp xếp giảm dần theo support
            sort!(local_frequent, by = x -> local_item_counts[x], rev=true)
            
            new_header_links = Vector{Union{Nothing, FPNode}}(undef, length(local_frequent))
            fill!(new_header_links, nothing)
            # Dùng mảng tạm để chèn link O(1)
            tail_links = Vector{Union{Nothing, FPNode}}(undef, length(local_frequent))
            fill!(tail_links, nothing)
            
            item_to_idx = Dict(it => idx for (idx, it) in enumerate(local_frequent))
            
            # 5. Xây dựng Conditional FP-Tree
            cond_root = FPNode(-1, 0, nothing, FPNode[], nothing)
            for (path, count) in paths
                curr_insert = cond_root
                for it in path
                    if haskey(item_to_idx, it)
                        child, is_new = add_child!(curr_insert, it, count)
                        if is_new
                            idx = item_to_idx[it]
                            if new_header_links[idx] === nothing
                                new_header_links[idx] = child
                                tail_links[idx] = child
                            else
                                tail_links[idx].link = child
                                tail_links[idx] = child
                            end
                        end
                        curr_insert = child
                    end
                end
            end
            
            # 6. Đệ quy
            mine_fp_tree(cond_root, local_frequent, new_header_links, prefix, min_sup, out)
        end
        
        pop!(prefix)
    end
end

# ==============================================================================
# PHẦN 2: THUẬT TOÁN H-MINE TỐI ƯU CỐT LÕI (Zero-Allocation + Hybrid)
# ==============================================================================
function mine_h_opt(prefix::Vector{Int},
                    header::HeaderTable,
                    database::Vector{Vector{Int}},
                    min_sup::Int,
                    out::IO)

    n = length(header.items)
    if n == 0 return end

    # Tìm max_item thực tế trong header hiện tại
    max_item = 0
    @inbounds for x in header.items
        if x > max_item
            max_item = x
        end
    end

    # Mapping O(1)
    item2idx = zeros(Int, max_item)
    @inbounds for i in 1:n
        item2idx[header.items[i]] = i
    end

    # Mảng tái sử dụng (Cấp phát 1 lần ngoài vòng lặp)
    local_counts = Vector{Int}(undef, n)
    parent_idx_to_local = Vector{Int}(undef, n)

    @inbounds for i in 1:n
        item = header.items[i]
        support = header.counts[i]

        push!(prefix, item)
        Utils.write_result(out, prefix, support)

        fill!(local_counts, 0)

        # ===== Step 1: Đếm support cục bộ và số lượng giao dịch =====
        curr = header.links[i]
        num_trans = 0
        while curr !== nothing
            num_trans += 1
            trans = database[curr.t_idx]
            @inbounds for p in (curr.pos + 1):length(trans)
                it = trans[p]
                if it <= max_item
                    idx = item2idx[it]
                    if idx > i 
                        local_counts[idx] += 1
                    end
                end
            end
            curr = curr.next
        end

        # ===== Step 2: Tính Mật Độ & Chọn Chiến Lược =====
        m = 0
        total_local_support = 0
        @inbounds for j in (i+1):n
            if local_counts[j] >= min_sup
                m += 1
                total_local_support += local_counts[j]
            end
        end

        if m > 0
            # Tính mật độ (Density)
            density = total_local_support / (num_trans * m)

            # SWAPPING: Nếu mật độ > 10% VÀ số giao dịch đủ lớn -> Chuyển sang FP-Tree
            if density > 0.10 && num_trans > 50
                
                # 1. Lọc và sắp xếp các item phổ biến theo F-List cục bộ (giảm dần)
                local_frequent = Int[]
                for j in (i+1):n
                    if local_counts[j] >= min_sup
                        push!(local_frequent, header.items[j])
                    end
                end
                sort!(local_frequent, by = x -> local_counts[item2idx[x]], rev=true)
                
                # Map nhanh
                fp_item2idx = Dict(it => idx for (idx, it) in enumerate(local_frequent))
                fp_links = Vector{Union{Nothing, FPNode}}(undef, length(local_frequent))
                fill!(fp_links, nothing)
                fp_tails = Vector{Union{Nothing, FPNode}}(undef, length(local_frequent))
                fill!(fp_tails, nothing)
                
                # 2. Xây cây FP-Tree dựa trên các hyper-link hiện tại
                fp_root = FPNode(-1, 0, nothing, FPNode[], nothing)
                curr_fp = header.links[i]
                
                while curr_fp !== nothing
                    trans = database[curr_fp.t_idx]
                    
                    # Trích xuất và sắp xếp transaction cục bộ
                    local_trans = Int[]
                    @inbounds for p in (curr_fp.pos + 1):length(trans)
                        it = trans[p]
                        if haskey(fp_item2idx, it)
                            push!(local_trans, it)
                        end
                    end
                    sort!(local_trans, by = x -> fp_item2idx[x])
                    
                    # Chèn vào cây
                    curr_insert = fp_root
                    for it in local_trans
                        child, is_new = add_child!(curr_insert, it, 1)
                        if is_new
                            idx = fp_item2idx[it]
                            if fp_links[idx] === nothing
                                fp_links[idx] = child
                                fp_tails[idx] = child
                            else
                                fp_tails[idx].link = child
                                fp_tails[idx] = child
                            end
                        end
                        curr_insert = child
                    end
                    
                    curr_fp = curr_fp.next
                end
                
                # 3. Mine FP-Tree
                mine_fp_tree(fp_root, local_frequent, fp_links, prefix, min_sup, out)

            else
                # TIẾP TỤC BẰNG H-MINE (Dữ liệu thưa -> Zero-Allocation)
                local_items = Vector{Int}(undef, m)
                counts_vec  = Vector{Int}(undef, m)
                l_links     = Vector{Union{HEntry, Nothing}}(undef, m)
                fill!(l_links, nothing)
                fill!(parent_idx_to_local, 0)

                idx_local = 1
                @inbounds for j in (i+1):n
                    if local_counts[j] >= min_sup
                        local_items[idx_local] = header.items[j]
                        counts_vec[idx_local] = local_counts[j]
                        parent_idx_to_local[j] = idx_local
                        idx_local += 1
                    end
                end

                curr_hm = header.links[i]
                while curr_hm !== nothing
                    trans = database[curr_hm.t_idx]
                    @inbounds for p in (curr_hm.pos + 1):length(trans)
                        it = trans[p]
                        if it <= max_item
                            p_idx = item2idx[it]
                            if p_idx > i
                                l_idx = parent_idx_to_local[p_idx]
                                if l_idx != 0
                                    l_links[l_idx] = HEntry(curr_hm.t_idx, p, l_links[l_idx])
                                    break
                                end
                            end
                        end
                    end
                    curr_hm = curr_hm.next
                end

                new_header = HeaderTable(local_items, counts_vec, l_links)
                mine_h_opt(prefix, new_header, database, min_sup, out)
            end
        end

        # ===== Step 4: Link adjustment (Dịch chuyển con trỏ H-Mine) =====
        curr = header.links[i]
        while curr !== nothing
            next_node = curr.next
            trans = database[curr.t_idx]

            @inbounds for p in (curr.pos + 1):length(trans)
                it = trans[p]
                if it <= max_item
                    idx = item2idx[it]
                    if idx > i
                        curr.pos = p
                        curr.next = header.links[idx]
                        header.links[idx] = curr
                        break
                    end
                end
            end
            curr = next_node
        end

        header.links[i] = nothing
        pop!(prefix)
    end
end