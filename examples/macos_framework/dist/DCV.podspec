Pod::Spec.new do |s|
    s.name             = 'DCV'
    s.version          = '1.0.1'
    s.summary          = 'macOS barcode reading framework.'
  
    s.description      = <<-DESC
    DCV is a versatile framework designed for barcode reading. It is built with Dynamsoft Barcode Reader C++ SDK. The framework supports various barcode types, including Code 39, Code 128, QR Code, DataMatrix, PDF417, etc.
    DESC
  
    s.homepage         = 'https://github.com/yushulx/ios-swiftui-barcode-mrz-document-scanner/tree/main/examples/macos_framework'
    s.license = { :type => 'MIT', :file => File.expand_path('LICENSE') }
    s.author           = { 'yushulx' => 'lingxiao1002@gmail.com' }
    s.source           = { :http => 'https://github.com/yushulx/ios-swiftui-barcode-mrz-document-scanner/raw/refs/heads/main/examples/macos_framework/dist/DCV.framework.zip' }
  
    s.macos.deployment_target = '10.13'
    s.vendored_frameworks = 'DCV.framework'
  
    s.frameworks = ['Foundation']
    s.requires_arc = true
  end
  