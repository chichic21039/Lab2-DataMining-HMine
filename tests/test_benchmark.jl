# # tests/test_benchmark.jl
# include("../src/main.jl")
# using Statistics, Printf

# # Hàm hỗ trợ cắt file để làm thực nghiệm Scalability
# function slice_dataset(input_path, output_path, percentage)
#     lines = readlines(input_path)
#     n = Int(floor(length(lines) * percentage / 100))
#     open(output_path, "w") do f
#         for i in 1:n
#             println(f, lines[i])
#         end
#     end
# end

# # Hàm đo thời gian chạy của SPMF (Java)
# function measure_spmf(input_path, minsup)
#     output_path = "temp_spmf.txt"
#     # Dùng @elapsed để đo thời gian thực thi lệnh shell
#     time_sec = @elapsed begin
#         cmd = `java -jar data/spmf.jar run HMine $input_path $output_path $(minsup)%`
#         run(pipeline(cmd, devnull)) # devnull để không hiện log Java làm rối terminal
#     end
#     return time_sec * 1000 # Trả về miliseconds
# end

# function run_full_benchmarks()
#     # Kiểm tra thư mục docs
#     if !isdir("docs") mkpath("docs") end

#     # 1. Cấu hình minsup cho thực nghiệm (b), (c), (d)
#     experiment_configs = Dict(
#         "mushrooms.txt" => [60, 55, 50, 45, 40],
#         "accidents.txt" => [90, 85, 80, 75, 70],
#         "retail.txt"    => [5, 2, 1, 0.5, 0.2],
#         "T10I4D100K.txt" => [10, 5, 2, 1, 0.5]
#     )

#     println(">>> Đang chạy Benchmark trên các tập dữ liệu...")
#     open("docs/benchmark_results.csv", "w") do io
#         println(io, "Dataset,Minsup,Version,Time_ms,Memory_MB,ItemsetCount")

#         for (fname, msups) in experiment_configs
#             path = "data/benchmark/" * fname
#             println("\nDataset: $fname")
#             for m in msups
#                 print("  Minsup $m%: ")
                
#                 # --- Đo bản Gốc ---
#                 stats_b = @timed run_hmine(path, m, "temp.txt", optimized=false)
#                 println(io, "$fname,$m,Base,$(stats_b.time*1000),$(stats_b.bytes/1024^2),$(countlines("temp.txt"))")
                
#                 # --- Đo bản Tối ưu ---
#                 stats_o = @timed run_hmine(path, m, "temp.txt", optimized=true)
#                 println(io, "$fname,$m,Optimized,$(stats_o.time*1000),$(stats_o.bytes/1024^2),$(countlines("temp.txt"))")
                
#                 # --- Đo SPMF ---
#                 time_spmf = measure_spmf(path, m)
#                 println(io, "$fname,$m,SPMF,$time_spmf,0,0") # SPMF không đo RAM dễ dàng như Julia nên để 0
                
#                 println("Done (Base: $(round(stats_b.time*1000))ms, Opt: $(round(stats_o.time*1000))ms, SPMF: $(round(time_spmf))ms)")
#             end
#         end
#     end

#     # 2. Thực nghiệm Scalability (Khả năng mở rộng)
#     println("\n>>> Đang chạy thực nghiệm Scalability trên Accidents.txt...")
#     percentages = [10, 25, 50, 75, 100]
#     fixed_minsup = 80 
    
#     open("docs/scalability_results.csv", "w") do io
#         println(io, "Percentage,Size_lines,Time_ms")
#         for p in percentages
#             temp_path = "data/benchmark/accidents_$(p)pct.txt"
#             slice_dataset("data/benchmark/accidents.txt", temp_path, p)
            
#             stats = @timed run_hmine(temp_path, fixed_minsup, "temp.txt", optimized=true)
#             println(io, "$p,$(countlines(temp_path)),$(stats.time*1000)")
#             println("  Kích thước $p%: $(round(stats.time*1000))ms")
#             rm(temp_path) 
#         end
#     end
#     println("\n>>> TẤT CẢ THỰC NGHIỆM ĐÃ HOÀN TẤT. Dữ liệu lưu tại thư mục docs/")
# end

