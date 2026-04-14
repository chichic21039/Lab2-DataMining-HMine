using Test
include("../src/main.jl")

# Hàm gọi Java để chạy SPMF tạo file mẫu
function generate_reference_spmf(input_path, output_path, minsup)
    cmd = `java -jar data/spmf.jar run HMine $input_path $output_path $(minsup)%`
    run(cmd)
end

# Hàm đọc và chuẩn hóa kết quả để so sánh cả itemset + support
function get_result_set(filepath)
    results = Set{String}()
    if isfile(filepath)
        open(filepath, "r") do f
            for line in eachline(f)
                line = strip(line)
                if isempty(line) || startswith(line, "@")
                    continue
                end

                parts = split(line, " #SUP: ")
                items = split(parts[1])
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
        ("data/toy/toy_example_ch2.txt", 50),      # thêm ví dụ tay chương 2
        ("data/benchmark/mushrooms.txt", 50),
        ("data/benchmark/accidents.txt", 70),
        ("data/benchmark/retail.txt", 90),
        ("data/benchmark/T10I4D100K.txt", 5)
    ]

    for (input_path, msup) in test_cases
        fname = splitext(basename(input_path))[1]

        println("\n>>> Đang xử lý tập dữ liệu: $input_path")

        ref_path  = "data/benchmark/ref_" * fname * ".txt"
        base_path = "data/benchmark/out_base_" * fname * ".txt"
        opt_path  = "data/benchmark/out_opt_" * fname * ".txt"

        println("1. Đang gọi SPMF để tạo đáp án chuẩn...")
        generate_reference_spmf(input_path, ref_path, msup)
        ref_set = get_result_set(ref_path)

        println("2a. Đang chạy H-Mine (bản gốc)...")
        run_hmine(input_path, msup, base_path, optimized=false)
        base_set = get_result_set(base_path)

        println("2b. Đang chạy H-Mine (bản tối ưu)...")
        run_hmine(input_path, msup, opt_path, optimized=true)
        opt_set = get_result_set(opt_path)

        println("3. Đang đối soát kết quả...")
        @test base_set == ref_set
        @test opt_set == ref_set

        if base_set == ref_set && opt_set == ref_set
            println("=> KẾT QUẢ KHỚP 100% ($(length(ref_set)) itemsets)")
        else
            println("=> THẤT BẠI: Có sự sai lệch kết quả!")
        end
    end
end