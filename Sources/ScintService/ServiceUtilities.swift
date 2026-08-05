import Foundation


func jsonString(_ object: Any) -> String {
    guard
        JSONSerialization.isValidJSONObject(object),
        let data = try? JSONSerialization.data(withJSONObject: object),
        let string = String(data: data, encoding: .utf8)
    else { return #"{"ok":false,"error":"failed_to_encode_json"}"# }
    return string
}

func parseJSONDict(_ json: String) -> [String: Any]? {
    guard
        let data = json.data(using: .utf8),
        let obj  = try? JSONSerialization.jsonObject(with: data),
        let dict = obj as? [String: Any]
    else { return nil }
    return dict
}

func int32(from value: Any?) -> Int32? {
    switch value {
    case let v as Int32: return v
    case let v as Int: return Int32(v)
    case let v as NSNumber: return v.int32Value
    case let v as String: return Int32(v)
    default: return nil
    }
}
