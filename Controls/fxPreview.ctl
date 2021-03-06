VERSION 5.00
Begin VB.UserControl fxPreviewCtl 
   AccessKeys      =   "T"
   AutoRedraw      =   -1  'True
   BackColor       =   &H80000005&
   ClientHeight    =   5685
   ClientLeft      =   0
   ClientTop       =   0
   ClientWidth     =   5760
   ClipControls    =   0   'False
   BeginProperty Font 
      Name            =   "Tahoma"
      Size            =   8.25
      Charset         =   0
      Weight          =   400
      Underline       =   0   'False
      Italic          =   0   'False
      Strikethrough   =   0   'False
   EndProperty
   ScaleHeight     =   379
   ScaleMode       =   3  'Pixel
   ScaleWidth      =   384
   ToolboxBitmap   =   "fxPreview.ctx":0000
   Begin VB.PictureBox picPreview 
      Appearance      =   0  'Flat
      AutoRedraw      =   -1  'True
      BackColor       =   &H00808080&
      ClipControls    =   0   'False
      ForeColor       =   &H80000008&
      Height          =   5100
      Left            =   0
      ScaleHeight     =   338
      ScaleMode       =   3  'Pixel
      ScaleWidth      =   382
      TabIndex        =   0
      TabStop         =   0   'False
      Top             =   0
      Width           =   5760
   End
   Begin VB.Label lblBeforeToggle 
      AutoSize        =   -1  'True
      BackStyle       =   0  'Transparent
      Caption         =   "show original image"
      BeginProperty Font 
         Name            =   "Tahoma"
         Size            =   9
         Charset         =   0
         Weight          =   400
         Underline       =   -1  'True
         Italic          =   -1  'True
         Strikethrough   =   0   'False
      EndProperty
      ForeColor       =   &H00C07031&
      Height          =   210
      Left            =   120
      MouseIcon       =   "fxPreview.ctx":0312
      MousePointer    =   99  'Custom
      TabIndex        =   1
      Top             =   5280
      Width           =   1590
   End
End
Attribute VB_Name = "fxPreviewCtl"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
'***************************************************************************
'PhotoDemon Effect Preview custom control
'Copyright �2012-2013 by Tanner Helland
'Created: 10/January/13
'Last updated: 07/November/13
'Last update: apply color management to anything rendered on the preview picture box
'
'For the first decade of its life, PhotoDemon relied on simple picture boxes for rendering its effect previews.
' This worked well enough when there were only a handful of tools available, but as the complexity of the program
' - and its various effects and tools - has grown, it has become more and more painful to update the preview
' system, because any changes have to be mirrored across a huge number of forms.
'
'Thus, this control was born.  It is now used on every single effect form in place of a regular picture box.  This
' allows me to add preview-related features just once - to the base control - and every tool will automatically
' reap the benefits.
'
'At present, there isn't much to the control.  It is capable of storing a copy of the original image and any
' filter-modified versions of the image.  The user can toggle between these by using the command link below the
' main picture box, or by pressing Alt+T.  This replaces the side-by-side "before and after" of past versions.
'
'All source code in this file is licensed under a modified BSD license.  This means you may use the code in your own
' projects IF you provide attribution.  For more information, please visit http://photodemon.org/about/license/
'
'***************************************************************************

Option Explicit

'Some preview boxes allow the user to click and select a color from the source image
Public Event ColorSelected()
Private isColorSelectionAllowed As Boolean, curColor As Long
Private colorJustClicked As Long

'Has this control been given a copy of the original image?
Private m_HasOriginal As Boolean, m_HasFX As Boolean

Private originalImage As pdLayer, fxImage As pdLayer

'The control's current state: whether it is showing the original image or the fx preview
Private curImageState As Boolean

'GetPixel is used to retrieve colors from the image
Private Declare Function GetPixel Lib "gdi32" (ByVal hDC As Long, ByVal x As Long, ByVal y As Long) As Long

'Mouse events are raised with the help of a bluMouseEvents class
Private WithEvents cMouseEvents As bluMouseEvents
Attribute cMouseEvents.VB_VarHelpID = -1

'Mouse enter/leave events will be handled by the bluMouseEvents object
Private Sub cMouseEvents_MouseIn()
    
    'If this preview control instance allows the user to select a color, display the original image upon mouse entrance
    If AllowColorSelection Then
        setPNGCursorToHwnd picPreview.hWnd, "C_PIPETTE", 0, 0
        If (Not originalImage Is Nothing) Then originalImage.renderToPictureBox picPreview
    End If
    
End Sub

