//
//  GeminiService.swift
//  Jom
//
//  Created by Vishwa Pandian on 3/29/25.
//

import Foundation
import Combine

class SocialAIService: ObservableObject {
    private let baseURL = "https://social-ai-backend-f6dmr6763q-uc.a.run.app/api/chat"
    @Published private(set) var sessionId: String?
    
    // Optionally inject userId if available
    var userId: String? = nil
    
    func sendMessage(_ message: String) -> AnyPublisher<String, Error> {
        var request = URLRequest(url: URL(string: baseURL)!)
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
            .map { $0.response }
            .eraseToAnyPublisher()
    }
}

struct SocialAIResponse: Decodable {
    let response: String
    let sessionId: String?
}
