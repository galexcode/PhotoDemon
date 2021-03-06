Attribute VB_Name = "Interface"
'***************************************************************************
'Miscellaneous Functions Related to the User Interface
'Copyright �2001-2013 by Tanner Helland
'Created: 6/12/01
'Last updated: 23/October/13
'Last update: new syncInterfaceToCurrentImage function, which should be universally used throughout PD in place of
'              the old metaToggle events.
'
'Miscellaneous routines related to rendering and handling PhotoDemon's interface.  As the program's complexity has
' increased, so has the need for specialized handling of certain UI elements.
'
'Many of the functions in this module rely on subclassing, either directly or through things like PD's window manager.
' As such, some functions may operate differently (or not at all) while in the IDE.
'
'All source code in this file is licensed under a modified BSD license.  This means you may use the code in your own
' projects IF you provide attribution.  For more information, please visit http://photodemon.org/about/license/
'
'***************************************************************************


Option Explicit

Private Declare Function GetWindowRect Lib "user32" (ByVal hndWindow As Long, ByRef lpRect As winRect) As Long
Private Declare Function MoveWindow Lib "user32" (ByVal hndWindow As Long, ByVal x As Long, ByVal y As Long, ByVal nWidth As Long, ByVal nHeight As Long, ByVal bRepaint As Long) As Long

'Used to measure the expected length of a string
Private Declare Function GetTextExtentPoint32 Lib "gdi32" Alias "GetTextExtentPoint32A" (ByVal hDC As Long, ByVal lpsz As String, ByVal cbString As Long, ByRef lpSize As POINTAPI) As Long

'These constants are used to toggle visibility of display elements.
Public Const VISIBILITY_TOGGLE As Long = 0
Public Const VISIBILITY_FORCEDISPLAY As Long = 1
Public Const VISIBILITY_FORCEHIDE As Long = 2

'These values are used to remember the user's current font smoothing setting.  We try to be polite and restore
' the original setting when the application terminates.
Private Declare Function SystemParametersInfo Lib "user32" Alias "SystemParametersInfoA" (ByVal uiAction As Long, ByVal uiParam As Long, ByRef pvParam As Long, ByVal fWinIni As Long) As Long

Private Const SPI_GETFONTSMOOTHING As Long = &H4A
Private Const SPI_SETFONTSMOOTHING As Long = &H4B
Private Const SPI_GETFONTSMOOTHINGTYPE As Long = &H200A
Private Const SPI_SETFONTSMOOTHINGTYPE As Long = &H200B
Private Const SmoothingClearType As Long = &H2
Private Const SmoothingStandardType As Long = &H1
Private Const SmoothingNone As Long = &H0
Private Const SPI_GETKEYBOARDDELAY As Long = &H16

'Constants that define single meta-level actions that require certain controls to be en/disabled.  (For example, use tSave to disable
' the File -> Save menu, file toolbar Save button, and Ctrl+S hotkey.)  Constants are listed in roughly the order they appear in the
' main menu.
Public Enum metaInitializer
     tSave
     tSaveAs
     tClose
     tUndo
     tRedo
     tRepeatLast
     tCopy
     tPaste
     tView
     tImageOps
     tImgMode32bpp
     tMetadata
     tGPSMetadata
     tEffects
     tMacro
     tSelection
     tSelectionTransform
     tZoom
End Enum

#If False Then
    Private Const tSave = 0, tSaveAs = 0, tClose = 0, tUndo = 0, tRedo = 0, tRepeatLast = 0, tCopy = 0, tPaste = 0, tView = 0, tImageOps = 0
    Private Const tImgMode32bpp = 0, tMetadata = 0, tGPSMetadata = 0, tEffects = 0, tMacro = 0, tSelection = 0, tSelectionTransform = 0, tZoom = 0
#End If

'If PhotoDemon enabled font smoothing where there was none previously, it will restore the original setting upon exit.  This variable
' can contain the following values:
' 0: did not have to change smoothing, as ClearType is already enabled
' 1: had to change smoothing type from Standard to ClearType
' 2: had to turn on smoothing, as it was originally turned off
Private hadToChangeSmoothing As Long

'PhotoDemon is designed against pixels at an expected screen resolution of 96 DPI.  Other DPI settings mess up our calculations.
' To remedy this, we dynamically modify all pixels measurements at run-time, using the current screen resolution as our guide.
Private dpiRatio As Double

'When a modal dialog is displayed, a reference to it is saved in this variable.  If subsequent modal dialogs are displayed (for example,
' if a tool dialog displays a color selection dialog), the previous modal dialog is given ownership over the new dialog.
Private currentDialogReference As Form
Private isSecondaryDialog As Boolean

