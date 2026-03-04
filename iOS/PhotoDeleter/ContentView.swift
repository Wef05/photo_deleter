import SwiftUI
import Photos

struct ContentView: View {
    @StateObject private var viewModel = PhotoCleanerViewModel()
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.08, green: 0.09, blue: 0.16), Color(red: 0.16, green: 0.08, blue: 0.25)],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                header

                card
                    .frame(maxHeight: .infinity)

                controls
            }
            .padding()
        }
        .task { await viewModel.requestAccessAndLoad() }
        .alert("需要照片权限", isPresented: $viewModel.showAccessAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("请在系统设置中允许访问相册后重试。")
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("相册清理")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text(viewModel.progressText)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    private var card: some View {
        Group {
            if let image = viewModel.currentImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.white.opacity(0.12))
                    .overlay {
                        Text(viewModel.finished ? "已完成清理" : "正在加载照片...")
                            .foregroundStyle(.white)
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(alignment: .top) {
            swipeHint
                .padding(.top, 16)
        }
        .rotationEffect(.degrees(Double(dragOffset.width / 16)))
        .offset(dragOffset)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: dragOffset)
        .gesture(
            DragGesture()
                .onChanged {
                    guard viewModel.currentImage != nil, !viewModel.finished else { return }
                    dragOffset = $0.translation
                }
                .onEnded { value in
                    guard viewModel.currentImage != nil, !viewModel.finished else {
                        dragOffset = .zero
                        return
                    }
                    let threshold: CGFloat = 110
                    if value.translation.width < -threshold {
                        viewModel.markForDeletion()
                    } else if value.translation.width > threshold {
                        viewModel.skip()
                    }
                    dragOffset = .zero
                }
        )
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Button {
                viewModel.markForDeletion()
            } label: {
                Label("左滑删除", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(viewModel.finished || viewModel.currentImage == nil)

            Button {
                viewModel.skip()
            } label: {
                Label("右滑跳过", systemImage: "arrow.right.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(viewModel.finished || viewModel.currentImage == nil)
        }
        .font(.headline)
        .foregroundStyle(.white)
        .padding(.bottom, 8)
        .overlay(alignment: .topTrailing) {
            Button {
                viewModel.undo()
            } label: {
                Label("撤回", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(.bordered)
            .tint(.white)
            .disabled(!viewModel.canUndo)
            .offset(y: -52)
        }
    }

    private var swipeHint: some View {
        HStack {
            hintLabel(text: "删除", color: .red)
            Spacer()
            hintLabel(text: "跳过", color: .blue)
        }
        .padding(.horizontal, 16)
    }

    private func hintLabel(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.9), in: Capsule())
            .foregroundStyle(.white)
    }
}
