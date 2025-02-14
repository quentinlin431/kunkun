//
//  ContentView.swift
//  rule
//
//  Created by 林琨 on 2025/2/13.
//

import SwiftUI
import Foundation

// AI推荐结果模型
struct AIRecommendation: Codable, Identifiable, Equatable {
    var id = UUID()
    var movieName: String
    var reason: String
    var imageUrl: String?
    
    static func == (lhs: AIRecommendation, rhs: AIRecommendation) -> Bool {
        return lhs.movieName == rhs.movieName && lhs.reason == rhs.reason
    }
}

// DeepSeek API 响应模型
struct DeepSeekResponse: Codable {
    var choices: [Choice]
}

struct Choice: Codable {
    var message: Message
}

struct Message: Codable {
    var content: String
}

// AI服务类
class AIRecommendationService: ObservableObject {
    func getRecommendation(for mood: String, genre: String, region: String) async throws -> AIRecommendation {
        let apiKey = "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"
        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20 // 设置超时时间为20秒
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "model": "meta-llama/llama-3.3-70b-instruct:free",
            "messages": [
                [
                    "role": "user",
                    "content": """
                    请你根据我的心情：\(mood)、电影类型：\(genre) 和地区：\(region)，推荐一部电影。请严格按照以下格式生成推荐内容：
                    电影:《电影名称》(年份)(国家|类型)
                    推荐理由:
                    - 🎬 理由1: 具体的剧情介绍。
                    - 🎥 理由2: 具体的剧情介绍。
                    - 🍿 理由3: 具体的剧情介绍。
                    """
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Response Status Code: \(httpResponse.statusCode)")
            }
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("API Response: \(responseString)")
            }
            
            // 解析响应
            let deepSeekResponse = try JSONDecoder().decode(DeepSeekResponse.self, from: data)
            if let content = deepSeekResponse.choices.first?.message.content {
                // 假设返回的内容是推荐的电影名称和推荐理由
                let movieInfo = content.split(separator: "|")
                let movieName = movieInfo.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "未知电影"
                let reason = movieInfo.dropFirst().first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "暂无推荐理由"
                let imageUrl = movieInfo.dropFirst(2).first?.trimmingCharacters(in: .whitespacesAndNewlines)
                
                return AIRecommendation(movieName: movieName, reason: reason, imageUrl: imageUrl)
            }
        } catch {
            print("解析错误或请求超时: \(error.localizedDescription)")
            // 返回离线推荐
            return offlineRecommendation()
        }
        
        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法获取AI推荐内容"])
    }
    
    private func offlineRecommendation() -> AIRecommendation {
        // 提供离线推荐
        let offlineMovies = [
            ("肖申克的救赎", "一部关于希望和友谊的经典电影。"),
            ("阿甘正传", "讲述了一个简单而伟大的人生故事。"),
            ("盗梦空间", "一场关于梦境与现实的视觉盛宴。"),
            ("星际穿越", "探索宇宙与人类命运的科幻巨作。"),
            ("美丽人生", "在战争中寻找生活的美好。")
        ]
        
        let randomIndex = Int.random(in: 0..<offlineMovies.count)
        let selectedMovie = offlineMovies[randomIndex]
        
        return AIRecommendation(movieName: selectedMovie.0, reason: selectedMovie.1, imageUrl: nil)
    }
}

class FavoritesManager: ObservableObject {
    @Published var favorites: [AIRecommendation] = []
    
    func addToFavorites(_ recommendation: AIRecommendation) {
        if !favorites.contains(where: { $0.movieName == recommendation.movieName }) {
            favorites.append(recommendation)
        }
    }
    
    func removeFromFavorites(_ recommendation: AIRecommendation) {
        favorites.removeAll { $0 == recommendation }
    }
}

