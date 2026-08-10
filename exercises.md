# Phiếu Phản Ánh — K3 Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay thế dòng gợi ý bằng câu trả lời của bạn.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Phạm Thái Sơn  Mã học viên: 2A202601984

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

Nếu cấu hình mặc định là `"changeme"`, khi đưa ứng dụng lên môi trường production mà quên thiết lập biến môi trường `AGENT_API_KEY`, ứng dụng vẫn sẽ khởi chạy bình thường mà không báo lỗi. Tuy nhiên, nó sẽ chấp nhận các request sử dụng API Key mặc định `"changeme"`. Kẻ tấn công hoặc người dùng biết được giá trị mặc định này sẽ có thể gọi API trái phép, làm thất thoát dữ liệu hoặc làm tăng hóa đơn dịch vụ LLM một cách nhanh chóng. Việc "chết sớm" (fail-fast) khi thiếu biến môi trường buộc container phải crash ngay lập tức lúc khởi chạy, giúp phát hiện lỗi cấu hình ngay từ bước triển khai (CI/CD hoặc Orchestrator báo lỗi đỏ), đảm bảo ứng dụng không bao giờ chạy trong tình trạng thiếu bảo mật ngoài production.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

```json
{"timestamp": "2026-08-10T04:37:06.123456+00:00", "service": "day12-agent", "version": "1.0.0", "event": "request_completed", "user_id": "sv-test", "cost_usd": 1.995e-05, "status_code": 200}
```

Hai việc có thể làm với dòng log JSON này:
1. **Phân tích và thống kê tự động (Metrics & Dashboarding):** Các hệ thống thu gom log tập trung (như ELK, Grafana Loki, Datadog) có thể dễ dàng tách các trường dữ liệu JSON để truy vấn nhanh chóng (ví dụ: tính tổng chi phí `cost_usd` của từng `user_id`, tính lượng request trung bình mỗi phút). Việc dùng `print` dạng văn bản tự do sẽ rất khó phân tích vì cấu trúc không đồng nhất.
2. **Thiết lập cảnh báo tự động (Alerting):** Chúng ta có thể dễ dàng cài đặt các bộ lọc kích hoạt cảnh báo gửi qua Slack, Discord hoặc PagerDuty khi phát hiện log có trường `status_code` là `429` (bị rate limit quá nhiều) hoặc khi `cost_usd` vượt quá ngưỡng ngân sách.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | ~340 MB |
| Multi-stage | 270 MB |

Giải thích: Phần dung lượng chênh lệch (~70 MB) là do trong phiên bản Multi-stage, chúng ta đã tách biệt hoàn toàn môi trường build và môi trường chạy. Phiên bản Multi-stage đã bỏ lại các tệp tin rác không cần thiết ở runtime bao gồm: bộ nhớ cache tải xuống của pip (`~/.cache/pip`), các thư viện build-only, compiler tools, và các dependencies dạng dev/build. Chúng ta chỉ sao chép các thư viện đã được biên dịch xong xuôi vào image chạy thực tế, giúp tối ưu hóa tối đa kích thước image.

> Kích thước image Multi-stage đo được thực tế là **270 MB**.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

- Với Dockerfile hiện tại: Khi sửa một ký tự trong `app/main.py`, các layer cài đặt dependencies (`COPY requirements.txt .` và `RUN pip install ...`) sẽ được dùng lại từ cache. Chỉ có layer `COPY . .` và các layer chạy lệnh phía sau nó bị chạy lại.
- Nếu đặt `COPY . .` lên trước `RUN pip install`: Mỗi khi có bất kỳ thay đổi nhỏ nào trong mã nguồn (như `app/main.py`), cache của layer `COPY . .` sẽ bị vô hiệu hóa (invalidated). Điều này kéo theo layer `RUN pip install` ở phía sau bắt buộc phải chạy lại từ đầu. Việc này khiến thời gian build tăng lên đáng kể vì phải tải xuống và cài đặt lại tất cả các thư viện trong mỗi lần sửa code.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

Chuỗi sự kiện:
1. Kẻ tấn công phát hiện và khai thác thành công một lỗ hổng bảo mật trong mã nguồn Python (ví dụ: Remote Code Execution - RCE qua việc thực thi lệnh hệ thống hoặc deserialization).
2. Kẻ tấn công chiếm quyền kiểm soát terminal bên trong container. Vì container mặc định chạy bằng quyền `root`, tiến trình độc hại này cũng sẽ có quyền đặc quyền `root` (UID 0) bên trong container.
3. Kẻ tấn công tiếp tục khai thác các lỗi bảo mật để thoát khỏi container (container breakout - ví dụ: chiếm quyền qua mount volume `/var/run/docker.sock` hoặc khai thác nhân kernel của host). Vì tiến trình trong container chạy bằng `root` (UID 0), khi thoát ra máy host, nó sẽ ánh xạ trực tiếp thành user `root` (UID 0) của máy host, giúp kẻ tấn công chiếm toàn quyền kiểm soát máy host.

Lệnh `USER appuser` cắt đứt chuỗi sự kiện ở bước 2: Tiến trình Python của ứng dụng chạy với UID 10001 (user thường). Dù kẻ tấn công có chiếm được quyền kiểm soát tiến trình bên trong container, họ cũng chỉ có đặc quyền hạn chế của user thường, không thể thao tác đặc quyền hệ thống hay thực hiện container breakout lên máy host.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

