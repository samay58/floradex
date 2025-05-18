import Foundation
import UIKit // For UIImage for potential resizing/handling later

// UIImage extension for resizing
extension UIImage {
    enum ImageProcessing {
        static func resized(_ image: UIImage, maxSide: CGFloat) -> UIImage? {
            let scale = min(maxSide / image.size.width, maxSide / image.size.height)
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            defer { UIGraphicsEndImageContext() }
            
            image.draw(in: CGRect(origin: .zero, size: newSize))
            return UIGraphicsGetImageFromCurrentImageContext()
        }
    }
}

// Assuming APIClient and APIEndpoint are defined elsewhere (e.g., Networking/APIClient.swift)
// And Secrets.openAIApiKey is available

enum SpriteEndpoint: APIEndpoint {
    case generate(prompt: String, apiKey: String)

    var baseURL: URL { URL(string: "https://api.openai.com")! }
    var path: String { "/v1/images/generations" }
    var method: HTTPMethod { .post }
    
    var headers: [String: String]? {
        var baseHeaders = ["Content-Type": "application/json"]
        switch self {
        case .generate(_, let apiKey):
            baseHeaders["Authorization"] = "Bearer \(apiKey)"
        }
        return baseHeaders
    }

    var parameters: [String: Any]? {
        switch self {
        case .generate(let prompt, _):
            return [
                "model": "gpt-image-1",
                "prompt": prompt,
                "n": 1,
                "size": "auto",
                "quality": "low",
                "background": "transparent"
            ]
        }
    }
    // body will be handled by APIClient by serializing parameters
    var body: Data? { nil }

    // Sprite generation can take >8s; allow longer per-request timeout (e.g., 60s)
    var timeout: TimeInterval? { 300 }
}

final class SpriteService {
    static let shared = SpriteService()
    private init() {}

    enum SpriteError: Error {
        case missingKey
        case apiRequestFailed(Error)
        case badResponseFormat
        case noSpriteURLFound
        case imageDownloadFailed(Error)
        case imageProcessingFailed
    }

    // Response structure for the image generation API
    private struct OpenAIImageGenerationResponse: Decodable {
        struct Datum: Decodable {
            let url: URL? // URL for the generated image
            let b64_json: String? // Base64 encoded JSON data if requested
        }
        let created: Int
        let data: [Datum]
    }

    func generateSprite(forCommonName commonName: String, latinName: String) async throws -> Data {
        guard let apiKey = Secrets.openAIApiKey.nonEmpty else {
            throw SpriteError.missingKey
        }

        // Construct the prompt
        let prompt = "8-bit GameBoy-style sprite of the plant \(commonName) (\(latinName)). Use a limited retro palette, transparent background. Pixel art style."

        let endpoint = SpriteEndpoint.generate(prompt: prompt, apiKey: apiKey)

        do {
            let response: OpenAIImageGenerationResponse = try await APIClient.shared.request(endpoint: endpoint)
            
            guard let firstDatum = response.data.first else {
                throw SpriteError.noSpriteURLFound // Or badResponseFormat
            }

            // Prefer URL and download, but b64_json is an option if response_format is changed
            if let spriteUrlString = firstDatum.url?.absoluteString,
               let spriteUrl = URL(string: spriteUrlString) {
                
                // Download the image data
                let (imageData, _) = try await URLSession.shared.data(from: spriteUrl)
                
                // Process and resize the image (e.g., to 64x64 PNG)
                guard let image = UIImage(data: imageData),
                      let resizedImage = UIImage.ImageProcessing.resized(image, maxSide: 64),
                      let pngData = resizedImage.pngData() else {
                    throw SpriteError.imageProcessingFailed
                }
                return pngData
                
            } else if let b64Json = firstDatum.b64_json,
                      let decodedData = Data(base64Encoded: b64Json) {
                // Process and resize the image if b64_json is used
                guard let image = UIImage(data: decodedData),
                      let resizedImage = UIImage.ImageProcessing.resized(image, maxSide: 64),
                      let pngData = resizedImage.pngData() else {
                    throw SpriteError.imageProcessingFailed
                }
                return pngData
            } else {
                throw SpriteError.noSpriteURLFound
            }
        } catch let apiError as APIError {
            print("Sprite generation API request failed: \(apiError)")
            throw SpriteError.apiRequestFailed(apiError)
        } catch let spriteError as SpriteError {
            throw spriteError // Re-throw specific sprite errors
        } catch {
            print("An unexpected error occurred during sprite generation: \(error)")
            throw SpriteError.apiRequestFailed(error) // General catch-all
        }
    }
} 
