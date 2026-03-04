# photo_deleter

一个基于 SwiftUI 的 iOS 相册清理应用（源码）。

## 功能
- 左滑删除（标记删除）
- 右滑跳过
- 撤回上一步操作
- 渐变背景 + 卡片式照片浏览 UI

## 代码位置
- `/home/runner/work/photo_deleter/photo_deleter/iOS/PhotoDeleter/PhotoDeleterApp.swift`
- `/home/runner/work/photo_deleter/photo_deleter/iOS/PhotoDeleter/ContentView.swift`
- `/home/runner/work/photo_deleter/photo_deleter/iOS/PhotoDeleter/PhotoCleanerViewModel.swift`

## 在 Xcode 中运行
1. 新建一个 iOS App（SwiftUI）工程。
2. 将 `iOS/PhotoDeleter/` 下的 Swift 文件加入工程。
3. 在工程 `Info.plist` 中添加 `NSPhotoLibraryUsageDescription`。
4. 真机或模拟器运行后，授权访问相册即可使用。
