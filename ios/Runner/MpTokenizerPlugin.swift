import Flutter
import UIKit

/// Platform Channel plugin for Mercado Pago card tokenization (iOS).
///
/// Calls the MP REST API /v1/card_tokens directly (PCI-compliant).
/// Cards are never sent to our backend — only tokens.
class MpTokenizerPlugin: NSObject, FlutterPlugin {
    static let channelName = "com.tensorroot.marketplace/mp_tokenizer"
    private var publicKey: String?

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        let instance = MpTokenizerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            guard let args = call.arguments as? [String: Any],
                  let pk = args["publicKey"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "publicKey is required", details: nil))
                return
            }
            publicKey = pk
            result(true)

        case "tokenizeCard":
            guard let pk = publicKey else {
                result(FlutterError(code: "NOT_INITIALIZED", message: "Call initialize first", details: nil))
                return
            }
            guard let args = call.arguments as? [String: Any],
                  let cardNumber = args["cardNumber"] as? String,
                  let expirationMonth = args["expirationMonth"] as? String,
                  let expirationYear = args["expirationYear"] as? String,
                  let securityCode = args["securityCode"] as? String,
                  let cardholderName = args["cardholderName"] as? String,
                  let identificationNumber = args["identificationNumber"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "All card fields are required", details: nil))
                return
            }
            let identificationType = (args["identificationType"] as? String) ?? "CPF"
            tokenizeCard(
                publicKey: pk,
                cardNumber: cardNumber,
                expirationMonth: expirationMonth,
                expirationYear: expirationYear,
                securityCode: securityCode,
                cardholderName: cardholderName,
                identificationNumber: identificationNumber,
                identificationType: identificationType,
                result: result
            )

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func tokenizeCard(
        publicKey: String,
        cardNumber: String,
        expirationMonth: String,
        expirationYear: String,
        securityCode: String,
        cardholderName: String,
        identificationNumber: String,
        identificationType: String,
        result: @escaping FlutterResult
    ) {
        guard let url = URL(string: "https://api.mercadopago.com/v1/card_tokens?public_key=\(publicKey)") else {
            result(FlutterError(code: "INVALID_URL", message: "Invalid MP API URL", details: nil))
            return
        }

        let body: [String: Any] = [
            "card_number": cardNumber,
            "expiration_month": expirationMonth,
            "expiration_year": expirationYear,
            "security_code": securityCode,
            "cardholder": [
                "name": cardholderName,
                "identification": [
                    "type": identificationType,
                    "number": identificationNumber
                ]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            result(FlutterError(code: "SERIALIZATION_ERROR", message: "Failed to serialize request", details: nil))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(code: "NETWORK_ERROR", message: error.localizedDescription, details: nil))
                    return
                }

                guard let data = data,
                      let httpResponse = response as? HTTPURLResponse else {
                    result(FlutterError(code: "TOKENIZATION_ERROR", message: "No response from MP API", details: nil))
                    return
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    let body = String(data: data, encoding: .utf8) ?? "Unknown error"
                    result(FlutterError(
                        code: "TOKENIZATION_ERROR",
                        message: "Failed to tokenize card: \(body)",
                        details: nil
                    ))
                    return
                }

                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tokenId = json["id"] as? String else {
                    result(FlutterError(code: "PARSE_ERROR", message: "Failed to parse MP token response", details: nil))
                    return
                }

                let lastFour = json["last_four_digits"] as? String
                let firstSix = json["first_six_digits"] as? String

                result([
                    "tokenId": tokenId,
                    "lastFourDigits": lastFour as Any,
                    "firstSixDigits": firstSix as Any
                ])
            }
        }.resume()
    }
}