Private Sub cMouseEvents_MouseOut()
    
    'If this preview control instance allows the user to select a color, restore whatever image was previously
    ' displayed upon mouse exit
    If AllowColorSelection Then
        setHandCursorToHwnd picPreview.hWnd
        If curImageState Then
            If (Not fxImage Is Nothing) Then fxImage.renderToPictureBox picPreview
        Else
            If (Not originalImage Is Nothing) Then originalImage.renderToPictureBox picPreview
        End If
    End If
    
End Sub

'The Enabled property is a bit unique; see http://msdn.microsoft.com/en-us/library/aa261357%28v=vs.60%29.aspx
Public Property Get SelectedColor() As Long
    SelectedColor = curColor
End Property

'The Enabled property is a bit unique; see http://msdn.microsoft.com/en-us/library/aa261357%28v=vs.60%29.aspx
Public Property Get AllowColorSelection() As Boolean
    AllowColorSelection = isColorSelectionAllowed
End Property

Public Property Let AllowColorSelection(ByVal isAllowed As Boolean)
    isColorSelectionAllowed = isAllowed
    PropertyChanged "AllowColorSelection"
End Property

'Use this to supply the preview with a copy of the original image's data.  The preview object can use this to display
' the original image when the user clicks the "show original image" link.
Public Sub setOriginalImage(ByRef srcLayer As pdLayer)

    'Note that we have a copy of the original image, so the calling function doesn't attempt to supply it again
    m_HasOriginal = True
    
    'Make a copy of the layer passed in
    If (originalImage Is Nothing) Then Set originalImage = New pdLayer
    
    originalImage.eraseLayer
    originalImage.createFromExistingLayer srcLayer
    
End Sub

'Use this to supply the object with a copy of the processed image's data.  The preview object can use this to display
' the processed image again if the user clicks the "show original image" link, then clicks it again.
Public Sub setFXImage(ByRef srcLayer As pdLayer)
56666
    'Note that we have a copy of the original image, so the calling function doesn't attempt to supply it again
    m_HasFX = True
    
    'Make a copy of the layer passed in
    If (fxImage Is Nothing) Then Set fxImage = New pdLayer
    
    fxImage.eraseLayer
    fxImage.createFromExistingLayer srcLayer
        
    'If the user was previously examining the original image, and color selection is not allowed, be helpful and
    ' automatically restore the previewed image.
    If (Not isColorSelectionAllowed) Then
        fxImage.renderToPictureBox picPreview
        lblBeforeToggle.Caption = g_Language.TranslateMessage("show original image") & " (alt+t) "
        curImageState = True
    'If color selection is allowed, the user may want to select more colors - so leave it on "original" mode if it
    ' is already there.
    Else
        If curImageState Then
            fxImage.renderToPictureBox picPreview
            lblBeforeToggle.Caption = g_Language.TranslateMessage("show original image") & " (alt+t) "
        End If
    End If

End Sub

'Has this preview control had an original version of the image set?
Public Function hasOriginalImage() As Boolean
    hasOriginalImage = m_HasOriginal
End Function

'Return a handle to our primary picture box
Public Function getPreviewPic() As PictureBox
    Set getPreviewPic = picPreview
End Function

'Return dimensions of the preview picture box
Public Function getPreviewWidth() As Long
    getPreviewWidth = picPreview.ScaleWidth
End Function

Public Function getPreviewHeight() As Long
    getPreviewHeight = picPreview.ScaleHeight
End Function

'Toggle between the preview image and the original image if the user clicks this label
Private Sub lblBeforeToggle_Click()
    
    'Before doing anything else, change the label caption
    If curImageState Then
        lblBeforeToggle.Caption = g_Language.TranslateMessage("show effect preview") & " (alt+t) "
    Else
        lblBeforeToggle.Caption = g_Language.TranslateMessage("show original image") & " (alt+t) "
    End If
    lblBeforeToggle.Refresh
    
    curImageState = Not curImageState
    
    'Update the image to match the new caption
    If Not curImageState Then
        If m_HasOriginal Then originalImage.renderToPictureBox picPreview
    Else
        
        If m_HasFX Then
            fxImage.renderToPictureBox picPreview
        Else
            If m_HasOriginal Then originalImage.renderToPictureBox picPreview
        End If
    End If
    
End Sub

'If color selection is allowed, raise that event now
Private Sub picPreview_MouseDown(Button As Integer, Shift As Integer, x As Single, y As Single)
    If isColorSelectionAllowed Then
        
        curColor = GetPixel(originalImage.getLayerDC, x - ((picPreview.ScaleWidth - originalImage.getLayerWidth) \ 2), y - ((picPreview.ScaleHeight - originalImage.getLayerHeight) \ 2))
        
        If curColor = -1 Then curColor = RGB(127, 127, 127)
        
        If AllowColorSelection Then colorJustClicked = 1
        RaiseEvent ColorSelected
    End If
