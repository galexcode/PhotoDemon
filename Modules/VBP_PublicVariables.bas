Attribute VB_Name = "Public_Variables"

'Contains any and all publicly-declared variables.  I am trying to move
' all public variables here (for obvious reasons), but the transition may
' not be completely done as long as this comment remains!

Option Explicit


'The number of images PhotoDemon has loaded this session (always goes up, never down; starts at zero when the program is loaded).
' This value correlates to the upper bound of the primary pdImages array.  For performance reasons, that array is not dynamically
' resized when images are loaded - the array stays the same size, and entries are deactivated as needed.  Thus, WHENEVER YOU
' NEED TO ITERATE THROUGH ALL LOADED IMAGES, USE THIS VALUE INSTEAD OF g_OpenImageCount.
Public g_NumOfImagesLoaded As Long

'The ID number (e.g. index in the pdImages array) of image the user is currently interacting with (e.g. the currently active image
' window).  Whenever a function needs to access the current image, use pdImages(g_CurrentImage).
Public g_CurrentImage As Long

'Number of image windows CURRENTLY OPEN.  This value goes up and down as images are opened or closed.  Use it to test for no open
' images (e.g. If g_OpenImageCount = 0...).  Note that this value SHOULD NOT BE USED FOR ITERATING OPEN IMAGES.  Instead, use
' g_NumOfImagesLoaded, which will always match the upper bound of the pdImages() array, and never decrements, even when images
' are unloaded.
Public g_OpenImageCount As Long

'This array is the heart and soul of a given PD session.  Every time an image is loaded, all of its relevant data is stored within
' a new entry in this array.
Public pdImages() As pdImage

'Main user preferences and settings handler
Public g_UserPreferences As pdPreferences

'Main file format compatibility handler
Public g_ImageFormats As pdFormats

'Main language and translation handler
Public g_Language As pdTranslate

'Progress bar class
Public g_ProgBar As cProgressBar

'Currently selected tool, previous tool
Public g_CurrentTool As PDTools
Public g_PreviousTool As PDTools

'Currently supported tools; these numbers correspond to the index of the tool's command button on the main form
Public Enum PDTools
    SELECT_RECT = 0
    SELECT_CIRC = 1
    SELECT_LINE = 2
End Enum

#If False Then
    Const SELECT_RECT = 0
    Const SELECT_CIRC = 1
    Const SELECT_LINE = 2
#End If

'Selection variables

'How should the selection be rendered?
Public Enum SelectionRender
    sLightbox = 0
    sHighlightBlue = 1
    sHighlightRed = 2
    sInvertRect = 3
End Enum


'Zoom data
Public Type ZoomData
    ZoomCount As Byte
    ZoomArray() As Double
    ZoomFactor() As Double
End Type

Public g_Zoom As ZoomData

'Whether or not to resize large images to fit on-screen (0 means "yes," 1 means "no")
Public g_AutozoomLargeImages As Long

'The path where DLLs and related support libraries are kept, currently "ProgramPath\App\PhotoDemon\Plugins\"
Public g_PluginPath As String

'Command line (used here for processing purposes)
Public g_CommandLine As String

'Is scanner/digital camera support enabled?
Public g_ScanEnabled As Boolean

'Is compression via zLib enabled?
Public g_ZLibEnabled As Boolean

'Is metadata handling via ExifTool enabled?
Public g_ExifToolEnabled As Boolean

'Because FreeImage is used far more than any other plugin, we no longer load it on-demand.  It is loaded once
' when the program starts, and released when the program ends.  This saves us from repeatedly having to load/free
' the entire library (which is fairly large).  This variable stores our received library handle.
Public g_FreeImageHandle As Long

'How to draw the background of image forms; -1 is checkerboard, any other value is treated as an RGB long
Public g_CanvasBackground As Long

'Whether or not to render a drop shadow onto the canvas around the image
Public g_CanvasDropShadow As Boolean

'g_canvasShadow contains a pdShadow object that helps us render a drop shadow around the image, if the user requests it
Public g_CanvasShadow As pdShadow

'Does the user want us to prompt them when they try to close unsaved images?
Public g_ConfirmClosingUnsaved As Boolean

'Whether or not to log program messages in a separate file - this is useful for debugging
Public g_LogProgramMessages As Boolean

'Whether or not we are running in the IDE or compiled
Public g_IsProgramCompiled As Boolean

'Temporary loading variable to disable Autog_Zoom feature
Public g_AllowViewportRendering As Boolean

'For the Open and Save common dialog boxes, it's polite to remember what format the user used last, then default
' the boxes to that.  (Note that these values are stored in the preferences file as well, but that is only accessed
' upon program load and unload.)
Public g_LastOpenFilter As Long
Public g_LastSaveFilter As Long

'DIB that contains a 2x2 pattern of the alpha checkerboard.  Use it with CreatePatternBrush to paint the alpha
' checkerboard prior to rendering.
Public g_CheckerboardPattern As pdLayer

