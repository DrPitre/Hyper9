import Foundation

extension Disassembler {
    enum PreByte {
        case none
        case page10
        case page11

        // Optional: A computed property to retrieve the value as a string
        var description: String {
            switch self {
            case .none:
                return ""
            case .page10:
                return "10"
            case .page11:
                return "11"
            }
        }
    }

    enum PostOperand {
        case byte(UInt8)
        case word(UInt16)
        case none

        // Optional: A computed property to retrieve the value as a string
        var description: String {
            switch self {
            case .byte(let value):
                return "\(value)"
            case .word(let value):
                return "\(value)"
            case .none:
                return "0"
            }
        }

        var hexDescription: String {
            switch self {
            case .byte(let value):
                return String(format: "%02X", value)
            case .word(let value):
                return String(format: "%04X", value)
            case .none:
                return ""
            }
        }
    }

    public struct Turbo9Operation {
        let label: String
        public let offset: UInt16
        let preByte: PreByte
        public let opcode: UInt8
        let instruction: Instruction
        public let addressMode: AddressMode
        let operand: Operand
        let postOperand: PostOperand
        public let size: UInt16
        
        public func isBranchSubroutineType() -> Bool {
            if self.instruction == .jsr || self.instruction == .bsr || self.instruction == .lbsr {
                return true
            }
            
            return false
        }
        
        public func isReturningInstruction() -> Bool {
            if self.instruction == .rts || self.instruction == .rti  {
                return true
            }
            
            return false
        }
        
        public var asCode: String {
            let paddedString = instructionBytes().padding(toLength: 8, withPad: " ", startingAt: 0)
            return [String(format: "%04X  %@  ", offset, paddedString), label.padding(toLength: 24, withPad: " ", startingAt: 0), instruction.rawValue.padding(toLength: 6, withPad: " ", startingAt: 0), operandAsString].compactMap { $0 }.joined(separator: " ")
        }

        // MARK: - Column accessors (for the UI)

        /// "C100" — 4-digit hex offset, no `$` prefix.
        public var addressText: String { String(format: "%04X", offset) }
        /// Raw instruction bytes as concatenated hex, e.g. "10A60003".
        public var bytesText: String { instructionBytes() }
        /// Symbol-table label for this address, or empty if none.
        public var labelText: String { label }
        /// Mnemonic e.g. "LDA".
        public var mnemonicText: String { instruction.rawValue }
        /// Formatted operand string, or empty if the instruction is inherent.
        public var operandText: String { operandAsString ?? "" }
        
        private func instructionBytes() -> String {
            var result = ""
            
            result = String(format: "%@%02X%@%@", preByte.description, opcode, operand.hexDescription, postOperand.hexDescription)
            
            return result
        }

        /*
         0000    D (A:B)    0101    Program Counter
         0001    X Index    1000    A Accumulator
         0010    Y Index    1001    B Accumulator
         0011    U Stack Pointer    1010    Condition Code
         0100    S Stack Pointer    1011    Direct Page
         */
        private func registerPostByte(postByte: UInt8) -> String {
            var result : String
            
            switch postByte {
            case 0x00:
                result = "D"
            case 0x01:
                result = "X"
            case 0x02:
                result = "Y"
            case 0x03:
                result = "U"
            case 0x04:
                result = "S"
            case 0x05:
                result = "PC"
            case 0x08:
                result = "A"
            case 0x09:
                result = "B"
            case 0x0A:
                result = "CC"
            case 0x0B:
                result = "DP"
            default:
                result = "??"
            }
            
            return result
        }
        
