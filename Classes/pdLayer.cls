VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "pdLayer"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
'***************************************************************************
'PhotoDemon Image Layer class
'Copyright �2000-2012 by Tanner Helland
'Created: 29/August/12
'Last updated: 29/August/12
'Last update: initial build
'
'The time has come to break PhotoDemon's reliance on picture boxes.  The new plan is to implement an honest-to-God
' DIB class that will manage all image data in memory.  If built correctly, this thing will provide a whole host of
' benefits, including but not limited to:
'
'- Ability to load large images without problems
'- Alpha channels
'- High bit depths
'- Much faster
'- Eventual implementation of layers and adjustment layers
'
'Those are serious benefits.
'
'Implementation will be slow and steady at first.  A rough roadmap is as follows:
'- Get image loading working.  This will require a lot of plumbing to already be in place, but I can't do anything else
' until I can get image data into the class.
'- Get viewport rendering working.  If I can't see the image, I can't work on it.
'- Experiment with tying the class's data into GetImageData, which is already well-implemented throughout PD.
'- Replace PicWidthL and PicHeightL with width/height values provided by this class.
'- Remove all direct intervention with ActiveForm.BackBuffer and force it through this class.  That means no unmanaged
' changing of width, height, etc - it has to come through here.
'
'This class will be a subset of pdImage().  Initially there will only be one layer (the image's data), but in the future,
' assuming this class is written well, a pdImage object could theoretically store many layers.
'
'Let the fun begin.
'
'Note: this work is based off a DIB class written by Herman Liu, which was in turn based off work by Carles PV.
' Many thanks to both these individuals for their outstanding work on graphics in VB.
'
'***************************************************************************

Option Explicit


'DIB Types
Private Type RGBQUAD
    Blue As Byte
    Green As Byte
    Red As Byte
    Alpha As Byte
End Type

Private Type Bitmap
    Type As Long
    Width As Long
    Height As Long
    WidthBytes As Long
    Planes As Integer
    BitsPerPixel As Integer
    Bits As Long
End Type

Private Type BITMAPINFOHEADER
    Size As Long
    Width As Long
    Height As Long
    Planes As Integer
    BitCount As Integer
    Compression As Long
    ImageSize As Long
    XPelsPerMeter As Long
    YPelsPerMeter As Long
    Colorused As Long
    ColorImportant As Long
End Type

Private Type BITMAPINFO
    Header As BITMAPINFOHEADER
    Colors(0 To 255) As RGBQUAD
End Type

'Rectangle type for use with SetRect/FillRect API calls
Private Type RECT
    x1 As Long
    y1 As Long
    x2 As Long
    y2 As Long
End Type

'SafeArray types for pointing VB arrays at arbitrary memory locations (in our case, bitmap data)
'Public Type SAFEARRAYBOUND
'    cElements As Long
'    lBound   As Long
'End Type
'
'Public Type SAFEARRAY2D
'    cDims      As Integer
'    fFeatures  As Integer
'    cbElements As Long
'    cLocks     As Long
'    pvData     As Long
'    Bounds(1)  As SAFEARRAYBOUND
'End Type


'Drawing API functions
Private Declare Function BitBlt Lib "gdi32" (ByVal hDC As Long, ByVal x As Long, ByVal y As Long, ByVal nWidth As Long, ByVal nHeight As Long, ByVal hSrcDC As Long, ByVal xSrc As Long, ByVal ySrc As Long, ByVal dwRop As Long) As Long
Private Declare Function StretchBlt Lib "gdi32" (ByVal hDestDC As Long, ByVal dstX As Long, ByVal dstY As Long, ByVal dstWidth As Long, ByVal dstHeight As Long, ByVal hSrcDC As Long, ByVal SrcX As Long, ByVal SrcY As Long, ByVal SrcWidth As Long, ByVal SrcHeight As Long, ByVal rastOp As Long) As Long
Private Declare Function SetStretchBltMode Lib "gdi32" (ByVal hDestDC As Long, ByVal nStretchMode As Long) As Long
Private Const STRETCHBLT_COLORONCOLOR As Long = 3
Private Const STRETCHBLT_HALFTONE As Long = 4

