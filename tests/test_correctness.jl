using Test
include("../src/main.jl")

# Hàm gọi Java để chạy SPMF tạo file mẫu
function generate_reference_spmf(input_path, output_path, minsup)
    # SPMF nhận minsup dạng %
    cmd = `java -jar data/spmf.jar run HMine $input_path $output_path $(minsup)%`
    run(cmd)
end

# Hàm đọc và chuẩn hóa kết quả để so sánh
function get_result_set(filepath)
    results = Set{String}()
    if isfile(filepath)
        open(filepath, "r") do f
            for line in eachline(f)
                line = strip(line)
                if isempty(line) || startswith(line, "@") continue end
                
                parts = split(line, " #SUP: ")
                items = split(parts[1])
                # Sắp xếp item để đảm bảo tính duy nhất khi so sánh Set
                sorted_items = sort(parse.(Int, items))
                normalized_line = join(sorted_items, " ") * " #SUP: " * parts[2]
                push!(results, normalized_line)
            end
        end
    end
    return results
end

@testset "Kiểm thử tự động hóa hoàn toàn với SPMF" begin
    test_cases = [
        ("mushrooms.txt", 50),
        ("accidents.txt", 70),
        ("retail.txt", 90),
        ("T10I4D100K.txt", 5)
    ]

    for (fname, msup) in test_cases
        println("\n>>> Đang xử lý tập dữ liệu: $fname")
        
        input_path = "data/benchmark/" * fname
        ref_path   = "data/benchmark/ref_" * fname
        base_path  = "data/benchmark/out_base_" * fname
        opt_path   = "data/benchmark/out_opt_" * fname

        # Bước 1: Tạo đáp án chuẩn từ SPMF
        println("1. Đang gọi SPMF để tạo đáp án chuẩn...")
        generate_reference_spmf(input_path, ref_path, msup)
        ref_set = get_result_set(ref_path)

        # Bước 2: Chạy bản Gốc (Base)
        println("2a. Đang chạy H-Mine (Bản gốc)...")
        run_hmine(input_path, msup, base_path, optimized=false)
        base_set = get_result_set(base_path)

        # Bước 3: Chạy bản Tối ưu (Optimized)
        println("2b. Đang chạy H-Mine (Bản tối ưu)...")
        run_hmine(input_path, msup, opt_path, optimized=true)
        opt_set = get_result_set(opt_path)

        # Bước 4: Đối soát 3 bên
        println("3. Đang đối soát kết quả...")
        
        # Test 1: Bản gốc khớp SPMF
        @test base_set == ref_set
        # Test 2: Bản tối ưu khớp SPMF
        @test opt_set == ref_set
        
        if base_set == ref_set && opt_set == ref_set
            println("=> KẾT QUẢ KHỚP 100% ($(length(ref_set)) itemsets)")
        else
            println("=> THẤT BẠI: Có sự sai lệch kết quả!")
        end
    end
end