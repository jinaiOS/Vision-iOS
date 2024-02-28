//
//  ViewController.swift
//  VisionPractice-iOS
//
//  Created by 김지은 on 2/27/24.
//

import UIKit
import AVFoundation
import VisionKit
import Vision

class ViewController: UIViewController {
    
    @IBOutlet weak var vBackground: UIView!
    @IBOutlet weak var vScanner: UIView!
    
    var captureSession = AVCaptureSession()
    var videoPreviewLayer = AVCaptureVideoPreviewLayer()
    var photoFileOutput = AVCapturePhotoOutput()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setCamera()
    }
    
    func setCamera() {
        self.captureSession = AVCaptureSession()
        self.captureSession.beginConfiguration()
        
        // AVCaptureSession 설정
        guard let videoDevice = AVCaptureDevice.default(for: AVMediaType.video),
              let photoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            // Error handling
            return
        }
        
        self.photoFileOutput = AVCapturePhotoOutput()
        
        self.captureSession.addInput(photoInput)
        self.captureSession.sessionPreset = .hd1280x720
        self.captureSession.addOutput(self.photoFileOutput)
        self.captureSession.commitConfiguration()
        
        self.setPreviewCamera()
    }
    
    func setPreviewCamera() {
        //preview
        self.videoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
        DispatchQueue.main.async {
            self.videoPreviewLayer.frame = self.vScanner.bounds
        }
        self.videoPreviewLayer.videoGravity = .resizeAspectFill
        DispatchQueue.main.async {
            self.vScanner.layer.addSublayer(self.videoPreviewLayer)
        }
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
    }
    
    @IBAction func captureButtonPressed(_ sender: Any) {
        let settings = AVCapturePhotoSettings()
        self.photoFileOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension ViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let imageData = photo.fileDataRepresentation(), let capturedImage = UIImage(data: imageData) {
            recognizeText(image: capturedImage)
        } else {
            // 이미지 데이터를 가져오지 못한 경우 에러 처리
            print("Error capturing photo: \(error?.localizedDescription ?? "Unknown error")")
        }
    }
    
    fileprivate func recognizeText(image: UIImage?){
            guard let cgImage = image?.cgImage else {
                fatalError("could not get image")
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest{ [weak self]request, error in
                
                let creditCardNumberPattern = "(\\\\d[ -]*?){15,19}"
                let expireDatePattern = "([0-9]{2}\\\\/[0-9]{2})"
                var creditCard = CreditCardInfo(number: nil, expireDate: nil)
                guard let observations = request.results as? [VNRecognizedTextObservation],
                      error == nil else{
                    return
                }
                
                let text = observations.compactMap({
                    $0.topCandidates(1).first?.string
                }).joined(separator: "\n")

                if let range = text.range(of: creditCardNumberPattern, options: .regularExpression) {
                    creditCard.number = String(text[range])
                        .replacingOccurrences(of: " ", with: "")
                        .replacingOccurrences(of: "-", with: "")
                } else if let range = text.range(of: expireDatePattern, options: .regularExpression) {
                    creditCard.expireDate = String(text[range])
                }
            }
       
            if #available(iOS 16.0, *) {
                let revision3 = VNRecognizeTextRequestRevision3
                request.revision = revision3
                request.recognitionLevel = .accurate
//                request.recognitionLanguages =  [commonVisionLang]
                request.usesLanguageCorrection = true

                do {
                    var possibleLanguages: Array<String> = []
                    possibleLanguages = try request.supportedRecognitionLanguages()
                    print(possibleLanguages)
                } catch {
                    print("Error getting the supported languages.")
                }
            } else {
                // Fallback on earlier versions
                request.recognitionLanguages =  ["en-US"]
                request.usesLanguageCorrection = true
            }
        
            do{
                try handler.perform([request])
            } catch {
//                label.text = "\(error)"
                print(error)
            }
        }
}
struct CreditCardInfo {
    var number: String
    var expireDate: String
    
    init(number: String?, expireDate: String?) {
        self.number = number ?? ""
        self.expireDate = expireDate ?? ""
        guard let number = number, let expireDate = expireDate else {
            return
        }
        print(number, expireDate)
    }
}
