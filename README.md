# Đồ Án Lab 2 - Data Mining: Khai phá Tập Phổ Biến Với H-Mine

Dự án này triển khai thuật toán **H-Mine** (bao gồm bản cơ bản và bản tối ưu hóa) bằng ngôn ngữ lập trình **Julia**. Dự án cung cấp mã nguồn để kiểm thử tính đúng đắn (so khớp với SPMF), đánh giá hiệu năng (benchmark) và ứng dụng mạnh mẽ vào bài toán thực tế **Market Basket Analysis** (Phân tích Giỏ hàng) ở Chương 5.


## Yêu cầu hệ thống và Cài đặt

Để chạy mã nguồn và các file Notebook trong dự án một cách trơn tru, máy tính của bạn cần thiết lập cấu hình môi trường Julia.

### 1. Yêu cầu môi trường
- **Ngôn ngữ:** Tải và cài đặt [Julia](https://julialang.org/downloads/) (phiên bản 1.9 trở lên).
- **Phần mềm biên dịch:** Khuyến khích sử dụng Visual Studio Code (chọn tải thêm extension *Julia Language Server* và *Jupyter*).

### 2. Cài đặt các gói thư viện chuẩn 
Mã nguồn có sử dụng cơ chế quản lý môi trường (Project) của thiết kế Julia. Để thiết lập môi trường chạy an toàn:
1. Mở Terminal trong VS Code tại thư mục `Lab2-DataMining-HMine`.
2. Mở cửa sổ Julia REPL bằng lệnh: `julia`
3. Gõ phím `]` để kích hoạt chế độ **Pkg mode** của Julia.
4. Chạy hai lệnh sau để khởi tạo và tải các thư viện theo cấu hình sẵn:
   ```julia
   pkg> activate .
   pkg> instantiate
   ```

### 3. Cài đặt tích hợp Jupyter (Cần thiết cho Chương 5)
Chương 5 có cung cấp một file tương tác mở rộng (Jupyter Notebook `*.ipynb`). Để file Notebook có thể chạy được Kernel Julia trong máy tính:
- Trong môi trường `Pkg mode` ở bước trên, chạy lệnh thêm thư viện IJulia:
  ```julia
  pkg> add IJulia
  ```
- *Khi thiết lập xong, bạn có thể tự do mở các file `.ipynb` qua VS Code (với extension Jupyter) và chọn Kernel phân giải là Julia.*


## Hướng dẫn chạy chương trình thuật toán cốt lõi

> **Lưu ý JIT Compiler của Julia:** 
> Sau khi mở VS Code, hãy chờ khoảng 1 phút để Julia Language Server load đủ.
> Khi lần đầu chạy, tiến trình thường chậm hơn thực tế do cơ chế cần biên dịch (Precompile). Bạn hãy chạy các dòng lệnh nhỏ ("bản cơ bản") để **warm-up** mã nguồn trước khi đo lường benchmark tốn thời gian.

### Chạy hệ thống Base & Optimized H-Mine
Sử dụng trên bộ dữ liệu kiểm thử mặc định `.txt`.

**Bản cơ bản:**
```bash
julia --project=. src/main.jl data/benchmark/mushrooms.txt 50 output_base.txt false
```

**Bản tối ưu:**
```bash
julia --project=. src/main.jl data/benchmark/mushrooms.txt 50 output_opt.txt true
```

### Chạy kiểm thử tự động
Việc này sẽ kiểm tra thuật toán xem file kết quả có giống hoàn toàn hay không đối với output tiêu chuẩn do thư viện SPMF được đưa qua môi trường trung gian sinh ra.

**Kiểm thử tính đúng đắn (Correctness):**
```bash
julia --project=. tests/test_correctness.jl
```

**Kiểm thử Benchmark hệ thống:**
Đánh giá hiệu năng hệ thống (Time & Peak Memory).
```bash
julia --project=. tests/test_benchmark.jl
```


## Chương 5: Phân Tích Giỏ Hàng (Market Basket Analysis)

Phần thi hành này ứng dụng cơ chế cấp phát tối ưu của thuật toán H-Mine nhằm phát hiện ra **Tập mục phổ biến (Frequent Itemsets)**. Dựa trên đó, hệ thống tiếp tục sinh ra hệ **Luật kết hợp (Association Rules)** áp dụng chặt trên dữ liệu mẫu `Groceries.txt` (hơn 9800 hóa đơn siêu thị).

### 1. Phân tích qua giao diện CLI Terminal

Bạn có thể xuất trọn bộ luật trực tiếp trên màn hình Console và lưu vào thư mục `data/groceries`.

**Lệnh chạy mặc định:**
```bash
julia --project=. src/market_basket_groceries.jl
```
*(Chạy tự động các cấu hình cài sẵn: đường dẫn `data/groceries/groceries.txt`, ngưỡng phổ biến Min Support = 1.0%, độ tin cậy Min Confidence = 0.2 (20%), Lọc Top 10 rule mạnh nhất theo chuẩn Lift)*

**Lệnh chạy với cấu hình tùy chỉnh ngữ cảnh:**
Thay đổi tham số theo thứ tự bắt buộc: `[đường_dẫn_file_data] [min_sup_%] [min_conf_rate] [top_k]`
```bash
julia --project=. src/market_basket_groceries.jl data/groceries/groceries.txt 1.0 0.2 10
```
*(Lệnh này thực hiện: Minsup = 1.0%, độ tin cậy = 20% và xuất danh sách Top 10 tập)*

**Vị trí file phân tích:**
Kết quả xuất chi tiết sau quá trình khởi chạy thành công sẽ được báo cáo ra 2 tệp cho mục đích nghiệp vụ:
- `data/groceries/frequent_itemsets.txt`
- `data/groceries/association_rules.txt`

### 2. Phân tích đồ họa trực quan (Sử dụng Jupyter Notebook)

Đây là phương thức khuyến cáo để có trải nghiệm nhìn nhận thuật toán tốt nhất, đi kèm nhiều khái niệm tính toán tường minh và giải thích ý nghĩa kinh tế học:
1. Bạn hãy mở file `notebooks/demo_market_basket_groceries.ipynb` trong công cụ VS Code.
2. Tại vị trí góc cao bên tay phải thanh công cụ của tệp, chuyển đổi loại **Kernel** sang ngôn ngữ lập trình **Julia**.
3. Tiến hành chạy tuần tự các ô lập trình bằng lệnh `Run All` để có thể nhận định tường minh về sự tương quan của 4 chỉ số sinh luật kết hợp gồm: **Support, Confidence, Lift, Conviction**.