# src/structures.jl
module Structures
    export HEntry, HeaderTable

    # Hyper-link entry
    mutable struct HEntry
        t_idx::Int                    # Chỉ số giao dịch trong database
        pos::Int                      # Vị trí item hiện tại trong giao dịch
        next::Union{HEntry, Nothing}  # Link tới giao dịch tiếp theo chứa cùng item
    end

    # Header table để quản lý các hàng đợi
    mutable struct HeaderTable
        items::Vector{Int}
        counts::Vector{Int}
        links::Vector{Union{HEntry, Nothing}}
    end
end