# run_full_benchmarks()













# # tests/test_benchmark.jl
# include("../src/main.jl")
# using Statistics, Printf

# # Hàm hỗ trợ cắt file để làm thực nghiệm Scalability
# function slice_dataset(input_path, output_path, percentage)
#     lines = readlines(input_path)
#     n = Int(floor(length(lines) * percentage / 100))
#     open(output_path, "w") do f
#         for i in 1:n
#             println(f, lines[i])
#         end
#     end
# end

# # Hàm đo thời gian chạy của SPMF (Java)
# function measure_spmf(input_path, minsup)
#     output_path = "temp_spmf.txt"
#     time_sec = @elapsed begin
#         cmd = `java -jar data/spmf.jar run HMine $input_path $output_path $(minsup)%`
#         run(pipeline(cmd, devnull)) 
#     end
#     return time_sec * 1000 
# end

# # --- HÀM MỚI: Đo Peak RAM bằng cách Polling (Lấy mẫu liên tục) ---
# function measure_peak_ram(func)
#     GC.gc() # Ép dọn rác trước khi đo để có baseline sạch
#     baseline = Base.gc_live_bytes() # RAM đang dùng trước khi chạy
    
#     done = Threads.Atomic{Bool}(false)
#     peak_mem = Threads.Atomic{UInt64}(0)
    
#     # Khởi tạo Task giám sát RAM chạy song song
#     monitor_task = Threads.@spawn begin
#         while !done[]
#             current_mem = Base.gc_live_bytes()
#             if current_mem > peak_mem[]
#                 peak_mem[] = current_mem
#             end
#             sleep(0.005) # Lấy mẫu mỗi 5ms để không ăn quá nhiều CPU
#         end
#     end
    
#     # Chạy thuật toán chính
#     func()
    
#     # Dừng giám sát
#     done[] = true
#     wait(monitor_task)
    
#     # Tính Peak RAM (Dung lượng đỉnh - Baseline ban đầu)
#     peak_used = (peak_mem[] > baseline) ? (peak_mem[] - baseline) : 0
#     return peak_used / 1024^2 # Trả về dung lượng theo đơn vị MB
# end

# function run_full_benchmarks()
#     if !isdir("docs") mkpath("docs") end

#     experiment_configs = Dict(
#         "mushrooms.txt" => [60, 55, 50, 45, 40],
#         "accidents.txt" => [90, 85, 80, 75, 70],
#         "retail.txt"    => [5, 2, 1, 0.5, 0.2],
#         "T10I4D100K.txt" => [10, 5, 2, 1, 0.5]
#     )

#     println(">>> Đang chạy Benchmark trên các tập dữ liệu...")
#     open("docs/benchmark_results.csv", "w") do io
#         println(io, "Dataset,Minsup,Version,Time_ms,Peak_RAM_MB,ItemsetCount")

#         for (fname, msups) in experiment_configs
#             path = "data/benchmark/" * fname
#             println("\nDataset: $fname")
#             for m in msups
#                 print("  Minsup $m%: ")
                
#                 # ==========================================
#                 # 1. ĐO BẢN GỐC (BASE)
#                 # ==========================================
#                 # Chạy lần 1: Lấy Time
#                 GC.gc() 
#                 time_b_sec = @elapsed run_hmine(path, m, "temp.txt", optimized=false)
                
#                 # Chạy lần 2: Lấy Peak RAM
#                 mem_b_mb = measure_peak_ram(() -> run_hmine(path, m, "temp_ram.txt", optimized=false))
#                 count_b = countlines("temp.txt")
                
#                 println(io, "$fname,$m,Base,$(time_b_sec*1000),$mem_b_mb,$count_b")
                
#                 # ==========================================
#                 # 2. ĐO BẢN TỐI ƯU (OPTIMIZED)
#                 # ==========================================
#                 # Chạy lần 1: Lấy Time
#                 GC.gc()
#                 time_o_sec = @elapsed run_hmine(path, m, "temp.txt", optimized=true)
                
