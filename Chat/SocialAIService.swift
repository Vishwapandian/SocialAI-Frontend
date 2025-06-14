import Foundation
import Combine
import FirebaseAuth

class SocialAIService: ObservableObject {
    private let baseChatURL = "https://social-ai-backend-f6dmr6763q-uc.a.run.app/api/chat"
    private let endChatURL  = "https://social-ai-backend-f6dmr6763q-uc.a.run.app/api/end-chat"
    private let emotionsURL = "https://social-ai-backend-f6dmr6763q-uc.a.run.app/api/emotions"
    private let resetURL = "https://social-ai-backend-f6dmr6763q-uc.a.run.app/api/reset"
    
    // Configuration API URLs (memory-related URLs removed)
    private let configEmotionsURL = "https://social-ai-backend-f6dmr6763q-uc.a.run.app/api/config/emotions"
    private let configBaseEmotionsURL = "https://social-ai-backend-f6dmr6763q-uc.a.run.app/api/config/base-emotions"
    private let configSensitivityURL = "https://social-ai-backend-f6dmr6763q-uc.a.run.app/api/config/sensitivity"
    private let configCustomInstructionsURL = "https://social-ai-backend-f6dmr6763q-uc.a.run.app/api/config/custom-instructions"
    private let configAllURL = "https://social-ai-backend-f6dmr6763q-uc.a.run.app/api/config/all"

    // Personas API
    private let personasURL = "https://social-ai-backend-f6dmr6763q-uc.a.run.app/api/personas"

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

    // MARK: - Persona model

    struct Persona: Codable, Identifiable, Hashable {
        var id: String? // Firestore doc ID (optional on creation)
        var name: String
        var baseEmotions: [String: Int]
        var sensitivity: Int
        var customInstructions: String
    }

    // Simple success wrapper for delete/update etc.
    struct PersonaWrapperResponse: Decodable {
        let success: Bool?
        let persona: Persona?
        let personas: [Persona]?
    }

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