'Previously, various PD functions had to manually enable/disable button and menu state based on their actions.  This is no longer necessary.
' Simply call this function whenever an action has done something that will potentially affect the interface, and this function will iterate
' through all potential image/interface interactions, dis/enabling buttons and menus as necessary.
Public Sub syncInterfaceToCurrentImage()

    Dim i As Long
    
    'Interface dis/enabling falls into two rough categories: stuff that changes based on the current image (e.g. Undo), and stuff that changes
    ' based on the *total* number of available images (e.g. visibility of the Effects menu).
    
    'Start by breaking our interface decisions into two broad categories: "no images are loaded" and "one or more images are loaded".
    
    'If no images are loaded, we can disable a whole swath of controls
    If g_OpenImageCount = 0 Then
    
        metaToggle tSave, False
        metaToggle tSaveAs, False
        metaToggle tClose, False
        metaToggle tUndo, False
        metaToggle tRedo, False
        metaToggle tRepeatLast, False
        metaToggle tCopy, False
        metaToggle tView, False
        metaToggle tImageOps, False
        metaToggle tSelection, False
        metaToggle tEffects, False
        metaToggle tMacro, False
        metaToggle tZoom, False
        
        toolbar_File.lblImgSize.ForeColor = &HD1B499
        toolbar_File.lblCoordinates.ForeColor = &HD1B499
        toolbar_File.lblImgSize.Caption = ""
        toolbar_File.lblCoordinates.Caption = ""
        
        Message "Please load an image.  (The large 'Open Image' button at the top-left should do the trick!)"
        
        'Finally, because dynamic icons are enabled, restore the main program icon and clear the icon cache
        destroyAllIcons
        setNewTaskbarIcon origIcon32, FormMain.hWnd
        setNewAppIcon origIcon16, origIcon32
        
        'If no images are currently open, but images were open in the past, release any memory associated with those images.
        ' This helps minimize PD's memory usage.
        If g_NumOfImagesLoaded > 1 Then
        
            'Loop through all pdImage objects and make sure they've been deactivated
            For i = 0 To g_NumOfImagesLoaded
                If (Not pdImages(i) Is Nothing) Then
                    pdImages(i).deactivateImage
                    Set pdImages(i) = Nothing
                End If
            Next i
            
            'Reset all window tracking variables
            g_NumOfImagesLoaded = 0
            g_CurrentImage = 0
            g_OpenImageCount = 0
            
        End If
        
        'Erase any remaining viewport buffer
        eraseViewportBuffers
    
    'If one or more images are loaded, our job is trickier.  Some controls (such as Copy to Clipboard) are enabled no matter what,
    ' while others (Undo and Redo) are only enabled if the current image requires it.
    Else
    
        'Start by enabling actions that are always available if one or more images are loaded.
        metaToggle tSaveAs, True
        metaToggle tClose, True
        metaToggle tCopy, True
        
        metaToggle tView, True
        metaToggle tZoom, True
        metaToggle tImageOps, True
        metaToggle tEffects, True
        metaToggle tMacro, True
        
        toolbar_File.lblImgSize.ForeColor = &H544E43
        toolbar_File.lblCoordinates.ForeColor = &H544E43
        
        'Next, attempt to enable controls whose state depends on the current image - e.g. "Save", which is only enabled if
        ' the image has not already been saved in its current state.
        
        'Note that all of these functions rely on the g_CurrentImage value to function.
        
        'Save is a bit funny, because if the image HAS been saved to file, we DISABLE the save button.
        metaToggle tSave, Not pdImages(g_CurrentImage).getSaveState
        
        'Undo, Redo, and RepeatLast are all closely related
        If Not (pdImages(g_CurrentImage).undoManager Is Nothing) Then metaToggle tUndo, pdImages(g_CurrentImage).undoManager.getUndoState
        If Not (pdImages(g_CurrentImage).undoManager Is Nothing) Then metaToggle tRedo, pdImages(g_CurrentImage).undoManager.getRedoState
        If Not (pdImages(g_CurrentImage).undoManager Is Nothing) Then metaToggle tRepeatLast, pdImages(g_CurrentImage).undoManager.getRedoState
        
        '"Fade last effect" is reserved for filters and effects only, so if the last Undo action was selection-only
        ' (e.g. "feather selection"), do not enable the "Fade Last Effect" menu.
        If Not (pdImages(g_CurrentImage).undoManager Is Nothing) Then
            If (pdImages(g_CurrentImage).undoManager.getUndoProcessType = 0) Or (pdImages(g_CurrentImage).undoManager.getUndoProcessType = 1) Then
                FormMain.MnuFadeLastEffect.Enabled = True
            Else
                FormMain.MnuFadeLastEffect.Enabled = False
            End If
        End If
        
        'Determine whether metadata is present, and dis/enable metadata menu items accordingly
        metaToggle tMetadata, pdImages(g_CurrentImage).imgMetadata.hasXMLMetadata
        metaToggle tGPSMetadata, pdImages(g_CurrentImage).imgMetadata.hasGPSMetadata()
        
        'Display the size of this image in the status bar
        If pdImages(g_CurrentImage).Width <> 0 Then DisplaySize pdImages(g_CurrentImage).Width, pdImages(g_CurrentImage).Height
        
        'Update the form's icon to match the current image; if a custom icon is not available, use the stock PD one
        If pdImages(g_CurrentImage).curFormIcon32 <> 0 Then
            If Not (pdImages(g_CurrentImage).containingForm Is Nothing) Then setNewTaskbarIcon pdImages(g_CurrentImage).curFormIcon32, pdImages(g_CurrentImage).containingForm.hWnd
            
            'If images are docked, they do not have their own taskbar entries.  Change the main program icon to match this image.
            setNewTaskbarIcon pdImages(g_CurrentImage).curFormIcon32, FormMain.hWnd
            setNewAppIcon pdImages(g_CurrentImage).curFormIcon16, pdImages(g_CurrentImage).curFormIcon32
        Else
            setNewTaskbarIcon origIcon32, FormMain.hWnd
        End If
        
        'Check the image's color depth, and check/uncheck the matching Image Mode setting
        If Not (pdImages(g_CurrentImage).getCompositedImage() Is Nothing) Then
            If pdImages(g_CurrentImage).getCompositedImage().getLayerColorDepth() = 32 Then metaToggle tImgMode32bpp, True Else metaToggle tImgMode32bpp, False
        End If
        
        'Restore the zoom value for this particular image (again, only if the form has been initialized)
        If pdImages(g_CurrentImage).Width <> 0 Then
            g_AllowViewportRendering = False
            toolbar_File.CmbZoom.ListIndex = pdImages(g_CurrentImage).currentZoomValue
            g_AllowViewportRendering = True
        End If
        
        'If a selection is active on this image, update the text boxes to match
        If pdImages(g_CurrentImage).selectionActive Then
            metaToggle tSelection, True
            metaToggle tSelectionTransform, pdImages(g_CurrentImage).mainSelection.isTransformable
            syncTextToCurrentSelection g_CurrentImage
        Else
            metaToggle tSelection, False
            metaToggle tSelectionTransform, False
        End If
        
        'Finally, if the histogram window is open, redraw it.  (This isn't needed at present, but could be useful in the future)
        'If FormHistogram.Visible And pdImages(g_CurrentImage).loadedSuccessfully Then
        '    FormHistogram.TallyHistogramValues
        '    FormHistogram.DrawHistogram
        'End If
        
    End If
    
    'Perform a special check for the image tabstrip.  Its appearance is contingent on a setting provided by the user, coupled
    ' with the number of presently open images.
    
    'A setting of 2 equates to index 2 in the menu, specifically "Never show image tabstrip".  Hide the tabstrip.
    If g_UserPreferences.GetPref_Long("Core", "Image Tabstrip Visibility", 1) = 2 Then
        g_WindowManager.setWindowVisibility toolbar_ImageTabs.hWnd, False
    Else
        
        'A setting of 1 equates to index 1 in the menu, specifically "Show for 2+ loaded images".  Check image count and
        ' set visibility accordingly.
        If g_UserPreferences.GetPref_Long("Core", "Image Tabstrip Visibility", 1) = 1 Then
            
            If g_OpenImageCount > 1 Then
                g_WindowManager.setWindowVisibility toolbar_ImageTabs.hWnd, True
            Else
                g_WindowManager.setWindowVisibility toolbar_ImageTabs.hWnd, False
            End If
        
        'A setting of 0 equates to index 0 in the menu, specifically "always show tabstrip".
        Else
        
            If g_OpenImageCount > 0 Then
                g_WindowManager.setWindowVisibility toolbar_ImageTabs.hWnd, True
            Else
                g_WindowManager.setWindowVisibility toolbar_ImageTabs.hWnd, False
            End If
        
        End If
    
    End If
    
    'Perform a special check if 2 or more images are loaded; if that is the case, enable a few additional controls, like
    ' the "Next/Previous" Window menu items.
    If g_OpenImageCount >= 2 Then
        FormMain.MnuWindow(7).Enabled = True
        FormMain.MnuWindow(8).Enabled = True
    Else
        FormMain.MnuWindow(7).Enabled = False
        FormMain.MnuWindow(8).Enabled = False
    End If
    
End Sub

