# include("../src/main.jl")
# using Statistics, Printf

# # =========================
# # Slice dataset (scalability)
# # =========================
# function slice_dataset(input_path, output_path, percentage)
#     lines = readlines(input_path)
#     n = Int(floor(length(lines) * percentage / 100))
#     open(output_path, "w") do f
#         for i in 1:n
#             println(f, lines[i])
#         end
#     end
# end

# # =========================
# # SPMF benchmark
# # =========================
# function measure_spmf(input_path, minsup)
#     output_path = "temp_spmf.txt"
#     # Xóa file cũ nếu có để đảm bảo tính đúng đắn
#     isfile(output_path) && rm(output_path)

#     time_ms = @elapsed begin
#         # Chạy lệnh java
#         cmd = `java -jar data/spmf.jar run HMine $input_path $output_path $(minsup)%`
#         run(pipeline(cmd, devnull))
#     end

#     return time_ms * 1000
# end

# # =========================
# # Peak RAM (Đo RAM nội bộ Julia)
# # =========================
# function measure_peak_ram_mb(func)
#     GC.gc()
#     baseline = Base.gc_live_bytes()

#     done = Threads.Atomic{Bool}(false)
#     peak_mem = Threads.Atomic{UInt64}(0)

#     monitor_task = Threads.@spawn begin
#         while !done[]
#             v = Base.gc_live_bytes()
#             if v > peak_mem[]
#                 peak_mem[] = v
#             end
#             yield()
#         end
#     end

#     func()

#     done[] = true
#     wait(monitor_task)

#     peak = peak_mem[] > baseline ? peak_mem[] - baseline : 0
#     return peak / 1024^2
# end

# # =========================
# # Correctness Logic
# # =========================
# function load_patterns(file)
#     s = Set{Vector{Int}}()
#     if !isfile(file) return s end
    
#     open(file) do f
#         for line in eachline(f)
#             if isempty(strip(line)) continue end
#             if occursin("#SUP", line)
#                 p = split(line, "#SUP")[1]
#                 # Thêm sort() để đảm bảo (1 2) giống (2 1) khi so sánh
#                 items = sort(parse.(Int, split(strip(p))))
#                 push!(s, items)
#             end
#         end
#     end
#     return s
# end

# function calculate_correctness_pct(my_file, spmf_file)
#     my_set = load_patterns(my_file)
#     spmf_set = load_patterns(spmf_file)
    
#     if isempty(spmf_set)
#         return isempty(my_set) ? 100.0 : 0.0
#     end
    
#     # Tính số lượng itemset tìm được nằm trong tập kết quả của SPMF
#     correct_hits = length(intersect(my_set, spmf_set))
#     return (correct_hits / length(spmf_set)) * 100.0
# end

# # =========================
# # MAIN
# # =========================
# function run_full_benchmarks()

#     isdir("docs") || mkpath("docs")

#     configs = Dict(
#         "mushrooms.txt" => [60,55,50,45,40],
#         "retail.txt" => [5,2,1,0.5,0.2],
#         "T10I4D100K.txt" => [10,5,2,1,0.5],
#         "accidents.txt" => [90,85,80,75,70]
#     )

#     println(">>> RUN BENCHMARK")

#     open("docs/benchmark_results.csv", "w") do io
#         println(io, "Dataset,Minsup,Version,Time_ms,Peak_RAM_MB,Correctness")

#         for (file, msups) in configs
#             path = "data/benchmark/" * file
#             println("\nDataset: $file")

#             for m in msups
#                 # --- Chạy SPMF trước để làm chuẩn ---
#                 spmf_out = "temp_spmf.txt"
#                 t_spmf = measure_spmf(path, m)
#                 println(io, "$file,$m,SPMF,$t_spmf,0.0,100.0")

#                 # --- BASE ---
#                 GC.gc()
#                 out_base = "out_base.txt"
#                 # Chạy lần 1 đo thời gian
#                 t_base = @elapsed run_hmine(path, m, out_base, optimized=false)
#                 t_base *= 1000

#                 # Chạy lần 2 đo RAM
#                 mem_base = measure_peak_ram_mb(() ->
#                     run_hmine(path, m, "out_base_ram.txt", optimized=false)
#                 )

#                 c_base_pct = calculate_correctness_pct(out_base, spmf_out)
#                 println(io, "$file,$m,Base,$t_base,$mem_base,$c_base_pct")

#                 # --- OPTIMIZED ---
#                 GC.gc()
#                 out_opt = "out_opt.txt"
#                 # Chạy lần 1 đo thời gian
#                 t_opt = @elapsed run_hmine(path, m, out_opt, optimized=true)
#                 t_opt *= 1000

#                 # Chạy lần 2 đo RAM
#                 mem_opt = measure_peak_ram_mb(() ->
#                     run_hmine(path, m, "out_opt_ram.txt", optimized=true)
#                 )

#                 c_opt_pct = calculate_correctness_pct(out_opt, spmf_out)
#                 println(io, "$file,$m,Optimized,$t_opt,$mem_opt,$c_opt_pct")

