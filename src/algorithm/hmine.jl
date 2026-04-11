using .Structures
using .Utils

function mine_h(prefix::Vector{Int},
                header::HeaderTable,
                database::Vector{Vector{Int}},
                min_sup::Int,
                out::IO)

    if isempty(header.items)
        return
    end
    n = length(header.items)

    # ===== Precompute: item -> index mapping (array, không Dict) =====
    max_item = header.items[end]
    item2idx = zeros(Int, max_item)
    @inbounds for i in 1:n
        item2idx[header.items[i]] = i
    end

    @inbounds for i in 1:n
        item = header.items[i]
        support = header.counts[i]

        # ===== Output =====
        push!(prefix, item)
        Utils.write_result(out, prefix, support)

        # ===== Step 1: Local counting =====
        local_counts = zeros(Int, max_item)

        curr = header.links[i]
        while curr !== nothing
            trans = database[curr.t_idx]

            @inbounds for p in (curr.pos + 1):length(trans)
                it = trans[p]
                if it <= max_item   # ✅ FIX
                    local_counts[it] += 1
                end
            end

            curr = curr.next
        end

        # ===== Step 2: Build local header =====
        local_items = Int[]
        @inbounds for j in (i+1):n
            it = header.items[j]
            if local_counts[it] >= min_sup
                push!(local_items, it)
            end
        end

        if !isempty(local_items)
            m = length(local_items)

            l_links = Vector{Union{HEntry, Nothing}}(undef, m)
            fill!(l_links, nothing)

            # ===== local item -> index (array) =====
            local_item2idx = zeros(Int, max_item)
            @inbounds for k in 1:m
                local_item2idx[local_items[k]] = k
            end

            # ===== Step 3: Virtual projection =====
            curr = header.links[i]
            while curr !== nothing
                trans = database[curr.t_idx]

                @inbounds for p in (curr.pos + 1):length(trans)
                    it = trans[p]
                    if it <= max_item   # ✅ FIX
                        idx = local_item2idx[it]

                        if idx != 0
                            l_links[idx] = HEntry(curr.t_idx, p, l_links[idx])
                            break
                        end
                    end
                end

                curr = curr.next
            end

            counts_vec = Vector{Int}(undef, m)
            @inbounds for k in 1:m
                counts_vec[k] = local_counts[local_items[k]]
            end

            new_header = HeaderTable(
                local_items,
                counts_vec,
                l_links
            )

            mine_h(prefix, new_header, database, min_sup, out)
        end

        # ===== Step 4: Link adjustment =====
        curr = header.links[i]
        while curr !== nothing
            next_node = curr.next
            trans = database[curr.t_idx]

            @inbounds for p in (curr.pos + 1):length(trans)
                it = trans[p]
                if it <= max_item   # ✅ FIX
                    idx = item2idx[it]

                    if idx > i   # chỉ xét item bên phải trong F-list
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