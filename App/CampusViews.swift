// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI

private let ink = Color(red: 0.14, green: 0.20, blue: 0.30)
private let weekdays = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
private let palette: [Color] = [.indigo, .teal, .orange, .purple, .blue, .pink]

struct CampusTabs: View {
    @EnvironmentObject var store: CampusStore
    var body: some View {
        TabView(selection: $store.tab) {
            ScheduleScreen().tabItem { Label("课表", systemImage: "calendar") }.tag(0)
            GradesScreen().tabItem { Label("成绩", systemImage: "chart.bar.xaxis") }.tag(1)
            SelectionScreen().tabItem { Label("选课", systemImage: "bolt.circle") }.tag(2)
            SettingsScreen().tabItem { Label("设置", systemImage: "slider.horizontal.3") }.tag(3)
        }
        .sheet(item: $store.browser) { SchoolBrowser(destination: $0).environmentObject(store) }
        .alert("校园助手", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button("知道了", role: .cancel) { store.message = nil }
        } message: { Text(store.message ?? "") }
    }
}

private struct Page<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color.indigo.opacity(0.10), Color.teal.opacity(0.06), Color(.systemBackground)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                        content
                        Text("CAMPUS / 校园助手").font(.system(size: 10, weight: .medium, design: .monospaced))
                            .tracking(3).foregroundStyle(.tertiary).frame(maxWidth: .infinity).padding(.top, 12)
                    }.padding(20)
                }
            }.navigationTitle(title)
        }
    }
}

private struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.5), lineWidth: 1))
    }
}

private struct ModeBadge: View {
    @EnvironmentObject var store: CampusStore
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: store.demo ? "sparkles" : "internaldrive")
            Text(store.modeLabel)
            Spacer(minLength: 0)
            if store.busy { ProgressView() }
        }.font(.caption).foregroundStyle(store.demo ? Color.orange : Color.secondary)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background((store.demo ? Color.orange : Color.indigo).opacity(0.08), in: Capsule())
    }
}

struct ScheduleScreen: View {
    @EnvironmentObject var store: CampusStore
    @State private var weekView = false
    @State private var detail: Lesson?
    var body: some View {
        Page(title: "我的课表", subtitle: store.demo ? "把校园日常，安排得从容一点。" : store.school.name) {
            ModeBadge()
            GlassCard {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(store.term.label).font(.caption).foregroundStyle(.secondary)
                        Text("第 \(store.week) 周").font(.system(size: 30, weight: .bold, design: .rounded))
                    }
                    Spacer()
                    Button { store.week = max(1, store.week - 1) } label: { Image(systemName: "chevron.left").padding(9) }.disabled(store.week == 1).accessibilityLabel("上一周")
                    Button { store.week = min(60, store.week + 1) } label: { Image(systemName: "chevron.right").padding(9) }.disabled(store.week == 60).accessibilityLabel("下一周")
                }
                Picker("课表视图", selection: $weekView) { Text("每日安排").tag(false); Text("一周总览").tag(true) }
                    .pickerStyle(.segmented).padding(.top, 10)
            }
            if weekView {
                weekGrid
            } else {
                HStack(spacing: 0) {
                    ForEach(1...7, id: \.self) { day in
                        Button { store.selectedDay = day } label: {
                            VStack(spacing: 8) {
                                Text(weekdays[day - 1]).font(.caption2)
                                Circle().fill(store.selectedDay == day ? .white : Color.indigo.opacity(0.3)).frame(width: 5, height: 5)
                            }.frame(maxWidth: .infinity).padding(.vertical, 13)
                                .foregroundStyle(store.selectedDay == day ? Color.white : Color.secondary)
                                .background(store.selectedDay == day ? Color.indigo : Color.clear, in: RoundedRectangle(cornerRadius: 16))
                        }.buttonStyle(.plain)
                    }
                }
                let lessons = store.visibleLessons.filter { $0.day == store.selectedDay }
                if lessons.isEmpty {
                    EmptyCard(title: store.demo || store.snapshot != nil ? "这一天，没有课程安排" : "还没有你的课表", subtitle: store.snapshot == nil && !store.demo ? "登录学校教务，开始同步。" : "也可以切换日期，看看接下来的安排。", symbol: "sun.horizon")
                }
                ForEach(lessons) { lesson in
                    Button { detail = lesson } label: {
                        GlassCard {
                            HStack(alignment: .top, spacing: 14) {
                                VStack(spacing: 3) {
                                    Text(String(format: "%02d", lesson.start)).font(.system(size: 26, weight: .bold, design: .rounded))
                                    Text("\(lesson.start)–\(lesson.end)节").font(.caption2)
                                }.foregroundStyle(palette[(lesson.day - 1) % palette.count]).frame(width: 52)
                                RoundedRectangle(cornerRadius: 2).fill(palette[(lesson.day - 1) % palette.count]).frame(width: 3, height: 65)
                                VStack(alignment: .leading, spacing: 7) {
                                    Text(lesson.name).font(.headline).foregroundStyle(.primary)
                                    Label(lesson.room.isEmpty ? "教室待公布" : lesson.room, systemImage: "mappin.and.ellipse")
                                    Text(lesson.teacher.isEmpty ? "教师待公布" : lesson.teacher)
                                }.font(.caption).foregroundStyle(.secondary)
                                Spacer(minLength: 0)
                            }
                        }
                    }.buttonStyle(.plain)
                }
            }
            HStack {
                Button { store.openSchool() } label: { Label("学校登录", systemImage: "person.crop.circle") }
                Spacer()
                Button { Task { await store.sync() } } label: { Label("同步课表与成绩", systemImage: "arrow.triangle.2.circlepath") }.disabled(store.busy)
            }.font(.subheadline)
        }
        .sheet(item: $detail) { lesson in
            NavigationStack {
                Form {
                    Section(lesson.name) {
                        LabeledContent("教师", value: lesson.teacher)
                        LabeledContent("教室", value: lesson.room)
                        LabeledContent("时间", value: "\(weekdays[lesson.day - 1]) · \(lesson.start)–\(lesson.end)节")
                        LabeledContent("周次", value: lesson.weeks)
                    }
                    if store.demo { Text("此课程为界面演示数据。真正的课程会在学校同步后显示。").foregroundStyle(.secondary) }
                }.textSelection(.enabled).navigationTitle("课程详情").navigationBarTitleDisplayMode(.inline)
                    .toolbar { Button("完成") { detail = nil } }
            }.presentationDetents([.medium, .large])
        }
    }

    private var weekGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(1...7, id: \.self) { day in
                    VStack(spacing: 12) {
                        Text(weekdays[day - 1]).font(.subheadline.bold()).foregroundStyle(.secondary)
                        ForEach(store.visibleLessons.filter { $0.day == day }) { lesson in
                            Button { detail = lesson } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("\(lesson.start)–\(lesson.end)节").font(.caption2.bold())
                                    Text(lesson.name).font(.subheadline.bold())
                                    Text(lesson.room).font(.caption2)
                                }.frame(width: 98, alignment: .leading).padding(12)
                                    .foregroundStyle(palette[(day - 1) % palette.count])
                                    .background(palette[(day - 1) % palette.count].opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
                            }.buttonStyle(.plain)
                        }
                        if !store.visibleLessons.contains(where: { $0.day == day }) { Text("无课").font(.caption).foregroundStyle(.tertiary).padding() }
                    }.frame(width: 122)
                }
            }.padding(.vertical, 5)
        }
    }
}