        /*
         b7    b6    b5    b4   b3    b2   b1   b0
         PC    S/U    Y    X    DP    B    A    CC
         */
        func pshpulOperandAsString(postByte: UInt8, register: Register) -> String {
            func addCommaIfNeeded(text : inout String) {
                if text != "" {
                    text = text + ","
                }
            }
            
            var result = ""
            if postByte & 0x01 == 0x01 {
                addCommaIfNeeded(text: &result)
                result += "CC"
            }
            if postByte & 0x02 == 0x02 {
                addCommaIfNeeded(text: &result)
                result += "A"
            }
            if postByte & 0x04 == 0x04 {
                addCommaIfNeeded(text: &result)
                result += "B"
            }
            if postByte & 0x08 == 0x08 {
                addCommaIfNeeded(text: &result)
                result += "DP"
            }
            if postByte & 0x10 == 0x10 {
                addCommaIfNeeded(text: &result)
                result += "X"
            }
            if postByte & 0x20 == 0x20 {
                addCommaIfNeeded(text: &result)
                result += "Y"
            }
            if postByte & 0x40 == 0x40 {
                addCommaIfNeeded(text: &result)
                if register == .U {
                    result += "S"
                } else {
                    result += "U"
                }
            }
            if postByte & 0x80 == 0x80 {
                addCommaIfNeeded(text: &result)
                result += "PC"
            }
            return result
        }
        
        func exgTfrOperandAsString(postByte: UInt8) -> String {
            let result = registerPostByte(postByte: postByte >> 4) + "," + registerPostByte(postByte: postByte & 0xF)
            return result
        }
        
       var operandAsString: String? {
           switch operand {
           case .immediate8(let value):
               // Exceptions: TFR and EXG
               if instruction == .tfr || instruction == .exg {
                   return exgTfrOperandAsString(postByte: value)
               } else if instruction == .pshs || instruction == .puls {
                    return pshpulOperandAsString(postByte: value, register: .SP)
               } else if instruction == .pshu || instruction == .pulu {
                    return pshpulOperandAsString(postByte: value, register: .U)
               }
               return "#\(value.asSigned)"

           case .immediate16(let value):
               return "#\(value.asSigned)"

           case .relative8(let value):
               var value = value.asWord

               // The value is a signed byte.
               // Flip the high bits if value is negative so we can add it to offset.
               if value & 0x80 == 0x80 {
                   value = value ^ 0xFF00
               }

               // 2 is the number of bytes between offset and the next instruction, which is where
               // the relative location should be calculated from.
               let location = offset &+ 2 &+ value
               return "\(location.asHex)"

           case .relative16(let value):
               var value = value

               // The value is a signed byte.
               // Flip the high bits if value is negative so we can add it to offset.
               if value & 0x8000 == 0x8000 {
                   let result = Int16(bitPattern: value)
                   value = UInt16(truncatingIfNeeded: result)
               }

               // 3 is the number of bytes between offset and the next instruction, which is where
               // the relative location should be calculated from.
               let location = offset &+ size &+ value
               return "\(location.asHex)"

           case .direct(let value):
               return "<\(value.asHex)"
           case .extended(let value):
               return ">\(value.asHex)"
           case .indexed(let value):
               return indexOperandAsString(postByte: value)
           case .inherent, .none:
               return nil
           }
       }
        
