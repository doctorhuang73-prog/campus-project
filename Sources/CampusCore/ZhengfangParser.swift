// SPDX-License-Identifier: GPL-3.0-or-later
// Field mappings follow znjhahaha/zhengfang-apk; see THIRD_PARTY.md.
import Foundation

public enum WeekPattern {
    public static func parse(_ raw: String) throws -> Set<Int> {
        let text = raw.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "（", with: "(").replacingOccurrences(of: "）", with: ")")
            .replacingOccurrences(of: "周", with: "").replacingOccurrences(of: "—", with: "-")
        guard !text.isEmpty else { throw CampusError.invalidSchedule }
        let pattern = try NSRegularExpression(pattern: "^(\\d{1,2})(?:-(\\d{1,2}))?(?:\\(([单双])\\))?$")
        var result = Set<Int>()
        for part in text.components(separatedBy: ",") {
            let ns = part as NSString
            guard let match = pattern.firstMatch(in: part, range: NSRange(location: 0, length: ns.length)),
                  let start = Int(ns.substring(with: match.range(at: 1))) else { throw CampusError.invalidSchedule }
            let end = match.range(at: 2).location == NSNotFound ? start : Int(ns.substring(with: match.range(at: 2)))!
            guard start >= 1, end <= 60, start <= end else { throw CampusError.invalidSchedule }
            let parity = match.range(at: 3).location == NSNotFound ? "" : ns.substring(with: match.range(at: 3))
            for week in start...end where parity.isEmpty || (parity == "单" ? week % 2 == 1 : week % 2 == 0) {
                result.insert(week)
            }
        }
        return result
    }
}

public enum ZhengfangParser {
    private static func root(_ data: Data) throws -> Any {
        guard let root = try? JSONSerialization.jsonObject(with: data) else {
            let html = String(data: data, encoding: .utf8)?.lowercased() ?? ""
            if html.contains("login_slogin") || html.contains("name=\"mm\"") || html.contains("cas/login") {
                throw CampusError.expiredSession
            }
            throw CampusError.unsupportedResponse
        }
        return root
    }
    private static func rows(_ data: Data, keys: [String]) throws -> [[String: Any]] {
        let value = try root(data)
        if let list = value as? [[String: Any]] { return list }
        if let object = value as? [String: Any] {
            for key in keys { if let list = object[key] as? [[String: Any]] { return list } }
        }
        throw CampusError.unsupportedResponse
    }
    static func text(_ row: [String: Any], _ keys: String...) -> String {
        for key in keys {
            if let s = row[key] as? String, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return s }
            if let n = row[key] as? NSNumber { return n.stringValue }
        }
        return ""
    }
    public static func schedule(_ data: Data) throws -> [Lesson] {
        try rows(data, keys: ["kbList", "data"]).enumerated().map { index, row in
            let name = text(row, "kcmc", "KCMC")
            guard !name.isEmpty, let day = Int(text(row, "xqj", "XQJ")), (1...7).contains(day) else { throw CampusError.invalidSchedule }
            let periods = text(row, "jcs", "JCS", "jcor", "JCOR").replacingOccurrences(of: "节", with: "")
            let parts = periods.split(separator: "-", omittingEmptySubsequences: false)
            let pair = parts.compactMap { Int($0) }
            guard pair.count == parts.count, (1...2).contains(pair.count), let start = pair.first, let end = pair.last,
                  start > 0, end >= start, end <= 16 else { throw CampusError.invalidSchedule }
            let weeks = text(row, "zcd", "ZCD", "weeks")
            _ = try WeekPattern.parse(weeks)
            return Lesson(id: "\(index)-\(text(row, "kch_id", "jxb_id"))", name: name,
                          teacher: text(row, "xm", "XM", "jsxm"), room: text(row, "cdmc", "CDMC", "jxcdmc"),
                          day: day, start: start, end: end, weeks: weeks)
        }
    }
    public static func grades(_ data: Data, page: Int = 1) throws -> [Grade] {
        try rows(data, keys: ["items", "data"]).enumerated().map { index, row in
            let name = text(row, "kcmc", "KCMC")
            guard !name.isEmpty else { throw CampusError.unsupportedResponse }
            return Grade(id: "\(page)-\(index)-\(text(row, "kch_id", "kch"))", name: name,
                         score: text(row, "cj", "zcj"), credits: Double(text(row, "xf")),
                         point: Double(text(row, "jd", "xfjd")), kind: text(row, "kcxzmc", "kclbmc"))
        }
    }
    public static func pageCount(_ data: Data) throws -> Int? {
        guard let object = try root(data) as? [String: Any] else { return nil }
        return Int(text(object, "totalPage", "totalPages"))
    }
}

public enum FormEncoding {
    public static func encode(_ fields: [String: String]) -> Data {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return fields.sorted { $0.key < $1.key }.map {
            "\($0.key.addingPercentEncoding(withAllowedCharacters: allowed)!)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed)!)"
        }.joined(separator: "&").data(using: .utf8)!
    }
}
