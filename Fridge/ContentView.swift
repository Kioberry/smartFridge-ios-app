import SwiftUI
import Combine
import UserNotifications

// MARK: - 1. Data Models (数据模型)
// 用于定义食物、隔层等核心数据结构

struct FoodItem: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var expirationDate: Date?
    var quantity: Int = 1

    // 用于计算过期状态
    var daysUntilExpiration: Int? {
        guard let expirationDate = expirationDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day
    }
}

struct Shelf: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var items: [FoodItem]
}

// MARK: - 2. App State (全局应用状态)
// 使用 ObservableObject 在整个 App 中共享和同步数据

@MainActor
class AppState: ObservableObject {
    @Published var shelves: [Shelf] = [
        Shelf(name: "上层", items: [FoodItem(name: "牛奶", expirationDate: Date().addingTimeInterval(5 * 86400))]),
        Shelf(name: "中层", items: [FoodItem(name: "鸡蛋", expirationDate: Date().addingTimeInterval(15 * 86400)), FoodItem(name: "奶酪", expirationDate: Date().addingTimeInterval(20 * 86400))]),
        Shelf(name: "下层/保鲜抽屉", items: [FoodItem(name: "生菜", expirationDate: Date().addingTimeInterval(2 * 86400)), FoodItem(name: "西红柿", expirationDate: Date().addingTimeInterval(6 * 86400))])
    ]
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // 计算属性，方便获取所有食物
    var allFoodItems: [FoodItem] {
        shelves.flatMap { $0.items }
    }
}


// MARK: - 3. AI Service (AI 服务)
// 负责与后端 AI API 进行通信

class GeminiService {
    // 通过 Secrets helper 安全地加载 API 密钥
    private let apiKey = Secrets.geminiApiKey

    private let apiUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-05-20:generateContent"

    // a. 分析冰箱图片
    func analyzeFridgeImage(imageData: Data, shelvesConfig: [String]) async throws -> [Shelf] {
        let base64Image = imageData.base64EncodedString()
        
        let shelfNames = shelvesConfig.joined(separator: ", ")
        let prompt = """
        Analyze this image of a refrigerator. The fridge is divided into these shelves: \(shelfNames).
        Identify all food items on each shelf.
        Return the result in a strict JSON format like this:
        [
          {
            "shelfName": "Shelf Name",
            "items": ["Food Item 1", "Food Item 2"]
          }
        ]
        If a shelf is empty, return an empty "items" array. If you cannot identify anything, return an empty array.
        """

        let payload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt],
                        [
                            "inlineData": [
                                "mimeType": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "responseMimeType": "application/json"
            ]
        ]
        
        // 解析返回的JSON并更新App状态
        let responseData = try await performRequest(payload: payload)
        
        // 解析返回的JSON字符串
        guard let responseString = String(data: responseData, encoding: .utf8),
              let jsonString = extractJsonString(from: responseString),
              let jsonData = jsonString.data(using: .utf8) else {
            throw URLError(.cannotParseResponse, userInfo: [NSLocalizedDescriptionKey: "Could not extract or parse JSON from API response."])
        }

        let decodedShelves = try JSONDecoder().decode([DecodableShelf].self, from: jsonData)

        // 将解码的数据结构转换为我们的应用模型
        let shelves = decodedShelves.map { decodableShelf -> Shelf in
            let foodItems = decodableShelf.items.map { FoodItem(name: $0) }
            // 确保返回的隔层名称与我们发送的配置匹配
            let matchedName = shelvesConfig.first { $0 == decodableShelf.shelfName } ?? decodableShelf.shelfName
            return Shelf(name: matchedName, items: foodItems)
        }
        
