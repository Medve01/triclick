import CoreFoundation

// Bindings to Apple's private MultitouchSupport framework.
// Linked at build time via -F/System/Library/PrivateFrameworks -framework MultitouchSupport.

typealias MTDeviceRef = UnsafeMutableRawPointer

typealias MTContactCallbackFunction = @convention(c) (
    MTDeviceRef?,
    UnsafeMutableRawPointer?,
    Int32,
    Double,
    Int32
) -> Int32

@_silgen_name("MTDeviceCreateDefault")
func MTDeviceCreateDefault() -> MTDeviceRef?

@_silgen_name("MTDeviceCreateList")
func MTDeviceCreateList() -> Unmanaged<CFArray>?

@_silgen_name("MTDeviceStart")
func MTDeviceStart(_ device: MTDeviceRef, _ mode: Int32)

@_silgen_name("MTDeviceStop")
func MTDeviceStop(_ device: MTDeviceRef)

@_silgen_name("MTDeviceIsRunning")
func MTDeviceIsRunning(_ device: MTDeviceRef) -> Bool

@_silgen_name("MTRegisterContactFrameCallback")
func MTRegisterContactFrameCallback(_ device: MTDeviceRef, _ callback: MTContactCallbackFunction)

@_silgen_name("MTUnregisterContactFrameCallback")
func MTUnregisterContactFrameCallback(_ device: MTDeviceRef, _ callback: MTContactCallbackFunction?)