    // MARK: - Fetch Current Emotions (with homeostasis)
    func fetchCurrentEmotions(userId: String) -> AnyPublisher<EmotionDataResponse, Error> {
        print("[SocialAIService] fetchCurrentEmotions for userId -> \(userId), sessionId -> \(sessionId ?? "nil")")

        guard let url = URL(string: emotionsURL) else {
            return Fail(error: NSError(domain: "SocialAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid emotions URL"])).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["userId": userId]
        // Always include sessionId for homeostasis-aware emotion fetching
        if let sessionId = sessionId {
            body["sessionId"] = sessionId
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error fetching current emotions"
                    print("[SocialAIService] fetchCurrentEmotions error: \(errorMessage), code: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
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

    // MARK: - Reset User Data
    /// Resets both emotions and memory for a user
    func resetUserData(userId: String) -> AnyPublisher<ResetResponse, Error> {
        print("[SocialAIService] resetUserData for userId -> \(userId)")

        guard let url = URL(string: resetURL) else {
            return Fail(error: NSError(domain: "SocialAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid reset URL"])).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["userId": userId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error resetting data"
                    throw NSError(domain: "SocialAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
                
                if httpResponse.statusCode == 200 {
                    return data
                } else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Failed to reset user data"
                    print("[SocialAIService] resetUserData error: \(errorMessage), code: \(httpResponse.statusCode)")
                    throw NSError(domain: "SocialAIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
            }
            .decode(type: ResetResponse.self, decoder: JSONDecoder())
            .handleEvents(receiveOutput: { [weak self] response in
                if response.success {
                    // Clear the stored session ID since we're starting fresh
                    self?.sessionId = nil
                    print("[SocialAIService] Reset successful - cleared sessionId")
                }
            })
            .eraseToAnyPublisher()
    }
    
    // MARK: - Configuration Management
    
    // MARK: - Get All Configuration
    func getAllConfiguration(userId: String) -> AnyPublisher<ConfigurationResponse, Error> {
        print("[SocialAIService] getAllConfiguration for userId -> \(userId)")
        
        guard let url = URL(string: "\(configAllURL)?userId=\(userId)") else {
            return Fail(error: NSError(domain: "SocialAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid config URL"])).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error getting configuration"
                    throw NSError(domain: "SocialAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
                return data
            }
            .decode(type: ConfigurationResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    // MARK: - Current Emotions Management
    func getCurrentEmotions(userId: String) -> AnyPublisher<EmotionsResponse, Error> {
        print("[SocialAIService] getCurrentEmotions for userId -> \(userId)")
        
        guard let url = URL(string: "\(configEmotionsURL)?userId=\(userId)") else {
            return Fail(error: NSError(domain: "SocialAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid emotions URL"])).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error getting emotions"
                    throw NSError(domain: "SocialAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
                return data
            }
            .decode(type: EmotionsResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    func updateCurrentEmotions(userId: String, emotions: [String: Int]) -> AnyPublisher<SuccessResponse, Error> {
        print("[SocialAIService] updateCurrentEmotions for userId -> \(userId)")
        
        guard let url = URL(string: configEmotionsURL) else {
            return Fail(error: NSError(domain: "SocialAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid emotions URL"])).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["userId": userId, "emotions": emotions]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error updating emotions"
                    throw NSError(domain: "SocialAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
                return data
            }
            .decode(type: SuccessResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    // MARK: - Base Emotions Management
    func getBaseEmotions(userId: String) -> AnyPublisher<BaseEmotionsResponse, Error> {
        print("[SocialAIService] getBaseEmotions for userId -> \(userId)")
        
        guard let url = URL(string: "\(configBaseEmotionsURL)?userId=\(userId)") else {
            return Fail(error: NSError(domain: "SocialAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid base emotions URL"])).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error getting base emotions"
                    throw NSError(domain: "SocialAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
                return data
            }
            .decode(type: BaseEmotionsResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    func updateBaseEmotions(userId: String, baseEmotions: [String: Int]) -> AnyPublisher<SuccessResponse, Error> {
        print("[SocialAIService] updateBaseEmotions for userId -> \(userId)")
        
        guard let url = URL(string: configBaseEmotionsURL) else {
            return Fail(error: NSError(domain: "SocialAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid base emotions URL"])).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["userId": userId, "baseEmotions": baseEmotions]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error updating base emotions"
                    throw NSError(domain: "SocialAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
                return data
            }
            .decode(type: SuccessResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    // MARK: - Sensitivity Management
    func getSensitivity(userId: String) -> AnyPublisher<SensitivityResponse, Error> {
        print("[SocialAIService] getSensitivity for userId -> \(userId)")
        
        guard let url = URL(string: "\(configSensitivityURL)?userId=\(userId)") else {
            return Fail(error: NSError(domain: "SocialAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid sensitivity URL"])).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error getting sensitivity"
                    throw NSError(domain: "SocialAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
                return data
            }
            .decode(type: SensitivityResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    func updateSensitivity(userId: String, sensitivity: Int) -> AnyPublisher<SuccessResponse, Error> {
        print("[SocialAIService] updateSensitivity for userId -> \(userId)")
        
        guard let url = URL(string: configSensitivityURL) else {
            return Fail(error: NSError(domain: "SocialAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid sensitivity URL"])).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["userId": userId, "sensitivity": sensitivity]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error updating sensitivity"
                    throw NSError(domain: "SocialAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
                return data
            }
            .decode(type: SuccessResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    // MARK: - Custom Instructions Management
    func getCustomInstructions(userId: String) -> AnyPublisher<CustomInstructionsResponse, Error> {
        print("[SocialAIService] getCustomInstructions for userId -> \(userId)")
        
        guard let url = URL(string: "\(configCustomInstructionsURL)?userId=\(userId)") else {
            return Fail(error: NSError(domain: "SocialAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid custom instructions URL"])).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error getting custom instructions"
                    throw NSError(domain: "SocialAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
                return data
            }
            .decode(type: CustomInstructionsResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    func updateCustomInstructions(userId: String, customInstructions: String) -> AnyPublisher<SuccessResponse, Error> {
        print("[SocialAIService] updateCustomInstructions for userId -> \(userId)")
        
        guard let url = URL(string: configCustomInstructionsURL) else {
            return Fail(error: NSError(domain: "SocialAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid custom instructions URL"])).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["userId": userId, "customInstructions": customInstructions]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error updating custom instructions"
                    throw NSError(domain: "SocialAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
                return data
            }
            .decode(type: SuccessResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }

    // MARK: - Personas CRUD

    func fetchPersonas() -> AnyPublisher<[Persona], Error> {
        guard let uid = userId, let url = URL(string: "\(personasURL)?userId=\(uid)") else {
            return Fail(error: NSError(domain: "SocialAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid personas URL"])).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error fetching personas"
                    throw NSError(domain: "SocialAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
                return data
            }
            .decode(type: PersonaWrapperResponse.self, decoder: JSONDecoder())
            .map { $0.personas ?? [] }
            .eraseToAnyPublisher()
    }

    func createPersona(name: String = "New Persona") -> AnyPublisher<Persona, Error> {
        guard let uid = userId, let url = URL(string: personasURL) else {
            return Fail(error: NSError(domain: "SocialAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid personas URL"])).eraseToAnyPublisher()
        }

        // Minimal default persona
        let payload: [String: Any] = [
            "userId": uid,
            "name": name,
            "baseEmotions": [
                "Red": 5,
                "Yellow": 20,
                "Green": 30,
                "Blue": 40,
                "Purple": 5,
            ],
            "sensitivity": 35,
            "customInstructions": "N/A"
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error creating persona"
                    throw NSError(domain: "SocialAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
                return data
            }
            .decode(type: PersonaWrapperResponse.self, decoder: JSONDecoder())
            .tryMap { wrapper in
                guard let persona = wrapper.persona else {
                    throw NSError(domain: "SocialAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Persona not returned"])
                }
                return persona
            }
            .eraseToAnyPublisher()
    }

    func updatePersona(_ persona: Persona) -> AnyPublisher<Persona, Error> {
        guard let uid = userId, let id = persona.id, let url = URL(string: "\(personasURL)/\(id)?userId=\(uid)") else {
            return Fail(error: NSError(domain: "SocialAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid persona id"])).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(persona)

        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error updating persona"
                    throw NSError(domain: "SocialAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
                return data
            }
            .decode(type: PersonaWrapperResponse.self, decoder: JSONDecoder())
            .tryMap { wrapper in
                guard let persona = wrapper.persona else {
                    throw NSError(domain: "SocialAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Persona not returned"])
                }
                return persona
            }
            .eraseToAnyPublisher()
    }

    func deletePersona(personaId: String) -> AnyPublisher<Bool, Error> {
        guard let uid = userId, let url = URL(string: "\(personasURL)/\(personaId)?userId=\(uid)") else {
            return Fail(error: NSError(domain: "SocialAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid personas URL"])).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error deleting persona"
                    throw NSError(domain: "SocialAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
                if httpResponse.statusCode == 200 {
                    return true
                } else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Failed to delete persona"
                    throw NSError(domain: "SocialAIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
            }
            .eraseToAnyPublisher()
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

// Struct for /api/reset endpoint response
struct ResetResponse: Decodable {
    let success: Bool
    let message: String
    let emotions_deleted: Bool
    let memory_deleted: Bool
    let userId: String
}

// MARK: - Configuration Response Structs

// Struct for /api/config/all endpoint response
struct ConfigurationResponse: Decodable {
    let emotions: [String: Int]
    let baseEmotions: [String: Int]
    let sensitivity: Int
    let customInstructions: String
    let userId: String
}

// Struct for /api/config/emotions endpoint response
struct EmotionsResponse: Decodable {
    let emotions: [String: Int]
    let userId: String
}

// Struct for /api/config/base-emotions endpoint response  
struct BaseEmotionsResponse: Decodable {
    let baseEmotions: [String: Int]
    let userId: String
}

// Struct for /api/config/sensitivity endpoint response  
struct SensitivityResponse: Decodable {
    let sensitivity: Int
    let userId: String
}

// Struct for /api/config/custom-instructions endpoint response  
struct CustomInstructionsResponse: Decodable {
    let customInstructions: String
    let userId: String
}

// Generic success response for PUT operations
struct SuccessResponse: Decodable {
    let success: Bool
    let message: String
    let userId: String
}

