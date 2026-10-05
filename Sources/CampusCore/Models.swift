// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

public enum CampusError: LocalizedError, Equatable {
    case invalidAddress, unsupportedResponse, expiredSession, invalidSchedule, tooManyPages
    case message(String)
    public var errorDescription: String? {
        switch self {
        case .invalidAddress: return "请输入完整的 HTTPS 教务根地址，例如 https://学校域名/jwglxt。不要填账号、密码或带票据的登录链接。"
        case .unsupportedResponse: return "学校返回的数据格式尚未适配。请使用教务网页查看，不会用演示数据替代真实结果。"
        case .expiredSession: return "未取得有效教务会话，请打开学校网页登录后再同步。"
        case .invalidSchedule: return "课表包含无法识别的星期、节次或周次，已保留原有数据。"
        case .tooManyPages: return "成绩分页数量超出初版限制，未保存不完整结果，请使用教务网页查看。"
        case .message(let message): return message
        }
    }
}

public struct School: Codable, Equatable {
    public var name: String
    public var address: String
    public init(name: String = "我的学校", address: String = "") { self.name = name; self.address = address }
    public func baseURL() throws -> URL {
        guard let c = URLComponents(string: address.trimmingCharacters(in: .whitespacesAndNewlines)),
              c.scheme?.lowercased() == "https", let host = c.host, !host.isEmpty,
              c.user == nil, c.password == nil, c.query == nil, c.fragment == nil,
              !c.path.lowercased().contains(".html"), !c.path.lowercased().contains(".aspx"),
              let url = c.url else { throw CampusError.invalidAddress }
        return url
    }
    public func endpoint(_ path: String, query: [String: String] = [:]) throws -> URL {
        let base = try baseURL()
        guard !path.contains("://"), !path.contains(".."), !path.contains("?"), !path.contains("#") else {
            throw CampusError.invalidAddress
        }
        let url = base.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        var c = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        if !query.isEmpty { c.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) } }
        return c.url!
    }
    public var storageKey: String { address.trimmingCharacters(in: .whitespacesAndNewlines) }
}

public struct Term: Codable, Equatable {
    public var year: Int
    public var semester: Int
    public init(year: Int, semester: Int) { self.year = year; self.semester = semester }
    public var label: String { "\(year)–\(year + 1) · 第\(semester)学期" }
    public var zfFields: [String: String] { ["xnm": String(year), "xqm": semester == 1 ? "3" : "12"] }
    public static var current: Term {
        let calendar = Calendar(identifier: .gregorian)
        let y = calendar.component(.year, from: Date()), m = calendar.component(.month, from: Date())
        return Term(year: m >= 8 ? y : y - 1, semester: (m >= 8 || m == 1) ? 1 : 2)
    }
}

public struct Lesson: Codable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var teacher: String
    public var room: String
    public var day: Int
    public var start: Int
    public var end: Int
    public var weeks: String
    public init(id: String, name: String, teacher: String, room: String, day: Int, start: Int, end: Int, weeks: String) {
        self.id = id; self.name = name; self.teacher = teacher; self.room = room
        self.day = day; self.start = start; self.end = end; self.weeks = weeks
    }
    public func occurs(in week: Int) -> Bool { (try? WeekPattern.parse(weeks).contains(week)) == true }
}

public struct Grade: Codable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var score: String
    public var credits: Double?
    public var point: Double?
    public var kind: String
    public init(id: String, name: String, score: String, credits: Double?, point: Double?, kind: String) {
        self.id = id; self.name = name; self.score = score; self.credits = credits; self.point = point; self.kind = kind
    }
    public static func weightedGPA(_ grades: [Grade]) -> Double? {
        let eligible = grades.filter { ($0.credits ?? 0) > 0 && $0.credits?.isFinite == true && $0.point?.isFinite == true }
        let weight = eligible.reduce(0.0) { $0 + ($1.credits ?? 0) }
        return weight > 0 ? eligible.reduce(0.0) { $0 + ($1.credits ?? 0) * ($1.point ?? 0) } / weight : nil
    }
}

public struct Snapshot: Codable {
    public var school: School
    public var term: Term
    public var lessons: [Lesson]
    public var grades: [Grade]
    public var date: Date
    public init(school: School, term: Term, lessons: [Lesson], grades: [Grade], date: Date = Date()) {
        self.school = school; self.term = term; self.lessons = lessons; self.grades = grades; self.date = date
    }
}

public enum Demo {
    public static let lessons: [Lesson] = [
        Lesson(id: "demo-1", name: "高等数学 A", teacher: "陈老师", room: "教学楼 A · 302", day: 1, start: 1, end: 2, weeks: "1-16周"),
        Lesson(id: "demo-2", name: "大学英语", teacher: "李老师", room: "外语楼 · 205", day: 1, start: 5, end: 6, weeks: "1-16周"),
        Lesson(id: "demo-3", name: "程序设计基础", teacher: "张老师", room: "实验楼 · 401", day: 2, start: 3, end: 4, weeks: "1-16周"),
        Lesson(id: "demo-4", name: "线性代数", teacher: "王老师", room: "教学楼 B · 108", day: 3, start: 1, end: 2, weeks: "1-16周"),
        Lesson(id: "demo-5", name: "大学物理", teacher: "刘老师", room: "教学楼 A · 502", day: 4, start: 3, end: 4, weeks: "1-16周"),
        Lesson(id: "demo-6", name: "体育", teacher: "赵老师", room: "体育中心", day: 5, start: 7, end: 8, weeks: "1-16周")
    ]
    public static let grades: [Grade] = [
        Grade(id: "g1", name: "高等数学 A", score: "92", credits: 5, point: 4.2, kind: "必修"),
        Grade(id: "g2", name: "大学英语", score: "88", credits: 3, point: 3.8, kind: "必修"),
        Grade(id: "g3", name: "程序设计基础", score: "95", credits: 4, point: 4.5, kind: "必修"),
        Grade(id: "g4", name: "体育", score: "优秀", credits: 1, point: nil, kind: "必修")
    ]
}
