VERSION 5.00
Begin VB.Form FormVignette 
   AutoRedraw      =   -1  'True
   BackColor       =   &H80000005&
   BorderStyle     =   4  'Fixed ToolWindow
   Caption         =   " Apply Vignetting"
   ClientHeight    =   6540
   ClientLeft      =   -15
   ClientTop       =   225
   ClientWidth     =   12090
   BeginProperty Font 
      Name            =   "Tahoma"
      Size            =   8.25
      Charset         =   0
      Weight          =   400
      Underline       =   0   'False
      Italic          =   0   'False
      Strikethrough   =   0   'False
   EndProperty
   LinkTopic       =   "Form1"
   MaxButton       =   0   'False
   MinButton       =   0   'False
   ScaleHeight     =   436
   ScaleMode       =   3  'Pixel
   ScaleWidth      =   806
   ShowInTaskbar   =   0   'False
   StartUpPosition =   1  'CenterOwner
   Begin VB.HScrollBar hsFeathering 
      Height          =   255
      Left            =   6120
      Max             =   100
      Min             =   1
      TabIndex        =   11
      Top             =   3000
      Value           =   30
      Width           =   4815
   End
   Begin VB.TextBox txtFeathering 
      Alignment       =   2  'Center
      BeginProperty Font 
         Name            =   "Tahoma"
         Size            =   9.75
         Charset         =   0
         Weight          =   400
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      ForeColor       =   &H00800000&
      Height          =   360
      Left            =   11040
      MaxLength       =   3
      TabIndex        =   10
      Text            =   "30"
      Top             =   2940
      Width           =   735
   End
   Begin VB.HScrollBar hsTransparency 
      Height          =   255
      Left            =   6120
      Max             =   100
      Min             =   1
      TabIndex        =   8
      Top             =   3840
      Value           =   80
      Width           =   4815
   End
   Begin VB.TextBox txtTransparency 
      Alignment       =   2  'Center
      BeginProperty Font 
         Name            =   "Tahoma"
         Size            =   9.75
         Charset         =   0
         Weight          =   400
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      ForeColor       =   &H00800000&
      Height          =   360
      Left            =   11040
      MaxLength       =   3
      TabIndex        =   7
      Text            =   "80"
      Top             =   3780
      Width           =   735
   End
   Begin VB.CommandButton CmdOK 
      Caption         =   "&OK"
      Default         =   -1  'True
      Height          =   495
      Left            =   9120
      TabIndex        =   0
      Top             =   5910
      Width           =   1365
   End
   Begin VB.CommandButton CmdCancel 
      Cancel          =   -1  'True
      Caption         =   "&Cancel"
      Height          =   495
      Left            =   10590
      TabIndex        =   1
      Top             =   5910
      Width           =   1365
   End
   Begin VB.TextBox txtRadius 
      Alignment       =   2  'Center
      BeginProperty Font 
         Name            =   "Tahoma"
         Size            =   9.75
         Charset         =   0
         Weight          =   400
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      ForeColor       =   &H00800000&
      Height          =   360
      Left            =   11040
      MaxLength       =   3
      TabIndex        =   3
      Text            =   "60"
      Top             =   2100
      Width           =   735
   End
   Begin VB.HScrollBar hsRadius 
      Height          =   255
      Left            =   6120
      Max             =   100
      Min             =   1
      TabIndex        =   2
      Top             =   2160
      Value           =   60
      Width           =   4815
   End
   Begin PhotoDemon.fxPreviewCtl fxPreview 
      Height          =   5625
      Left            =   120
      TabIndex        =   6
      Top             =   120
      Width           =   5625
      _ExtentX        =   9922
      _ExtentY        =   9922
   End
   Begin VB.Label lblFeathering 
      AutoSize        =   -1  'True
      BackStyle       =   0  'Transparent
      Caption         =   "softness:"
      BeginProperty Font 
         Name            =   "Tahoma"
         Size            =   12
         Charset         =   0
         Weight          =   400
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      ForeColor       =   &H00404040&
      Height          =   285
      Left            =   6000
      TabIndex        =   12
      Top             =   2640
      Width           =   945
   End
   Begin VB.Label lblTransparency 
      AutoSize        =   -1  'True
      BackStyle       =   0  'Transparent
      Caption         =   "strength:"
      BeginProperty Font 
         Name            =   "Tahoma"
         Size            =   12
         Charset         =   0
         Weight          =   400
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      ForeColor       =   &H00404040&
      Height          =   285
      Left            =   6000
      TabIndex        =   9
      Top             =   3480
      Width           =   960
   End
   Begin VB.Label lblBackground 
      Height          =   855
      Left            =   0
      TabIndex        =   5
      Top             =   5760
      Width           =   12135
   End
   Begin VB.Label lblRadius 
      AutoSize        =   -1  'True
      BackStyle       =   0  'Transparent
      Caption         =   "radius (percentage):"
      BeginProperty Font 
         Name            =   "Tahoma"
         Size            =   12
         Charset         =   0
         Weight          =   400
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      ForeColor       =   &H00404040&
      Height          =   285
      Left            =   6000
      TabIndex        =   4
      Top             =   1800
      Width           =   2145
   End
