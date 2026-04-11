# src/utils.jl
module Utils
    export read_spmf, write_result

    function read_spmf(file_path::String)
        db = Vector{Vector{Int}}()
        open(file_path, "r") do f
            for line in eachline(f)
                if isempty(strip(line)) || startswith(line, "@") continue end
                # SPMF format: space separated integers [cite: 82]
                push!(db, parse.(Int, split(strip(line))))
            end
        end
        return db
    end

    function write_result(io::IO, prefix::Vector{Int}, support::Int)
        # Output format: item1 item2 #SUP: count
        line = join(prefix, " ") * " #SUP: $support\n"
        write(io, line)
    end
end