        return shelves
    }

    // b. 获取食物的过期日期
    func getExpirationDates(for items: [String]) async throws -> [FoodItem] {
        guard !items.isEmpty else { return [] }
        let prompt = """
        Estimate a reasonable expiration date for the following food items based on common shelf life. Today's date is \(Date().formatted(date: .long, time: .omitted)).
        Food list: \(items.joined(separator: ", "))
        Return the result in a strict JSON format like this:
        [
          {
            "name": "Food Name",
            "expiresInDays": 7
          }
        ]
        """
        
        let payload: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["responseMimeType": "application/json"]
        ]
        
        let responseData = try await performRequest(payload: payload)
        
        guard let responseString = String(data: responseData, encoding: .utf8),
              let jsonString = extractJsonString(from: responseString),
              let jsonData = jsonString.data(using: .utf8) else {
            throw URLError(.cannotParseResponse, userInfo: [NSLocalizedDescriptionKey: "Could not extract or parse JSON from expiration date API response."])
        }
        
        let decodedItems = try JSONDecoder().decode([DecodableFoodExpiration].self, from: jsonData)
        
        let foodItems = decodedItems.map { decodedItem -> FoodItem in
            let expirationDate = Calendar.current.date(byAdding: .day, value: decodedItem.expiresInDays, to: Date())
            return FoodItem(name: decodedItem.name, expirationDate: expirationDate)
        }
        
        return foodItems
    }
    
    // c. 分析菜谱和所需食材
    func getRecipeIngredients(for dish: String, currentInventory: [String]) async throws -> (required: [String], missing: [String]) {
        let prompt = """
        I want to cook: "\(dish)".
        Please list all the main ingredients needed for this dish.
        This is my current inventory of ingredients: \(currentInventory.joined(separator: ", ")).
        Analyze which ingredients I am missing.
        Return the result in a strict JSON format like this:
        {
          "required": ["Ingredient A", "Ingredient B", "Ingredient C"],
          "missing": ["Ingredient B"]
        }
        """
        
        let payload: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["responseMimeType": "application/json"]
        ]
        
        let responseData = try await performRequest(payload: payload)

        guard let responseString = String(data: responseData, encoding: .utf8),
              let jsonString = extractJsonString(from: responseString),
              let jsonData = jsonString.data(using: .utf8) else {
            throw URLError(.cannotParseResponse, userInfo: [NSLocalizedDescriptionKey: "Could not extract or parse JSON from recipe API response."])
        }

        let decodedRecipe = try JSONDecoder().decode(DecodableRecipe.self, from: jsonData)
        return (decodedRecipe.required, decodedRecipe.missing)
    }

    // 通用网络请求函数
    private func performRequest(payload: [String: Any]) async throws -> Data {
        guard !apiKey.isEmpty else {
            throw URLError(.userAuthenticationRequired, userInfo: [NSLocalizedDescriptionKey: "API Key is missing. Please set it in GeminiService.swift."])
        }
        
        guard let url = URL(string: "\(apiUrl)?key=\(apiKey)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No response body"
            print("Server Error: \(errorBody)")
            throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "Server returned an error. Check console for details."])
        }
        
        // 直接返回原始数据，让调用方处理
        return data
    }

    // 从API返回的文本中提取JSON字符串
    private func extractJsonString(from text: String) -> String? {
        // Gemini API有时会返回 ```json ... ``` 格式的字符串
        if let range = text.range(of: "```json\n") {
            let startIndex = range.upperBound
            if let endIndex = text.range(of: "\n```", range: startIndex..<text.endIndex) {
                return String(text[startIndex..<endIndex.lowerBound])
            }
        }
        // 如果没有```标记，则假定整个字符串是JSON
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // 用于解码的辅助结构体
    private struct DecodableShelf: Codable {
        let shelfName: String
        let items: [String]
    }
    
    private struct DecodableFoodExpiration: Codable {
        let name: String
        let expiresInDays: Int
    }
    
    private struct DecodableRecipe: Codable {
        let required: [String]
        let missing: [String]
    }
}


// MARK: - 4. Main Tabbed View (主视图)

struct ContentView: View {
    @StateObject private var appState = AppState()
    private let geminiService = GeminiService()

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }
            
            InventoryView()
                .tabItem {
                    Label("库存", systemImage: "list.bullet.rectangle.portrait.fill")
                }

            MealsView()
                .tabItem {
                    Label("餐食", systemImage: "fork.knife.circle.fill")
                }

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
        }
        .environmentObject(appState)
        .environment(\.geminiService, geminiService)
        .overlay {
            if appState.isLoading {
                LoadingView()
            }
        }
        .alert(item: $appState.errorMessage) { message in
            Alert(title: Text("发生错误"), message: Text(message), dismissButton: .default(Text("好的")))
        }
    }
}

// MARK: - 5. Feature Views (四大功能模块)

