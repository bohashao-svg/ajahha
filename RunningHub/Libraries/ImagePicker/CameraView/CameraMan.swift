import Foundation
import AVFoundation
import PhotosUI

protocol CameraManDelegate: AnyObject {
  func cameraManNotAvailable(_ cameraMan: CameraMan)
  func cameraManDidStart(_ cameraMan: CameraMan)
  func cameraMan(_ cameraMan: CameraMan, didChangeInput input: AVCaptureDeviceInput)
}

class CameraMan: NSObject {
  weak var delegate: CameraManDelegate?

  let session = AVCaptureSession()
  let queue = DispatchQueue(label: "no.hyper.ImagePicker.Camera.SessionQueue")

  var backCamera: AVCaptureDeviceInput?
  var frontCamera: AVCaptureDeviceInput?
  var photoOutput: AVCapturePhotoOutput?
  var startOnFrontCamera: Bool = false
  var pendingPhotoCompletion: (() -> Void)?
  var pendingLocation: CLLocation?

  deinit { stop() }

  // MARK: - Setup

  func setup(_ startOnFrontCamera: Bool = false) {
    self.startOnFrontCamera = startOnFrontCamera
    checkPermission()
  }

  func setupDevices() {
    // AVCaptureDevice.devices() 已废弃，改用 AVCaptureDeviceDiscoverySession
    let discoverySession = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.builtInWideAngleCamera],
      mediaType: .video,
      position: .unspecified
    )
    discoverySession.devices.forEach {
      switch $0.position {
      case .front: self.frontCamera = try? AVCaptureDeviceInput(device: $0)
      case .back:  self.backCamera  = try? AVCaptureDeviceInput(device: $0)
      default: break
      }
    }
    photoOutput = AVCapturePhotoOutput()
  }

  func addInput(_ input: AVCaptureDeviceInput) {
    configurePreset(input)
    if session.canAddInput(input) {
      session.addInput(input)
      DispatchQueue.main.async { self.delegate?.cameraMan(self, didChangeInput: input) }
    }
  }

  // MARK: - Permission

  func checkPermission() {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:     start()
    case .notDetermined:  requestPermission()
    default:              delegate?.cameraManNotAvailable(self)
    }
  }

  func requestPermission() {
    AVCaptureDevice.requestAccess(for: .video) { granted in
      DispatchQueue.main.async {
        granted ? self.start() : self.delegate?.cameraManNotAvailable(self)
      }
    }
  }

  // MARK: - Session

  var currentInput: AVCaptureDeviceInput? { session.inputs.first as? AVCaptureDeviceInput }

  fileprivate func start() {
    setupDevices()
    guard let input = (startOnFrontCamera ? frontCamera ?? backCamera : backCamera),
          let output = photoOutput else { return }
    addInput(input)
    if session.canAddOutput(output) { session.addOutput(output) }
    queue.async {
      self.session.startRunning()
      DispatchQueue.main.async { self.delegate?.cameraManDidStart(self) }
    }
  }

  func stop() { session.stopRunning() }

  func switchCamera(_ completion: (() -> Void)? = nil) {
    guard let currentInput else { completion?(); return }
    queue.async {
      guard let input = (currentInput == self.backCamera) ? self.frontCamera : self.backCamera
      else { DispatchQueue.main.async { completion?() }; return }
      self.configure { self.session.removeInput(currentInput); self.addInput(input) }
      DispatchQueue.main.async { completion?() }
    }
  }

  func takePhoto(_ previewLayer: AVCaptureVideoPreviewLayer, location: CLLocation?, completion: (() -> Void)? = nil) {
    guard let output = photoOutput,
          let connection = output.connection(with: .video) else { return }
    connection.videoOrientation = Helper.videoOrientation()
    pendingPhotoCompletion = completion
    pendingLocation = location
    let settings = AVCapturePhotoSettings()
    queue.async { output.capturePhoto(with: settings, delegate: self) }
  }

  func savePhoto(_ image: UIImage, location: CLLocation?, completion: (() -> Void)? = nil) {
    PHPhotoLibrary.shared().performChanges({
      let req = PHAssetChangeRequest.creationRequestForAsset(from: image)
      req.creationDate = Date()
      req.location = location
    }) { _, _ in DispatchQueue.main.async { completion?() } }
  }

  func flash(_ mode: AVCaptureDevice.FlashMode) {
    guard let device = currentInput?.device,
          device.isFlashAvailable else { return }
    queue.async { self.lock { device.torchMode = mode == .on ? .on : .off } }
  }

  func focus(_ point: CGPoint) {
    guard let device = currentInput?.device,
          device.isFocusModeSupported(.locked) else { return }
    queue.async { self.lock { device.focusPointOfInterest = point } }
  }

  func zoom(_ zoomFactor: CGFloat) {
    guard let device = currentInput?.device, device.position == .back else { return }
    queue.async { self.lock { device.videoZoomFactor = zoomFactor } }
  }

  func lock(_ block: () -> Void) {
    if let device = currentInput?.device, (try? device.lockForConfiguration()) != nil {
      block(); device.unlockForConfiguration()
    }
  }

  func configure(_ block: () -> Void) {
    session.beginConfiguration(); block(); session.commitConfiguration()
  }

  func configurePreset(_ input: AVCaptureDeviceInput) {
    for asset in preferredPresets() {
      let preset = AVCaptureSession.Preset(rawValue: asset)
      if input.device.supportsSessionPreset(preset) && session.canSetSessionPreset(preset) {
        session.sessionPreset = preset; return
      }
    }
  }

  func preferredPresets() -> [String] {
    [AVCaptureSession.Preset.high.rawValue,
     AVCaptureSession.Preset.medium.rawValue,
     AVCaptureSession.Preset.low.rawValue]
  }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraMan: AVCapturePhotoCaptureDelegate {
  func photoOutput(_ output: AVCapturePhotoOutput,
                   didFinishProcessingPhoto photo: AVCapturePhoto,
                   error: Error?) {
    let completion = pendingPhotoCompletion
    let location  = pendingLocation
    pendingPhotoCompletion = nil
    pendingLocation = nil

    guard error == nil,
          let data  = photo.fileDataRepresentation(),
          let image = UIImage(data: data) else {
      DispatchQueue.main.async { completion?() }
      return
    }
    savePhoto(image, location: location, completion: completion)
  }
}