End Sub

'When the user is selecting a color, we want to give them a preview of how that color will affect the previewed image.
' This is handled in the _MouseDown event above.  After the color has been selected, we want to restore the original
' image on a subsequent mouse move, in case the user wants to select a different color.
Private Sub picPreview_MouseMove(Button As Integer, Shift As Integer, x As Single, y As Single)
    
    If colorJustClicked > 0 Then
    
        'To accomodate shaky hands, allow a few mouse movements before resetting the image
        If colorJustClicked < 4 Then
            colorJustClicked = colorJustClicked + 1
        Else
            colorJustClicked = 0
            If (Not originalImage Is Nothing) Then originalImage.renderToPictureBox picPreview
        End If
        
    End If
    
End Sub

'I haven't made up my mind on whether to use AutoRedraw or not; just to be safe, I've added handling code to the _Paint
' event so that AutoRedraw can be turned off without trouble.
Private Sub picPreview_Paint()

    'Update the image to match the before/after label state
    If Not curImageState Then
        If m_HasOriginal Then originalImage.renderToPictureBox picPreview
    Else
        
        If m_HasFX Then
            fxImage.renderToPictureBox picPreview
        Else
            If m_HasOriginal Then originalImage.renderToPictureBox picPreview
        End If
    End If

End Sub

'When the control's access key is pressed (alt+t) , toggle the original/current image
Private Sub UserControl_AccessKeyPress(KeyAscii As Integer)
    lblBeforeToggle_Click
End Sub

Private Sub UserControl_AmbientChanged(PropertyName As String)
    
    'Keep the control's backcolor in sync with the parent object
    If UCase$(PropertyName) = "BACKCOLOR" Then
        BackColor = Ambient.BackColor
    End If

End Sub

Private Sub UserControl_Initialize()
    
    'A check must be made for IDE behavior so the project will compile; VB's initialization of user controls during
    ' compiling and design process causes no shortage of odd issues and errors otherwise
    If g_UserModeFix Then
        
        'Set up a mouse events handler.  (NOTE: this handler subclasses, which may cause instability in the IDE.)
        Set cMouseEvents = New bluMouseEvents
        cMouseEvents.Attach picPreview.hWnd, UserControl.hWnd
        
        'Give the toggle image text the same font as the rest of the project.
        lblBeforeToggle.FontName = g_InterfaceFont
        
    End If
    
    curImageState = True
    curColor = 0
            
End Sub

'Initialize our effect preview control
Private Sub UserControl_InitProperties()
    
    'Set the background of the fxPreview to match the background of our parent object
    BackColor = Ambient.BackColor
    
    'Mark the original image as having NOT been set
    m_HasOriginal = False
    
    'By default, the control cannot be used for color selection
    isColorSelectionAllowed = False
    
End Sub

Private Sub UserControl_ReadProperties(PropBag As PropertyBag)
    
    With PropBag
        AllowColorSelection = .ReadProperty("ColorSelection", False)
    End With
    
End Sub

'Redraw the user control after it has been resized
Private Sub UserControl_Resize()
    redrawControl
End Sub

Private Sub UserControl_Show()
    
    'Translate the user control text in the compiled EXE
    If g_UserModeFix Then
        lblBeforeToggle.Caption = g_Language.TranslateMessage("show original image") & " (alt+t) "
    Else
        lblBeforeToggle.Caption = "show original image (alt+t) "
    End If
    
    'Reset the mouse cursors
    setArrowCursorToHwnd picPreview.hWnd
    setArrowCursorToHwnd UserControl.hWnd
    
End Sub

Private Sub UserControl_Terminate()

    'Release any image objects that may have been created
    If Not (originalImage Is Nothing) Then originalImage.eraseLayer
    If Not (fxImage Is Nothing) Then fxImage.eraseLayer
    
End Sub

'After a resize or paint request, update the layout of our control
Private Sub redrawControl()
    
    'Always make the preview picture box the width of the user control (at present)
    picPreview.Width = ScaleWidth
    
    'Adjust the preview picture box's height to be just above the "show original image" link
    lblBeforeToggle.Top = ScaleHeight - fixDPI(24)
    picPreview.Height = lblBeforeToggle.Top - (ScaleHeight - (lblBeforeToggle.Height + lblBeforeToggle.Top))
        
End Sub

Private Sub UserControl_WriteProperties(PropBag As PropertyBag)

    'Store all associated properties
    With PropBag
        .WriteProperty "ColorSelection", AllowColorSelection, False
    End With
    
End Sub