// MARK: 5.1 Home View (首页)
struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.geminiService) private var geminiService
    
    @State private var showingImagePicker = false
    @State private var inputImage: UIImage?
    @State private var sourceType: UIImagePickerController.SourceType = .camera

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let image = inputImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .shadow(radius: 5)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.secondarySystemBackground))
                            .frame(height: 250)
                        
                        Text("请拍照或从相册选择一张冰箱照片")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)
                }

                HStack(spacing: 20) {
                    Button {
                        sourceType = .camera
                        showingImagePicker = true
                    } label: {
                        Label("拍照", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        sourceType = .photoLibrary
                        showingImagePicker = true
                    } label: {
                        Label("选择照片", systemImage: "photo.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                
                Button(action: analyzeImage) {
                    Label("开始分析冰箱", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(inputImage == nil || appState.isLoading)
                
                Divider()
                
                List {
                    ForEach(appState.shelves) { shelf in
                        Section(header: Text(shelf.name).font(.headline)) {
                            if shelf.items.isEmpty {
                                Text("这个隔层是空的").foregroundColor(.gray)
                            } else {
                                ForEach(shelf.items) { item in
                                    Text(item.name)
                                }
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("智能冰箱")
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $inputImage, sourceType: sourceType)
            }
        }
    }
    
    private func analyzeImage() {
        guard let inputImage = inputImage, let imageData = inputImage.jpegData(compressionQuality: 0.8) else {
            appState.errorMessage = "没有有效的图片。"
            return
        }
        
        appState.isLoading = true
        appState.errorMessage = nil
        
        Task {
            do {
                let shelfNames = appState.shelves.map { $0.name }
                var identifiedShelves = try await geminiService.analyzeFridgeImage(imageData: imageData, shelvesConfig: shelfNames)
                
                // 分析完成后，获取所有新识别食物的过期日期
                let allNewItems = identifiedShelves.flatMap { $0.items.map { $0.name } }
                if !allNewItems.isEmpty {
                    let itemsWithDates = try await geminiService.getExpirationDates(for: allNewItems)
                    
                    // 将带日期的物品更新回 identifiedShelves
                    for i in 0..<identifiedShelves.count {
                        for j in 0..<identifiedShelves[i].items.count {
                            let currentItemName = identifiedShelves[i].items[j].name
                            if let datedItem = itemsWithDates.first(where: { $0.name == currentItemName }) {
                                identifiedShelves[i].items[j] = datedItem
                            }
                        }
                    }
                }
                
                // 在主线程上更新状态
                await MainActor.run {
                    appState.shelves = identifiedShelves
                    appState.isLoading = false
                }
            } catch {
                await MainActor.run {
                    appState.errorMessage = "分析失败: \(error.localizedDescription)"
                    appState.isLoading = false
                }
            }
        }
    }
}

// MARK: 5.2 Inventory View (库存)
struct InventoryView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationView {
            List {
                ForEach(appState.allFoodItems) { item in
                    HStack {
                        Text(item.name)
                        Spacer()
                        if let days = item.daysUntilExpiration {
                            Text(days > 0 ? "还剩 \(days) 天" : (days == 0 ? "今天过期" : "已过期"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(expirationColor(for: days))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(expirationColor(for: days).opacity(0.15))
                                .cornerRadius(8)
                        } else {
                            Text("日期未知")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("库存清单")
            .onAppear(perform: scheduleNotifications)
        }
    }
    
    private func expirationColor(for days: Int) -> Color {
        if days < 0 {
            return .red
        } else if days <= 3 {
            return .orange
        } else {
            return .green
        }
    }
    
    // 提醒功能
    private func scheduleNotifications() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("请求通知权限失败: \(error)")
                return
            }
            if granted {
                print("通知权限已获取")
                center.removeAllPendingNotificationRequests() // 清除旧的提醒
                
                for item in appState.allFoodItems {
                    guard let days = item.daysUntilExpiration, days >= 0, days <= 3 else { continue }
                    
                    let content = UNMutableNotificationContent()
                    content.title = "冰箱物品即将过期！"
                    content.body = "\(item.name) 将在 \(days) 天后过期，请尽快食用！"
                    content.sound = .default
                    
                    // 每天早上9点提醒
                    var dateComponents = DateComponents()
                    dateComponents.hour = 9
                    dateComponents.minute = 0
                    
                    // 创建一个从明天开始的触发器
                    guard let triggerDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()),
                          let triggerComponents = Optional(Calendar.current.dateComponents([.year, .month, .day], from: triggerDate)) else { continue }
                    
                    var finalComponents = triggerComponents
                    finalComponents.hour = 9
                    finalComponents.minute = 0
                    
                    let trigger = UNCalendarNotificationTrigger(dateMatching: finalComponents, repeats: false)
                    let request = UNNotificationRequest(identifier: item.id.uuidString, content: content, trigger: trigger)
                    
                    center.add(request) { error in
                        if let error = error {
                            print("添加通知失败: \(error)")
                        } else {
                            print("已为 '\(item.name)' 设置提醒。")
                        }
                    }
                }
            }
        }
    }
}

// MARK: 5.3 Meals View (餐食)
struct MealsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.geminiService) private var geminiService
    
    @State private var dishName: String = ""
    @State private var requiredIngredients: [String] = []
    @State private var missingIngredients: [String] = []
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("输入想做的菜，比如“西红柿炒蛋”", text: $dishName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("分析", action: findIngredients)
                        .buttonStyle(.borderedProminent)
                        .disabled(dishName.isEmpty || appState.isLoading)
                }
                .padding()
                
                if appState.isLoading && requiredIngredients.isEmpty {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
                    List {
                        Section(header: Text("所需食材 (\(requiredIngredients.count))")) {
                            ForEach(requiredIngredients, id: \.self) { ingredient in
                                HStack {
                                    Text(ingredient)
                                    Spacer()
                                    if missingIngredients.contains(ingredient) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                    } else {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                        }
                        
                        Section(header: Text("冰箱里缺少的食材 (\(missingIngredients.count))")) {
                            ForEach(missingIngredients, id: \.self) { ingredient in
                                Text(ingredient)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("智能餐食助手")
        }
    }
    
    private func findIngredients() {
        guard !dishName.isEmpty else { return }
        appState.isLoading = true
        appState.errorMessage = nil
        
        let currentItems = appState.allFoodItems.map { $0.name }
        
        Task {
            do {
                let result = try await geminiService.getRecipeIngredients(for: dishName, currentInventory: currentItems)
                await MainActor.run {
                    self.requiredIngredients = result.required
                    self.missingIngredients = result.missing
                    appState.isLoading = false
                }
            } catch {
                await MainActor.run {
                    appState.errorMessage = "分析菜谱失败: \(error.localizedDescription)"
                    appState.isLoading = false
                }
            }
        }
    }
}

// MARK: 5.4 Settings View (设置)
struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("冰箱隔层管理")) {
                    ForEach($appState.shelves) { $shelf in
                        TextField("隔层名称", text: $shelf.name)
                    }
                    .onDelete(perform: deleteShelf)
                    
                    Button(action: addShelf) {
                        Label("添加新隔层", systemImage: "plus.circle.fill")
                    }
                }
                
                Section(header: Text("关于")) {
                    HStack {
                        Text("App 名称")
                        Spacer()
                        Text("智能冰箱整理")
                            .foregroundColor(.secondary)
                    }
                     HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
            .toolbar {
                EditButton()
            }
        }
    }
    
    private func addShelf() {
        withAnimation {
            let newShelfName = "新隔层 \(appState.shelves.count + 1)"
            appState.shelves.append(Shelf(name: newShelfName, items: []))
        }
    }
    
    private func deleteShelf(at offsets: IndexSet) {
        appState.shelves.remove(atOffsets: offsets)
    }
}


// MARK: - 6. Helper Views and Extensions (辅助视图和扩展)

// 用于安全加载 API 密钥的辅助工具
struct Secrets {
    private static func getSecrets() -> [String: Any]? {
        // 1. 找到 Secrets.plist 文件的路径
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist") else {
            print("错误: 找不到 Secrets.plist 文件。请确保已将其添加到项目中。")
            return nil
        }
        // 2. 加载文件内容
        guard let xml = FileManager.default.contents(atPath: path) else {
            print("错误: 无法加载 Secrets.plist 文件。")
            return nil
        }
        // 3. 将文件内容解析为字典
        return (try? PropertyListSerialization.propertyList(from: xml, options: .mutableContainersAndLeaves, format: nil)) as? [String: Any]
    }

    // 提供一个简单的计算属性来获取密钥
    static var geminiApiKey: String {
        guard let secrets = getSecrets(), let key = secrets["GeminiAPIKey"] as? String else {
            // 如果找不到密钥，App 将会崩溃并提示明确的错误信息，这有助于开发者快速定位问题。
            fatalError("错误: 无法在 Secrets.plist 中找到 'GeminiAPIKey'。请检查您的配置文件。")
        }
        // 确保密钥不是空的
        guard !key.isEmpty else {
            fatalError("错误: 'GeminiAPIKey' 的值为空。请在 Secrets.plist 中设置您的密钥。")
        }
        return key
    }
}


// 用于显示加载动画的视图
struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.4).edgesIgnoringSafeArea(.all)
            VStack {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                Text("请稍候，AI正在分析...")
                    .foregroundColor(.white)
                    .padding(.top, 8)
            }
            .padding(20)
            .background(Color.black.opacity(0.7))
            .cornerRadius(15)
        }
    }
}

// 用于在 SwiftUI 中使用 UIImagePickerController
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType
    @Environment(\.presentationMode) private var presentationMode

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// 用于在环境中传递 AI 服务实例
private struct GeminiServiceKey: EnvironmentKey {
    static let defaultValue: GeminiService = GeminiService()
}

extension EnvironmentValues {
    var geminiService: GeminiService {
        get { self[GeminiServiceKey.self] }
        set { self[GeminiServiceKey.self] = newValue }
    }
}

// 用于Alert的扩展
extension String: Identifiable {
    public var id: String { self }
}

// MARK: - App Entry Point
@main
struct SmartFridgeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

