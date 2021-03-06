#if os(Linux)
import Glibc
#else
import Darwin
#endif

public func expandUserDirectory(inPath path: String) throws -> String {
    if !path.starts(with: "~") {
        return path
    }

    var foundOne = false
    let secondSeparatorIndex = path.firstIndex { c in
        if c == kSeparatorCharacter {
            foundOne = true
            return false
        }
        return foundOne && c == kSeparatorCharacter
    }
    var userHome = ""
    let index = secondSeparatorIndex ?? path.firstIndex(of: kSeparatorCharacter) ?? path.endIndex
    if foundOne && secondSeparatorIndex == nil || index == path.index(after: path.startIndex)  {
        let homeFromEnv = getenv("HOME")
        errno = 0
        let userPasswd = getpwuid(getuid())
        if userPasswd == nil && errno != 0 {
            throw SystemError(posixErrorCode: errno)
        }

        guard let homePointer = userPasswd?.pointee.pw_dir else {
            return path
        }
        userHome = String(cString: homeFromEnv ?? homePointer)
    } else {
        let userName = String(path[path.index(after: path.startIndex)..<index])
        errno = 0
        let userPasswd = getpwnam(userName)
        if userPasswd == nil && errno != 0 {
            throw SystemError(posixErrorCode: errno)
        }

        guard let homePointer = userPasswd?.pointee.pw_dir else {
            return path
        }
        userHome = String(cString: homePointer)
    }

    let result = _stripFromRight(userHome, kSeparatorCharacter) + String(path[index...])
    return result.isEmpty ? "/" : result
}

public func makeAbsolute(path: String) throws -> String {
    var path = path
    if !isAbsolute(path: path) {
        let buffer = getcwd(nil, 0)
        if buffer == nil {
            throw SystemError(posixErrorCode: errno)
        }
        path = join(path: String(cString: buffer!), withPaths: path)
    }
    return normalize(path: path)
}

extension PathRepresentable {
    public func expandUserDirectory() -> Self {
        return Self(string: (try? expandUserDirectory(inPath:)(self.pathString)) ?? "/")
    }

    public func makeAbsolute() -> Self {
        return (try? makeAbsolute(path:)(self.pathString)).map(Self.init(string:)) ?? self
    }
}
