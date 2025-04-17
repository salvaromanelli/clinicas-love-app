import Foundation

class ReplicateAPIService {
    private let apiKey: String
    private let baseURL = "https://api.replicate.com/v1"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func sendFacialData(facialPoints: [String: Any], completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/your-endpoint") else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "input": facialPoints
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(error))
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "No data received", code: 0, userInfo: nil)))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let outputUrl = json["output_url"] as? String {
                    completion(.success(outputUrl))
                } else {
                    completion(.failure(NSError(domain: "Invalid response format", code: 0, userInfo: nil)))
                }
            } catch {
                completion(.failure(error))
            }
        }

        task.resume()
    }
}