'SafeArray API functions
Private Declare Function VarPtrArray Lib "msvbvm60" Alias "VarPtr" (Ptr() As Any) As Long
Private Declare Sub CopyMemory Lib "kernel32" Alias "RtlMoveMemory" (lpDst As Any, lpSrc As Any, ByVal byteLength As Long)

'DIB API functions
' (Note that these are currently declared in FastDrawing as well)
Private Declare Function CreateDIBSection Lib "gdi32" (ByVal hDC As Long, lpBitsInfo As BITMAPINFOHEADER, ByVal wUsage As Long, lpBits As Long, ByVal Handle As Long, ByVal dw As Long) As Long
Private Declare Function GetObject Lib "gdi32" Alias "GetObjectA" (ByVal hObject As Long, ByVal nCount As Long, ByRef lpObject As Any) As Long
Private Declare Function GetDIBits Lib "gdi32" (ByVal aHDC As Long, ByVal hBitmap As Long, ByVal nStartScan As Long, ByVal nNumScans As Long, lpBits As Any, lpBI As BITMAPINFO, ByVal wUsage As Long) As Long
Private Declare Function StretchDIBits Lib "gdi32" (ByVal hDC As Long, ByVal x As Long, ByVal y As Long, ByVal dx As Long, ByVal dy As Long, ByVal SrcX As Long, ByVal SrcY As Long, ByVal wSrcWidth As Long, ByVal wSrcHeight As Long, lpBits As Any, lpBitsInfo As BITMAPINFO, ByVal wUsage As Long, ByVal dwRop As Long) As Long

'DC API functions
Private Declare Function CreateCompatibleDC Lib "gdi32" (ByVal hDC As Long) As Long
Private Declare Function DeleteDC Lib "gdi32" (ByVal hDC As Long) As Long
Private Declare Function ReleaseDC Lib "user32" (ByVal HWnd As Long, ByVal hDC As Long) As Long

'Object API functions
Private Const OBJ_BITMAP As Long = 7
Private Declare Function DeleteObject Lib "gdi32" (ByVal hObject As Long) As Long
Private Declare Function GetObjectType Lib "gdi32" (ByVal hgdiobj As Long) As Long
Private Declare Function SelectObject Lib "gdi32" (ByVal hDC As Long, ByVal hObject As Long) As Long

'Rectangle objects to be used with brushes
Private Declare Function SetRect Lib "user32" (lpRect As RECT, ByVal x1 As Long, ByVal y1 As Long, ByVal x2 As Long, ByVal y2 As Long) As Long
Private Declare Function FillRect Lib "user32" (ByVal hDC As Long, lpRect As RECT, ByVal hBrush As Long) As Long

'Brush creation
Private Declare Function CreateSolidBrush Lib "gdi32" (ByVal crColor As Long) As Long


'Variables related to the DIB
'hDC for this layer
Private layerDC As Long
'DIB handle for this layer
Private layerDIB As Long
'Original handle when this layer is first created (we must store this so we can properly clean up the DIB when we're finished)
Private layerDIBOriginal As Long
'Pointer to the actual DIB bits
Private layerDIBits As Long
'Persistent DIB header; this will be used to create the DIB associated with this layer
Private layerDIBHeader As BITMAPINFOHEADER

'An StdPicture associated with this layer (may or may not be used)
'Private layerPicture As StdPicture

'The layer's width and height
Private layerWidth As Long, layerHeight As Long

'The layer's array width (layerWidth * 4 for 32-bit, varies for 24-bit due to DWORD-alignment)
Private layerArrayWidth As Long

'The layer's color depth (should only ever be 24 or 32)
Private layerColorDepth As Long

