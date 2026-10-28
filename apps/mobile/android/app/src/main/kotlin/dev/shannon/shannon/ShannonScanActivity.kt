package dev.shannon.shannon

// CaptureActivity owns permission requests, live camera preview, autofocus,
// pause/resume, and camera release. It never uploads frames or saves scan images.
class ShannonScanActivity : com.journeyapps.barcodescanner.CaptureActivity()