struct ContentView: View {
    @State private var moodText: String = ""
    @State private var selectedMood: String?
    @State private var navigateToGenreSelection = false
    @State private var selectedTab = 0
    @StateObject private var favoritesManager = FavoritesManager()
    let moods = [
        ("开心", "😊"),
        ("难过", "😢"),
        ("兴奋", "😄"),
        ("疲惫", "😩"),
        ("失恋", "💔"),
        ("焦虑", "😰"),
        ("愤怒", "😡"),
        ("无聊", "😐")
    ]
    
    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                VStack(spacing: 20) {
                    Spacer()
                    
                    Text("选择心情")
                        .font(.title)
                        .bold()
                    
                    // 用户输入心情
                    HStack {
                        TextField("描述一下你的心情...", text: $moodText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding()
                            .frame(height: 50)
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(radius: 5)
                        
                        Button(action: {
                            if !moodText.isEmpty {
                                selectedMood = moodText
                                navigateToGenreSelection = true
                            }
                        }) {
                            Text("提交")
                                .font(.headline)
                                .padding()
                                .frame(height: 50)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .shadow(radius: 5)
                        }
                    }
                    .padding(.horizontal)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 20) {
                        ForEach(moods, id: \.0) { mood in
                            Button(action: {
                                selectedMood = mood.0
                                navigateToGenreSelection = true
                            }) {
                                VStack {
                                    Text(mood.1)
                                        .font(.largeTitle)
                                    Text(mood.0)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                                .padding()
                                .frame(width: 80, height: 80)
                                .background(Color.white)
                                .cornerRadius(15)
                                .shadow(radius: 5)
                            }
                        }
                    }
                    .padding()
                    
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .navigationTitle("心情推荐")
                .navigationBarHidden(true)
                .navigationDestination(isPresented: $navigateToGenreSelection) {
                    if let mood = selectedMood {
                        GenreSelectionView(mood: mood, favoritesManager: favoritesManager)
                    }
                }
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                    Text("首页")
                }
                .tag(0)
                
                BoxOfficeView()
                    .tabItem {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                        Text("票房")
                    }
                    .tag(1)
                
                FavoritesView(favoritesManager: favoritesManager)
                    .tabItem {
                        Image(systemName: selectedTab == 2 ? "heart.fill" : "heart")
                        Text("收藏")
                    }
                    .tag(2)
            }
            .accentColor(Color.purple) // 选中的颜色
        }
    }
}

// 示例视图
struct BoxOfficeView: View {
    var body: some View {
        Text("票房页面")
    }
}

struct FavoritesView: View {
    @ObservedObject var favoritesManager: FavoritesManager
    
