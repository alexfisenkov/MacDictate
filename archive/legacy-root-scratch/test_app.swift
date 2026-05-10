import Cocoa

let fm = FileManager.default
let home = fm.homeDirectoryForCurrentUser.path
print("Home:", home)
let dir = home + "/.macdictate"
do {
    try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
    print("Created dir!")
} catch {
    print("Error:", error)
}