'metaToggle enables or disables a swath of controls related to a simple keyword (e.g. "Undo", which affects multiple menu items
' and toolbar buttons)
Public Sub metaToggle(ByVal metaItem As metaInitializer, ByVal newState As Boolean)
    
    Dim i As Long
    
    Select Case metaItem
            
        'Save (left-hand panel button AND menu item)
        Case tSave
            If FormMain.MnuFile(7).Enabled <> newState Then
                toolbar_File.cmdSave.Enabled = newState
                FormMain.MnuFile(7).Enabled = newState
                
                'The File -> Revert menu is also tied to Save state (if the image has not been saved in its current state,
                ' we allow the user to revert to the last save state).
                FormMain.MnuFile(9).Enabled = newState
                
            End If
            
        'Save As (menu item only)
        Case tSaveAs
            If FormMain.MnuFile(8).Enabled <> newState Then
                toolbar_File.cmdSaveAs.Enabled = newState
                FormMain.MnuFile(8).Enabled = newState
            End If
            
        'Close and Close All
        Case tClose
            If FormMain.MnuFile(4).Enabled <> newState Then
                FormMain.MnuFile(4).Enabled = newState
                FormMain.MnuFile(5).Enabled = newState
                toolbar_File.cmdClose.Enabled = newState
            End If
        
        'Undo (left-hand panel button AND menu item)
        Case tUndo
            If FormMain.MnuEdit(0).Enabled <> newState Then
                toolbar_File.cmdUndo.Enabled = newState
                FormMain.MnuEdit(0).Enabled = newState
            End If
            'If Undo is being enabled, change the text to match the relevant action that created this Undo file
            If newState Then
                toolbar_File.cmdUndo.ToolTip = pdImages(g_CurrentImage).undoManager.getUndoProcessID
                FormMain.MnuEdit(0).Caption = g_Language.TranslateMessage("Undo:") & " " & pdImages(g_CurrentImage).undoManager.getUndoProcessID & vbTab & "Ctrl+Z"
            Else
                toolbar_File.cmdUndo.ToolTip = ""
                FormMain.MnuEdit(0).Caption = g_Language.TranslateMessage("Undo") & vbTab & "Ctrl+Z"
            End If
            
            'When changing menu text, icons must be reapplied.
            resetMenuIcons
        
        'Redo (left-hand panel button AND menu item)
        Case tRedo
            If FormMain.MnuEdit(1).Enabled <> newState Then
                toolbar_File.cmdRedo.Enabled = newState
                FormMain.MnuEdit(1).Enabled = newState
            End If
            
            'If Redo is being enabled, change the menu text to match the relevant action that created this Undo file
            If newState Then
                toolbar_File.cmdRedo.ToolTip = pdImages(g_CurrentImage).undoManager.getRedoProcessID
                FormMain.MnuEdit(1).Caption = g_Language.TranslateMessage("Redo:") & " " & pdImages(g_CurrentImage).undoManager.getRedoProcessID & vbTab & "Ctrl+Y"
            Else
                toolbar_File.cmdRedo.ToolTip = ""
                FormMain.MnuEdit(1).Caption = g_Language.TranslateMessage("Redo") & vbTab & "Ctrl+Y"
            End If
            
            'When changing menu text, icons must be reapplied.
            resetMenuIcons
        
        'Repeat last action (menu item only)
        Case tRepeatLast
            If FormMain.MnuEdit(2).Enabled <> newState Then FormMain.MnuEdit(2).Enabled = newState
            
        'Copy (menu item only)
        Case tCopy
            If FormMain.MnuEdit(4).Enabled <> newState Then FormMain.MnuEdit(4).Enabled = newState
        
        'Paste (menu item only)
        Case tPaste
            If FormMain.MnuEdit(5).Enabled <> newState Then FormMain.MnuEdit(5).Enabled = newState
        
        'View (top-menu level)
        Case tView
            If FormMain.MnuView.Enabled <> newState Then FormMain.MnuView.Enabled = newState
        
        'ImageOps is all Image-related menu items; it enables/disables the Image, Select, Color, and Print menus
        Case tImageOps
            If FormMain.MnuImageTop.Enabled <> newState Then
                FormMain.MnuImageTop.Enabled = newState
                
                'Use this same command to disable other menus
                
                'File -> Print
                FormMain.MnuFile(13).Enabled = newState
                
                'Select menu
                FormMain.MnuSelectTop.Enabled = newState
                
                'Adjustments menu
                FormMain.MnuAdjustmentsTop.Enabled = newState
            End If
            
            'FitWindowToImage is a little weird - we disable it if no images are active, but also if images are docked.
            If newState Then
                
                'The "Fit viewport around image" option is only available for floating image windows.  If images are docked,
                ' do not enable that menu, even if requested.
                If g_WindowManager.getFloatState(IMAGE_WINDOW) Then
                    FormMain.MnuFitWindowToImage.Enabled = True
                Else
                    FormMain.MnuFitWindowToImage.Enabled = False
                End If
                
            Else
                FormMain.MnuFitWindowToImage.Enabled = newState
            End If
        
        'Effects (top-level menu)
        Case tEffects
            If FormMain.MnuFilter.Enabled <> newState Then FormMain.MnuFilter.Enabled = newState
            
        'Macro (within the Tools menu)
        Case tMacro
            If FormMain.mnuTool(3).Enabled <> newState Then FormMain.mnuTool(3).Enabled = newState
        
        'Selections in general
        Case tSelection
            
            'If selections are not active, clear all the selection value textboxes
            If Not newState Then
                For i = 0 To toolbar_Selections.tudSel.Count - 1
                    toolbar_Selections.tudSel(i).Value = 0
                Next i
            End If
            
            'Set selection text boxes to enable only when a selection is active.  Other selection controls can remain active
            ' even without a selection present; this allows the user to set certain parameters in advance, so when they actually
            ' draw a selection, it already has the attributes they want.
            For i = 0 To toolbar_Selections.tudSel.Count - 1
                toolbar_Selections.tudSel(i).Enabled = newState
            Next i
            
            'En/disable all selection menu items that rely on an existing selection to operate
            If FormMain.MnuSelect(2).Enabled <> newState Then
                
                'Select none, invert selection
                FormMain.MnuSelect(1).Enabled = newState
                FormMain.MnuSelect(2).Enabled = newState
                
                'Grow/shrink/border/feather/sharpen selection
                For i = 4 To 8
                    FormMain.MnuSelect(i).Enabled = newState
                Next i
                
                'Save selection
                FormMain.MnuSelect(11).Enabled = newState
                
                'Export selection top-level menu
                FormMain.MnuSelect(12).Enabled = newState
                
            End If
                                    
            'Selection enabling/disabling also affects the Crop to Selection command
            If FormMain.MnuImage(7).Enabled <> newState Then FormMain.MnuImage(7).Enabled = newState
            
        'Transformable selection controls specifically
        Case tSelectionTransform
        
            'Under certain circumstances, it is desirable to disable only the selection location boxes
            For i = 0 To toolbar_Selections.tudSel.Count - 1
                If (Not newState) Then toolbar_Selections.tudSel(i).Value = 0
                toolbar_Selections.tudSel(i).Enabled = newState
            Next i
        
        '32bpp color mode (e.g. add/remove alpha channel).  Previously I disabled the "add alpha channel"-type options if the image was already
        ' 32bpp, but I've since changed my mind.  It may be useful to take a 32bpp image and apply a *new* alpha channel, so those options are
        ' now enabled regardless of color depth.  "Remove transparency", however, is still disabled for 24bpp images.
        Case tImgMode32bpp
            FormMain.MnuTransparency(3).Enabled = newState
        
        'If the ExifTool plugin is not available, metadata will ALWAYS be disabled.  (We do not currently have a separate fallback for
        ' reading/browsing/writing metadata.)
        Case tMetadata
        
            If g_ExifToolEnabled Then
                If FormMain.MnuMetadata(0).Enabled <> newState Then FormMain.MnuMetadata(0).Enabled = newState
            Else
                If FormMain.MnuMetadata(0).Enabled Then FormMain.MnuMetadata(0).Enabled = False
            End If
        
        Case tGPSMetadata
        
            If g_ExifToolEnabled Then
                If FormMain.MnuMetadata(3).Enabled <> newState Then FormMain.MnuMetadata(3).Enabled = newState
            Else
                If FormMain.MnuMetadata(3).Enabled Then FormMain.MnuMetadata(3).Enabled = False
            End If
            
        Case tZoom
            If toolbar_File.CmbZoom.Enabled <> newState Then
                toolbar_File.CmbZoom.Enabled = newState
                toolbar_File.cmdZoomIn.Enabled = newState
                toolbar_File.cmdZoomOut.Enabled = newState
            End If
            
            'When disabling zoom controls, reset the zoom drop-down to 100%
            If Not newState Then toolbar_File.CmbZoom.ListIndex = ZOOM_100_PERCENT
            
    End Select
    
