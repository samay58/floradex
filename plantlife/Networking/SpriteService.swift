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
                "quality": "medium",
                "background": "transparent",
                "output_format": "png"
            ]
        }
    }
    // body will be handled by APIClient by serializing parameters
    var body: Data? { nil }

    // Sprite generation can take >8s; allow longer per-request timeout (e.g., 60s)
    var timeout: TimeInterval? { 300 }
}

final class SpriteService: Sendable {
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
        print("[SpriteService] Starting sprite generation for: \(commonName) (\(latinName))")
        
        guard let apiKey = Secrets.openAIApiKey.nonEmpty else {
            print("[SpriteService] Error: Missing OpenAI API key")
            throw SpriteError.missingKey
        }

        // Construct the prompt for gpt-image-1
        let prompt = "Create a simple pixel art sprite of a \(commonName) plant (\(latinName)). The sprite should be in a retro 8-bit video game style with a limited color palette, centered in the frame, and suitable for a plant collection game. Make it cute and iconic."

        let endpoint = SpriteEndpoint.generate(prompt: prompt, apiKey: apiKey)

        do {
            let response: OpenAIImageGenerationResponse = try await APIClient.shared.request(endpoint: endpoint)
            print("[SpriteService] Received response from OpenAI API. Data count: \(response.data.count)")
            
            guard let firstDatum = response.data.first else {
                print("[SpriteService] No data in response from OpenAI API")
                throw SpriteError.noSpriteURLFound // Or badResponseFormat
            }

            // gpt-image-1 always returns base64-encoded images
            guard let b64Json = firstDatum.b64_json,
                  let decodedData = Data(base64Encoded: b64Json) else {
                print("[SpriteService] No base64 data in response from OpenAI API")
                throw SpriteError.badResponseFormat
            }
            
            print("[SpriteService] Received base64 image data. Decoded size: \(decodedData.count) bytes")
            
            // Process and resize the image
            guard let image = UIImage(data: decodedData) else {
                print("[SpriteService] Failed to create UIImage from decoded base64 data")
                throw SpriteError.imageProcessingFailed
            }
            print("[SpriteService] Created UIImage from base64 data. Original dimensions: \(image.size.width)x\(image.size.height)")
            
            guard let resizedImage = UIImage.ImageProcessing.resized(image, maxSide: 64) else {
                print("[SpriteService] Failed to resize image to 64x64")
                throw SpriteError.imageProcessingFailed
            }
            print("[SpriteService] Resized image to: \(resizedImage.size.width)x\(resizedImage.size.height)")
            
            guard let pngData = resizedImage.pngData() else {
                print("[SpriteService] Failed to convert resized image to PNG data")
                throw SpriteError.imageProcessingFailed
            }
            
            // Log successful sprite generation
            if let verifyImage = UIImage(data: pngData) {
                print("[SpriteService] Successfully generated sprite PNG data. Size: \(pngData.count) bytes. Dimensions: \(verifyImage.size.width)x\(verifyImage.size.height)")
            } else {
                print("[SpriteService] Successfully generated sprite PNG data. Size: \(pngData.count) bytes. Could not create UIImage from data for dimension check.")
            }
            
            return pngData
        } catch let apiError as APIError {
            print("[SpriteService] Sprite generation API request failed: \(apiError). Endpoint: \(endpoint.path), Params: \(String(describing: endpoint.parameters))")
            throw SpriteError.apiRequestFailed(apiError)
        } catch let spriteError as SpriteError {
            throw spriteError // Re-throw specific sprite errors
        } catch {
            print("[SpriteService] An unexpected error occurred during sprite generation: \(error)")
            throw SpriteError.apiRequestFailed(error) // General catch-all
        }
    }
} 
