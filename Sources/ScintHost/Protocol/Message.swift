import Foundation


enum MCPProtocol {
    static let version = "2026-07-28"
    static let jsonRPCVersion = "2.0"
    static let contextMetadataKey = "com.kaechle.scint/context"
}

enum JSONRPCResponse: Sendable, Equatable, Codable {
    case result(id: Property, result: Property)
    case error(id: Property?, error: Property)

    init(from decoder: any Decoder) throws {
        let value = try Property(from: decoder)
        guard case .object(let object) = value,
              object["jsonrpc"] == .string(MCPProtocol.jsonRPCVersion)
        else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "A JSON-RPC response must be an object with jsonrpc 2.0."
            ))
        }

        func validID(_ value: Property) -> Bool {
            if case .string = value { return true }
            if case .integer = value { return true }
            return false
        }

        switch (object["result"], object["error"]) {
            case (.some(let result), nil):
                guard let id = object["id"], validID(id), case .object = result else {
                    throw DecodingError.dataCorrupted(.init(
                        codingPath: decoder.codingPath,
                        debugDescription: "A result response requires a valid id and object result."
                    ))
                }
                self = .result(id: id, result: result)

            case (nil, .some(let error)):
                let id = object["id"]
                guard id.map(validID) ?? true,
                      case .object(let fields) = error,
                      case .integer? = fields["code"],
                      case .string? = fields["message"]
                else {
                    throw DecodingError.dataCorrupted(.init(
                        codingPath: decoder.codingPath,
                        debugDescription: "An error response requires a valid error object."
                    ))
                }
                self = .error(id: id, error: error)

            default:
                throw DecodingError.dataCorrupted(.init(
                    codingPath: decoder.codingPath,
                    debugDescription: "A JSON-RPC response must contain exactly one of result or error."
                ))
        }
    }

    func encode(to encoder: any Encoder) throws {
        func validID(_ value: Property) -> Bool {
            if case .string = value { return true }
            if case .integer = value { return true }
            return false
        }

        var object: [String: Property] = ["jsonrpc": .string(MCPProtocol.jsonRPCVersion)]
        switch self {
            case .result(let id, let result):
                guard validID(id), case .object = result else {
                    throw EncodingError.invalidValue(self, .init(
                        codingPath: encoder.codingPath,
                        debugDescription: "A result response requires a valid id and object result."
                    ))
                }
                object["id"] = id
                object["result"] = result

            case .error(let id, let error):
                guard id.map(validID) ?? true,
                      case .object(let fields) = error,
                      case .integer? = fields["code"],
                      case .string? = fields["message"]
                else {
                    throw EncodingError.invalidValue(self, .init(
                        codingPath: encoder.codingPath,
                        debugDescription: "An error response requires a valid error object."
                    ))
                }
                if let id { object["id"] = id }
                object["error"] = error
        }
        try Property.object(object).encode(to: encoder)
    }
}

enum JSONRPCMessage: Sendable, Equatable, Codable {
    case request(id: Property, method: String, params: Property?)
    case notification(method: String, params: Property?)
    case response(JSONRPCResponse)

    init(from decoder: any Decoder) throws {
        let value = try Property(from: decoder)
        guard case .object(let object) = value,
              object["jsonrpc"] == .string(MCPProtocol.jsonRPCVersion)
        else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "A JSON-RPC message must be an object with jsonrpc 2.0."
            ))
        }

        func validID(_ value: Property) -> Bool {
            if case .string = value { return true }
            if case .integer = value { return true }
            return false
        }

        if object["method"] != nil {
            guard let method = object["method"]?.string,
                  object["result"] == nil,
                  object["error"] == nil
            else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: decoder.codingPath,
                    debugDescription: "A JSON-RPC request or notification requires a string method."
                ))
            }
            let params = object["params"]
            if let params, case .object = params {} else if params != nil {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: decoder.codingPath,
                    debugDescription: "JSON-RPC params must be an object."
                ))
            }
            if let id = object["id"] {
                guard validID(id) else {
                    throw DecodingError.dataCorrupted(.init(
                        codingPath: decoder.codingPath,
                        debugDescription: "A JSON-RPC request id must be a string or integer."
                    ))
                }
                self = .request(id: id, method: method, params: params)
            } else {
                self = .notification(method: method, params: params)
            }
            return
        }

        switch (object["result"], object["error"]) {
            case (.some(let result), nil):
                guard let id = object["id"], validID(id), case .object = result else {
                    throw DecodingError.dataCorrupted(.init(
                        codingPath: decoder.codingPath,
                        debugDescription: "A result response requires a valid id and object result."
                    ))
                }
                self = .response(.result(id: id, result: result))

            case (nil, .some(let error)):
                let id = object["id"]
                guard id.map(validID) ?? true,
                      case .object(let fields) = error,
                      case .integer? = fields["code"],
                      case .string? = fields["message"]
                else {
                    throw DecodingError.dataCorrupted(.init(
                        codingPath: decoder.codingPath,
                        debugDescription: "An error response requires a valid error object."
                    ))
                }
                self = .response(.error(id: id, error: error))

            default:
                throw DecodingError.dataCorrupted(.init(
                    codingPath: decoder.codingPath,
                    debugDescription: "The object is not a valid JSON-RPC message."
                ))
        }
    }

    func encode(to encoder: any Encoder) throws {
        func validID(_ value: Property) -> Bool {
            if case .string = value { return true }
            if case .integer = value { return true }
            return false
        }

        switch self {
            case .request(let id, let method, let params):
                guard validID(id), !method.isEmpty else {
                    throw EncodingError.invalidValue(self, .init(
                        codingPath: encoder.codingPath,
                        debugDescription: "A JSON-RPC request requires a valid id and method."
                    ))
                }
                if let params, case .object = params {} else if params != nil {
                    throw EncodingError.invalidValue(self, .init(
                        codingPath: encoder.codingPath,
                        debugDescription: "JSON-RPC params must be an object."
                    ))
                }
                var object: [String: Property] = [
                    "jsonrpc": .string(MCPProtocol.jsonRPCVersion),
                    "id": id,
                    "method": .string(method)
                ]
                if let params { object["params"] = params }
                try Property.object(object).encode(to: encoder)

            case .notification(let method, let params):
                guard !method.isEmpty else {
                    throw EncodingError.invalidValue(self, .init(
                        codingPath: encoder.codingPath,
                        debugDescription: "A JSON-RPC notification requires a method."
                    ))
                }
                if let params, case .object = params {} else if params != nil {
                    throw EncodingError.invalidValue(self, .init(
                        codingPath: encoder.codingPath,
                        debugDescription: "JSON-RPC params must be an object."
                    ))
                }
                var object: [String: Property] = [
                    "jsonrpc": .string(MCPProtocol.jsonRPCVersion),
                    "method": .string(method)
                ]
                if let params { object["params"] = params }
                try Property.object(object).encode(to: encoder)

            case .response(let response):
                try response.encode(to: encoder)
        }
    }

    static func decode(_ data: Data) throws -> Self {
        try JSONDecoder().decode(Self.self, from: data)
    }

    func encodeLine() throws -> Data {
        var data = try JSONEncoder().encode(self)
        data.append(0x0A)
        return data
    }
}
