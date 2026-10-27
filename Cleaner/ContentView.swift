import SwiftUI
import Foundation

struct CleanItem: Identifiable {
    let id = UUID()
    let title: String
    let path: URL
    let bytes: Int64
    let detail: String
    var selected: Bool = true
}

@MainActor
final class CleanerModel: ObservableObject {
    @Published var items: [CleanItem] = []
    @Published var isScanning = false
    @Published var report = "点击“扫描”检查本应用可安全访问的缓存。"
    @Published var lastFreed: Int64 = 0

    private let fm = FileManager.default

    func scan() {
        isScanning = true
        defer { isScanning = false }
        var found: [CleanItem] = []
        let candidates: [(String, URL?, String)] = [
            ("本应用缓存", fm.urls(for: .cachesDirectory, in: .userDomainMask).first, "仅限清爽助手自身缓存"),
            ("本应用临时文件", URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true), "仅限清爽助手自身临时目录")
        ]

        for (name, url, detail) in candidates {
            guard let url else { continue }
            let size = directorySize(url)
            found.append(CleanItem(title: name, path: url, bytes: size, detail: detail))
        }

        items = found
        let total = found.reduce(Int64(0)) { $0 + $1.bytes }
        report = "扫描完成：发现 \(found.count) 个可检查目录，共 \(Self.format(total))。\\n出于安全限制，本版本不会扫描或删除其他 App 的私有数据。"
        lastFreed = 0
    }

    func cleanSelected() {
        var freed: Int64 = 0
        var deleted = 0
        var errors: [String] = []

        for item in items where item.selected {
            do {
                let children = try fm.contentsOfDirectory(at: item.path,
                                                          includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                                                          options: [.skipsHiddenFiles])
                for child in children {
                    do {
                        let size = directorySize(child)
                        try fm.removeItem(at: child)
                        freed += size
                        deleted += 1
                    } catch {
                        errors.append("\(child.lastPathComponent)：\(error.localizedDescription)")
                    }
                }
            } catch {
                errors.append("\(item.title)：\(error.localizedDescription)")
            }
        }

        lastFreed = freed
        scan()
        report = "清理结束：删除 \(deleted) 个文件/目录，释放约 \(Self.format(freed))。"
        if !errors.isEmpty {
            report += "\\n有 \(errors.count) 项未能删除；未成功的项目已保留。"
        }
    }

    private func directorySize(_ url: URL) -> Int64 {
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        if !isDir.boolValue {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey])
            return Int64(values?.fileSize ?? 0)
        }
        var total: Int64 = 0
        guard let enumerator = fm.enumerator(at: url,
                                             includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                                             options: [.skipsHiddenFiles]) else { return 0 }
        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
               values.isRegularFile == true {
                total += Int64(values.fileSize ?? 0)
            }
        }
        return total
    }

    static func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

struct ContentView: View {
    @StateObject private var model = CleanerModel()
    @State private var showConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("清爽助手").font(.largeTitle.bold())
                        Text("iOS 17 · 安全清理").font(.subheadline).foregroundStyle(.secondary)
                        Text("只处理本应用自己的缓存与临时文件，不触碰其他应用数据。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding(.top, 12)

                    HStack(spacing: 12) {
                        statCard(title: "可检查目录", value: "\(model.items.count)")
                        statCard(title: "本次释放", value: CleanerModel.format(model.lastFreed))
                    }

                    Button {
                        model.scan()
                    } label: {
                        Label(model.isScanning ? "扫描中…" : "开始扫描", systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity).padding(.vertical, 5)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isScanning)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("扫描项目").font(.headline)
                        if model.items.isEmpty {
                            Text("尚未扫描").foregroundStyle(.secondary)
                        }
                        ForEach($model.items) { $item in
                            HStack(alignment: .top, spacing: 12) {
                                Toggle("", isOn: $item.selected).labelsHidden()
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title).font(.body.weight(.semibold))
                                    Text(item.detail).font(.caption).foregroundStyle(.secondary)
                                    Text(CleanerModel.format(item.bytes)).font(.subheadline.monospacedDigit())
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    Button(role: .destructive) {
                        showConfirm = true
                    } label: {
                        Label("清理所选项目", systemImage: "trash")
                            .frame(maxWidth: .infinity).padding(.vertical, 5)
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.items.isEmpty || !model.items.contains(where: { $0.selected }))

                    Text(model.report)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text("安全提示：缓存清理可能导致本应用下次打开时重新生成缓存。本版本不会清理系统核心文件、照片、聊天记录或其他 App 的私有数据。")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("确认清理所选缓存？", isPresented: $showConfirm, titleVisibility: .visible) {
                Button("删除所选缓存", role: .destructive) { model.cleanSelected() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("只会删除清爽助手自己的缓存和临时文件。")
            }
        }
        .tint(.blue)
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.bold()).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