    var body: some View {
        ScrollView {
            if favoritesManager.favorites.isEmpty {
                Text("空空如也，快去探索新的电影吧！")
                    .font(.system(size: 18))
                    .foregroundColor(.gray)
                    .padding()
            } else {
                VStack(spacing: 15) {
                    ForEach(favoritesManager.favorites) { movie in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(movie.movieName)
                                    .font(.system(size: 20, weight: .medium))
                                Spacer()
                                Button(action: {
                                    favoritesManager.removeFromFavorites(movie)
                                }) {
                                    Text("删除")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                }
                            }
                            Text(movie.reason)
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 3)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("收藏夹")
    }
}

struct MoodLoadingView: View {
    @State private var loadingText = "AI 正在为您生成个性化推荐..."
    @State private var currentMessageIndex = 0
    let messages = [
        "正在分析您的心情...",
        "正在计算最佳推荐内容...",
        "即将完成！"
    ]
    
    var body: some View {
        VStack {
            // AI Processing Section
            VStack {
                Text("🐸")
                    .font(.system(size: 80))
                    .padding(.bottom, 10)
                    .animation(Animation.easeInOut(duration: 1).repeatForever(autoreverses: true))
                
                Text(loadingText)
                    .font(.headline)
                    .foregroundColor(.gray)
                    .padding(.top, 10)
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            .padding(.top, 50)
            
            // Suggested Location
            VStack(alignment: .leading, spacing: 10) {
                Text("探索 San Francisco")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                Text("San Francisco is known for its diverse and iconic food scene.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading, spacing: 5) {
                    Text("Places to visit")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("Golden Gate Bridge")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .padding(10)
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 3)
            }
            .padding(20)
            .background(Color.white.opacity(0.4))
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            .padding(.top, 30)
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                currentMessageIndex = (currentMessageIndex + 1) % messages.count
                loadingText = messages[currentMessageIndex]
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(gradient: Gradient(colors: [Color.purple, Color.blue]), startPoint: .top, endPoint: .bottom))
        .edgesIgnoringSafeArea(.all)
    }
}

struct GenreSelectionView: View {
    let mood: String
    @ObservedObject var favoritesManager: FavoritesManager
    let genres = [
        "随机", "细腻真实的生活", "夸张诙谐的", "浪漫感人的", "刺激冒险的",
        "科幻奇幻的", "悬疑惊悚的", "历史传记的", "动画梦幻的", "音乐剧",
        "纪录片", "战争片", "西部片"
    ]
    
    let regions = [
        "随机", "中国", "美国", "韩国", "日本", "欧洲", "其他"
    ]
    
    let emojis = ["🎬", "🎥", "🍿", "📽️", "🎞️", "📺", "🎭", "🎨", "🎻", "🎸", "🎹", "🥁"]
    
    @State private var selectedGenres: Set<String> = []
    @State private var selectedRegions: Set<String> = []
    @State private var navigateToRecommendation = false
    
    var body: some View {
        VStack(spacing: 25) {
            Text("选择电影类型和地区")
                .font(.system(size: 24, weight: .medium))
                .padding(.top)
            
            ScrollView {
                LazyVGrid(columns: [GridItem(), GridItem()], spacing: 20) {
                    ForEach(genres, id: \.self) { genre in
                        let randomEmoji = emojis.randomElement() ?? "🎬"
                        Button(action: {
                            if selectedGenres.contains(genre) {
                                selectedGenres.remove(genre)
                            } else {
                                selectedGenres.insert(genre)
                            }
                        }) {
                            VStack {
                                Text(randomEmoji)
                                    .font(.system(size: 24))
                                    .padding(.bottom, 5)
                                Text(genre)
                                    .foregroundColor(.primary)
                                    .font(.system(size: 16))
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: selectedGenres.contains(genre) ? [Color.blue.opacity(0.4), Color.blue.opacity(0.6)] : [Color.blue.opacity(0.1), Color.blue.opacity(0.05)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: .gray.opacity(0.3), radius: 5, x: 0, y: 3)
                            .scaleEffect(selectedGenres.contains(genre) ? 1.05 : 1.0)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedGenres.contains(genre) ? Color.blue : Color.clear, lineWidth: 2)
                            )
                        }
                        .animation(.spring(), value: selectedGenres)
                    }
                }
                .padding()
                
                Text("选择国家/地区")
                    .font(.system(size: 24, weight: .medium))
                    .padding(.top)
                
                LazyVGrid(columns: [GridItem(), GridItem()], spacing: 20) {
                    ForEach(regions, id: \.self) { region in
                        Button(action: {
                            if selectedRegions.contains(region) {
                                selectedRegions.remove(region)
                            } else {
                                selectedRegions.insert(region)
                            }
                        }) {
                            VStack {
                                Text(region)
                                    .foregroundColor(.primary)
                                    .font(.system(size: 16))
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: selectedRegions.contains(region) ? [Color.green.opacity(0.4), Color.green.opacity(0.6)] : [Color.green.opacity(0.1), Color.green.opacity(0.05)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: .gray.opacity(0.3), radius: 5, x: 0, y: 3)
                            .scaleEffect(selectedRegions.contains(region) ? 1.05 : 1.0)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedRegions.contains(region) ? Color.green : Color.clear, lineWidth: 2)
                            )
                        }
                        .animation(.spring(), value: selectedRegions)
                    }
                }
                .padding()
            }
            
            Button(action: {
                navigateToRecommendation = true
            }) {
                Text("确认选择")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                    .foregroundColor(.white)
                    .shadow(radius: 3)
                    .scaleEffect(1.05)
                    .font(.system(size: 18))
            }
            .padding(.top)
            .disabled(selectedGenres.isEmpty || selectedRegions.isEmpty)
            
            NavigationLink(
                destination: MoodDetailView(
                    mood: mood,
                    genre: selectedGenres.joined(separator: ", "),
                    region: selectedRegions.joined(separator: ", "),
                    favoritesManager: favoritesManager
                ),
                isActive: $navigateToRecommendation
            ) {
                EmptyView()
            }
        }
        .padding()
        .navigationTitle("选择电影类型和地区")
    }
}

struct MoodDetailView: View {
    let mood: String
    let genre: String
    let region: String
    @ObservedObject var favoritesManager: FavoritesManager
    @StateObject private var aiService = AIRecommendationService()
    @State private var aiRecommendation: AIRecommendation?
    @State private var isLoading = true
    @State private var error: Error?
    @State private var animateContent = false
    