#                 # Chạy lần 2: Lấy Peak RAM
#                 mem_o_mb = measure_peak_ram(() -> run_hmine(path, m, "temp_ram.txt", optimized=true))
#                 count_o = countlines("temp.txt")
                
#                 println(io, "$fname,$m,Optimized,$(time_o_sec*1000),$mem_o_mb,$count_o")
                
#                 # ==========================================
#                 # 3. ĐO SPMF
#                 # ==========================================
#                 time_spmf = measure_spmf(path, m)
#                 println(io, "$fname,$m,SPMF,$time_spmf,0,0") 
                
#                 println("Done (Base Time: $(round(time_b_sec*1000))ms | Opt Time: $(round(time_o_sec*1000))ms | Opt RAM: $(round(mem_o_mb, digits=2))MB)")
#             end
#         end
#     end

#     # Thực nghiệm Scalability (Khả năng mở rộng)
#     println("\n>>> Đang chạy thực nghiệm Scalability trên Accidents.txt...")
#     percentages = [10, 25, 50, 75, 100]
#     fixed_minsup = 80 
    
#     open("docs/scalability_results.csv", "w") do io
#         println(io, "Percentage,Size_lines,Time_ms,Peak_RAM_MB")
#         for p in percentages
#             temp_path = "data/benchmark/accidents_$(p)pct.txt"
#             slice_dataset("data/benchmark/accidents.txt", temp_path, p)
            
#             # Scalability cũng chạy 2 lần tương tự để lấy cả Time và RAM
#             GC.gc()
#             time_scale = @elapsed run_hmine(temp_path, fixed_minsup, "temp.txt", optimized=true)
#             mem_scale = measure_peak_ram(() -> run_hmine(temp_path, fixed_minsup, "temp_ram.txt", optimized=true))
            
#             println(io, "$p,$(countlines(temp_path)),$(time_scale*1000),$mem_scale")
#             println("  Kích thước $p%: $(round(time_scale*1000))ms - RAM: $(round(mem_scale, digits=2))MB")
#             rm(temp_path) 
#         end
#     end
    
#     # Dọn file rác do lần chạy RAM tạo ra
#     if isfile("temp_ram.txt") rm("temp_ram.txt") end
    
#     println("\n>>> TẤT CẢ THỰC NGHIỆM ĐÃ HOÀN TẤT. Dữ liệu lưu tại thư mục docs/")
# end

# run_full_benchmarks()








# tests/test_benchmark.jl
include("../src/main.jl")
using Statistics, Printf

# Hàm hỗ trợ cắt file để làm thực nghiệm Scalability
function slice_dataset(input_path, output_path, percentage)
    lines = readlines(input_path)
    n = Int(floor(length(lines) * percentage / 100))
    open(output_path, "w") do f
        for i in 1:n
            println(f, lines[i])
        end
    end
end

# Hàm đo thời gian chạy của SPMF (Java)
function measure_spmf(input_path, minsup)
    output_path = "temp_spmf.txt"
    time_sec = @elapsed begin
        cmd = `java -jar data/spmf.jar run HMine $input_path $output_path $(minsup)%`
        run(pipeline(cmd, devnull)) 
    end
    return time_sec * 1000 
end

# --- Hàm đo Peak RAM cực nhanh (Aggressive Polling) ---
function measure_peak_ram_mb(func)
    GC.gc() # Dọn rác tạo baseline sạch
    baseline = Base.gc_live_bytes()
    
    done = Threads.Atomic{Bool}(false)
    peak_mem = Threads.Atomic{UInt64}(0)
    
    # Chạy luồng ngầm giám sát RAM
    monitor_task = Threads.@spawn begin
        while !done[]
            current_mem = Base.gc_live_bytes()
            if current_mem > peak_mem[]
                peak_mem[] = current_mem
            end
            # Dùng yield() thay vì sleep() để lấy mẫu liên tục ở tốc độ tối đa của CPU
            yield() 
        end
    end
    
    # Chạy thuật toán chính
    func()
    
    # Dừng luồng đo
    done[] = true
    wait(monitor_task)
    
    # Tính toán Peak RAM thực dùng và đổi sang MB
    peak_used_bytes = (peak_mem[] > baseline) ? (peak_mem[] - baseline) : 0
    return peak_used_bytes / 1024^2 # Trả về đơn vị MB
