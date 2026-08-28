import Foundation


enum CallbackError: Error, CustomStringConvertible, Equatable {
    case invalidURL
    case missing(String)
    case invalidDescriptor(String)
    case notFound(DescriptorId)
    case invalidCommand(Reference)
    case invalidArtifact(Reference)
    case invalidTrigger(Reference)
    case invalidArguments
    case dispatchFailed(Reference)
    case runFailed(Reference)

    var description: String {
        switch self {
            case .invalidURL: return "Invalid Scint URL."
            case .missing(let name): return "Missing callback parameter: \(name)."
            case .invalidDescriptor(let value): return "Invalid descriptor: \(value)."
            case .notFound(let descriptor): return "Descriptor not found: \(descriptor)."
            case .invalidCommand(let ref): return "Callback target is not a Command: \(ref.descriptorId)."
            case .invalidArtifact(let ref): return "Callback target is not a runnable Artifact: \(ref.descriptorId)."
            case .invalidTrigger(let ref): return "Callback target is not composable: \(ref.descriptorId)."
            case .invalidArguments: return "Callback arguments must be a Properties object."
            case .dispatchFailed(let ref): return "Command dispatch failed: \(ref.descriptorId)."
            case .runFailed(let ref): return "Artifact execution failed: \(ref.descriptorId)."
        }
    }
}

enum ParsingError: Error, CustomStringConvertible, Equatable {
    case invalid(String)
    case missingArgument(String)
    case unexpectedArguments([String])

    var description: String {
        switch self {
            case .invalid(let message): return message
            case .missingArgument(let name): return "Missing required argument: \(name)."
            case .unexpectedArguments(let values): return "Unexpected arguments: \(values.joined(separator: ", "))."
        }
    }
}

enum RuntimeError: Error, Codable, Equatable {
    case error(String)
    case context(Context)
    case composition(Composition)
    case interfaces(Interfaces)
    case persistence(Persistence)
    case settings(Settings)
    case spaces(Workspaces)

    static func fatal() -> Never { fatalError() }

    enum Catalog: Error, CustomStringConvertible, Equatable, Codable {
        case missingDescriptor(Reference)

        var description: String {
            switch self {
                case .missingDescriptor(let ref): return "No descriptor for \(ref.id)"
            }
        }
    }

    enum Composition: Error, CustomStringConvertible, Equatable, Codable {
        case invalidOrigin(String)
        case notFound(String)
        case notAllowed(String, String)

        var description: String {
            switch self {
                case .invalidOrigin(let origin): return "Can't use \(origin) as an origin for this component."
                case .notFound(let value): return "Space with value of \(value) not found."
                case .notAllowed(let first, let second): return "Projection not allowed with \(first) and \(second)."
            }
        }
    }

    enum Context: Error, CustomStringConvertible, Equatable, Codable {
        case functionNotFound(String)
        case invalidArguments(String)
        case missingRequired(Reference)
        case notStarted
        case refNotFound
        case startFailed(String)
        case missing(Reference)

        case contextNotFound(UUID)

        var description: String {
            switch self {
                case .contextNotFound(let v): return "Context not found: \(v)"
                case .functionNotFound(let v): return "Function not found: \(v)"
                case .invalidArguments(let v): return "Invalid arguments: \(v)"
                case .missingRequired(let v): return "Missing required: \(v)"
                case .notStarted: return "Not started."
                case .refNotFound: return "Harness ref not found"
                case .startFailed(let v): return "Harness start failed: \(v)"
                case .missing(let v): return "Missing model for ref: \(v)"
            }
        }
    }

    enum Interfaces: Error, CustomStringConvertible, Equatable, Codable {
        case notFound(String)

        var description: String {
            switch self {
                case .notFound(let v): return "Space not found: \(v)"
            }
        }
    }

    enum Library: Error, CustomStringConvertible, Equatable, Codable {
        case loadFailed

        var description: String {
            switch self {
                case .loadFailed: "Workspaces accessed before runtime finished loading."
            }
        }
    }

    enum Persistence: Error, CustomStringConvertible, Equatable, Codable {
        case unregisteredType(String)
        case encodingFailed(Reference)
        case decodingFailed(URL)
        case notFound(URL)

        var description: String {
            switch self {
                case .notFound(let v): return "File not found: \(v.path)"
                case .encodingFailed(let v): return "Failed to encode \(v.id)"
                case .decodingFailed(let v): return "Failed to decode \(v.lastPathComponent)"
                case .unregisteredType(let id): return "No registry entry for type \(id)"
            }
        }
    }

    enum Settings: Error, CustomStringConvertible, Equatable, Codable {
        case notFound(String)

        var description: String {
            switch self {
                case .notFound(let v): return "Settings not found: \(v)"
            }
        }
    }

    enum Workspaces: Error, CustomStringConvertible, Equatable, Codable {
        case loadFailed

        var description: String {
            switch self {
                case .loadFailed: "Workspaces accessed before runtime finished loading."
            }
        }
    }
}