End Sub


'For best results, any modal form should be shown via this function.  This function will automatically center the form over the main window,
' while also properly assigning ownership so that the dialog is truly on top of any active windows.  It also handles deactivation of
' other windows (to prevent click-through), and dynamic top-most behavior to ensure that the program doesn't steal focus if the user switches
' to another program while a modal dialog is active.
Public Sub showPDDialog(ByRef dialogModality As FormShowConstants, ByRef dialogForm As Form)

    On Error GoTo showPDDialogError

    'Start by loading the form and hiding it
    dialogForm.Visible = False
    
    'Store a reference to this dialog; if subsequent dialogs are loaded, this dialog will be given ownership over them
    If (currentDialogReference Is Nothing) Then
        
        'This is a regular modal dialog, and the main form should be its owner
        isSecondaryDialog = False
        Set currentDialogReference = dialogForm
                
    Else
    
        'We already have a reference to a modal dialog - that means a modal dialog is raising *another* modal dialog.  Give the previous
        ' modal dialog ownership over this new dialog!
        isSecondaryDialog = True
        
    End If
    
    'Retrieve and cache the hWnd; we need access to this even if the form is unloaded, so we can properly deregister it
    ' with the window manager.
    Dim dialogHwnd As Long
    dialogHwnd = dialogForm.hWnd
    
    'Get the rect of the main form, which we will use to calculate a center position
    Dim ownerRect As winRect
    GetWindowRect FormMain.hWnd, ownerRect
    
    'Determine the center of that rect
    Dim centerX As Long, centerY As Long
    centerX = ownerRect.x1 + (ownerRect.x2 - ownerRect.x1) \ 2
    centerY = ownerRect.y1 + (ownerRect.y2 - ownerRect.y1) \ 2
    
    'Get the rect of the child dialog
    Dim dialogRect As winRect
    GetWindowRect dialogHwnd, dialogRect
    
    'Determine an upper-left point for the dialog based on its size
    Dim newLeft As Long, newTop As Long
    newLeft = centerX - ((dialogRect.x2 - dialogRect.x1) \ 2)
    newTop = centerY - ((dialogRect.y2 - dialogRect.y1) \ 2)
    
    'Move the dialog into place, but do not repaint it (that will be handled in a moment by the .Show event)
    MoveWindow dialogHwnd, newLeft, newTop, dialogRect.x2 - dialogRect.x1, dialogRect.y2 - dialogRect.y1, 0
        
    'Manually disable all other images forms to prevent them from mistakenly receiving input
    Dim i As Long
    If g_NumOfImagesLoaded > 0 Then
        For i = 0 To g_NumOfImagesLoaded
            If Not pdImages(i) Is Nothing Then
                If pdImages(i).IsActive And (Not pdImages(i).containingForm Is Nothing) And (i <> g_CurrentImage) Then pdImages(i).containingForm.Enabled = False
            End If
        Next i
    End If

    'Show the dialog, and dynamically assign its owner to the proper window (the main form if no child windows are active; otherwise, the
    ' active child image window).  Note that in almost all cases, the owning window will already be activated.  The only problem occurs if
    ' a modal dialog is active, and the user switches to another window then returns, while image windows are floating.  Still need to debug
    ' that case.
    'getModalOwner().ActivateWorkaround
    
    'Register the window with the window manager, which will also make it a top-most window
    g_WindowManager.requestTopmostWindow dialogHwnd, getModalOwner().hWnd
    
    'Use VB to actually display the dialog
    dialogForm.Show dialogModality, getModalOwner()
    
    'Re-enable any disabled image forms
    If g_NumOfImagesLoaded > 0 Then
        For i = 0 To g_NumOfImagesLoaded
            If Not pdImages(i) Is Nothing Then
                If pdImages(i).IsActive And (Not pdImages(i).containingForm Is Nothing) And i <> g_CurrentImage Then pdImages(i).containingForm.Enabled = True
            End If
        Next i
    End If
    
    'De-register this hWnd with the window manager
    g_WindowManager.requestTopmostWindow dialogHwnd, 0, True
    
    'Release our reference to this dialog
    If isSecondaryDialog Then
        isSecondaryDialog = False
    Else
        Set currentDialogReference = Nothing
    End If
    
    'If the form has not been unloaded, unload it now
    If Not (dialogForm Is Nothing) Then
        Unload dialogForm
        Set dialogForm = Nothing
    End If
    
    Exit Sub
    
'For reasons I can't yet ascertain, this function will sometimes fail, claiming that a modal window is already active.  If that happens,
' we can just exit.
showPDDialogError:

End Sub

