//
//  GeminiService.swift
//  Jom
//
//  Created by Vishwa Pandian on 3/29/25.
//

import Foundation
import Combine

class GeminiService: ObservableObject {
    private let apiKey = "AIzaSyAIxbOXF0j9a6WvDzW8nGThUJ-A9yyrZsE"
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent"
    
    // Knowledge file contents
    private var knowledgeContent: String {
        // Read knowledge.txt from documents directory
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent("knowledge.txt")
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                return try String(contentsOf: fileURL, encoding: .utf8)
            } catch {
                print("Error reading knowledge.txt from documents: \(error.localizedDescription)")
            }
        }
        
        // Fallback to bundle if not found in documents
        if let path = Bundle.main.path(forResource: "knowledge", ofType: "txt"),
           let content = try? String(contentsOfFile: path, encoding: .utf8) {
            return content
        }
        
        return ""
    }
    
    // Default system prompt for journaling
    private let defaultSystemPrompt = """
    Your name is Jom. You are an AI powered journal. Your main purpose is to gather information about the user's day (what they did, how they felt, reflections, etc... normal journal stuff). Speak in a casual tone. Be consise. Don't be afraid to use slang or imperfect grammer.
    """
    
    init() {
        // No need to read knowledge.txt in init since we now get it dynamically
    }
    
    func sendMessage(_ message: String, conversationHistory: [Message] = []) -> AnyPublisher<String, Error> {
        let fullSystemPrompt = defaultSystemPrompt + "\n\nuser knowledge: [\(knowledgeContent)]"
        return sendMessageWithSystemPrompt(message, conversationHistory: conversationHistory, systemPrompt: fullSystemPrompt)
    }
    
    func sendMessageWithSystemPrompt(_ message: String, conversationHistory: [Message] = [], systemPrompt: String) -> AnyPublisher<String, Error> {
        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            return Fail(error: makeError("Invalid URL")).eraseToAnyPublisher()
        }
        
        var request = makeRequest(url: url)
        
        let contents = buildContents(message: message, conversationHistory: conversationHistory)
        let requestBody = buildRequestBodyWithSystemPrompt(contents: contents, systemPrompt: systemPrompt)
        
        request.httpBody = requestBody
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap(handleResponse)
            .decode(type: GeminiResponse.self, decoder: JSONDecoder())
            .map(\.firstCandidateText)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Helpers
    
    private func makeRequest(url: URL) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        return req
    }
    
    private func handleResponse(data: Data, response: URLResponse) throws -> Data {
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw makeError(errorMessage)
        }
        return data
    }
    
    private func makeError(_ message: String) -> NSError {
        NSError(domain: "GeminiService", code: 0, userInfo: [NSLocalizedDescriptionKey: message])
    }
    
    private func buildRequestBodyWithSystemPrompt(contents: [[String: Any]], systemPrompt: String) -> Data {
        let requestBody: [String: Any] = [
            "system_instruction": [
                "parts": [
                    ["text": systemPrompt]
                ]
            ],
            "contents": contents,
            "generationConfig": [
                "temperature": 1,
                "topK": 40,
                "topP": 0.95,
                "maxOutputTokens": 1000
            ]
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: requestBody) else {
            return Data()
        }
        return data
    }
    
    private func buildContents(message: String, conversationHistory: [Message]) -> [[String: Any]] {
        var contents: [[String: Any]] = conversationHistory.map {
            [
                "role": $0.isFromUser ? "user" : "model",
                "parts": [["text": $0.content]]
            ]
        }
        
        // Add current message
        contents.append([
            "role": "user",
            "parts": [["text": message]]
        ])
        
        return contents
    }
}

// MARK: - GeminiResponse + convenience
struct GeminiResponse: Decodable {
    let candidates: [Candidate]?
    
    var firstCandidateText: String {
        candidates?.first?.content.parts.first?.text ?? "Sorry, I couldn't generate a response."
    }
    
    struct Candidate: Decodable {
        let content: Content
    }
    
    struct Content: Decodable {
        let parts: [Part]
        let role: String
    }
    
    struct Part: Decodable {
        let text: String
    }
}