end

function run_full_benchmarks()
    if !isdir("docs") mkpath("docs") end

    experiment_configs = Dict(
        "mushrooms.txt" => [60, 55, 50, 45, 40],
        "accidents.txt" => [90, 85, 80, 75, 70],
        "retail.txt"    => [5, 2, 1, 0.5, 0.2],
        "T10I4D100K.txt" => [10, 5, 2, 1, 0.5]
    )

    println(">>> Đang chạy Benchmark trên các tập dữ liệu...")
    open("docs/benchmark_results.csv", "w") do io
        # Tiêu đề cột dùng Peak_RAM_MB
        println(io, "Dataset,Minsup,Version,Time_ms,Peak_RAM_MB,ItemsetCount")

        for (fname, msups) in experiment_configs
            path = "data/benchmark/" * fname
            println("\nDataset: $fname")
            for m in msups
                print("  Minsup $m%: ")
                
                # --- 1. Đo bản Gốc (Base) ---
                GC.gc()
                # Chạy lần 1 để lấy Time (làm tròn 4 số)
                time_b_ms = round((@elapsed run_hmine(path, m, "temp.txt", optimized=false)) * 1000, digits=4)
                # Chạy lần 2 lấy Peak RAM (làm tròn 2 số, đơn vị MB)
                mem_b_mb = round(measure_peak_ram_mb(() -> run_hmine(path, m, "temp_ram.txt", optimized=false)), digits=2)
                count_b = countlines("temp.txt")
                
                println(io, "$fname,$m,Base,$time_b_ms,$mem_b_mb,$count_b")
                
                # --- 2. Đo bản Tối ưu (Optimized) ---
                GC.gc()
                time_o_ms = round((@elapsed run_hmine(path, m, "temp.txt", optimized=true)) * 1000, digits=4)
                mem_o_mb = round(measure_peak_ram_mb(() -> run_hmine(path, m, "temp_ram.txt", optimized=true)), digits=2)
                count_o = countlines("temp.txt")
                
                println(io, "$fname,$m,Optimized,$time_o_ms,$mem_o_mb,$count_o")
                
                # --- 3. Đo SPMF ---
                time_spmf = round(measure_spmf(path, m), digits=4)
                println(io, "$fname,$m,SPMF,$time_spmf,0.0,0") 
                
                println("Done (Base: $(time_b_ms)ms | Opt: $(time_o_ms)ms | Peak RAM Opt: $(mem_o_mb) MB)")
            end
        end
    end

    # --- Thực nghiệm Scalability ---
    println("\n>>> Đang chạy thực nghiệm Scalability trên Accidents.txt...")
    percentages = [10, 25, 50, 75, 100]
    fixed_minsup = 80 
    
    open("docs/scalability_results.csv", "w") do io
        println(io, "Percentage,Size_lines,Time_ms,Peak_RAM_MB")
        for p in percentages
            temp_path = "data/benchmark/accidents_$(p)pct.txt"
            slice_dataset("data/benchmark/accidents.txt", temp_path, p)
            
            GC.gc()
            time_scale_ms = round((@elapsed run_hmine(temp_path, fixed_minsup, "temp.txt", optimized=true)) * 1000, digits=4)
            mem_scale_mb = round(measure_peak_ram_mb(() -> run_hmine(temp_path, fixed_minsup, "temp_ram.txt", optimized=true)), digits=2)
            
            println(io, "$p,$(countlines(temp_path)),$time_scale_ms,$mem_scale_mb")
            println("  Kích thước $p%: $(time_scale_ms)ms - Peak RAM: $(mem_scale_mb) MB")
            rm(temp_path) 
        end
    end
    
    # Dọn dẹp file tạm của quá trình đo RAM
    if isfile("temp_ram.txt") rm("temp_ram.txt") end
    
    println("\n>>> TẤT CẢ THỰC NGHIỆM ĐÃ HOÀN TẤT. Dữ liệu lưu tại thư mục docs/")
end

run_full_benchmarks()