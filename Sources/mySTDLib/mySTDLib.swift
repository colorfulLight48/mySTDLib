// The Swift Programming Language
// https://docs.swift.org/swift-book
// MARK: - Value Logic

#if Value
public enum WorldValue {
    public enum EmbeddedApp {
        @available(macOS 26.0, *)
        public struct IntListSink<let Count: Int> {
            public var index = 0
            public var buffer = InlineArray<Count, Int>(repeating: 0)

            public mutating func push(_ value: Int) {
                precondition(index < Count, "Too many integers in VM program")
                buffer[index] = value
                index += 1
            }
        }
        @resultBuilder
        @available(macOS 26.0, *)
        public enum IntListBuilder<let Count: Int> {
            public static func buildBlock(_ component: InlineArray<Count, Int>) -> InlineArray<Count, Int> { component }
        }


        public protocol Runnable {
            func run()
        }
        @available(macOS 26.0, *)
        public struct EmbeddedStackVM<let count: Int>: WorldValue.EmbeddedApp.Runnable {
            public let program: InlineArray<count, Int>
            public init(@IntListBuilder<count> _ code: () -> InlineArray<count, Int>) {
                self.program = code()
            }
            public func run() {
                var vm: WorldValue.StandardVM.EmbeddedStackVM = WorldValue.StandardVM.EmbeddedStackVM()
                try? vm.run(self.program)
            }
        }
        @resultBuilder
        public enum BothBuilder {
            public static func buildBlock<A, B>(_ a: A, _ b: B) -> Both<A, B> {
                Both(a, b)
            }
        }

        public struct Both<A: WorldValue.EmbeddedApp.Runnable, B: WorldValue.EmbeddedApp.Runnable>: WorldValue.EmbeddedApp.Runnable {
            public let a: A
            public let b: B
            public init(_ a: A, _ b: B) {
                self.a = a
                self.b = b
            }
            public init(@BothBuilder _ closure: () -> Both) {
                self = closure()
            }
            public func run() {
                self.a.run()
                self.b.run()
            }
        }
        public struct EmbeddedSwiftCode: WorldValue.EmbeddedApp.Runnable {
            public let fn: @convention(c) () -> Void

            public init(_ fn: @convention(c) () -> Void) {
                self.fn = fn
            }

            public func run() {
                fn()
            }
        }
        @resultBuilder
        public enum EmbeddedAppBuilder {
            public static func buildBlock<T: WorldValue.EmbeddedApp.Runnable>(_ component: T) -> WorldValue.EmbeddedApp.EmbeddedApp<T> {
                return WorldValue.EmbeddedApp.EmbeddedApp(component)
            }
        }
        public struct EmbeddedApp<Function: WorldValue.EmbeddedApp.Runnable>: WorldValue.EmbeddedApp.Runnable {
            public let code: Function
            public init(_ code: Function) {
                self.code = code
            }
            public init(@EmbeddedAppBuilder _ code: () -> WorldValue.EmbeddedApp.EmbeddedApp<Function>) {
                self = code()
            }
            public func run() {
                self.code.run()
            }
        }
        public protocol EmbeddedAppLauncher {
            associatedtype T: WorldValue.EmbeddedApp.Runnable
            var app: WorldValue.EmbeddedApp.EmbeddedApp<T> {get}
            init()
        }

    }
    public enum CoreApp {
        public protocol Runnable {
            func run()
        }
        @resultBuilder
        public enum IntListBuilder {
            public static func buildBlock(_ components: Int...) -> [Int] {
                return components
            }
        }

        @available(macOS 26.0, *)
        public struct StackVM: WorldValue.CoreApp.Runnable {
            public let code: [Int]
            public func run() {
                var vm: WorldValue.StandardVM.StackVM = WorldValue.StandardVM.StackVM()
                try? vm.run(self.code)
            }
            public init(@IntListBuilder _ code: () -> [Int]) {
                self.code = code()
            }
        }
        public struct HeapVM: WorldValue.CoreApp.Runnable {
            public let code: [Int]
            public func run() {
                var vm: WorldValue.StandardVM.HeapVM = WorldValue.StandardVM.HeapVM()
                try? vm.run(self.code)
            }
            public init(@IntListBuilder _ code: () -> [Int]) {
                self.code = code()
            }
        }
        public struct SwiftCode: WorldValue.CoreApp.Runnable {
            public let code: () -> Void
            public func run() {
                self.code()
            }
            public init(code: @escaping () -> Void) {
                self.code = code
            }
        }
        @resultBuilder
        public enum CoreAppBuilder {
            public static func buildBlock(_ components: any WorldValue.CoreApp.Runnable...) -> [any WorldValue.CoreApp.Runnable] {
                return components
            }
        }
        public struct CoreApp: Runnable {
            public let code: [any WorldValue.CoreApp.Runnable]
            public func run() {
                for part: any WorldValue.CoreApp.Runnable in code {
                    part.run()
                }
            }
            public init(@CoreAppBuilder _ code: () -> [any Runnable]) {
                self.code = code()
            }
        }
        public protocol CoreAppStarter {
            var app: WorldValue.CoreApp.CoreApp {get}
            init()
        }
        
    }
    public enum StandardVM {
        