'Return this layer's color depth
Public Function getLayerColorDepth() As Long
    getLayerColorDepth = layerColorDepth
End Function

'Return this layer's array width
Public Function getLayerArrayWidth() As Long
    getLayerArrayWidth = layerArrayWidth
End Function

'Return this layer's width
Public Function getLayerWidth() As Long
    getLayerWidth = layerWidth
End Function

'Return this layer's height
Public Function getLayerHeight() As Long
    getLayerHeight = layerHeight
End Function

'Return whether or not this layer has image data associated with it
Public Function hasImage() As Boolean
    hasImage = (layerDIB <> 0)
End Function

Public Function getLayerDC() As Long
    getLayerDC = layerDC
End Function

Public Function getLayerDIBits() As Long
    getLayerDIBits = layerDIBits
End Function

'Make a copy of an existing layer
Public Function createFromExistingLayer(ByRef srcLayer As pdLayer, Optional ByVal newWidth As Long = -1, Optional ByVal newHeight As Long = -1) As Boolean

    'Make sure the layer we're passed isn't empty
    If srcLayer.getLayerDC <> 0 Then
    
        'Prepare new width and height values as requested by the user
        If newWidth = -1 Then newWidth = srcLayer.getLayerWidth
        If newHeight = -1 Then newHeight = srcLayer.getLayerHeight
        
        'If the width and height values are not being changed, the transfer is simple
        If (newWidth = srcLayer.getLayerWidth) And (newHeight = srcLayer.getLayerHeight) Then
        
            'Create a new, blank DIB the same size as the source layer
            If createBlank(srcLayer.getLayerWidth, srcLayer.getLayerHeight, srcLayer.getLayerColorDepth) Then
                'Copy the image data without modification
                BitBlt layerDC, 0, 0, layerWidth, layerHeight, srcLayer.getLayerDC, 0, 0, vbSrcCopy
                createFromExistingLayer = True
                Exit Function
            End If
        
        'If new width and height values are being specified, the transfer is a bit more complex
        Else
        
            'Create a new, blank DIB at the requested size
            If createBlank(newWidth, newHeight, srcLayer.getLayerColorDepth) Then

                'If either dimension of the new image will be smaller than the source, request halftoning
                If (newWidth < srcLayer.getLayerWidth) Or (newHeight < srcLayer.getLayerHeight) Then
                    SetStretchBltMode layerDC, STRETCHBLT_HALFTONE
                Else
                    SetStretchBltMode layerDC, STRETCHBLT_COLORONCOLOR
                End If

                'Resize and copy the image data
                StretchBlt layerDC, 0, 0, newWidth, newHeight, srcLayer.getLayerDC, 0, 0, srcLayer.getLayerWidth, srcLayer.getLayerHeight, vbSrcCopy
                createFromExistingLayer = True
                Exit Function
                        
            End If
        
        End If
            
        createFromExistingLayer = False
    
    End If
    
    createFromExistingLayer = False

End Function

'Give this layer a picture from a standard VB picture object
Public Function CreateFromPicture(ByRef srcPicture As StdPicture) As Boolean

    'Make sure the picture we're passed isn't empty
    If (Not srcPicture Is Nothing) Then
    
        'Make sure the picture is actually a picture
        If GetObjectType(srcPicture) = OBJ_BITMAP Then
        
            'Select the picture's attributes into a bitmap object
            Dim tmpBitmap As Bitmap
            GetObject srcPicture.Handle, Len(tmpBitmap), tmpBitmap
            
            'Use that bitmap object to create a new, blank DIB of the same size
            If createBlank(tmpBitmap.Width, tmpBitmap.Height) Then
            
                'Create a new DC
                Dim TmpDC As Long
                TmpDC = CreateCompatibleDC(0)
                
                'If successful, select the object into that DC
                If TmpDC <> 0 Then
                
                    'Temporary holder for the object selection
                    Dim oldBitmap As Long
                    oldBitmap = SelectObject(TmpDC, srcPicture.Handle)
                    
                    'Use BitBlt to copy the pixel data to this layer
                    BitBlt layerDC, 0, 0, layerWidth, layerHeight, TmpDC, 0, 0, vbSrcCopy
                    
                    'Now that we have the pixel data, erase all temporary objects
                    SelectObject TmpDC, oldBitmap
                    DeleteDC TmpDC
                
                    'Success!
                    CreateFromPicture = True
                    Exit Function
                    
                End If
            
                CreateFromPicture = False
            
            End If
            
            CreateFromPicture = False
        
        End If
        
        CreateFromPicture = False
    
    End If
    
    CreateFromPicture = False

