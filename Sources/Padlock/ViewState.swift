import SwiftUI

// The macOS 27 SDK also exports a macro named State whose plugin is not
// shipped in the standalone Command Line Tools. A type alias unambiguously
// selects the original property wrapper, also supported on macOS 13–26.
typealias ViewState<Value> = SwiftUI.State<Value>
