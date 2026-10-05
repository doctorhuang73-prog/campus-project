// SPDX-License-Identifier: GPL-3.0-only
import Foundation
import WebKit

/// Read-only API transport. Session cookies stay in memory and never go to GitHub.
final class AcademicClient: NSObject, URLSessionTaskDelegate {
    private var session: URLSession!
    private let school: School
    private let cookieStorage: HTTPCookieStorage

    init(school: School, cookies: [HTTPCookie]) throws {
        self.school = school
        let base = try school.baseURL()
        let configuration = URLSessionConfiguration.ephemeral
        cookieStorage = configuration.httpCookieStorage!
        super.init()
        configuration.timeoutIntervalForRequest = 25
        configuration.timeoutIntervalForResource = 60
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        for cookie in cookies {
            let domain = cookie.domain.hasPrefix(".") ? String(cookie.domain.dropFirst()) : cookie.domain
            if base.host == domain || base.host?.hasSuffix("." + domain) == true {
                cookieStorage.setCookie(cookie)
            }
        }
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    func close() { session.invalidateAndCancel() }

    // API requests never forward authenticated requests to an SSO/third-party origin.
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard let base = try? school.baseURL(), let url = request.url,
              url.scheme == "https", url.host == base.host, url.port == base.port,
              !url.path.lowercased().contains("login") else { completionHandler(nil); return }
        completionHandler(request)
    }

    private func post(path: String, query: [String: String], fields: [String: String]) async throws -> Data {
        let url = try school.endpoint(path, query: query)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = FormEncoding.encode(fields)
        request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
        request.setValue(try school.endpoint("xtgl/index_initMenu.html").absoluteString, forHTTPHeaderField: "Referer")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw CampusError.unsupportedResponse }
        if http.statusCode == 401 || (300...399).contains(http.statusCode) { throw CampusError.expiredSession }
        guard (200...299).contains(http.statusCode) else { throw CampusError.message("教务服务器返回 HTTP \(http.statusCode)，请稍后重试。") }
        guard data.count < 10_000_000 else { throw CampusError.unsupportedResponse }
        return data
    }

    func fetch(term: Term) async throws -> Snapshot {
        let schedule = try await post(path: "kbcx/xskbcx_cxXsKb.html", query: ["gnmkdm": "N253508"], fields: term.zfFields)
        let lessons = try ZhengfangParser.schedule(schedule)
        var grades: [Grade] = []
        for page in 1...50 {
            var fields = term.zfFields
            fields.merge(["queryModel.showCount": "100", "queryModel.currentPage": String(page),
                          "queryModel.sortName": "", "queryModel.sortOrder": "asc", "time": "0"]) { _, b in b }
            let data = try await post(path: "cjcx/cjcx_cxDgXscj.html", query: ["doType": "query", "gnmkdm": "N305005"], fields: fields)
            let batch = try ZhengfangParser.grades(data, page: page)
            grades += batch
            let pageCount = try ZhengfangParser.pageCount(data)
            if let count = pageCount, count > 50 { throw CampusError.tooManyPages }
            if batch.isEmpty || (pageCount.map { page >= $0 } ?? (batch.count < 100)) {
                return Snapshot(school: school, term: term, lessons: lessons, grades: grades)
            }
        }
        throw CampusError.tooManyPages
    }
}