'When a modal dialog needs to be raised, we want to set its ownership to the top-most (relevant) window in the program, which may or may
' not be the main form.  This function should be called to determine the proper owner of any modal dialog box.
'
'If the caller knows in advance that a modal dialog is owned by another modal dialog (for example, a tool dialog displaying a color
' selection dialog), it can explicitly mark the assumeSecondaryDialog function as TRUE.
Public Function getModalOwner(Optional ByVal assumeSecondaryDialog As Boolean = False) As Form

    'If a modal dialog is already active, it gets ownership over subsequent dialogs
    If isSecondaryDialog Or assumeSecondaryDialog Then
        Set getModalOwner = currentDialogReference
        
    'No modal dialog is active, making this the only one.  Give the main form or the active image form ownership.
    Else
        
        'If no images have been loaded, the main form owns any dialog boxes.
        If g_OpenImageCount = 0 Then
            Set getModalOwner = FormMain
        
        'If images HAVE been loaded, make the top-most child the dialog owner
        Else
            Set getModalOwner = pdImages(g_CurrentImage).containingForm
        End If
    
    End If
    
End Function

'Return the system keyboard delay, in seconds.  This isn't an exact science because the delay is actually hardware dependent
' (e.g. the system returns a value from 0 to 3), but we can use a "good enough" approximation.
Public Function getKeyboardDelay() As Double
    Dim keyDelayIndex As Long
    SystemParametersInfo SPI_GETKEYBOARDDELAY, 0, keyDelayIndex, 0
    getKeyboardDelay = (keyDelayIndex + 1) * 0.25
End Function

Public Sub toggleImageTabstripAlignment(ByVal newAlignment As AlignConstants)
    
    'Reset the menu checkmarks
    Dim curMenuIndex As Long
    
    Select Case newAlignment
    
        Case vbAlignLeft
            curMenuIndex = 4
        
        Case vbAlignTop
            curMenuIndex = 5
        
        Case vbAlignRight
            curMenuIndex = 6
        
        Case vbAlignBottom
            curMenuIndex = 7
        
    End Select
    
    Dim i As Long
    For i = 4 To 7
        If i = curMenuIndex Then
            FormMain.MnuWindowTabstrip(i).Checked = True
        Else
            FormMain.MnuWindowTabstrip(i).Checked = False
        End If
    Next i
    
    'Write the preference out to file.
    g_UserPreferences.SetPref_Long "Core", "Image Tabstrip Alignment", CLng(newAlignment)
    
    'Notify the window manager of the change
    g_WindowManager.setImageTabstripAlignment newAlignment
    
    '...and force the tabstrip to redraw itself (which it may not if the tabstrip's size hasn't changed, e.g. if Left and Right layout is toggled)
    toolbar_ImageTabs.forceRedraw
    
End Sub

'The image tabstrip can set to appear under a variety of circumstances.  Use this sub to change the current setting; it will
' automatically handle syncing with the preferences file.
Public Sub toggleImageTabstripVisibility(ByVal newSetting As Long, Optional ByVal suppressInterfaceSync As Boolean = False)

    'Start by synchronizing menu checkmarks to the selected option
    Dim i As Long
    For i = 0 To 2
        If newSetting = i Then
            FormMain.MnuWindowTabstrip(i).Checked = True
        Else
            FormMain.MnuWindowTabstrip(i).Checked = False
        End If
    Next i

    'Write the matching preference out to file
    g_UserPreferences.SetPref_Long "Core", "Image Tabstrip Visibility", newSetting
    
    'Synchronize the interface to match; note that this will handle showing/hiding the tabstrip based on the number of
    ' currently open images.
    If Not suppressInterfaceSync Then syncInterfaceToCurrentImage
    
    'If images are loaded, we may need to redraw their viewports because the available client area may have changed.
    If (g_NumOfImagesLoaded > 0) And (Not g_WindowManager.getFloatState(IMAGE_WINDOW)) Then
        For i = 0 To g_NumOfImagesLoaded
            If (Not pdImages(i) Is Nothing) Then
                If pdImages(i).IsActive Then PrepareViewport pdImages(i).containingForm, "Image tabstrip visibility toggled"
            End If
        Next i
    End If

End Sub

'Both toolbars and image windows can be floated or docked.  Because some behind-the-scenes maintenance has to be applied whenever
' this setting is changed, all float toggle operations should wrap this singular function.
Public Sub toggleWindowFloating(ByVal whichWindowType As pdWindowType, ByVal floatStatus As Boolean, Optional ByVal suspendMenuRefresh As Boolean = False)

    'Make a note of the currently active image
    Dim backupCurrentImage As Long
    backupCurrentImage = g_CurrentImage
    
    Dim i As Long

    Select Case whichWindowType
    
        Case TOOLBAR_WINDOW
            FormMain.MnuWindow(4).Checked = floatStatus
            g_UserPreferences.SetPref_Boolean "Core", "Floating Toolbars", floatStatus
            g_WindowManager.setFloatState TOOLBAR_WINDOW, floatStatus
            
            'If image windows are docked, we need to redraw all their windows, because the available client area will have changed.
            If Not g_WindowManager.getFloatState(IMAGE_WINDOW) Then
                If g_NumOfImagesLoaded > 0 Then
                    For i = 0 To g_NumOfImagesLoaded
                        If (Not pdImages(i) Is Nothing) Then
                            If pdImages(i).IsActive Then PrepareViewport pdImages(i).containingForm, "Toolbar float status changed"
                        End If
                    Next i
                End If
            End If
            
        Case IMAGE_WINDOW
            FormMain.MnuWindow(5).Checked = floatStatus
            g_UserPreferences.SetPref_Boolean "Core", "Floating Image Windows", floatStatus
            
            'If image windows are floating, do not display the image tabstrip
            If (Not floatStatus) Then
                If g_OpenImageCount > 1 Then
                    g_WindowManager.setWindowVisibility toolbar_ImageTabs.hWnd, True
                Else
                    g_WindowManager.setWindowVisibility toolbar_ImageTabs.hWnd, False
                End If
            Else
                g_WindowManager.setWindowVisibility toolbar_ImageTabs.hWnd, False
            End If
            
            'Notify the window manager of the change
            g_WindowManager.setFloatState IMAGE_WINDOW, floatStatus
            
            'As a convenience to the user, cascade any open windows
            If floatStatus And (g_OpenImageCount > 0) Then g_WindowManager.cascadeImageWindows
            
            'All image windows need to be redrawn, because the available client area will have changed.
            If g_NumOfImagesLoaded > 0 Then
                For i = 0 To g_NumOfImagesLoaded
                    If (Not pdImages(i) Is Nothing) Then
                        If pdImages(i).IsActive Then PrepareViewport pdImages(i).containingForm, "Image float status changed"
                    End If
                Next i
            End If
            
            'If image windows are docked, there's no reason to display extra Window menu items like "Cascade" or "Minimize all windows".
            ' En/disable those menu entries as necessary.
            
            '(The 9 here is a magic number corresponding to the index of the Cascade menu entry.
            For i = 9 To FormMain.MnuWindow.Count - 1
                FormMain.MnuWindow(i).Visible = g_WindowManager.getFloatState(IMAGE_WINDOW)
            Next i
            
            'Menu icons may need to be reapplied to those menus if they were previously hidden
            If Not suspendMenuRefresh Then resetMenuIcons
            
    End Select
    
    'Restore focus to the previously active window
    If (Not suspendMenuRefresh) And (g_NumOfImagesLoaded > 0) Then
        If Not (pdImages(backupCurrentImage).containingForm Is Nothing) Then pdImages(backupCurrentImage).containingForm.ActivateWorkaround
    End If
    
    'The "Fit viewport around image" option is only available for floating image windows
    If g_WindowManager.getFloatState(IMAGE_WINDOW) Then
        FormMain.MnuFitWindowToImage.Enabled = True
    Else
        FormMain.MnuFitWindowToImage.Enabled = False
    End If