#                 println("Done $file m=$m | Base=$(round(t_base,digits=2))ms | Opt=$(round(t_opt,digits=2))ms | Acc=$(round(c_opt_pct, digits=2))%")
#                 sleep(3)
#             end
#         end
#     end

#     # =========================
#     # SCALABILITY
#     # =========================
#     println("\n>>> SCALABILITY TEST")

#     percentages = [10,25,50,75,100]
#     fixed_minsup = 80

#     open("docs/scalability_results.csv", "w") do io
#         println(io, "Percentage,Size_lines,Time_ms,Peak_RAM_MB")

#         for p in percentages
#             temp = "data/benchmark/accidents_$(p)pct.txt"
#             slice_dataset("data/benchmark/accidents.txt", temp, p)

#             GC.gc()
#             t = @elapsed run_hmine(temp, fixed_minsup, "tmp.txt", optimized=true)
#             t *= 1000

#             mem = measure_peak_ram_mb(() ->
#                 run_hmine(temp, fixed_minsup, "tmp_ram.txt", optimized=true)
#             )

#             line_count = countlines(temp)
#             println(io, "$p,$line_count,$t,$mem")
#             println("  $p% -> $(round(t,digits=2)) ms | $(round(mem,digits=2)) MB")

#             rm(temp)
#         end
#     end

#     # Dọn dẹp file tạm
#     for f in ["out_base.txt", "out_base_ram.txt", "out_opt.txt", "out_opt_ram.txt", "temp_spmf.txt", "tmp.txt", "tmp_ram.txt"]
#         isfile(f) && rm(f)
#     end

#     println("\n>>> ALL DONE")
# end

# run_full_benchmarks()




include("../src/main.jl")
using Statistics, Printf, Random

# =========================
# Slice dataset (scalability)
# =========================
function slice_dataset(input_path, output_path, percentage)
    lines = readlines(input_path)
    n = Int(floor(length(lines) * percentage / 100))
    open(output_path, "w") do f
        for i in 1:n
            println(f, lines[i])
        end
    end
end

# =========================
# SPMF benchmark
# =========================
function measure_spmf(input_path, minsup)
    output_path = "temp_spmf.txt"
    isfile(output_path) && rm(output_path)

    time_ms = @elapsed begin
        cmd = `java -jar data/spmf.jar run HMine $input_path $output_path $(minsup)%`
        run(pipeline(cmd, devnull))
    end

    return time_ms * 1000
end

# =========================
# Peak RAM (Julia heap estimate)
# =========================
function measure_peak_ram_mb(func)
    GC.gc()
    baseline = Base.gc_live_bytes()

    done = Threads.Atomic{Bool}(false)
    peak_mem = Threads.Atomic{UInt64}(0)

    monitor_task = Threads.@spawn begin
        while !done[]
            v = Base.gc_live_bytes()
            if v > peak_mem[]
                peak_mem[] = v
            end
            yield()
        end
    end

    func()

    done[] = true
    wait(monitor_task)

    peak = peak_mem[] > baseline ? peak_mem[] - baseline : 0
    return peak / 1024^2
end

# =========================
# Support-aware pattern loading
# =========================
function load_patterns_with_support(file)
    d = Dict{Tuple{Vararg{Int}}, Int}()
    if !isfile(file)
        return d
    end

    open(file) do f
        for line in eachline(f)
            line = strip(line)
            if isempty(line) || startswith(line, "@")
                continue
            end

            parts = split(line, " #SUP: ")
            items = Tuple(sort(parse.(Int, split(strip(parts[1])))))
            sup = parse(Int, strip(parts[2]))
            d[items] = sup
        end
    end
    return d
end

function calculate_correctness_pct(my_file, spmf_file)
    my_dict = load_patterns_with_support(my_file)
    spmf_dict = load_patterns_with_support(spmf_file)

    if isempty(spmf_dict)
        return isempty(my_dict) ? 100.0 : 0.0
    end

    correct = 0
    for (itemset, sup) in spmf_dict
        if haskey(my_dict, itemset) && my_dict[itemset] == sup
            correct += 1
        end
    end

    return 100.0 * correct / length(spmf_dict)
end

function count_patterns(file)
    if !isfile(file)
        return 0
    end
    cnt = 0
    open(file) do f
        for line in eachline(f)
            line = strip(line)
            if !isempty(line) && occursin("#SUP:", line)
                cnt += 1
            end
        end
    end
    return cnt
end

# =========================
# Synthetic datasets for avg transaction length
# =========================
function generate_synthetic_dataset(output_path; n_trans=5000, n_items=100, trans_len=10, seed=42)
    rng = MersenneTwister(seed)
    open(output_path, "w") do io
        for _ in 1:n_trans
            items = sort(randperm(rng, n_items)[1:trans_len])
            println(io, join(items, " "))
        end
    end
end

