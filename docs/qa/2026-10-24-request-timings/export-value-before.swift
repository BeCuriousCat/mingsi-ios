    static func exportValue(_ value: DatabaseValue) -> Any {
        if value.isNull {
            return NSNull()
        }
        if let string = String.fromDatabaseValue(value) {
            return string
        }
        if let bool = Bool.fromDatabaseValue(value) {
            return bool
        }
        if let int64 = Int64.fromDatabaseValue(value) {
            return int64
        }
        if let double = Double.fromDatabaseValue(value) {
            return double
        }
        if let data = Data.fromDatabaseValue(value) {
            return data.base64EncodedString()
        }
        return "\(value)"
    }