End Sub

'Toolbars can be dynamically shown/hidden by a variety of processes (e.g. clicking an entry in the Window menu, clicking the X in a
' toolbar's command box, etc).  All those operations should wrap this singular function.
Public Sub toggleToolbarVisibility(ByVal whichToolbar As pdToolbarType)

    Select Case whichToolbar
    
        Case FILE_TOOLBOX
            FormMain.MnuWindow(0).Checked = Not FormMain.MnuWindow(0).Checked
            g_UserPreferences.SetPref_Boolean "Core", "Show File Toolbox", FormMain.MnuWindow(0).Checked
            g_WindowManager.setWindowVisibility toolbar_File.hWnd, FormMain.MnuWindow(0).Checked
        
        Case SELECTION_TOOLBOX
            FormMain.MnuWindow(1).Checked = Not FormMain.MnuWindow(1).Checked
            g_UserPreferences.SetPref_Boolean "Core", "Show Selections Toolbox", FormMain.MnuWindow(1).Checked
            g_WindowManager.setWindowVisibility toolbar_Selections.hWnd, FormMain.MnuWindow(1).Checked
    
    End Select
    
    'If both images and toolbars are docked, we need to redraw any open images because the available client area will have changed.
    If g_NumOfImagesLoaded > 0 Then
        Dim i As Long
        For i = 0 To g_NumOfImagesLoaded
            If (Not pdImages(i) Is Nothing) Then
                If pdImages(i).IsActive Then PrepareViewport pdImages(i).containingForm, "Toolbar visibility changed"
            End If
        Next i
    End If

End Sub

Public Function fixDPI(ByVal pxMeasurement As Long) As Long

    'The first time this function is called, dpiRatio will be 0.  Calculate it.
    If dpiRatio = 0# Then
    
        'There are 1440 twips in one inch.  (Twips are resolution-independent.)  Use that knowledge to calculate DPI.
        dpiRatio = 1440 / Screen.TwipsPerPixelX
        
        'FYI: if the screen resolution is 96 dpi, this function will return the original pixel measurement, due to
        ' this calculation.
        dpiRatio = dpiRatio / 96
    
    End If
    
    fixDPI = CLng(dpiRatio * CDbl(pxMeasurement))
    
End Function

Public Function fixDPIFloat(ByVal pxMeasurement As Long) As Double

    'The first time this function is called, dpiRatio will be 0.  Calculate it.
    If dpiRatio = 0# Then
    
        'There are 1440 twips in one inch.  (Twips are resolution-independent.)  Use that knowledge to calculate DPI.
        dpiRatio = 1440 / Screen.TwipsPerPixelX
        
        'FYI: if the screen resolution is 96 dpi, this function will return the original pixel measurement, due to
        ' this calculation.
        dpiRatio = dpiRatio / 96
    
    End If
    
    fixDPIFloat = dpiRatio * CDbl(pxMeasurement)
    
End Function

Public Sub displayWaitScreen(ByVal waitTitle As String, ByRef ownerForm As Form)
    
    FormWait.Visible = False
    
    FormWait.lblWaitTitle.Caption = waitTitle
    FormWait.lblWaitTitle.Visible = True
    FormWait.lblWaitTitle.Refresh
    
    Screen.MousePointer = vbHourglass
    
    FormWait.Show vbModeless, ownerForm
    FormWait.Refresh
    DoEvents
    
End Sub

Public Sub hideWaitScreen()
    Screen.MousePointer = vbDefault
    Unload FormWait
End Sub

'Given a wordwrap label with a set size, attempt to fit the label's text inside it
Public Sub fitWordwrapLabel(ByRef srcLabel As Label, ByRef srcForm As Form)

    'We will use a pdFont object to help us measure the label in question
    Dim tmpFont As pdFont
    Set tmpFont = New pdFont
    tmpFont.setFontBold srcLabel.FontBold
    tmpFont.setFontItalic srcLabel.FontItalic
    tmpFont.setFontFace srcLabel.FontName
    tmpFont.setFontSize srcLabel.FontSize
    tmpFont.createFontObject
    tmpFont.setTextAlignment srcLabel.Alignment
    tmpFont.attachToDC srcForm.hDC
    
    'Retrieve the height from the pdFont class
    Dim lblHeight As Long
    lblHeight = tmpFont.getHeightOfWordwrapString(srcLabel.Caption, srcLabel.Width - 1)
    
    Dim curFontSize As Long
    curFontSize = srcLabel.FontSize
    
    'If the text is too tall, shrink the font until an acceptable size is found.  Note that the reported text value tends to be
    ' smaller than the space actually required.  I do not know why this happens.  To account for it, I cut a further 10% from
    ' the requested height, just to be safe.
    If (lblHeight > srcLabel.Height * 0.85) Then
            
        'Try shrinking the font size until an acceptable width is found
        Do While (lblHeight > srcLabel.Height * 0.85) And (curFontSize >= 8)
        
            curFontSize = curFontSize - 1
            
            tmpFont.setFontSize curFontSize
            tmpFont.createFontObject
            tmpFont.attachToDC srcForm.hDC
            lblHeight = tmpFont.getHeightOfWordwrapString(srcLabel.Caption, srcLabel.Width)
            
        Loop
            
    End If
    
    'When an acceptable size is found, set it and exit.
    srcLabel.FontSize = curFontSize
    srcLabel.Refresh

End Sub

