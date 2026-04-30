// The Swift Programming Language
// https://docs.swift.org/swift-book
// MARK: - Value Logic

#if Value
public enum WorldValue {
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
        public struct SafeStack {
            private var storage: InlineArray<256, Int> = .init()
            private var count = 0

            public mutating func push(_ value: Int) {
                // Safe: Checks bounds before adding
                storage[count] = value
                count += 1
            }

            public mutating func pop() -> Int {
                count -= 1
                return storage[count]
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
        }
        
        // MARK: - StackVM (stack-based)
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