End
Attribute VB_Name = "FormVignette"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
'***************************************************************************
'Image Vignette tool
'Copyright �2012-2013 by Tanner Helland
'Created: 31/January/13
'Last updated: 31/January/13
'Last update: initial build
'
'This tool allows the user to apply vignetting to an image.
'
'***************************************************************************

Option Explicit

'CANCEL button
Private Sub CmdCancel_Click()
    Unload Me
End Sub

'OK button
Private Sub cmdOK_Click()

    'Before rendering anything, check to make sure the text boxes have valid input
    If Not EntryValid(txtRadius, hsRadius.Min, hsRadius.Max, True, True) Then
        AutoSelectText txtRadius
        Exit Sub
    End If
    
    If Not EntryValid(txtFeathering, hsFeathering.Min, hsFeathering.Max, True, True) Then
        AutoSelectText txtFeathering
        Exit Sub
    End If
    
    If Not EntryValid(txtTransparency, hsTransparency.Min, hsTransparency.Max, True, True) Then
        AutoSelectText txtTransparency
        Exit Sub
    End If
    
    'Based on the user's selection, submit the proper processor request
    Me.Visible = False
    Process Vignetting, hsRadius.Value, hsFeathering.Value, hsTransparency.Value
    Unload Me
    
End Sub

'Apply a new lens distortion to an image
Public Sub ApplyVignette(ByVal maxRadius As Double, ByVal vFeathering As Double, ByVal vTransparency As Double, Optional ByVal toPreview As Boolean = False, Optional ByRef dstPic As fxPreviewCtl)
    
    If toPreview = False Then Message "Applying vignetting..."
    
    'Create a local array and point it at the pixel data of the current image
    Dim dstImageData() As Byte
    Dim dstSA As SAFEARRAY2D
    prepImageData dstSA, toPreview, dstPic
    CopyMemory ByVal VarPtrArray(dstImageData()), VarPtr(dstSA), 4
    
    'Local loop variables can be more efficiently cached by VB's compiler, so we transfer all relevant loop data here
    Dim x As Long, y As Long, initX As Long, initY As Long, finalX As Long, finalY As Long
    initX = curLayerValues.Left
    initY = curLayerValues.Top
    finalX = curLayerValues.Right
    finalY = curLayerValues.Bottom
            
    'These values will help us access locations in the array more quickly.
    ' (qvDepth is required because the image array may be 24 or 32 bits per pixel, and we want to handle both cases.)
    Dim QuickVal As Long, qvDepth As Long
    qvDepth = curLayerValues.BytesPerPixel
    
    'To keep processing quick, only update the progress bar when absolutely necessary.  This function calculates that value
    ' based on the size of the area to be processed.
    Dim progBarCheck As Long
    progBarCheck = findBestProgBarValue()
        
    'Calculate the center of the image
    Dim midX As Double, midY As Double
    midX = CDbl(finalX - initX) / 2
    midX = midX + initX
    midY = CDbl(finalY - initY) / 2
    midY = midY + initY
        
    'X and Y values, remapped around a center point of (0, 0)
    Dim nX As Double, nY As Double
    Dim nX2 As Double, nY2 As Double
            
    'Radius is based off the smaller of the two dimensions - width or height
    Dim tWidth As Long, tHeight As Long
    tWidth = curLayerValues.Width
    tHeight = curLayerValues.Height
    Dim sRadiusW As Double, sRadiusH As Double
    Dim sRadiusW2 As Double, sRadiusH2 As Double
    
    sRadiusW = tWidth * (maxRadius / 100)
    sRadiusW2 = sRadiusW * sRadiusW
    sRadiusH = tHeight * (maxRadius / 100)
    sRadiusH2 = sRadiusH * sRadiusH
    
    Dim sRadiusMax As Double, sRadiusMin As Double
    Dim blendVal As Double
    
    'Adjust the vignetting to be a proportion of the image's maximum radius.  This ensures accurate correlations
    ' between the preview and the final result.
    Dim vFeathering2 As Double
    vFeathering2 = (vFeathering / 100) * (sRadiusW * sRadiusH)
    
    'Modify the transparency to be on a scale of [0, 1]
    vTransparency = 1 - (vTransparency / 100)
    
    'Loop through each pixel in the image, converting values as we go
    For x = initX To finalX
        QuickVal = x * qvDepth
    For y = initY To finalY
    
        'Remap the coordinates around a center point of (0, 0)
        nX = x - midX
        nY = y - midY
        nX2 = nX * nX
        nY2 = nY * nY
                
        'If the values are going to be out-of-bounds, force them to black
        sRadiusMax = sRadiusH2 - ((sRadiusH2 * nX2) / sRadiusW2)
        
        If nY2 > sRadiusMax Then
            dstImageData(QuickVal + 2, y) = BlendColors(0, dstImageData(QuickVal + 2, y), vTransparency)
            dstImageData(QuickVal + 1, y) = BlendColors(0, dstImageData(QuickVal + 1, y), vTransparency)
            dstImageData(QuickVal, y) = BlendColors(0, dstImageData(QuickVal, y), vTransparency)
            
        'Otherwise, check for feathering
        Else
            sRadiusMin = sRadiusMax - vFeathering2
            
            If nY2 >= sRadiusMin Then
                blendVal = (nY2 - sRadiusMin) / vFeathering2
                blendVal = blendVal * (1 - vTransparency)
                dstImageData(QuickVal + 2, y) = BlendColors(dstImageData(QuickVal + 2, y), 0, blendVal)
                dstImageData(QuickVal + 1, y) = BlendColors(dstImageData(QuickVal + 1, y), 0, blendVal)
                dstImageData(QuickVal, y) = BlendColors(dstImageData(QuickVal, y), 0, blendVal)
            End If
            
        End If
                        
    Next y
        If Not toPreview Then
            If (x And progBarCheck) = 0 Then SetProgBarVal x
        End If
    Next x
    
    'With our work complete, point both ImageData() arrays away from their DIBs and deallocate them
    CopyMemory ByVal VarPtrArray(dstImageData), 0&, 4
    Erase dstImageData
    
    'Pass control to finalizeImageData, which will handle the rest of the rendering
    finalizeImageData toPreview, dstPic
        