    var body: some View {
        let animalEmojis = ["🐸"] // 使用小青蛙表情
        let randomEmoji = animalEmojis.randomElement() ?? "🐸"
        
        ScrollView {
            VStack(alignment: .center, spacing: 25) {
                Text("您现在的心情是：\(mood)")
                    .font(.system(size: 22, weight: .medium))
                    .padding(.top)
                
                if isLoading {
                    VStack {
                        Text(randomEmoji)
                            .font(.system(size: 100)) // 大小青蛙表情
                            .padding(.bottom, 20)
                        
                        Text("AI正在为您生成个性化推荐...")
                            .font(.system(size: 18, weight: .medium))
                            .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 3)
                    .padding()
                } else if let error = error {
                    Text("抱歉，获取推荐时出现错误：\(error.localizedDescription)")
                        .foregroundColor(.red)
                } else if let recommendation = aiRecommendation {
                    // 显示电影图片
                    if let imageUrl = recommendation.imageUrl, let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .cornerRadius(10)
                        } placeholder: {
                            ProgressView()
                        }
                    }
                    
                    // 电影推荐
                    VStack(alignment: .leading, spacing: 15) {
                        Text("为你推荐：")
                            .font(.system(size: 20, weight: .medium))
                        
                        HStack {
                            Image(systemName: "film")
                                .foregroundColor(.blue)
                            Text("电影名称: \(recommendation.movieName)")
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                        
                        HStack {
                            Image(systemName: "quote.bubble")
                                .foregroundColor(.green)
                            Text("推荐理由: \(recommendation.reason)")
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(10)
                        
                        HStack(spacing: 15) {
                            Button(action: {
                                favoritesManager.addToFavorites(recommendation)
                            }) {
                                Text("一键收藏")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange)
                                    .cornerRadius(12)
                                    .foregroundColor(.white)
                                    .shadow(radius: 3)
                            }
                            .scaleEffect(1.05)
                            .animation(.spring(), value: aiRecommendation)
                            
                            Button(action: {
                                Task {
                                    await fetchNewRecommendation()
                                }
                            }) {
                                Text("换一个")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.purple)
                                    .cornerRadius(12)
                                    .foregroundColor(.white)
                                    .shadow(radius: 3)
                            }
                            .scaleEffect(1.05)
                            .animation(.spring(), value: aiRecommendation)
                        }
                        .padding(.top)
                    }
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 40)
                }
            }
            .padding()
            .onAppear {
                Task {
                    await fetchNewRecommendation()
                }
            }
        }
    }
    
    private func fetchNewRecommendation() async {
        do {
            let recommendation = try await aiService.getRecommendation(for: mood, genre: genre, region: region)
            await MainActor.run {
                self.aiRecommendation = recommendation
                self.isLoading = false
                withAnimation(.easeOut(duration: 0.8)) {
                    self.animateContent = true
                }
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
