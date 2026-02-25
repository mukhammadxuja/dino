import Foundation

enum RepeatMode: Int {
    case off = 1
    case one = 2
    case all = 3
}

func testSwitch(nextMode: RepeatMode) -> Int {
    let mrValue: Int
    switch nextMode {
    case .off: mrValue = 0
    case .one: mrValue = 1
    case .all: mrValue = 2
    }
    return mrValue
}

print(testSwitch(nextMode: .all))