# =========================
# MAIN
# =========================
function run_full_benchmarks()
    isdir("data/benchmark") || mkpath("data/benchmark")

    configs = Dict(
        "mushrooms.txt"   => [60, 55, 50, 45, 40],
        "retail.txt"      => [5, 2, 1, 0.5, 0.2],
        "T10I4D100K.txt"  => [10, 5, 2, 1, 0.5],
        "accidents.txt"   => [90, 85, 80, 75, 70]
    )

    println(">>> RUN BENCHMARK")

    open("data/benchmark/benchmark_results.csv", "w") do io
        println(io, "Dataset,Minsup,Version,Time_ms,Peak_RAM_MB,Correctness,Pattern_Count")

        for (file, msups) in configs
            path = "data/benchmark/" * file
            println("\nDataset: $file")

            for m in msups
                # --- SPMF ---
                spmf_out = "temp_spmf.txt"
                t_spmf = measure_spmf(path, m)
                pattern_count_spmf = count_patterns(spmf_out)
                println(io, "$file,$m,SPMF,$t_spmf,missing,100.0,$pattern_count_spmf")

                # --- BASE ---
                GC.gc()
                out_base = "out_base.txt"
                t_base = @elapsed run_hmine(path, m, out_base, optimized=false)
                t_base *= 1000

                mem_base = measure_peak_ram_mb(() ->
                    run_hmine(path, m, "out_base_ram.txt", optimized=false)
                )

                c_base_pct = calculate_correctness_pct(out_base, spmf_out)
                p_base = count_patterns(out_base)
                println(io, "$file,$m,Base,$t_base,$mem_base,$c_base_pct,$p_base")

                # --- OPTIMIZED ---
                GC.gc()
                out_opt = "out_opt.txt"
                t_opt = @elapsed run_hmine(path, m, out_opt, optimized=true)
                t_opt *= 1000

                mem_opt = measure_peak_ram_mb(() ->
                    run_hmine(path, m, "out_opt_ram.txt", optimized=true)
                )

                c_opt_pct = calculate_correctness_pct(out_opt, spmf_out)
                p_opt = count_patterns(out_opt)
                println(io, "$file,$m,Optimized,$t_opt,$mem_opt,$c_opt_pct,$p_opt")

                println("Done $file m=$m | Base=$(round(t_base,digits=2))ms | Opt=$(round(t_opt,digits=2))ms | Correct=$(round(c_opt_pct,digits=2))%")
                sleep(2)
            end
        end
    end

    # =========================
    # SCALABILITY
    # =========================
    println("\n>>> SCALABILITY TEST")

    percentages = [10, 25, 50, 75, 100]
    fixed_minsup = 80

    open("data/benchmark/scalability_results.csv", "w") do io
        println(io, "Percentage,Size_lines,Time_ms,Peak_RAM_MB")

        for p in percentages
            temp = "data/benchmark/accidents_$(p)pct.txt"
            slice_dataset("data/benchmark/accidents.txt", temp, p)

            GC.gc()
            t = @elapsed run_hmine(temp, fixed_minsup, "tmp.txt", optimized=true)
            t *= 1000

            mem = measure_peak_ram_mb(() ->
                run_hmine(temp, fixed_minsup, "tmp_ram.txt", optimized=true)
            )

            line_count = countlines(temp)
            println(io, "$p,$line_count,$t,$mem")
            println("  $p% -> $(round(t,digits=2)) ms | $(round(mem,digits=2)) MB")

            rm(temp)
        end
    end

    # =========================
    # AVG TRANSACTION LENGTH EXPERIMENT
    # =========================
    println("\n>>> AVG TRANSACTION LENGTH TEST")

    trans_lengths = [5, 10, 15, 20, 25]
    fixed_minsup = 5.0

    open("data/benchmark/avg_transaction_length_results.csv", "w") do io
        println(io, "Avg_Transaction_Length,Time_ms,Peak_RAM_MB,Pattern_Count")

        for len_t in trans_lengths
            temp_file = "data/benchmark/syn_len_$(len_t).txt"
            generate_synthetic_dataset(temp_file; n_trans=5000, n_items=100, trans_len=len_t, seed=42+len_t)

            GC.gc()
            out_file = "tmp_len_out.txt"
            t = @elapsed run_hmine(temp_file, fixed_minsup, out_file, optimized=true)
            t *= 1000

            mem = measure_peak_ram_mb(() ->
                run_hmine(temp_file, fixed_minsup, "tmp_len_ram.txt", optimized=true)
            )

            pcount = count_patterns(out_file)
            println(io, "$len_t,$t,$mem,$pcount")
            println("  AvgLen=$len_t -> $(round(t,digits=2)) ms | $(round(mem,digits=2)) MB | $pcount patterns")

            rm(temp_file; force=true)
        end
    end

    # cleanup
    for f in [
        "out_base.txt", "out_base_ram.txt", "out_opt.txt", "out_opt_ram.txt",
        "temp_spmf.txt", "tmp.txt", "tmp_ram.txt",
        "tmp_len_out.txt", "tmp_len_ram.txt"
    ]
        isfile(f) && rm(f)
    end

    println("\n>>> ALL DONE")
end

run_full_benchmarks()