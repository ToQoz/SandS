import Cocoa

class Event {
    let cgEvent: CGEvent
    let keyCode: CGKeyCode
    var flags: CGEventFlags {
        return cgEvent.flags
    }

    init(_ event: CGEvent) {
        self.cgEvent = event
        self.keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
    }

    func isSpace() -> Bool {
        return keyCode == 49
    }

    func isNonCoalescedSpace() -> Bool {
        return isSpace() && flags.rawValue == CGEventFlags.maskNonCoalesced.rawValue
    }
}

enum Mode {
    case Normal
    case SandS
    case Shift
    case Space
}

class Interceptor: NSObject {
    private var mode: Mode = .Normal

    func intercept(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case CGEventType.keyDown:
            return interceptKeyDown(Event(event))
        case CGEventType.keyUp:
            return interceptKeyUp(Event(event))
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    func interceptKeyDown(_ event: Event) -> Unmanaged<CGEvent>? {
        if (event.isNonCoalescedSpace()) {
            switch (self.mode) {
            case .Normal:
                self.mode = .SandS
                return nil
            case .SandS, .Shift:
                return nil
            case .Space:
                self.mode = .Normal
                return Unmanaged.passUnretained(event.cgEvent)
            }
        } else {
            switch (self.mode) {
            case .Normal, .Space:
                self.mode = .Normal
            case .SandS, .Shift:
                self.mode = .Shift
                event.cgEvent.setIntegerValueField(.keyboardEventKeycode, value: Int64(event.keyCode))
                event.cgEvent.flags = CGEventFlags(
                    rawValue: event.flags.rawValue | CGEventFlags.maskShift.rawValue
                )
            }
            
            return Unmanaged.passUnretained(event.cgEvent)
        }
    }

    func interceptKeyUp(_ event: Event) -> Unmanaged<CGEvent>? {
        if (!event.isSpace()) {
            return Unmanaged.passUnretained(event.cgEvent)
        }
        
        switch (self.mode) {
        case .Normal:
            break
        case .SandS:
            self.mode = .Space

            let spaceKeyUp = event.cgEvent.copy()!
            spaceKeyUp.type = .keyUp
            let spaceKeyDown = event.cgEvent.copy()!
            spaceKeyDown.type = .keyDown

            spaceKeyDown.post(tap: CGEventTapLocation.cghidEventTap)
            spaceKeyUp.post(tap: CGEventTapLocation.cghidEventTap)
        case .Shift:
            self.mode = .Normal
        case .Space:
            break
        }
        
        return Unmanaged.passUnretained(event.cgEvent)
    }
}