struct GradesScreen: View {
    @EnvironmentObject var store: CampusStore
    @State private var query = ""
    var body: some View {
        Page(title: "成绩与绩点", subtitle: store.term.label) {
            ModeBadge()
            GlassCard {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("学分加权 GPA").font(.caption).foregroundStyle(.secondary)
                        Text(store.gpa).font(.system(size: 44, weight: .bold, design: .rounded)).foregroundStyle(.indigo)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 7) {
                        Text("\(store.grades.count)").font(.title.bold())
                        Text("课程记录").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text("仅统计学校返回有效学分和绩点的记录；未自行换算等级成绩，也未合并重修成绩。")
                    .font(.caption2).foregroundStyle(.secondary).padding(.top, 10)
            }
            HStack { Image(systemName: "magnifyingglass").foregroundStyle(.secondary); TextField("搜索课程", text: $query) }
                .padding(14).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            let rows = store.grades.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
            ForEach(rows) { grade in
                GlassCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(grade.name).font(.headline)
                            Text("\(grade.kind) · \(grade.credits.map { String(format: "%g", $0) } ?? "—") 学分").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(grade.score.isEmpty ? "—" : grade.score).font(.title2.bold()).foregroundStyle(.indigo)
                    }
                }
            }
            if rows.isEmpty { EmptyCard(title: "暂无成绩记录", subtitle: "可切换学期、调整搜索词，或登录后同步。", symbol: "chart.bar.doc.horizontal") }
            Button { Task { await store.sync() } } label: { Label("同步本学期数据", systemImage: "arrow.clockwise") }.disabled(store.busy)
        }
    }
}

