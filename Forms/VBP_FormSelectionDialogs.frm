VERSION 5.00
Begin VB.Form FormSelectionDialogs 
   Appearance      =   0  'Flat
   AutoRedraw      =   -1  'True
   BackColor       =   &H80000005&
   BorderStyle     =   4  'Fixed ToolWindow
   Caption         =   " Selection options"
   ClientHeight    =   2640
   ClientLeft      =   45
   ClientTop       =   315
   ClientWidth     =   6660
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
   ScaleHeight     =   176
   ScaleMode       =   3  'Pixel
   ScaleWidth      =   444
   ShowInTaskbar   =   0   'False
   Begin VB.CommandButton CmdCancel 
      Cancel          =   -1  'True
      Caption         =   "&Cancel"
      Height          =   495
      Left            =   5190
      TabIndex        =   1
      Top             =   2040
      Width           =   1365
   End
   Begin VB.CommandButton CmdOK 
      Caption         =   "&OK"
      Default         =   -1  'True
      Height          =   495
      Left            =   3720
      TabIndex        =   0
      Top             =   2040
      Width           =   1365
   End
   Begin PhotoDemon.sliderTextCombo sltSelValue 
      Height          =   495
      Left            =   360
      TabIndex        =   3
      Top             =   720
      Width           =   5895
      _ExtentX        =   10186
      _ExtentY        =   873
      Min             =   1
      Max             =   500
      Value           =   1
      BeginProperty Font {0BE35203-8F91-11CE-9DE3-00AA004BB851} 
         Name            =   "Tahoma"
         Size            =   9.75
         Charset         =   0
         Weight          =   400
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
   End
   Begin VB.Label lblTitle 
      Appearance      =   0  'Flat
      AutoSize        =   -1  'True
      BackColor       =   &H80000005&
      BackStyle       =   0  'Transparent
      Caption         =   "slider caption:"
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
      Index           =   0
      Left            =   360
      TabIndex        =   4
      Top             =   360
      Width           =   1500
   End
   Begin VB.Label lblBackground 
      Height          =   855
      Left            =   -5400
      TabIndex        =   2
      Top             =   1890
      Width           =   12135
   End
End
Attribute VB_Name = "FormSelectionDialogs"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
'***************************************************************************
'Multi-purpose Selection Dialog
'Copyright �2012-2013 by Tanner Helland
'Created: 11/July/13
'Last updated: 11/July/13
'Last update: initial build
'
'Custom dialog box for asking the user for a selection-related parameters.  Because all selection-related options
' (grow, shrink, border, feather, etc) don't provide previews, it is easy to handle their dialogs using a single
' form - saving on resources in the process.
'
'This form is not designed to be displayed on its own.  Use the displaySelectionDialog function in the
' Selection_Handler module to properly initialize it (and properly capture all return values).
'
'All source code in this file is licensed under a modified BSD license.  This means you may use the code in your own
' projects IF you provide attribution.  For more information, please visit http://photodemon.org/about/license/
'
'***************************************************************************

Option Explicit

'The user input from the dialog
Private userAnswer As VbMsgBoxResult

'The slider value, if the dialog is closed via OK
Private userValue As Double

'Custom tooltip class allows for things like multiline, theming, and multiple monitor support
Dim m_ToolTip As clsToolTip

Public Property Get DialogResult() As VbMsgBoxResult
    DialogResult = userAnswer
End Property

Public Property Get ParamValue() As Double
    ParamValue = userValue
End Property

'The ShowDialog routine presents the user with the form.  FormID MUST BE SET in advance of calling this.
Public Sub showDialog(ByVal typeOfDialog As SelectionDialogType)
    
    'Based on the type of dialog requested, rebuild the dialog's text
    Dim titleText As String, sliderText As String
    
    Select Case typeOfDialog
    
        Case SEL_GROW
            titleText = g_Language.TranslateMessage("Grow selection")
            sliderText = g_Language.TranslateMessage("grow by this many pixels:")
        
        Case SEL_SHRINK
            titleText = g_Language.TranslateMessage("Shrink selection")
            sliderText = g_Language.TranslateMessage("shrink by this many pixels:")
        
        Case SEL_BORDER
            titleText = g_Language.TranslateMessage("Border selection")
            sliderText = g_Language.TranslateMessage("border radius:")
        
        Case SEL_FEATHER
            titleText = g_Language.TranslateMessage("Feather selection")
            sliderText = g_Language.TranslateMessage("feather radius:")
        
        Case SEL_SHARPEN
            titleText = g_Language.TranslateMessage("Sharpen selection")
            sliderText = g_Language.TranslateMessage("sharpen radius:")
    
    End Select
    
    Me.Caption = " " & titleText
    lblTitle(0).Caption = sliderText
    
    'Provide a default answer of "first image only" (in the event that the user clicks the "x" button in the top-right)
    userAnswer = vbNo

    'Apply any custom styles to the form
    Set m_ToolTip = New clsToolTip
    makeFormPretty Me, m_ToolTip

    'Display the form
    showPDDialog vbModal, Me

End Sub

'Update the dialog's return value based on the pressed command button
Private Sub CmdCancel_Click()
    userAnswer = vbCancel
    userValue = 0
    Me.Hide
End Sub

Private Sub CmdOK_Click()
    
    If sltSelValue.IsValid Then
        userAnswer = vbOK
        userValue = sltSelValue.Value
        Me.Hide
    End If
    
End Sub

Private Sub Form_Unload(Cancel As Integer)
    ReleaseFormTheming Me
End Sub
