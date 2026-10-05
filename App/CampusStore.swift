// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import SwiftUI
import WebKit

@MainActor
final class CampusStore: ObservableObject {
    @Published var school: School
    @Published var term: Term
    @Published private(set) var snapshot: Snapshot?
    @Published private(set) var demo = true
    @Published var busy = false
    @Published var message: String?
    @Published var week = 1
    @Published var selectedDay = 1
    @Published var tab = 0
    @Published var browser: BrowserDestination?
    @Published private(set) var webData = WKWebsiteDataStore.nonPersistent()
    private var generation = UUID()
    private var activeClient: AcademicClient?
    private let configKey = "campus-school-v1"
    private let termKey = "campus-term-v1"

    init() {
        school = UserDefaults.standard.data(forKey: configKey).flatMap { try? JSONDecoder().decode(School.self, from: $0) } ?? School()
        term = UserDefaults.standard.data(forKey: termKey).flatMap { try? JSONDecoder().decode(Term.self, from: $0) } ?? .current
        if let data = try? Data(contentsOf: Self.cacheURL), let saved = try? JSONDecoder().decode(Snapshot.self, from: data),
           saved.school == school, saved.term == term {
            snapshot = saved; demo = false
        }
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "--preview-tab"), args.indices.contains(index + 1) {
            tab = Int(args[index + 1]) ?? 0
            demo = true
        }
    }
    var lessons: [Lesson] { demo ? Demo.lessons : (snapshot?.lessons ?? []) }
    var grades: [Grade] { demo ? Demo.grades : (snapshot?.grades ?? []) }
    var visibleLessons: [Lesson] { lessons.filter { $0.occurs(in: week) }.sorted { ($0.day, $0.start) < ($1.day, $1.start) } }
    var modeLabel: String { demo ? "演示模式 · 非真实教务数据" : (snapshot == nil ? "尚未同步真实数据" : "本机缓存 · 可离线查看") }
    var gpa: String { Grade.weightedGPA(grades).map { String(format: "%.2f", $0) } ?? "—" }

    func openSchool(selection: Bool = false) {
        do {
            let url = try selection
                ? school.endpoint("xsxk/zzxkyzb_cxZzxkYzbIndex.html", query: ["gnmkdm": "N253512", "layout": "default"])
                : school.baseURL()
            if demo { setDemo(false) }
            browser = BrowserDestination(url: url, title: selection ? "学校选课" : "学校登录", login: !selection)
        } catch { message = error.localizedDescription; tab = 3 }
    }

    private static var cacheURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("campus-snapshot.json")
    }
    func configure(school newSchool: School, term newTerm: Term) throws {
        _ = try newSchool.baseURL()
        let changedSchool = school != newSchool
        let changedTerm = term != newTerm
        generation = UUID()
        activeClient?.close(); activeClient = nil; busy = false
        if changedSchool { webData = .nonPersistent() }
        if changedSchool || changedTerm {
            snapshot = nil
            try? FileManager.default.removeItem(at: Self.cacheURL)
        }
        school = newSchool; term = newTerm; demo = false
        UserDefaults.standard.set(try JSONEncoder().encode(school), forKey: configKey)
        UserDefaults.standard.set(try JSONEncoder().encode(term), forKey: termKey)
    }
    func setDemo(_ value: Bool) {
        generation = UUID(); activeClient?.close(); activeClient = nil; busy = false
        demo = value
    }
    func sync() async {
        guard !busy else { return }
        guard !demo else { message = "当前是演示模式。请先在设置中填写学校教务地址，再完成网页登录。"; return }
        let requestID = generation
        busy = true
        defer { if requestID == generation { busy = false; activeClient?.close(); activeClient = nil } }
        do {
            _ = try school.baseURL()
            let cookies = await withCheckedContinuation { continuation in
                webData.httpCookieStore.getAllCookies { continuation.resume(returning: $0) }
            }
            guard requestID == generation else { return }
            guard !cookies.isEmpty else { throw CampusError.expiredSession }
            let client = try AcademicClient(school: school, cookies: cookies)
            activeClient = client
            let result = try await client.fetch(term: term)
            guard requestID == generation else { return }
            let url = Self.cacheURL
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(result).write(to: url, options: [.atomic, .completeFileProtection])
            var directory = url.deletingLastPathComponent()
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try? directory.setResourceValues(values)
            snapshot = result
            message = "已同步 \(result.lessons.count) 条课程安排和 \(result.grades.count) 条成绩。"
        } catch {
            guard requestID == generation else { return }
            message = error.localizedDescription
        }
    }
    func clearLocalData() {
        generation = UUID(); activeClient?.close(); activeClient = nil; busy = false
        webData = .nonPersistent(); snapshot = nil; demo = false
        do {
            if FileManager.default.fileExists(atPath: Self.cacheURL.path) { try FileManager.default.removeItem(at: Self.cacheURL) }
            message = "本机课表、成绩缓存与网页会话已清除。"
        } catch { message = "网页会话已退出，但缓存文件删除失败：\(error.localizedDescription)" }
    }
}