struct SelectionScreen: View {
    @EnvironmentObject var store: CampusStore
    var body: some View {
        Page(title: "选课工作台", subtitle: "从课程发现，到确认你的下一堂课。") {
            ModeBadge()
            GlassCard {
                Label("校方选课入口", systemImage: "graduationcap.fill").font(.title3.bold())
                Text("在 App 内打开学校原有选课页面，沿用已登录的网页会话。课程查询、选课和退课以学校页面为准。")
                    .font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 12)
                Button { store.openSchool(selection: true) } label: {
                    Label("进入学校选课", systemImage: "arrow.up.right").frame(maxWidth: .infinity).padding(.vertical, 8)
                }.buttonStyle(.borderedProminent)
                Button("还没登录？先登录学校") { store.openSchool() }.font(.caption).padding(.top, 6)
            }
            Text("安卓功能迁移进度").font(.headline)
            modeRow("01", "即时选课", "初版通过学校网页手动操作，不会自动提交。", "网页可用", .teal)
            modeRow("02", "余量检测 / 捡漏", "原生队列和轮询协议尚未接入。", "待迁移", .secondary)
            modeRow("03", "定时任务", "iOS 无法保证锁屏后准点唤醒；后续需另定执行方案。", "需调整", .orange)
            Text("初版原生数据同步仅面向新正方通用接口。其他教务系统可先尝试学校网页，不能据此认定已完成原生适配。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private func modeRow(_ number: String, _ title: String, _ detail: String, _ status: String, _ color: Color) -> some View {
        GlassCard {
            HStack(alignment: .top, spacing: 12) {
                Text(number).font(.system(size: 23, weight: .light, design: .rounded)).foregroundStyle(.tertiary)
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Text(title).font(.headline); Spacer(); Text(status).font(.caption2.bold()).foregroundStyle(color) }
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct SettingsScreen: View {
    @EnvironmentObject var store: CampusStore
    @State private var name = ""
    @State private var address = ""
    @State private var year = Term.current.year
    @State private var semester = Term.current.semester
    @State private var confirmClear = false
    var body: some View {
        Page(title: "设置", subtitle: "你的学校，你的校园节奏。") {
            ModeBadge()
            GlassCard {
                Label("学校与学期", systemImage: "building.columns").font(.headline)
                TextField("学校名称", text: $name).textFieldStyle(.roundedBorder).padding(.top, 10)
                TextField("https://学校域名/jwglxt", text: $address).textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                Text("填写教务系统根地址，保留 /jwglxt 等前缀；不要填写登录票据链接。初版暂不支持 HTTP 学校。")
                    .font(.caption2).foregroundStyle(.secondary).padding(.bottom, 8)
                Stepper("学年：\(String(year))–\(String(year + 1))", value: $year, in: 2000...2100).font(.subheadline)
                Picker("学期", selection: $semester) { Text("第一学期").tag(1); Text("第二学期").tag(2) }.pickerStyle(.segmented)
                Button("保存并切换到真实数据") {
                    do {
                        try store.configure(school: School(name: name.isEmpty ? "我的学校" : name, address: address), term: Term(year: year, semester: semester))
                        store.message = "配置已保存。请打开学校登录页面，登录成功后同步数据。"
                    } catch { store.message = error.localizedDescription }
                }.buttonStyle(.borderedProminent).padding(.top, 8)
                Button("打开学校登录") { store.openSchool() }.padding(.top, 6)
            }
            GlassCard {
                Label("数据与隐私", systemImage: "lock.shield").font(.headline)
                Toggle("查看演示数据", isOn: Binding(get: { store.demo }, set: { store.setDemo($0) })).padding(.top, 8)
                Text("账号密码只在你打开的学校网页中填写。App 不采集密码；网页会话仅保留于本次运行，课表和成绩缓存在本机。")
                    .font(.caption).foregroundStyle(.secondary).padding(.vertical, 8)
                if let date = store.snapshot?.date { Text("上次同步：\(date.formatted(date: .abbreviated, time: .shortened))").font(.caption) }
                Button("退出网页会话并清除数据", role: .destructive) { confirmClear = true }
            }
            GlassCard {
                Text("校园助手 · iOS 初版 0.1.0").font(.headline)
                Text("界面与教务协议参考正方教务助手，正在逐步迁移。尚未完成特定学校实测、插件系统、课表提醒及自动抢课。")
                    .font(.caption).foregroundStyle(.secondary).padding(.vertical, 8)
                Link("查看本项目源码", destination: URL(string: "https://github.com/doctorhuang73-prog/campus-project")!)
                Link("原安卓开源项目", destination: URL(string: "https://github.com/znjhahaha/zhengfang-apk")!).padding(.top, 5)
                Text("GPL-3.0-only · 详见仓库许可证与来源说明").font(.caption2).foregroundStyle(.secondary).padding(.top, 6)
            }
        }
        .onAppear { name = store.school.name; address = store.school.address; year = store.term.year; semester = store.term.semester }
        .confirmationDialog("清除本机课表、成绩和登录会话？", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("清除并退出", role: .destructive) { store.clearLocalData() }
        }
    }
}

private struct EmptyCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    var body: some View {
        GlassCard {
            VStack(spacing: 12) {
                Image(systemName: symbol).font(.largeTitle).foregroundStyle(.indigo.opacity(0.6))
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }.frame(maxWidth: .infinity).padding(.vertical, 22)
        }
    }
}