End Function

' Simplified and for 24 or 32-BPP only
Public Function createBlank(ByVal iWidth As Long, ByVal iHeight As Long, Optional ByVal colorDepth As Long = 24, Optional ByVal BackColor As Long = vbWhite) As Boolean
    
    'Erase any existing layer data
    eraseLayer
    
    'PhotoDemon only supports 24 and 32 BPP at present
    If colorDepth <> 32 And colorDepth <> 24 Then
        colorDepth = 24
    End If
    
    'Remember this color depth, width, and height
    layerColorDepth = colorDepth
    layerWidth = iWidth
    layerHeight = iHeight
    
    'Prepare the required header
    With layerDIBHeader
        .Size = Len(layerDIBHeader)
        .Planes = 1
        'This could be 24; for now, I'm using only 32 as part of the test implementation
        .BitCount = colorDepth
        .Width = iWidth
        .Height = -iHeight
        'As always, this value needs to be a multiple of four; with 32bpp that's automatic, with 24bpp it is not
        If colorDepth = 32 Then
            layerArrayWidth = 4 * iWidth
        Else
            layerArrayWidth = (iWidth * 3 + 3) And &HFFFFFFFC
        End If
        .ImageSize = layerArrayWidth * iHeight
    End With
    
    'Create a new DC for use with this layer
    layerDC = CreateCompatibleDC(0)
    
    If layerDC <> 0 Then
        
        'Create a DIB
        layerDIB = CreateDIBSection(layerDC, layerDIBHeader, 0, layerDIBits, 0, 0)
        
        'If successful, select the newly created dib into our DC
        If layerDIB <> 0 Then
        
            'We will later use layerDIBOriginal to clear up the memory associated with this layer
            layerDIBOriginal = SelectObject(layerDC, layerDIB)
            
            'Finally, set the backColor
            Dim layerRect As RECT
            SetRect layerRect, 0, 0, iWidth, iHeight
            
            Dim hBrush As Long
            hBrush = CreateSolidBrush(BackColor)
            FillRect layerDC, layerRect, hBrush
            DeleteObject hBrush
        
        'If DIB creation failed, clear out the work we've done so far
        Else
            eraseLayer
        End If
        
    End If
    
    'Return success contingent on whether we have a DIB pointer or not
    createBlank = (layerDIB <> 0)
    
End Function

'This will effectively reset everything related to this layer, including image data.  Use cautiously!
Public Function eraseLayer()

    'If we have image data, clear it out
    If layerDC <> 0 Then
        If layerDIB <> 0 Then
            SelectObject layerDC, layerDIBOriginal
            DeleteObject layerDIB
        End If
        DeleteDC layerDC
    End If

    'Reset all associated DIB section variables
    layerDC = 0
    layerDIB = 0
    layerDIBOriginal = 0
    layerDIBits = 0

    'Reset layer size
    layerWidth = 0
    layerHeight = 0

End Function

'INITIALIZE class
Private Sub Class_Initialize()

    'Reset all associated DIB section variables
    layerDC = 0
    layerDIB = 0
    layerDIBOriginal = 0
    layerDIBits = 0
    
    'Reset layer size
    layerWidth = 0
    layerHeight = 0
    
End Sub

'TERMINATE class
Private Sub Class_Terminate()
    eraseLayer
End Sub