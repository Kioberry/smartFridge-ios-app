import SwiftUI
import SwiftData
import PhotosUI

struct AnalyzeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var shelves: [Shelf]
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var inputImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isLoading = false
    @State private var alertMessage: AlertMessage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 25) {
                    if let image = inputImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(16)
                            .shadow(radius: 5)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(UIColor.secondarySystemBackground))
                                .frame(height: 250)

                            VStack {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.largeTitle)
                                    .foregroundColor(BrandColors.secondaryText)
                                Text("选择一张冰箱照片开始")
                                    .foregroundColor(BrandColors.secondaryText)
                                    .padding(.top, 5)
                            }
                        }
                    }

                    HStack(spacing: 15) {
                        Button {
                            showingCamera = true
                        } label: {
                            Label("拍照", systemImage: "camera.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.gray.opacity(0.2))
                        .foregroundColor(BrandColors.primary)

                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label("从相册选择", systemImage: "photo.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.gray.opacity(0.2))
                        .foregroundColor(BrandColors.primary)
                    }

                    Button(action: analyzeImage) {
                        Text("开始分析")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(inputImage == nil || isLoading)
                }
                .padding()
            }
            .navigationTitle("冰箱分析")
            .fullScreenCover(isPresented: $showingCamera) {
                ImagePicker(image: $inputImage)
                    .ignoresSafeArea()
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        inputImage = uiImage
                    }
                }
            }
            .overlay {
                if isLoading { LoadingView() }
            }
            .alert(item: $alertMessage) { msg in
                Alert(title: Text("提示"), message: Text(msg.message), dismissButton: .default(Text("好的")))
            }
            .background(BrandColors.background)
        }
    }

    private func analyzeImage() {
        guard let inputImage,
              let resizedImage = ImageResizer.resize(image: inputImage, targetSize: CGSize(width: 800, height: 800)),
              let imageData = resizedImage.jpegData(compressionQuality: 0.8) else {
            alertMessage = AlertMessage(message: String(localized: "图片处理失败，请重试。"))
            return
        }

        guard let apiKey = Secrets.geminiApiKey else {
            alertMessage = AlertMessage(message: String(localized: "API密钥缺失，请在Secrets.plist中配置GeminiAPIKey。"))
            return
        }

        let shelfNames = shelves.isEmpty ? [
            String(localized: "上层"),
            String(localized: "中层"),
            String(localized: "下层")
        ] : shelves.map(\.name)
        let service = GeminiService(apiKey: apiKey)

        Task {
            isLoading = true
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    var parsedShelves = try await service.analyzeFridgeImage(imageData: imageData, shelvesConfig: shelfNames)
                    let allNames = parsedShelves.flatMap(\.itemNames)
                    if !allNames.isEmpty {
                        let dated = try await service.getExpirationDates(for: allNames)
                        for i in 0..<parsedShelves.count {
                            for j in 0..<parsedShelves[i].itemNames.count {
                                let name = parsedShelves[i].itemNames[j]
                                if let match = dated.first(where: { $0.name == name }) {
                                    parsedShelves[i].itemNames[j] = match.name
                                }
                            }
                        }
                        return (parsedShelves, dated)
                    }
                    return (parsedShelves, [] as [(name: String, expiresInDays: Int)])
                }.value

                // Clear existing data and replace
                for existing in shelves {
                    modelContext.delete(existing)
                }

                for shelfData in result.0 {
                    let shelf = Shelf(name: shelfData.shelfName)
                    modelContext.insert(shelf)
                    for itemName in shelfData.itemNames {
                        let expDays = result.1.first(where: { $0.name == itemName })?.expiresInDays
                        let expDate = expDays.flatMap { Calendar.current.date(byAdding: .day, value: $0, to: Date()) }
                        let item = FoodItem(name: itemName, expirationDate: expDate, shelf: shelf)
                        modelContext.insert(item)
                    }
                }
                try modelContext.save()

                isLoading = false
            } catch {
                alertMessage = AlertMessage(message: String(localized: "分析失败: \(error.localizedDescription)"))
                isLoading = false
            }
        }
    }
}
