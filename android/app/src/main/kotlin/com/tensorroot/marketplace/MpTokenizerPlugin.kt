package com.tensorroot.marketplace

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Platform Channel plugin for Mercado Pago card tokenization.
 *
 * Uses Mercado Pago Core Methods SDK for PCI-compliant card tokenization.
 * Cards are never sent to our backend — only tokens.
 */
class MpTokenizerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var publicKey: String? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                publicKey = call.argument<String>("publicKey")
                if (publicKey == null) {
                    result.error("INVALID_ARGS", "publicKey is required", null)
                    return
                }
                result.success(true)
            }

            "tokenizeCard" -> {
                val pk = publicKey
                if (pk == null) {
                    result.error("NOT_INITIALIZED", "Call initialize first", null)
                    return
                }

                val cardNumber = call.argument<String>("cardNumber")
                val expirationMonth = call.argument<String>("expirationMonth")
                val expirationYear = call.argument<String>("expirationYear")
                val securityCode = call.argument<String>("securityCode")
                val cardholderName = call.argument<String>("cardholderName")
                val identificationNumber = call.argument<String>("identificationNumber")
                val identificationType = call.argument<String>("identificationType") ?: "CPF"

                if (cardNumber == null || expirationMonth == null || expirationYear == null ||
                    securityCode == null || cardholderName == null || identificationNumber == null
                ) {
                    result.error("INVALID_ARGS", "All card fields are required", null)
                    return
                }

                tokenizeCard(
                    pk, cardNumber, expirationMonth, expirationYear,
                    securityCode, cardholderName, identificationNumber,
                    identificationType, result
                )
            }

            else -> result.notImplemented()
        }
    }

    private fun tokenizeCard(
        publicKey: String,
        cardNumber: String,
        expirationMonth: String,
        expirationYear: String,
        securityCode: String,
        cardholderName: String,
        identificationNumber: String,
        identificationType: String,
        result: MethodChannel.Result
    ) {
        // Use Mercado Pago REST API for tokenization (no SDK dependency needed)
        // This calls the public card token endpoint directly
        Thread {
            try {
                val url = java.net.URL("https://api.mercadopago.com/v1/card_tokens?public_key=$publicKey")
                val connection = url.openConnection() as java.net.HttpURLConnection
                connection.requestMethod = "POST"
                connection.setRequestProperty("Content-Type", "application/json")
                connection.doOutput = true

                val body = """
                    {
                        "card_number": "$cardNumber",
                        "expiration_month": "$expirationMonth",
                        "expiration_year": "$expirationYear",
                        "security_code": "$securityCode",
                        "cardholder": {
                            "name": "$cardholderName",
                            "identification": {
                                "type": "$identificationType",
                                "number": "$identificationNumber"
                            }
                        }
                    }
                """.trimIndent()

                connection.outputStream.use { it.write(body.toByteArray()) }

                val responseCode = connection.responseCode
                val responseBody = if (responseCode in 200..299) {
                    connection.inputStream.bufferedReader().readText()
                } else {
                    connection.errorStream?.bufferedReader()?.readText() ?: "Unknown error"
                }

                if (responseCode in 200..299) {
                    // Parse token ID from JSON response
                    val tokenId = parseJsonField(responseBody, "id")
                    val lastFour = parseJsonField(responseBody, "last_four_digits")
                    val firstSix = parseJsonField(responseBody, "first_six_digits")

                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        result.success(
                            mapOf(
                                "tokenId" to tokenId,
                                "lastFourDigits" to lastFour,
                                "firstSixDigits" to firstSix
                            )
                        )
                    }
                } else {
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        result.error("TOKENIZATION_ERROR", "Failed to tokenize card: $responseBody", null)
                    }
                }
            } catch (e: Exception) {
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    result.error("TOKENIZATION_ERROR", e.message, null)
                }
            }
        }.start()
    }

    private fun parseJsonField(json: String, field: String): String? {
        val regex = """"$field"\s*:\s*"([^"]+)"""".toRegex()
        return regex.find(json)?.groupValues?.get(1)
    }

    companion object {
        const val CHANNEL_NAME = "com.tensorroot.marketplace/mp_tokenizer"
    }
}
