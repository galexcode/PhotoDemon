Attribute VB_Name = "Custom_Dialog_Handler"
'***************************************************************************
'Custom Dialog Interface
'Copyright �2011-2012 by Tanner Helland
'Created: 30/November/12
'Last updated: 04/December/12
'Last update: added support for the JPEG-2000 (JP2) dialog
'
'Module for handling all custom dialog forms used by PhotoDemon.  There are quite a few already, and I expect
' the number to grow as I phase out generic message boxes in favor of more descriptive (and eye-catching)
' dialogs designed for a specific purpose.
'
'All dialogs are based off the same template, as you can see - they are just modal forms with a specially
' designed ".ShowDialog" sub or function that sets a ".userResponse" property.  The wrapper function in this
' module simply checks that value, unloads the dialog form, then returns it; this keeps all load/unload
' burdens here so that calling functions can simply use a MsgBox-style line to call the dialogs and check
' the user's response.
'
'***************************************************************************

Option Explicit

'Present a dialog box to confirm the closing of an unsaved image
Public Function confirmClose(ByVal formID As Long) As VbMsgBoxResult

    Load dialog_UnsavedChanges
    
    dialog_UnsavedChanges.formID = formID
    dialog_UnsavedChanges.ShowDialog
    
    confirmClose = dialog_UnsavedChanges.DialogResult
    
    Unload dialog_UnsavedChanges
    Set dialog_UnsavedChanges = Nothing

End Function

'Present a dialog box to ask the user how they want to deal with a multipage image.
Public Function promptMultiImage(ByVal srcFilename As String, ByVal numOfPages As Long) As VbMsgBoxResult

    Load dialog_MultiImage
    dialog_MultiImage.ShowDialog srcFilename, numOfPages
    
    promptMultiImage = dialog_MultiImage.DialogResult
    
    Unload dialog_MultiImage
    Set dialog_MultiImage = Nothing

End Function

'Present a dialog box to ask the user for various JPEG export settings
Public Function promptJPEGSettings(Optional ByVal showAdvanced As Boolean = False) As VbMsgBoxResult

    Load dialog_ExportJPEG
    dialog_ExportJPEG.ShowDialog showAdvanced

    promptJPEGSettings = dialog_ExportJPEG.DialogResult
    
    Unload dialog_ExportJPEG
    Set dialog_ExportJPEG = Nothing

End Function

'Present a dialog box to ask the user for various JPEG-2000 (JP2) export settings
Public Function promptJP2Settings() As VbMsgBoxResult

    Load dialog_ExportJP2
    dialog_ExportJP2.ShowDialog

    promptJP2Settings = dialog_ExportJP2.DialogResult
    
    Unload dialog_ExportJP2
    Set dialog_ExportJP2 = Nothing

End Function