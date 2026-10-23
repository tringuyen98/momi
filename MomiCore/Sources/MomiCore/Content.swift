import Foundation

public struct Article: Identifiable, Sendable {
    public var id: String
    public var title: String
    public var topic: String
    public var summary: String
    public var body: String
    public var sourceTitle: String
    public var sourceURL: String
}
public struct Food: Identifiable, Sendable {
    public var id: String
    public var name: String
    public var nutrients: String
    public var preparation: String
    public var vegetarian: Bool
    public var allergens: [String]
    public var symbol: String
}
public enum ContentLibrary {
    public static let articles: [Article] = [
        .init(id: "prepare", title: "Chuẩn bị cho buổi khám trước thai kỳ", topic: "Chuẩn bị mang thai", summary: "Gom những thông tin cần thiết và câu hỏi của riêng bạn.", body: "Bạn có thể chuẩn bị bệnh sử, hồ sơ tiêm chủng, danh sách thuốc và sản phẩm bổ sung đang dùng. Ghi lại những điều muốn hỏi để thuận tiện trao đổi trong buổi khám.\n\nMomi giúp lưu thông tin và lịch hẹn. Việc khám, xét nghiệm hoặc thay đổi sản phẩm đang dùng cần dựa trên tư vấn phù hợp với bạn.", sourceTitle: "CDC — Planning for Pregnancy", sourceURL: "https://www.cdc.gov/pregnancy/about/"),
        .init(id: "folate", title: "Tìm hiểu folate và axit folic", topic: "Dinh dưỡng", summary: "Thực phẩm và viên bổ sung có vai trò khác nhau.", body: "Folate là vitamin nhóm B có trong một số thực phẩm. Axit folic là dạng thường có trong sản phẩm bổ sung. Hướng dẫn chuẩn bị mang thai có khuyến nghị riêng về axit folic từ trước khi có thai.\n\nHãy xem nguồn dưới đây và trao đổi về sản phẩm, lượng dùng phù hợp. Không tự cộng thêm nhiều viên có thành phần giống nhau. Momi chỉ nhắc theo lịch bạn đã thiết lập.", sourceTitle: "NHS — Vitamins and supplements in pregnancy", sourceURL: "https://www.nhs.uk/pregnancy/keeping-well/pregnancy-vitamins-and-supplements/"),
        .init(id: "food", title: "Ăn đa dạng, theo cách phù hợp với mình", topic: "Dinh dưỡng", summary: "Gợi ý món ăn để bạn lựa chọn, không phải thực đơn điều trị.", body: "Ăn đa dạng giúp cung cấp nhiều loại dưỡng chất. Khi chọn món, lưu ý dị ứng, nguyên liệu và cách chế biến. Nấu chín thực phẩm và chọn sản phẩm sữa phù hợp.\n\nDanh sách món của Momi là gợi ý tổ chức bữa ăn. Hàm lượng dưỡng chất tùy nguyên liệu và khẩu phần; app không xác định bạn đang thiếu chất.", sourceTitle: "ACOG — Healthy Eating During Pregnancy", sourceURL: "https://www.acog.org/womens-health/faqs/healthy-eating-during-pregnancy"),
        .init(id: "vaccines", title: "Mang theo hồ sơ tiêm chủng", topic: "Vaccine", summary: "Lưu phiếu cũ và chuẩn bị câu hỏi cho cơ sở y tế.", body: "Tìm lại phiếu tiêm hoặc hồ sơ cũ nếu có. Bạn có thể chụp vào Momi, kiểm tra thông tin được đọc từ ảnh và lưu ngày hẹn đã được xác nhận.\n\nViệc cần tiêm loại nào và khi nào phụ thuộc tiền sử, giai đoạn và hướng dẫn chuyên môn. Momi không tự tạo phác đồ tiêm.", sourceTitle: "CDC — Planning for Pregnancy", sourceURL: "https://www.cdc.gov/pregnancy/about/"),
        .init(id: "cycle", title: "Ghi lại chu kỳ để hiểu cơ thể", topic: "Chu kỳ", summary: "Ngày đã ghi nhận và dự đoán là hai loại thông tin khác nhau.", body: "Bạn có thể ghi ngày bắt đầu kỳ kinh, triệu chứng và những câu hỏi muốn hỏi bác sĩ. Không cần ghi đủ mỗi ngày.\n\nLịch chu kỳ không xác định chắc chắn ngày rụng trứng. Momi hiện lưu ngày bạn ghi nhận và không đưa ra kết luận khả năng có thai.", sourceTitle: "ASRM — Optimizing natural fertility", sourceURL: "https://www.asrm.org/practice-guidance/practice-committee-documents/optimizing-natural-fertility-a-committee-opinion-2021/")
    ]
    public static let foods: [Food] = [
        .init(id: "beans", name: "Đậu phụ và rau nấu chín", nutrients: "Đạm thực vật · chất xơ", preparation: "Chọn nguyên liệu tươi, rửa rau và nấu chín. Kiểm tra thành phần nếu dùng sốt đóng gói.", vegetarian: true, allergens: ["Đậu nành"], symbol: "carrot"),
        .init(id: "fish", name: "Cá hồi nấu chín với rau", nutrients: "Đạm · omega-3", preparation: "Nấu chín kỹ. Lựa chọn loại cá và khẩu phần theo hướng dẫn dinh dưỡng phù hợp.", vegetarian: false, allergens: ["Cá"], symbol: "fish"),
        .init(id: "yogurt", name: "Sữa chua từ sữa thanh/tiệt trùng", nutrients: "Canxi · đạm", preparation: "Kiểm tra nhãn, hạn sử dụng và điều kiện bảo quản.", vegetarian: true, allergens: ["Sữa"], symbol: "cup.and.saucer"),
        .init(id: "lentils", name: "Đậu đỗ nấu chín", nutrients: "Folate · chất xơ · đạm", preparation: "Nấu chín, kết hợp các thực phẩm khác để bữa ăn đa dạng.", vegetarian: true, allergens: [], symbol: "leaf"),
        .init(id: "eggs", name: "Trứng hấp chín", nutrients: "Đạm · choline", preparation: "Nấu chín cả lòng trắng và lòng đỏ; kiểm tra các nguyên liệu đi kèm.", vegetarian: true, allergens: ["Trứng"], symbol: "oval")
    ]
}