        /// Indirect, aka. pointer.
        ///
        /// The next byte forms a postbyte which dictates what byte or bytes follow.
        private func indexOperandAsString(postByte : UInt8) -> String {
            var result = ""
            
            // Determine mode type.
            var registerPostIncrement = ""
            var registerPreDecrement = ""
            let registerNo = (postByte & 0x60) >> 5
            var leftBracket = ""
            var rightBracket = ""
            var register = ""
            var offset : String = ""
            var least5 = Int16(postByte & 0x1F)
            switch registerNo {
            case 0:
                register = "X"
            case 1:
                register = "Y"
            case 2:
                register = "U"
            default:
                register = "S"
            }
            if postByte & 0x80 == 0 {
                // 5-bit offset - if bit 4 is 1 then result is negative
                if least5 & 0x10 == 0x10 {
                    let comp = ~least5 & 0x0F
                    least5 = -(comp + 1)
                }
                offset = least5.asSignedString
            } else {
                offset = "0"
                switch least5 {
                case 0: // direct auto increment by 1
                    registerPostIncrement = "+"
                case 1: // direct auto increment by 2
                    registerPostIncrement = "++"
                case 2: // direct auto decrement by 1
                    registerPreDecrement = "-"
                case 3: // direct auto decrement by 2
                    registerPreDecrement = "--"
                case 4: // direct constant offset from register (2s complement) no offset
                    offset = "0"
                case 5: // direct B accumulator offset from register (2s complement)
                    offset = "B"
                case 6: // direct A accumulator offset from register (2s complement)
                    offset = "A"
                case 8: // direct constant offset from register 8-bit
                    if let value = UInt8(postOperand.description) {
                        offset = Int8(bitPattern: value).asSignedString
                    }
                case 9: // direct constant offset from register 16-bit
                    offset = Int16(bitPattern: UInt16(postOperand.description)!).asSignedString
                case 11: // direct D accumulator offset from register (2s complement)
                    offset = "D"
                case 12: // direct constant offset from program counter 8-bit
                    if var value = Int(postOperand.description) {
                        value = value & 0xFF
                        offset = Int8(bitPattern: UInt8(value)).asSignedString
                    }
                    register = "PC"
                case 13: // direct constant offset from program counter 16-bit
                    if let value = UInt16(postOperand.description) {
                        offset = Int16(bitPattern: value).asSignedString
                    }
                    register = "PC"
                case 20: // indirect constant offset from register (2s complement - no offset) no offset
                    leftBracket = "["
                    rightBracket = "]"
                case 24: // indirect constant offset from register (2s complement - no offset) 8 bit offset
                    leftBracket = "["
                    rightBracket = "]"
                    if var value = Int(postOperand.description) {
                        value = value & 0xFF
                        offset = Int8(bitPattern: UInt8(value)).asSignedString
                    }
                case 25: // indirect constant offset from register (2s complement - no offset) 16 bit offset
                    leftBracket = "["
                    rightBracket = "]"
                    if let value = UInt16(postOperand.description) {
                        offset = Int16(bitPattern: value).asSignedString
                    }
                case 21: // indirect B accumulator offset from register (2s complement offset)
                    leftBracket = "["
                    rightBracket = "]"
                    offset = "B"
                case 22: // indirect A accumulator offset from register (2s complement offset)
                    leftBracket = "["
                    rightBracket = "]"
                    offset = "A"
                case 27: // indirect D accumulator offset from register (2s complement offset)
                    leftBracket = "["
                    rightBracket = "]"
                    offset = "D"
                case 17: // indirect auto increment by 2 from register
                    leftBracket = "["
                    rightBracket = "]"
                    registerPostIncrement = "++"
                case 19: // indirect auto decrement by 2 from register
                    leftBracket = "["
                    rightBracket = "]"
                    registerPreDecrement = "--"
                case 28: // indirect constant offset from program counter 8-bit offset
                    leftBracket = "["
                    rightBracket = "]"
                    offset = Int8(bitPattern: UInt8(postOperand.description)!).asSignedString
                    register = "PC"
                case 29: // indirect constant offset from program counter 16-bit offset
                    leftBracket = "["
                    rightBracket = "]"
                    offset = Int16(bitPattern: UInt16(postOperand.description)!).asSignedString
                    register = "PC"
                case 31: // extended indirect 16-bit address
                    leftBracket = "["
                    rightBracket = "]"
                    if let value = UInt16(postOperand.description) {
                        offset = Int16(bitPattern: value).asSignedString
                    }
                    register = ""
                default:
                    offset = ""
                }
            }

            if register == "" {
                result = leftBracket + offset + rightBracket
            } else {
                result = leftBracket + offset + "," + registerPreDecrement + register + registerPostIncrement + rightBracket
            }

            return result
        }

   }
}