        struct UnknownOpcodeError: Error {
            let opcode: Int
            let pc: Int
        }
        public protocol VM {
            var products: [Int: Int] {get}
            mutating func run(_ program: [Int]) throws
        }
        // A no-heap stack using a fixed-size buffer
        // Add this at the very top of your library file
        @available(macOS 26.0, *) 
        public struct SafeStack {
            // 1. You MUST provide a repeating value (0) to initialize the stack memory
            // 2. Note: Order is InlineArray<Capacity, Element>
            private var storage = InlineArray<256, Int>(repeating: 0)
            private var count = 0

            public init() {} // Explicit init for your protocol

            public mutating func push(_ value: Int) {
                // Safe check for your RP2350
                if count < 256 {
                    storage[count] = value
                    count += 1
                }
            }

            public mutating func pop() -> Int {
                if count > 0 {
                    count -= 1
                    return storage[count]
                }
                return 0 // Or throw your UnknownOpcodeError
            }
        }


        // MARK: - HeapVM (register-style, heap-based)
        public struct HeapVM: VM {
            private var shared: [Int: Int] = [:]
            public var products: [Int: Int] = [:]

            public mutating func run(_ program: [Int]) throws {
                var heap: [Int: Int] = [:]
                var pc = 0

                while pc < program.count {
                    let opcode = program[pc]

                    switch opcode {
                    case 1: // LOAD addr value
                        let addr = program[pc + 1]
                        let value = program[pc + 2]
                        heap[addr] = value
                        pc += 3
                    case 2: // ADD a b dest
                        let a = program[pc + 1]
                        let b = program[pc + 2]
                        let dest = program[pc + 3]
                        let av = heap[a] ?? 0
                        let bv = heap[b] ?? 0
                        heap[dest] = av + bv
                        pc += 4
                    case 4: // PRINT addr
                        let addr = program[pc + 1]
                        print("HeapVM PRINT:", heap[addr] ?? 0)
                        pc += 2
                    case 5: // HALT
                        return
                    default:
                        throw WorldValue.StandardVM.UnknownOpcodeError(opcode: opcode, pc: pc)
                    }
                }
            }
            public init() {}
        }
        @available(macOS 26.0, *) 
        public struct EmbeddedStackVM {
        

            public mutating func run<let Count: Int>(_ program: InlineArray<Count, Int>) throws {
                var stack: SafeStack = .init()
                var pc: Int = 0

                while pc < program.count {
                    let opcode = program[pc]

                    switch opcode {
                        case 0: // PUSH value
                            let value = program[pc + 1]
                            stack.push(value)
                            pc += 2
                        case 1: // ADD (stack)
                            let b = stack.pop()
                            let a = stack.pop()
                            stack.push(a + b)
                            pc += 1
                        case 2: // PRINT (stack)
                            let value = stack.pop()
                            print("StackVM PRINT:", value)
                            pc += 1
                        case 3: // HALT
                            return
                        case 4: // Subtract
                            let b = stack.pop()
                            let a = stack.pop()
                            stack.push(a - b)
                            pc += 1
                        default:
                            throw UnknownOpcodeError(opcode: opcode, pc: pc)
                    }
                }
            }
            public init() {}
        }

        @available(macOS 26.0, *) 
        public struct StackVM: VM {
            private var shared: [Int: Int] = [:]
            public var products: [Int: Int] = [:]

            public mutating func run(_ program: [Int]) throws {
                var stack: SafeStack = .init()
                var pc: Int = 0

                while pc < program.count {
                    let opcode = program[pc]

                    switch opcode {
                        case 0: // PUSH value
                            let value = program[pc + 1]
                            stack.push(value)
                            pc += 2
                        case 1: // ADD (stack)
                            let b = stack.pop()
                            let a = stack.pop()
                            stack.push(a + b)
                            pc += 1
                        case 2: // PRINT (stack)
                            let value = stack.pop()
                            print("StackVM PRINT:", value)
                            pc += 1
                        case 3: // HALT
                            return
                        case 4: // Subtract
                            let b = stack.pop()
                            let a = stack.pop()
                            stack.push(a - b)
                            pc += 1
                        default:
                            throw UnknownOpcodeError(opcode: opcode, pc: pc)
                    }
                }
            }
            public init() {}
        }
        public protocol VMEntrypoint {
            associatedtype V: WorldValue.StandardVM.VM
            var program: [Int] {get}
            var vm: V {get}
            init()   
        }
    }
}
public extension WorldValue.StandardVM.VMEntrypoint {
    static func main() {
        let i = self.init()
        i.run()
    }
    func run() {
        var vmCopy: Self.V = self.vm
        try? vmCopy.run(program)
    }
}
public extension WorldValue.CoreApp.CoreAppStarter {
    static func main() {
        self.init().app.run()
    }
}
public extension WorldValue.EmbeddedApp.EmbeddedAppLauncher {
    static func main() {
        self.init().app.run()
    }
}
#endif

// MARK: - OOP Logic
#if OOP
public enum WorldOOP {
      // Nothing so far
}
#endif

// MARK: - Async Logic
#if Async
public enum WorldAsync {
      // Nothing so far
}
#endif
// This triggers only if you are on a Pico (no OS) but forgot the Value trait
#if !Value && !OOP && !Async
    #warning("No traits imported! The library will be empty. Did you forget to enable 'Value', 'OOP', or 'Async'?")
#endif