'Is the current system running Vista, Windows 7, or later?  (Used to determine availability of certain system features)
Public g_IsVistaOrLater As Boolean
Public g_IsWin7OrLater As Boolean

'Is theming enabled?  (Used to handle some menu icon rendering quirks)
Public g_IsThemingEnabled As Boolean

'Render the interface using Segoe UI if the user specifies as much in the Preferences dialog
Public g_UseFancyFonts As Boolean
Public g_InterfaceFont As String

'This g_cMonitors object contains data on all monitors on this system.  It is used to handle multiple monitor situations.
Public g_cMonitors As clsMonitors

'If the user attempts to close the program while multiple unsaved images are present, these values allow us to count
' a) how many unsaved images are present
' b) if the user wants to deal with all the images (if the "Repeat this action..." box is checked on the unsaved
'     image confirmation prompt) in the same fashion
' c) what the user's preference is for dealing with all the unsaved images
Public g_NumOfUnsavedImages As Long
Public g_DealWithAllUnsavedImages As Boolean
Public g_HowToDealWithAllUnsavedImages As VbMsgBoxResult

'When the entire program is being shut down, this variable is set
Public g_ProgramShuttingDown As Boolean

'The user is attempting to close all images (necessary for handling the "repeat for all images" check box)
Public g_ClosingAllImages As Boolean

'JPEG export options; these are set by the JPEG export dialog if the user clicks "OK" (not Cancel)
Public g_JPEGQuality As Long
Public g_JPEGFlags As Long
Public g_JPEGThumbnail As Long

'JPEG-2000 export compression ratio; this is set by the JP2 export dialog if the user clicks "OK" (not Cancel)
Public g_JP2Compression As Long

'Exported color depth
Public g_ColorDepth As Long

'Color count
Public g_LastColorCount As Long

'Is the current image grayscale?  This variable is set by the quick count colors routine.  Do not trust its
' state unless you have just called the quick count colors routine (otherwise it may be outdated).
Public g_IsImageGray As Boolean

'Is the current image black and white (literally, is it monochrome e.g. comprised of JUST black and JUST white)?
' This variable is set by the quick count colors routine.  Do not trust its state unless you have just called
' the quick count colors routine (otherwise it may be outdated).
Public g_IsImageMonochrome As Boolean

'What threshold should be used for simplifying an image's complex alpha channel?
' (This is set by the custom alpha cutoff dialog.)
Public g_AlphaCutoff As Byte

'When an image has its colors counted, the image's ID is stored here.  Other functions can use this to see if the
' current color count is relevant for a given image (e.g. if the image being worked on has just had its colors counted).
Public g_LastImageScanned As Long

'Some actions take a long time to execute.  This global variable can be used to track if a function is still running.
' Just make sure to initialize it properly (in case the last function didn't!).
'Public g_Processing As Boolean

'If this is the first time the user has run PhotoDemon (as determined by the lack of a preferences XML file), this
' variable will be set to TRUE early in the load process.  Other routines can then modify their behavior accordingly.
Public g_IsFirstRun As Boolean

'Drag and drop operations are allowed at certain times, but not others.  Any time a modal form is displayed, drag-and-drop
' must be disallowed - with the exception of common dialog boxes.  To make sure this behavior is carefully maintained,
' we track drag-and-drop enabling ourselves
Public g_AllowDragAndDrop As Boolean

'While Undo/Redo operations are active, certain tasks can be ignored.  This public value can be used to check Undo/Redo activity.
Public g_UndoRedoActive As Boolean

'Per the excellent advice of Kroc (camendesign.com), a custom UserMode variable is less prone to errors than the usual
' Ambient.UserMode value supplied to ActiveX controls.  This fixes a problem where ActiveX controls sometimes think they
' are being run in a compiled EXE, when actually their properties are just being written as part of .exe compiling.
Public g_UserModeFix As Boolean

'PhotoDemon's language files provide a small amount of metadata to help the program know how to use them.  This type
' was previously declared inside the pdTranslate class, but with the addition of a Language Editor, I have moved it
' here, so the entire project can access the type.
Public Type pdLanguageFile
    Author As String
    FileName As String
    langID As String
    langName As String
    langType As String
    langVersion As String
    langStatus As String
End Type

'GDI+ availability is determined at the very start of the program; we rely on it heavily, so expect problems if
' it can't be initialized!
Public g_GDIPlusAvailable As Boolean

'PhotoDemon's primary window manager.  This handles positioning, layering, and sizing of all windows in the project.
Public g_WindowManager As pdWindowManager

'PhotoDemon's visual theme engine.
Public g_Themer As pdVisualThemes

'PhotoDemon's recent files manager.
Public g_RecentFiles As pdRecentFiles

'To improve mousewheel handling, we dynamically track the position of the mouse.  If it is over the image tabstrip,
' the main form will forward mousewheel events there; otherwise, the image window gets them.
Public g_MouseOverImageTabstrip As Boolean

