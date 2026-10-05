import XCTest
@testable import CampusCore

final class CampusCoreTests: XCTestCase {
    func data(_ string: String) -> Data { Data(string.utf8) }
    func testAcademicPrefixIsPreserved() throws {
        let school = School(name: "测试学校", address: "https://school.example/jwglxt/")
        XCTAssertEqual(try school.endpoint("/kbcx/query.html").absoluteString, "https://school.example/jwglxt/kbcx/query.html")
    }
    func testUnsafeOrTicketAddressesRejected() {
        for address in ["http://school.example", "https://u:p@school.example", "https://school.example/?ticket=secret", "https://school.example/#token", "file:///etc/passwd", "https://school.example/login.html"] {
            XCTAssertThrowsError(try School(address: address).baseURL(), address)
        }
    }
    func testEndpointCannotEscapeSchool() {
        let school = School(address: "https://school.example/jwglxt")
        XCTAssertThrowsError(try school.endpoint("https://other.example/"))
        XCTAssertThrowsError(try school.endpoint("../other"))
    }
    func testSemesterMapping() {
        XCTAssertEqual(Term(year: 2026, semester: 1).zfFields, ["xnm": "2026", "xqm": "3"])
        XCTAssertEqual(Term(year: 2025, semester: 2).zfFields["xqm"], "12")
    }
    func testWeekRangesAndParity() throws {
        XCTAssertEqual(try WeekPattern.parse("1-8周(单),10-12周(双),15周"), Set([1, 3, 5, 7, 10, 12, 15]))
        XCTAssertEqual(try WeekPattern.parse("2-6周（双）"), Set([2, 4, 6]))
        for text in ["", "未知", "0-5周", "4-2周", "1-99周"] { XCTAssertThrowsError(try WeekPattern.parse(text)) }
    }
    func testScheduleFromZhengfang() throws {
        let json = #"{"kbList":[{"kcmc":"高等数学","xqj":1,"jcs":"1-2","zcd":"1-16周(单)","xm":"教师","cdmc":"A101"}]}"#
        let result = try ZhengfangParser.schedule(data(json))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].room, "A101")
        XCTAssertTrue(result[0].occurs(in: 3)); XCTAssertFalse(result[0].occurs(in: 4))
    }
    func testMissingWeeksOrPeriodsRejectInsteadOfInventingSchedule() {
        for json in [#"{"kbList":[{"kcmc":"数学","xqj":1,"jcs":"1-2"}]}"#,
                     #"{"kbList":[{"kcmc":"数学","xqj":9,"jcs":"1-2","zcd":"1-8周"}]}"#,
                     #"{"kbList":[{"kcmc":"数学","xqj":1,"jcs":"1-x","zcd":"1-8周"}]}"#] {
            XCTAssertThrowsError(try ZhengfangParser.schedule(data(json)))
        }
    }
    func testEmptyListIsValidButErrorObjectIsNot() throws {
        XCTAssertEqual(try ZhengfangParser.schedule(data(#"{"kbList":[]}"#)), [])
        XCTAssertThrowsError(try ZhengfangParser.schedule(data(#"{"message":"没有访问权限"}"#)))
    }
    func testLoginHTMLRequiresNewSession() {
        XCTAssertThrowsError(try ZhengfangParser.grades(data("<form action='xtgl/login_slogin.html'></form>"))) {
            XCTAssertEqual($0 as? CampusError, .expiredSession)
        }
    }
    func testGradesKeepNonNumericScoresAndPagination() throws {
        let json = #"{"items":[{"kcmc":"体育","cj":"优秀","xf":"1"},{"kcmc":"数学","cj":90,"xf":4,"jd":"4.0"}],"totalPage":"2"}"#
        let result = try ZhengfangParser.grades(data(json))
        XCTAssertEqual(result[0].score, "优秀"); XCTAssertNil(result[0].point)
        XCTAssertEqual(Grade.weightedGPA(result), 4)
        XCTAssertEqual(try ZhengfangParser.pageCount(data(json)), 2)
    }
    func testWeightedGPA() {
        let grades = [Grade(id: "a", name: "a", score: "90", credits: 4, point: 4, kind: ""),
                      Grade(id: "b", name: "b", score: "80", credits: 2, point: 3, kind: "")]
        XCTAssertEqual(Grade.weightedGPA(grades)!, 22.0 / 6, accuracy: 0.0001)
        XCTAssertNil(Grade.weightedGPA([]))
    }
    func testFormEncodingDoesNotTurnPlusIntoSpace() {
        XCTAssertEqual(String(data: FormEncoding.encode(["name": "a+b &中文"]), encoding: .utf8), "name=a%2Bb%20%26%E4%B8%AD%E6%96%87")
    }
    func testCacheRoundTripPreservesSchoolAndTerm() throws {
        let saved = Snapshot(school: School(name: "测试", address: "https://school.example/jwglxt"), term: .current, lessons: Demo.lessons, grades: Demo.grades)
        let decoded = try JSONDecoder().decode(Snapshot.self, from: JSONEncoder().encode(saved))
        XCTAssertEqual(decoded.school, saved.school); XCTAssertEqual(decoded.term, saved.term)
        XCTAssertEqual(decoded.lessons, saved.lessons)
    }
}
