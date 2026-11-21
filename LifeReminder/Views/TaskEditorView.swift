import SwiftUI
import UIKit
import PhotosUI

struct TaskEditorView: View {
    @State private var draft: TaskItem
    @State private var showDeleteConfirm = false

    private let isNew: Bool
    private let onSave: (TaskItem) -> Void
    private let onDelete: ((TaskItem) -> Void)?
    private let onClose: () -> Void

    init(task: TaskItem?,
         onSave: @escaping (TaskItem) -> Void,
         onDelete: ((TaskItem) -> Void)?,
         onClose: @escaping () -> Void) {
        _draft = State(initialValue: task ?? TaskItem(title: "",
                                                      dueDate: Date().addingTimeInterval(3600),
                                                      leadMinutes: 10))
        isNew = (task == nil)
        self.onSave = onSave
        self.onDelete = onDelete
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetGrip()

            HStack {
                Button(action: onClose) {
                    Text("取消")
                        .font(Theme.font(17))
                        .foregroundColor(Theme.label2)
                }
                .frame(width: 60, alignment: .leading)

                Spacer()

                Text(isNew ? "新建提醒" : "编辑提醒")
                    .font(Theme.font(17, .semibold))
                    .foregroundColor(Theme.label)

                Spacer()

                Button(action: save) {
                    Text(isNew ? "添加" : "保存")
                        .font(Theme.font(17, .semibold))
                        .foregroundColor(canSave ? Theme.blue : Theme.label3)
                }
                .frame(width: 60, alignment: .trailing)
                .disabled(!canSave)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    GroupCard(radius: 22, solid: true) {
                        HStack {
                            TextField("想做什么？", text: $draft.title)
                                .font(Theme.font(19, .medium))
                                .foregroundColor(Theme.label)
                                .accentColor(Theme.blue)
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 58)

                        CellDivider(inset: 16)

                        HStack(spacing: 10) {
                            Text("时间")
                                .font(Theme.font(17))
                                .foregroundColor(Theme.label)
                            Spacer()
                            DatePicker("",
                                       selection: $draft.dueDate,
                                       displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .accentColor(Theme.blue)
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 54)

                        CellDivider(inset: 16)

                        HStack(spacing: 10) {
                            Text("提前")
                                .font(Theme.font(17))
                                .foregroundColor(Theme.label)
                            Spacer()
                            Menu {
                                ForEach([0, 5, 10, 15, 30, 60], id: \.self) { minutes in
                                    Button(leadLabel(minutes)) {
                                        draft.leadMinutes = minutes
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(leadLabel(draft.leadMinutes))
                                        .font(Theme.font(15))
                                        .foregroundColor(Theme.label2)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(Theme.label3)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 54)
                    }

                    Text("重要程度")
                        .font(Theme.font(13, .semibold))
                        .foregroundColor(Theme.label2)
                        .padding(.leading, 6)

                    SegmentedControl(items: ["不急", "普通", "重要"], selection: priorityIndex)

                    if !isNew && onDelete != nil {
                        Button(action: {
                            Haptics.warning()
                            showDeleteConfirm = true
                        }) {
                            Text("删除这个提醒")
                                .font(Theme.font(17))
                                .foregroundColor(Theme.red)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Capsule().fill(Theme.fill))
                        }
                        .buttonStyle(PressableStyle())
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
            }
        }
        .alert(isPresented: $showDeleteConfirm) {
            Alert(title: Text("删除这个提醒？"),
                  message: Text("删除后无法恢复。"),
                  primaryButton: .destructive(Text("删除")) {
                      onDelete?(draft)
                  },
                  secondaryButton: .cancel(Text("取消")))
        }
    }

    private var canSave: Bool {
        !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var priorityIndex: Binding<Int> {
        Binding(get: {
            TaskPriority.allCases.firstIndex(of: draft.priority) ?? 1
        }, set: { index in
            let cases = TaskPriority.allCases
            if cases.indices.contains(index) {
                draft.priority = cases[index]
            }
        })
    }

    private func leadLabel(_ minutes: Int) -> String {
        minutes <= 0 ? "准时" : "提前 \(minutes) 分钟"
    }

    private func save() {
        guard canSave else { return }
        var task = draft
        task.title = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
        task.leadMinutes = max(0, min(180, task.leadMinutes))
        Haptics.success()
        onSave(task)
    }
}

struct AnniversarySheet: View {
    private let existing: Anniversary?

    @State private var title: String
    @State private var date: Date
    @State private var repeatMode: AnniversaryRepeat
    @State private var remind: Bool
    @State private var pickedImage: UIImage?
    @State private var existingImage: UIImage?
    @State private var removeImage = false
    @State private var showPicker = false
    @State private var manualRepeat: Bool

    let onSave: (Anniversary) -> Void
    let onClose: () -> Void

    init(item: Anniversary? = nil,
         onSave: @escaping (Anniversary) -> Void,
         onClose: @escaping () -> Void) {
        self.existing = item
        _title = State(initialValue: item?.title ?? "")
        _date = State(initialValue: item?.date ?? Date())
        _repeatMode = State(initialValue: item?.repeatMode ?? .none)
        _remind = State(initialValue: item?.remind ?? true)
        _existingImage = State(initialValue: AnniversaryImageStore.load(item?.imageFile))
        _manualRepeat = State(initialValue: (item?.repeatMode ?? .none) != .none)
        self.onSave = onSave
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetGrip()

            HStack {
                Button(action: onClose) {
                    Text("取消")
                        .font(Theme.font(17))
                        .foregroundColor(Theme.label2)
                }
                .frame(width: 60, alignment: .leading)

                Spacer()

                Text(existing == nil ? "新建纪念日" : "编辑纪念日")
                    .font(Theme.font(17, .semibold))
                    .foregroundColor(Theme.label)

                Spacer()

                Button(action: save) {
                    Text(existing == nil ? "添加" : "保存")
                        .font(Theme.font(17, .semibold))
                        .foregroundColor(canSave ? Theme.blue : Theme.label3)
                }
                .frame(width: 60, alignment: .trailing)
                .disabled(!canSave)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    GroupCard(radius: 22, solid: true) {
                        TextField("纪念日名称，比如「在一起」", text: $title)
                            .font(Theme.font(19, .medium))
                            .foregroundColor(Theme.label)
                            .accentColor(Theme.blue)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 58)

                        CellDivider(inset: 16)

                        photoRow

                        CellDivider(inset: 16)

                        HStack {
                            Text("日期")
                                .font(Theme.font(17))
                                .foregroundColor(Theme.label)
                            Spacer()
                            DatePicker("", selection: $date, displayedComponents: [.date])
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .accentColor(Theme.blue)
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 54)

                        CellDivider(inset: 16)

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("重复")
                                    .font(Theme.font(17))
                                    .foregroundColor(Theme.label)
                                Spacer()
                                if repeatMode != .none {
                                    Text("自动识别")
                                        .font(Theme.font(11, .medium))
                                        .foregroundColor(Theme.label3)
                                }
                            }
                            SegmentedControl(items: AnniversaryRepeat.allCases.map { $0.label },
                                             selection: repeatSelection)
                        }
                        .padding(16)

                        if repeatMode != .none {
                            CellDivider(inset: 16)

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("到时提醒")
                                        .font(Theme.font(17))
                                        .foregroundColor(Theme.label)
                                    Text("当天早上 9:00 通知")
                                        .font(Theme.font(12))
                                        .foregroundColor(Theme.label2)
                                }
                                Spacer()
                                Toggle("", isOn: $remind)
                                    .labelsHidden()
                                    .toggleStyle(SwitchToggleStyle(tint: Theme.blue))
                            }
                            .padding(.horizontal, 16)
                            .frame(minHeight: 60)
                        }
                    }

                    GFCaption(text: "会根据名称自动识别周年 / 每月 / 每周（比如「结婚纪念日」「房租」「周会」），识别后也可以手动修改。选过去的日期显示已经多久，选未来的日期显示倒计时。")
                        .padding(.leading, 6)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
            }
        }
        .sheet(isPresented: $showPicker) {
            PhotoPicker { image in
                pickedImage = image
                removeImage = false
                showPicker = false
            }
        }
        .onChange(of: title) { value in
            guard !manualRepeat else { return }
            let detected = Anniversary.detectRepeat(for: value)
            if detected != .none {
                withAnimation(.easeOut(duration: 0.2)) {
                    repeatMode = detected
                }
            }
        }
    }

    // MARK: - 封面图

    private var currentImage: UIImage? {
        if let pickedImage = pickedImage { return pickedImage }
        return removeImage ? nil : existingImage
    }

    private var photoRow: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.fill)
                    .frame(width: 52, height: 52)

                if let image = currentImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Theme.blue)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("封面图片")
                    .font(Theme.font(17))
                    .foregroundColor(Theme.label)
                Text(currentImage == nil ? "选一张照片显示在卡片上" : "轻点更换封面")
                    .font(Theme.font(12))
                    .foregroundColor(Theme.label2)
            }

            Spacer(minLength: 0)

            if currentImage != nil {
                Button(action: {
                    Haptics.tap()
                    pickedImage = nil
                    removeImage = true
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.label3)
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.label3)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 68)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.tap()
            showPicker = true
        }
    }

    private var repeatSelection: Binding<Int> {
        Binding(
            get: {
                AnniversaryRepeat.allCases.firstIndex(of: repeatMode) ?? 0
            },
            set: { index in
                manualRepeat = true
                repeatMode = AnniversaryRepeat.allCases[index]
            }
        )
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        guard canSave else { return }
        var item = existing ?? Anniversary(title: "", date: date)
        item.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        item.date = date
        item.repeatMode = repeatMode
        item.remind = remind

        if let image = pickedImage, let name = AnniversaryImageStore.save(image) {
            item.imageFile = name
        } else if removeImage {
            item.imageFile = nil
        }

        Haptics.success()
        onSave(item)
    }
}

// MARK: - 系统相册选图（PHPicker，不申请相册权限）

struct PhotoPicker: UIViewControllerRepresentable {
    var onPick: (UIImage) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let controller = PHPickerViewController(configuration: config)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (UIImage) -> Void

        init(onPick: @escaping (UIImage) -> Void) {
            self.onPick = onPick
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }

            provider.loadObject(ofClass: UIImage.self) { object, _ in
                guard let image = object as? UIImage else { return }
                DispatchQueue.main.async {
                    self.onPick(image)
                }
            }
        }
    }
}

private struct SheetGrip: View {
    var body: some View {
        Capsule()
            .fill(Theme.label3)
            .frame(width: 38, height: 5)
            .padding(.top, 8)
            .padding(.bottom, 12)
    }
}
