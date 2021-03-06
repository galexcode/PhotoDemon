VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "pdICCProfile"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
'***************************************************************************
'PhotoDemon ICC (International Color Consortium) Profile Manager
'Copyright �2012-2013 by Tanner Helland
'Created: 05/November/13
'Last updated: 05/November/13
'Last update: moved a bunch of code to the new Color_Management module.  Certain ICC Profile actions (like loading and
'              validating profiles) will need to be handled for both raw image data, and destination DCs (like forms
'              and preview picture boxes), so it made sense to abstract some functions away from this per-image class.
'
'ICC profiles can be embedded in certain types of images (JPEG, PNG, and TIFF at the time of this writing).  These
' profiles can be used to convert an image to its true color space, taking into account any pecularities of the
' device that captured the image (typically a camera), and the device now being used to display the image
' (typically a monitor).
'
'ICC profile handling is broken into two parts: extracting the profile from an image, then applying that profile
' to the image.  The extraction step is currently handled via FreeImage or GDI+, while the application step is handled
' by Windows.  In the future I may look at adding ExifTool as a possibly mechanism for extracting the profile, as it
' provides better support for esoteric formats than FreeImage.
'
'Note that this class retains a copy of the ICC Profile itself, which is typically a ~1-5k byte array.  In the future
' I may add support for attaching a new profile to an image, or for exporting a profile to file.
'
'Also note that this class interacts heavily with the Color_Management module.
'
'This class would not be possible without this excellent test code from pro VB coder LaVolpe:
' http://www.vbforums.com/showthread.php?666143-RESOLVED-ICC-%28Color-Profiles%29
' Note that LaVolpe's code contains a number of errors, so if you're looking to build your own ICC implementation,
' I suggest basing it off my implementation instead.
'
'All source code in this file is licensed under a modified BSD license.  This means you may use the code in your own
' projects IF you provide attribution.  For more information, please visit http://photodemon.org/about/license/
'
'***************************************************************************

Option Explicit

'If we are able to successfully load an ICC profile for this image, this will be set to TRUE.
Private iccDataPresent As Boolean

'The actual ICC Profile is stored in this array
Private iccData() As Byte

'CopyMemory is used to shuttle around ICC data in memory
Private Declare Sub CopyMemory Lib "kernel32" Alias "RtlMoveMemory" (ByRef lpDestination As Any, ByRef lpSource As Any, ByVal Length As Long)

'If an ICC profile is present, apply it to the parent pdImage object.  The parent must be explicitly passed, as this
' small class does not maintain a persistent link on its own.
Public Function applyICCtoParentImage(ByRef parentPDImage As pdImage) As Boolean

    'Before doing anything else, make sure we actually have an ICC profile to apply!
    If Not iccDataPresent Then
        Message "ICC transform requested, but no data found.  Abandoning attempt."
        Exit Function
    End If
    
    Message "Using embedded ICC profile to convert image to sRGB space for editing..."
    
    'Use the Color_Management module to convert the raw ICC profile into an internal Windows profile handle.  Note that
    ' this function will also validate the profile for us.
    Dim srcProfile As Long
    srcProfile = loadICCProfileFromMemory(VarPtr(iccData(0)), UBound(iccData) + 1)
    
    'If we successfully opened and validated our source profile, continue on to the next step!
    If srcProfile <> 0 Then
    
        'Now it is time to determine our destination profile.  Because PhotoDemon operates on DIBs that default
        ' to the sRGB space, that's the profile we want to use for transformation.
            
        'Use the Color_Management module to request a standard sRGB profile.
        Dim dstProfile As Long
        dstProfile = loadStandardICCProfile(LCS_sRGB)
        
        'It's highly unlikely that a request for a standard ICC profile will fail, but just be safe, double-check the
        ' returned handle before continuing.
        If dstProfile <> 0 Then
            
            'We can now use our profile matrix to generate a transformation object, which we will use to directly modify
            ' the DIB's RGB values.
            Dim iccTransformation As Long
            iccTransformation = requestProfileTransform(srcProfile, dstProfile, INTENT_PERCEPTUAL)
            
            'If the transformation was generated successfully, carry on!
            If iccTransformation <> 0 Then
                
                'The only transformation function relevant to PD involves the use of BitmapBits, so we will provide
                ' the API with direct access to our DIB bits.
                
                'Note that a color format must be explicitly specified - we vary this contingent on the parent image's
                ' color depth.
                Dim transformCheck As Boolean
                transformCheck = applyColorTransformToLayer(iccTransformation, parentPDImage.getActiveLayer)
                
                'If the transform was successful, pat ourselves on the back.
                If transformCheck Then
                    Message "ICC profile transformation successful.  Image is now sRGB."
                Else
                    Message "ICC profile could not be applied.  Image remains in original profile."
                End If
                
                'Release our transformation
                releaseColorTransform iccTransformation
                                
            Else
                Message "Both ICC profiles loaded successfully, but transformation could not be created."
                applyICCtoParentImage = False
            End If
        
            releaseICCProfile dstProfile
        
        Else
            Message "Could not obtain standard sRGB color profile.  Color management has been disabled for this image."
            applyICCtoParentImage = False
        End If
        
        releaseICCProfile srcProfile
    
    Else
        Message "Embedded ICC profile is invalid.  Color management has been disabled for this image."
        applyICCtoParentImage = False
    End If
    
End Function

'At load-time, while a FreeImage handle is still active, use this function to extract an ICC profile from an image.
' This function assumes you have already checked to make sure the image contains an ICC profile (see the
' Plugin_FreeImage_Expanded module for details).
Public Function loadICCFromFreeImage(ByVal fi_Bitmap As Long) As Boolean

    Message "Image contains ICC profile.  Copying profile now..."
    
    'Check to make sure the supplied FreeImage bitmap actually has ICC data
    If FreeImage_GetICCProfileSize(fi_Bitmap) > 0 Then
    
        Dim fiProfileHeader As FIICCPROFILE
        fiProfileHeader = FreeImage_GetICCProfile(fi_Bitmap)
        
        'Use the SIZE value from the header to prepare a VB array to receive the profile data
        ReDim iccData(0 To fiProfileHeader.Size - 1) As Byte
        
        'Extract the ICC data into the array
        CopyMemory ByVal VarPtr(iccData(0)), ByVal fiProfileHeader.Data, fiProfileHeader.Size
        
        'The complete ICC profile will now be inside the iccData array.
        Message "ICC profile copied successfully."
        Debug.Print "ICC profile size (in bytes): " & CStr(UBound(iccData) + 1)
        iccDataPresent = True
        loadICCFromFreeImage = True
        
    Else
        Message "ICC profile could not be copied (unknown error)."
        loadICCFromFreeImage = False
    End If
    
End Function

Public Function loadICCFromGDIPlus(ByVal profileSize As Long, ByVal ptrToProfile As Long) As Boolean

    Message "Image contains ICC profile.  Copying profile now..."
    
    'Use the SIZE parameter to prepare a VB array to receive the profile data
    ReDim iccData(0 To profileSize - 1) As Byte
    
    'Extract the ICC data using the supplied pointer
    CopyMemory ByVal VarPtr(iccData(0)), ByVal ptrToProfile, profileSize
        
    'The complete ICC profile will now be inside the iccData array.
    Message "ICC profile copied successfully."
    Debug.Print "ICC profile size (in bytes): " & CStr(UBound(iccData) + 1)
    iccDataPresent = True
    loadICCFromGDIPlus = True

End Function

Public Function hasICCData() As Boolean
    hasICCData = iccDataPresent
End Function

Private Sub Class_Initialize()
    iccDataPresent = False
End Sub
