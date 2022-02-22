

import UIKit
import AVFoundation

public enum CameraPosition {
    case front
    case back
}

public protocol ScannerViewDelegate {
    func cancelButtonTapped(controller: ScannerView)
    func barcodeReadValue(controller: ScannerView, resultValue: String)
}


public final class ScannerView: UIViewController {
    
    private let scannerQueue = DispatchQueue(label: "Scanner Queue")
    private let metadataScannerQueue = DispatchQueue(label: "Metadata Scanner Queue")
    
    private var captureSession: AVCaptureSession
    private var captureDevice: AVCaptureDevice?
    public var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    private var output: AVCaptureMetadataOutput?
    
    public var delegate: ScannerViewDelegate?
    //comment
    
    private var _cancelButton: UIButton?
    private var _scannerBox: UIView?
    
    var cancelButton: UIButton {
        if let currentButton = _cancelButton {
            return currentButton
        }
        let button = UIButton(frame: CGRect(x: self.view.frame.minX, y: self.view.frame.minY + 50, width: 80, height: 30))
        button.setTitle("Cancel", for: .normal)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5);
        button.setTitleColor(UIColor.white, for: UIControl.State.normal)
        button.layer.borderWidth = 0.8
        button.layer.borderColor = UIColor.white.cgColor
        button.layer.cornerRadius = 0.5;
        button.tag = 98
        button.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        _cancelButton = button
        return button
    }
    
    var scannerBox: UIView {
        if let scannerBox = _scannerBox {
            return scannerBox
        }
        let scanBox = UIView(frame: CGRect.zero)
        _scannerBox = scanBox
        return scanBox
    }
    
    deinit {
        captureSession.stopRunning()
        videoPreviewLayer?.removeFromSuperlayer()
        delegate = nil
        
        if let output = output {
            captureSession.removeOutput(output)
        }
    }
    
    public init() {
        self.captureSession = AVCaptureSession()
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        self.view.addSubview(self.cancelButton)
        self.view.bringSubviewToFront(self.cancelButton)
        self.view.addSubview(self.scannerBox)
        self.view.addSubview(self.scannerBox)
        //self.view.updateConstraintsIfNeeded()
        // Do any additional setup after loading the view.
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        prepareCamera(orientation: .portrait)
    }
    
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        print("viewDidLayoutSubviews");
        //
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("viewWillDisappear");
        self.stopCapturing()
    }
    
    func shouldAutorotate() -> Bool {
        if (UIDevice.current.orientation == UIDeviceOrientation.portraitUpsideDown) {
            return false
        }else {
            return true
        }
    }
    
    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        if (UIDevice.current.orientation == UIDeviceOrientation.landscapeLeft || UIDevice.current.orientation == UIDeviceOrientation.landscapeRight){
            videoPreviewLayer.connection?.videoOrientation = .landscapeRight;
            let btnCancel = self.view.viewWithTag(98)
            btnCancel?.frame = CGRect(x: self.view.frame.minX, y: self.view.frame.minY + 50, width: 80, height: 30)
        }else if (UIDevice.current.orientation == UIDeviceOrientation.portrait) {
            videoPreviewLayer.connection?.videoOrientation = .portrait;
            let btnCancel = self.view.viewWithTag(98)
            btnCancel?.frame = CGRect(x: self.view.frame.minX, y: self.view.frame.minY + 50, width: 80, height: 30)
        }
        DispatchQueue.main.async {
            self.insertPreviewLayer()
            self.layoutFrames()
        }
    }
    
    /// prepareCamera method should be executed only when delegate is set.
    private func prepareCamera(orientation: AVCaptureVideoOrientation) {
        self.scannerQueue.async {
            self.prepareVideoPreviewLayer(orientation: orientation)
            self.setupSessionInput(for: .back)
            self.setupSessionOutput()
            
            DispatchQueue.main.async {
                self.insertPreviewLayer()
                self.layoutFrames()
                self.startCapturing()
            }
        }
    }
    
    /// Initialize the video preview layer and set its videoGravity
    public func prepareVideoPreviewLayer(orientation: AVCaptureVideoOrientation) {
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer.connection?.videoOrientation = orientation;
    }
    
    /// Layout videoPreviewLayer. This method should be executed in main thread.
    func layoutFrames() {
        self.videoPreviewLayer.frame = self.view.bounds
        self.view.setNeedsLayout()
    }
    
    public func insertPreviewLayer() {
        self.view.layer.insertSublayer(self.videoPreviewLayer, at: 0)
    }
    
    /**
     Setup instance of the AVCaptureDevice class to initialize a device object
     and provide the video as the media type parameter.
     */
    private func setupSessionInput(for position: CameraPosition) {
        // Get an instance of the AVCaptureDeviceInput class using the previous device object.
        guard let device = AVCaptureDevice.default(for: .video) else {
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            try device.lockForConfiguration()
            captureSession.beginConfiguration()
            
            // autofocus settings and focus on middle point
            device.autoFocusRangeRestriction = .near
            device.focusMode = .continuousAutoFocus
            device.exposureMode = .continuousAutoExposure
            
            if let currentInput = captureSession.inputs.filter({$0 is AVCaptureDeviceInput}).first {
                captureSession.removeInput(currentInput)
            }
            
            // Set the input device on the capture session.
            
            if device.supportsSessionPreset(.hd4K3840x2160) == true {
                captureSession.sessionPreset = .hd4K3840x2160
            } else if device.supportsSessionPreset(.high) == true {
                captureSession.sessionPreset = .high
            }
            
            captureSession.usesApplicationAudioSession = false
            captureSession.addInput(input)
            captureSession.commitConfiguration()
            device.unlockForConfiguration()
            captureDevice = device
            
        } catch(let error) {
            print(error.localizedDescription)
            return
        }
    }
    
    private func setupSessionOutput() {
        let captureOutput = AVCaptureMetadataOutput()
        captureSession.addOutput(captureOutput)
        captureOutput.setMetadataObjectsDelegate(self, queue: metadataScannerQueue)
        captureOutput.metadataObjectTypes = captureOutput.availableMetadataObjectTypes
        output = captureOutput
    }
    
    // MARK: - Open functions to use framework
    public func startCapturing() {
        self.scannerQueue.async {
            self.captureSession.startRunning()
        }
    }
    
    public func stopCapturing() {
        scannerQueue.async {
            self.captureSession.stopRunning()
        }
    }
}

extension ScannerView: AVCaptureMetadataOutputObjectsDelegate {
    
    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        if metadataObjects.count == 0{
            scannerBox.frame = CGRect.zero
            return
        }
        
        for obj in metadataObjects {
            let metadataObj = videoPreviewLayer?.transformedMetadataObject(for: obj)
            scannerBox.frame = metadataObj!.bounds
            scannerBox.layer.borderColor = UIColor.red.cgColor
            scannerBox.layer.borderWidth = 2
            guard let text = (obj as? AVMetadataMachineReadableCodeObject)?.stringValue else { return }
            
            stopCapturing()
            DispatchQueue.main.async {
                if let delegate = self.delegate {
                    delegate.barcodeReadValue(controller: self, resultValue: text)
                }
            }
        }
    }
}


// MARK: UIButton functions

fileprivate extension ScannerView {
    @objc func cancelButtonTapped() {
        if let delegate = self.delegate {
            delegate.cancelButtonTapped(controller: self)
        }
    }
}
