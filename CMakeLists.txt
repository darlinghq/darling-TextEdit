project(TextEdit)

add_compile_options(
	-nostdinc
	-Wmost
	-Wno-four-char-constants
	-Wno-unknown-pragmas
	-std=gnu99
)

add_darling_executable(TextEdit
	Document.m
	Controller.m
	ScalingScrollView.m
	MultiplePageView.m
	Preferences.m
	Edit_main.m
	EncodingManager.m
	DocumentController.m
	DocumentWindowController.m
	LinePanelController.m
	PrintPanelAccessoryController.m
	DocumentPropertiesPanelController.m
	FontNameTransformer.m
	PrintingTextView.m
)
set_target_properties(TextEdit PROPERTIES LINK_FLAGS "-Wl,-sectorder,__TEXT,__text,${CMAKE_CURRENT_SOURCE_DIR}/TextEdit.scatterload -Wl,-e,start")
