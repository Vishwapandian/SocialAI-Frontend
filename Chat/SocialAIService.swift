import Foundation
import Combine
import FirebaseAuth

class SocialAIService: ObservableObject {
    private let baseChatURL = "https://social-ai-backend-f6dmr6763q-uc.a.run.app/api/chat"
    private let endChatURL  = "https://social-ai-backend-f6dmr6763q-uc.a.run.app/api/end-chat"
    private let emotionsURL = "https://social-ai-backend-f6dmr6763q-uc.a.run.app/api/emotions"

    // Persist the current session ID across instances using UserDefaults
    private static var storedSessionId: String? {
        get { UserDefaults.standard.string(forKey: "SocialAIService.sessionId") }
        set { UserDefaults.standard.set(newValue, forKey: "SocialAIService.sessionId") }
    }

    // Published so UI can react if needed. Syncs to the static store.
    @Published private(set) var sessionId: String? {
        didSet {
            print("[SocialAIService] Updated sessionId -> \(sessionId ?? "nil")")
            SocialAIService.storedSessionId = sessionId
        }
    }

    // Optionally inject userId if available
    var userId: String? = nil

    // MARK: - Init
    init() {
        // Pull any stored session on startup
        self.sessionId = SocialAIService.storedSessionId
        print("[SocialAIService] init – recovered sessionId: \(sessionId ?? "nil")")
    }

    // MARK: - Send Message
    func sendMessage(_ message: String) -> AnyPublisher<SocialAIResponse, Error> {
        print("[SocialAIService] sendMessage -> \(message)")

        var request = URLRequest(url: URL(string: baseChatURL)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["message": message]
        if let sessionId = sessionId {
            body["sessionId"] = sessionId
        }
        if let userId = userId {
            body["userId"] = userId
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw NSError(domain: "SocialAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
                return data
            }
            .decode(type: SocialAIResponse.self, decoder: JSONDecoder())
            .handleEvents(receiveOutput: { [weak self] response in
                self?.sessionId = response.sessionId
            })
            .map { $0 }
            .eraseToAnyPublisher()
    }

    // MARK: - Fetch Initial Emotions
    func fetchInitialEmotions(userId: String) -> AnyPublisher<EmotionDataResponse, Error> {
        print("[SocialAIService] fetchInitialEmotions for userId -> \(userId)")

        guard let url = URL(string: emotionsURL) else {
            return Fail(error: NSError(domain: "SocialAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid emotions URL"])).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["userId": userId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error fetching emotions"
                    print("[SocialAIService] fetchInitialEmotions error: \(errorMessage), code: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                    throw NSError(domain: "SocialAIService", code: (response as? HTTPURLResponse)?.statusCode ?? 0, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
                return data
            }
            .decode(type: EmotionDataResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }

    // MARK: - End Chat
    /// Call this when the app goes to background / quits so the backend can persist memory & analytics.
    func endChat(surveyData: [String: Any]? = nil) {
        // Resolve latest session & user IDs
        let currentSession = sessionId ?? SocialAIService.storedSessionId
        let currentUserId  = userId ?? Auth.auth().currentUser?.uid

        guard let sess = currentSession, let uid = currentUserId else {
            print("[SocialAIService] endChat – missing sessionId or userId (session: \(String(describing: currentSession)), userId: \(String(describing: currentUserId)))")
            return
        }

        print("[SocialAIService] endChat -> sessionId: \(sess), userId: \(uid)")

        var request = URLRequest(url: URL(string: endChatURL)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var requestBody: [String: Any] = [
            "sessionId": sess,
            "userId": uid
        ]
        
        // Include survey data if provided
        if let surveyData = surveyData {
            requestBody["surveyData"] = surveyData
        }
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[SocialAIService] endChat network error: \(error.localizedDescription)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("[SocialAIService] endChat – invalid response object")
                return
            }

            if let data = data {
                do {
                    let responseJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    let success = responseJSON?["success"] as? Bool ?? false
                    let memorySaved = responseJSON?["memory_saved"] as? Bool ?? false
                    let trackingSaved = responseJSON?["tracking_saved"] as? Bool ?? false
                    
                    print("[SocialAIService] endChat response – status: \(httpResponse.statusCode), success: \(success), memory_saved: \(memorySaved), tracking_saved: \(trackingSaved)")
                    
                    if let updatedMemory = responseJSON?["updated_memory"] {
                        print("[SocialAIService] endChat updated memory: \(updatedMemory)")
                    }
                } catch {
                    let bodyString = String(data: data, encoding: .utf8) ?? "<no body>"
                    print("[SocialAIService] endChat – server status: \(httpResponse.statusCode), body: \(bodyString)")
                }
            } else {
                print("[SocialAIService] endChat – server status: \(httpResponse.statusCode), no response data")
            }
        }.resume()
    }
}

struct SocialAIResponse: Decodable {
    let response: String
    let sessionId: String?
    let emotions: [String: Int]?
}

// Struct for /api/emotions endpoint response
struct EmotionDataResponse: Decodable {
    let emotions: [String: Int]
    let userId: String
}