Người dùng có thể gửi tối đa **20 request** trong vòng 2 giây liên tiếp.

Cách đạt được con số đó (Hiện tượng Traffic Spiking):
- Giả sử hệ thống reset số đếm lúc giây 00.
- Người dùng gửi 10 request từ giây thứ 59 đến giây thứ 60 của phút trước.
- Ngay khi bước sang giây 00 của phút tiếp theo, bộ đếm được reset về 0. Người dùng lập tức gửi tiếp 10 request nữa từ giây 00 đến giây 01 của phút sau.
- Tổng cộng, trong khoảng thời gian 2 giây liên tiếp (từ giây 59 phút trước đến giây 01 phút sau), người dùng đã gửi thành công 20 request mà không hề vi phạm hạn mức 10 request/phút của thuật toán fixed window.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

- **Sự khác biệt:** Rate limit giới hạn về **tần suất/số lượng request** trong một đơn vị thời gian (ví dụ: tối đa 10 request/phút) để chống quá tải hệ thống. Cost guard giới hạn về **chi phí/số lượng token** tiêu thụ trong một đơn vị thời gian (ví dụ: tối đa 10 USD/tháng) để kiểm soát ngân sách.
- **Rate limit cho qua nhưng Cost guard chặn:** Người dùng chỉ gửi duy nhất 1 request trong vòng 1 phút (đáp ứng tốt rate limit 10 request/phút), nhưng request này yêu cầu LLM tóm tắt một file tài liệu khổng lồ chứa hàng triệu từ, làm tiêu hao đến 2.000.000 tokens và vượt quá ngân sách tháng còn lại của người dùng đó. Rate limit cho qua, nhưng Cost guard sẽ chặn lại.
- **Cost guard cho qua nhưng Rate limit chặn:** Người dùng liên tục gửi 100 request siêu ngắn (mỗi request chỉ 1-2 từ như "Hi", "Hello") trong vòng 10 giây. Tổng chi phí tiêu hao cực kỳ nhỏ (chỉ khoảng 0.00001 USD - hoàn toàn nằm trong ngân sách), nhưng vì tần suất quá dày đặc, Rate limit sẽ chặn lại (trả về 429) để bảo vệ hệ thống khỏi bị spam.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

Thứ tự sự kiện xảy ra:
1. Redis mất kết nối đột ngột trong vòng 30 giây.
2. Endpoint gộp (liveness probe) của cả 3 container nhận thấy không kết nối được với Redis, đồng loạt trả về lỗi `503 Service Unavailable`.
3. Bộ điều phối (Orchestrator) thấy liveness probe bị lỗi liên tục sẽ kết luận cả 3 container ứng dụng đã chết.
4. Orchestrator lập tức tiến hành **khởi động lại (restart)** cả 3 container cùng một lúc.
5. Trong suốt quá trình khởi động lại, các container đều không thể phục vụ traffic. Kể cả khi Redis đã kết nối lại, hệ thống vẫn bị gián đoạn (downtime) vì các container đang trong chu kỳ khởi động và tải lại ứng dụng. Nếu Redis mất kết nối lâu hơn, orchestrator sẽ rơi vào vòng lặp restart vô tận (crash loop backoff), biến một sự cố mất kết nối cơ sở dữ liệu ngắn thành sự cố sập toàn bộ hệ thống dịch vụ.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

Nếu lịch sử được lưu trong một dict Python (RAM của từng instance), giá trị `history_length` của response sẽ **nhảy lộn xộn hoặc tăng không đều** (ví dụ: gọi lần 1 được 1, gọi lần 2 được 0, lần 3 được 2, lần 4 lại về 1...).

Nguyên nhân là do bộ cân bằng tải (Load Balancer) sẽ điều phối các request lần lượt đến các container khác nhau (container A, B, C) theo thuật toán Round Robin. Mỗi container chỉ lưu và biết một phần lịch sử hội thoại của những request gửi đến chính nó mà không hề biết các request được gửi đến container khác, dẫn đến tình trạng AI bị "mất trí nhớ ngẫu nhiên".

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

- **Thông báo lỗi:** `Error: Invalid value for '--port': '$PORT' is not a valid integer. Usage: uvicorn [OPTIONS] APP`
- **Cách tìm ra nguyên nhân:** Đọc build logs và runtime logs trên dashboard của Railway hoặc chạy lệnh `railway logs`. Nhận thấy uvicorn báo lỗi không khởi động được do giá trị của tham số `--port` nhận vào trực tiếp chuỗi chữ `"$PORT"` thay vì số cổng thực tế. Nguyên nhân là vì `startCommand` trong `railway.toml` chạy trực tiếp uvicorn mà không qua một lớp shell để giải nghĩa và nội suy biến môi trường.
- **Cách sửa:** Sửa lại `startCommand` trong `railway.toml` thành `sh -c 'uvicorn app.main:app --host 0.0.0.0 --port $PORT'` để shell giải quyết phần nội suy biến môi trường, hoặc xóa hẳn `startCommand` để Railway tự động dùng lệnh `CMD` tối ưu sẵn trong `Dockerfile`.