End Sub

Private Sub Form_Activate()
    
    'Draw a preview of the effect
    updatePreview
        
    'Assign the system hand cursor to all relevant objects
    makeFormPretty Me
            
End Sub

Private Sub Form_Unload(Cancel As Integer)
    ReleaseFormTheming Me
End Sub

'Keep the scroll bar and the text box values in sync
Private Sub hsRadius_Change()
    copyToTextBoxI txtRadius, hsRadius.Value
    updatePreview
End Sub

Private Sub hsRadius_Scroll()
    copyToTextBoxI txtRadius, hsRadius.Value
    updatePreview
End Sub

Private Sub txtRadius_GotFocus()
    AutoSelectText txtRadius
End Sub

Private Sub txtRadius_KeyUp(KeyCode As Integer, Shift As Integer)
    textValidate txtRadius
    If EntryValid(txtRadius, hsRadius.Min, hsRadius.Max, False, False) Then hsRadius.Value = Val(txtRadius)
End Sub

Private Sub hsTransparency_Change()
    copyToTextBoxI txtTransparency, hsTransparency.Value
    updatePreview
End Sub

Private Sub hsTransparency_Scroll()
    copyToTextBoxI txtTransparency, hsTransparency.Value
    updatePreview
End Sub

Private Sub txtTransparency_GotFocus()
    AutoSelectText txtTransparency
End Sub

Private Sub txtTransparency_KeyUp(KeyCode As Integer, Shift As Integer)
    textValidate txtTransparency
    If EntryValid(txtTransparency, hsTransparency.Min, hsTransparency.Max, False, False) Then hsTransparency.Value = Val(txtTransparency)
End Sub

Private Sub hsFeathering_Change()
    copyToTextBoxI txtFeathering, hsFeathering.Value
    updatePreview
End Sub

Private Sub hsFeathering_Scroll()
    copyToTextBoxI txtFeathering, hsFeathering.Value
    updatePreview
End Sub

Private Sub txtFeathering_GotFocus()
    AutoSelectText txtFeathering
End Sub

Private Sub txtFeathering_KeyUp(KeyCode As Integer, Shift As Integer)
    textValidate txtFeathering
    If EntryValid(txtFeathering, hsFeathering.Min, hsFeathering.Max, False, False) Then hsFeathering.Value = Val(txtFeathering)
End Sub

'Redraw the on-screen preview of the transformed image
Private Sub updatePreview()

    ApplyVignette hsRadius.Value, hsFeathering.Value, hsTransparency.Value, True, fxPreview
    
End Sub