'Because VB6 apps look terrible on modern version of Windows, I do a bit of beautification to every form upon at load-time.
' This routine is nice because every form calls it at least once, so I can make centralized changes without having to rewrite
' code in every individual form.  This is also where run-time translation occurs.
Public Sub makeFormPretty(ByRef tForm As Form, Optional ByRef customTooltips As clsToolTip, Optional ByVal tooltipsAlreadyInitialized As Boolean = False, Optional ByVal useDoEvents As Boolean = False)

    'Before doing anything else, make sure the form's default cursor is set to an arrow
    tForm.MouseIcon = LoadPicture("")
    tForm.MousePointer = 0

    'FORM STEP 1: Enumerate through every control on the form.  We will be making changes on-the-fly on a per-control basis.
    Dim eControl As Control
    
    For Each eControl In tForm.Controls
        
        'STEP 1: give all clickable controls a hand icon instead of the default pointer.
        ' (Note: this code will set all command buttons, scroll bars, option buttons, check boxes,
        ' list boxes, combo boxes, and file/directory/drive boxes to use the system hand cursor)
        If ((TypeOf eControl Is CommandButton) Or (TypeOf eControl Is HScrollBar) Or (TypeOf eControl Is VScrollBar) Or (TypeOf eControl Is OptionButton) Or (TypeOf eControl Is CheckBox) Or (TypeOf eControl Is ListBox) Or (TypeOf eControl Is ComboBox) Or (TypeOf eControl Is FileListBox) Or (TypeOf eControl Is DirListBox) Or (TypeOf eControl Is DriveListBox)) And (Not TypeOf eControl Is PictureBox) Then
            setHandCursor eControl
        End If
        
        'STEP 2: if the current system is Vista or later, and the user has requested modern typefaces via Edit -> Preferences,
        ' redraw all control fonts using Segoe UI.
        If ((TypeOf eControl Is TextBox) Or (TypeOf eControl Is CommandButton) Or (TypeOf eControl Is OptionButton) Or (TypeOf eControl Is CheckBox) Or (TypeOf eControl Is ListBox) Or (TypeOf eControl Is ComboBox) Or (TypeOf eControl Is FileListBox) Or (TypeOf eControl Is DirListBox) Or (TypeOf eControl Is DriveListBox) Or (TypeOf eControl Is Label)) And (Not TypeOf eControl Is PictureBox) Then
            eControl.FontName = g_InterfaceFont
        End If
        
        If ((TypeOf eControl Is jcbutton) Or (TypeOf eControl Is smartOptionButton) Or (TypeOf eControl Is smartCheckBox) Or (TypeOf eControl Is sliderTextCombo) Or (TypeOf eControl Is textUpDown) Or (TypeOf eControl Is commandBar)) Then
            eControl.Font.Name = g_InterfaceFont
        End If
                        
        'STEP 3: remove TabStop from each picture box.  They should never receive focus, but I often forget to change this
        ' at design-time.
        If (TypeOf eControl Is PictureBox) Then eControl.TabStop = False
        
        'Optionally, DoEvents can be called after each change.  This slows the process, but it allows external progress
        ' bars to be automatically refreshed.
        If useDoEvents Then DoEvents
                
    Next
    
    'FORM STEP 2: subclass this form and force controls to render transparent borders properly.
    g_Themer.requestContainerSubclass tForm.hWnd
    
    'FORM STEP 3: find any picture boxes on the form that are being used as containers, and subclass them as well
    For Each eControl In tForm.Controls
        If (TypeOf eControl Is PictureBox) Then
            'SubclassFrame eControl.hWnd, False
        End If
        
        'Optionally, DoEvents can be called after each change.  This slows the process, but it allows external progress
        ' bars to be automatically refreshed.
        If useDoEvents Then DoEvents
        
    Next
    
    'FORM STEP 4: translate the form (and all controls on it)
    If g_Language.translationActive And tForm.Enabled Then
        g_Language.applyTranslations tForm, useDoEvents
    End If
    
    'FORM STEP 5: if a custom tooltip handler was passed in, activate and populate it now.
    If Not (customTooltips Is Nothing) Then
        
        'In rare cases, the custom tooltip handler passed to this function may already be initialized.  Some forms
        ' do this if they need to handle multiline tooltips (as VB will not handle them properly).  If the class has
        ' NOT been initialized, we can do so now - otherwise, trust that it was already created correctly.
        If Not tooltipsAlreadyInitialized Then
            customTooltips.Create tForm
            customTooltips.MaxTipWidth = PD_MAX_TOOLTIP_WIDTH
            customTooltips.DelayTime(ttDelayShow) = 10000
        End If
        
        'Once again, enumerate every control on the form and copy their tooltips into this object.  (This allows
        ' for things like automatic multiline support, unsupported characters, theming, and displaying tooltips
        ' on the correct monitor of a multimonitor setup.)
        Dim tmpTooltip As String
        For Each eControl In tForm.Controls
            
            If (TypeOf eControl Is CommandButton) Or (TypeOf eControl Is CheckBox) Or (TypeOf eControl Is OptionButton) Or (TypeOf eControl Is PictureBox) Or (TypeOf eControl Is TextBox) Or (TypeOf eControl Is ListBox) Or (TypeOf eControl Is ComboBox) Or (TypeOf eControl Is colorSelector) Then
                If (Trim(eControl.ToolTipText) <> "") Then
                    tmpTooltip = eControl.ToolTipText
                    eControl.ToolTipText = ""
                    customTooltips.AddTool eControl, tmpTooltip
                End If
            End If
            
            'Optionally, DoEvents can be called after each change.  This slows the process, but it allows external progress
            ' bars to be automatically refreshed.
            If useDoEvents Then DoEvents
            
        Next
                
    End If
    
    
    'Refresh all non-MDI forms after making the changes above
    If tForm.Name <> "FormMain" Then
        tForm.Refresh
    Else
        'The main from is a bit different - if it has been translated or changed, it needs menu icons reassigned.
        If FormMain.Visible Then applyAllMenuIcons
    End If
        
End Sub


'Used to enable font smoothing if currently disabled.
Public Sub handleClearType(ByVal startingProgram As Boolean)
    
    'At start-up, activate ClearType.  At shutdown, restore the original setting (as necessary).
    If startingProgram Then
    
        hadToChangeSmoothing = 0
    
        'Get current font smoothing setting
        Dim pv As Long
        SystemParametersInfo SPI_GETFONTSMOOTHING, 0, pv, 0
        
        'If font smoothing is disabled, mark it
        If pv = 0 Then hadToChangeSmoothing = 2
        
        'If font smoothing is enabled but set to Standard instead of ClearType, mark it
        If pv <> 0 Then
            SystemParametersInfo SPI_GETFONTSMOOTHINGTYPE, 0, pv, 0
            If pv = SmoothingStandardType Then hadToChangeSmoothing = 1
        End If
        
        Select Case hadToChangeSmoothing
        
            'ClearType is enabled, no changes necessary
            Case 0
            
            'Standard smoothing is enabled; switch it to ClearType for the duration of the program
            Case 1
                SystemParametersInfo SPI_SETFONTSMOOTHINGTYPE, 0, ByVal SmoothingClearType, 0
                
            'No smoothing is enabled; turn it on and activate ClearType for the duration of the program
            Case 2
                SystemParametersInfo SPI_SETFONTSMOOTHING, 1, pv, 0
                SystemParametersInfo SPI_SETFONTSMOOTHINGTYPE, 0, ByVal SmoothingClearType, 0
            
        End Select
    
    Else
        
        Select Case hadToChangeSmoothing
        
            'ClearType was enabled, no action necessary
            Case 0
            
            'Standard smoothing was enabled; restore it now
            Case 1
                SystemParametersInfo SPI_SETFONTSMOOTHINGTYPE, 0, ByVal SmoothingStandardType, 0
                
            'No smoothing was enabled; restore that setting now
            Case 2
                SystemParametersInfo SPI_SETFONTSMOOTHING, 0, pv, 0
                SystemParametersInfo SPI_SETFONTSMOOTHINGTYPE, 0, ByVal SmoothingNone, 0
        
        End Select
    
    End If
    
