@send
external getRandomValues: (WebCryptoTypes.crypto, 't) => 't = "getRandomValues"

@send
external randomUUID: WebCryptoTypes.crypto => string = "randomUUID"