End Sub

'When a themed form is unloaded, it may be desirable to release certain changes made to it - or in our case, unsubclass it.
' This function should be called when any themed form is unloaded.
Public Sub ReleaseFormTheming(ByRef tForm As Object)
    g_Themer.releaseContainerSubclass tForm.hWnd
    Set tForm = Nothing
End Sub

'Perform any drawing routines related to the main form
Public Sub RedrawMainForm()
    
    'Redraw the progress bar
    If FormMain.picProgBar.Visible Then FormMain.picProgBar.Refresh
    g_ProgBar.Draw
    
End Sub

'Display the specified size in the main form's status bar
Public Sub DisplaySize(ByVal iWidth As Long, ByVal iHeight As Long)
    
    toolbar_File.lblImgSize.Caption = g_Language.TranslateMessage("size") & ":" & vbCrLf & iWidth & "x" & iHeight
    toolbar_File.lblImgSize.Refresh
    
    'Size is only displayed when it is changed, so if any controls have a maxmimum value linked to the size of the image,
    ' now is an excellent time to update them.
    If iWidth < iHeight Then
        toolbar_Selections.sltSelectionBorder.Max = iWidth
        toolbar_Selections.sltCornerRounding.Max = iWidth
        toolbar_Selections.sltSelectionLineWidth.Max = iHeight
    Else
        toolbar_Selections.sltSelectionBorder.Max = iHeight
        toolbar_Selections.sltCornerRounding.Max = iHeight
        toolbar_Selections.sltSelectionLineWidth.Max = iWidth
    End If
    
End Sub

'PhotoDemon's software processor requires that all parameters be passed as a string, with individual parameters separated by
' the "|" character.  This function can be used to automatically assemble any number of parameters into such a string.
Public Function buildParams(ParamArray allParams() As Variant) As String

    buildParams = ""

    If Not IsMissing(allParams) Then
    
        Dim i As Long
        For i = LBound(allParams) To UBound(allParams)
            buildParams = buildParams & CStr(allParams(i))
            If i < UBound(allParams) Then buildParams = buildParams & "|"
        Next i
    
    End If

End Function

'This wrapper is used in place of the standard MsgBox function.  At present it's just a wrapper around MsgBox, but
' in the future I may replace the dialog function with something custom.
Public Function pdMsgBox(ByVal pMessage As String, ByVal pButtons As VbMsgBoxStyle, ByVal pTitle As String, ParamArray ExtraText() As Variant) As VbMsgBoxResult

    Dim newMessage As String, newTitle As String
    newMessage = pMessage
    newTitle = pTitle

    'All messages are translatable, but we don't want to translate them if the translation object isn't ready yet
    If (Not (g_Language Is Nothing)) Then
        If g_Language.readyToTranslate Then
            If g_Language.translationActive Then
                newMessage = g_Language.TranslateMessage(pMessage)
                newTitle = g_Language.TranslateMessage(pTitle)
            End If
        End If
    End If
    
    'Once the message is translated, we can add back in any optional parameters
    If Not IsMissing(ExtraText) Then
    
        Dim i As Long
        For i = LBound(ExtraText) To UBound(ExtraText)
            newMessage = Replace$(newMessage, "%" & i + 1, CStr(ExtraText(i)))
        Next i
    
    End If

    pdMsgBox = MsgBox(newMessage, pButtons, newTitle)

End Function

'This popular function is used to display a message in the main form's status bar.
' INPUTS:
' 1) the message to be displayed (mString)
' *2) any values that must be calculated at run-time, which are labeled in the message string by "%n"
Public Sub Message(ByVal mString As String, ParamArray ExtraText() As Variant)

    Dim newString As String
    newString = mString

    'All messages are translatable, but we don't want to translate them if the translation object isn't ready yet
    If (Not (g_Language Is Nothing)) Then
        If g_Language.readyToTranslate Then
            If g_Language.translationActive Then newString = g_Language.TranslateMessage(mString)
        End If
    End If
    
    'Once the message is translated, we can add back in any optional parameters
    If Not IsMissing(ExtraText) Then
    
        Dim i As Long
        For i = LBound(ExtraText) To UBound(ExtraText)
            newString = Replace$(newString, "%" & i + 1, CStr(ExtraText(i)))
        Next i
    
    End If

    If MacroStatus = MacroSTART Then newString = newString & " {-" & g_Language.TranslateMessage("Recording") & "-}"
    
    If MacroStatus <> MacroBATCH Then
        If FormMain.Visible Then
            g_ProgBar.Text = newString
            g_ProgBar.Draw
        End If
    End If
    
    If Not g_IsProgramCompiled Then Debug.Print newString
    
    'If we're logging program messages, open up a log file and dump the message there
    If g_LogProgramMessages = True Then
        Dim fileNum As Integer
        fileNum = FreeFile
        Open g_UserPreferences.getDataPath & PROGRAMNAME & "_DebugMessages.log" For Append As #fileNum
            Print #fileNum, mString
            If mString = "Finished." Then Print #fileNum, vbCrLf
        Close #fileNum
    End If
    
End Sub

'Pass AutoSelectText a text box and it will select all text currently in the text box
Public Function AutoSelectText(ByRef tBox As TextBox)
    If Not tBox.Visible Then Exit Function
    If Not tBox.Enabled Then Exit Function
    tBox.SetFocus
    tBox.SelStart = 0
    tBox.SelLength = Len(tBox.Text)
End Function

'When the mouse is moved outside the primary image, clear the image coordinates display
Public Sub ClearImageCoordinatesDisplay()
    toolbar_File.lblCoordinates.Caption = ""
    toolbar_File.lblCoordinates.Refresh
End Sub

'Populate the passed combo box with options related to distort filter edge-handle options.  Also, select the specified method by default.
Public Sub popDistortEdgeBox(ByRef cmbEdges As ComboBox, Optional ByVal defaultEdgeMethod As EDGE_OPERATOR)

    cmbEdges.Clear
    cmbEdges.AddItem " clamp them to the nearest available pixel"
    cmbEdges.AddItem " reflect them across the nearest edge"
    cmbEdges.AddItem " wrap them around the image"
    cmbEdges.AddItem " erase them"
    cmbEdges.AddItem " ignore them"
    cmbEdges.ListIndex = defaultEdgeMethod
    
End Sub

'Return the width (and below, height) of a string, in pixels, according to the font assigned to fontContainerDC
Public Function getPixelWidthOfString(ByVal srcString As String, ByVal fontContainerDC As Long) As Long
    Dim txtSize As POINTAPI
    GetTextExtentPoint32 fontContainerDC, srcString, Len(srcString), txtSize
    getPixelWidthOfString = txtSize.x
End Function

Public Function getPixelHeightOfString(ByVal srcString As String, ByVal fontContainerDC As Long) As Long
    Dim txtSize As POINTAPI
    GetTextExtentPoint32 fontContainerDC, srcString, Len(srcString), txtSize
    getPixelHeightOfString = txtSize.y
End Function
