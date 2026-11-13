project(TextEdit)

add_compile_options(
	-nostdinc
	-Wno-deprecated-declarations
)

add_darling_executable(TextEdit
	Controller.m
	Document.m
	DocumentController.m
	DocumentPropertiesPanelController.m
	DocumentWindowController.m
	Edit_main.m
	EncodingManager.m
	FontNameTransformer.m
	LinePanelController.m
	MultiplePageView.m
	Preferences.m
	PrintingTextView.m
	PrintPanelAccessoryController.m
	ScalingScrollView.m
)

target_link_libraries(TextEdit AppKit Foundation objc)
set_property(TARGET TextEdit APPEND_STRING PROPERTY
	LINK_FLAGS " -Wl,-sectorder,__TEXT,__text,${CMAKE_CURRENT_SOURCE_DIR}/TextEdit.scatterload")

set(TextEdit_contents "libexec/darling/Applications/TextEdit.app/Contents")

# Info.plist: fill in the build settings Xcode would substitute
file(STRINGS Version.xcconfig TextEdit_version_line REGEX "^CURRENT_PROJECT_VERSION")
string(REGEX REPLACE ".*= *" "" TextEdit_version "${TextEdit_version_line}")
file(READ Info-TextEdit.plist TextEdit_plist)
string(REPLACE "$(CURRENT_PROJECT_VERSION)" "${TextEdit_version}" TextEdit_plist "${TextEdit_plist}")
file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/Info.plist "${TextEdit_plist}")
file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/PkgInfo "APPLttxt")
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS Info-TextEdit.plist Version.xcconfig)

# Icons: each .iconset becomes an .icns, as iconutil does in Xcode builds
set(TextEdit_icons Edit html rtf rtfd txt)
foreach(icon IN LISTS TextEdit_icons)
	set(icns ${CMAKE_CURRENT_BINARY_DIR}/${icon}.icns)
	file(GLOB icon_images ${CMAKE_CURRENT_SOURCE_DIR}/${icon}.iconset/*.png)
	add_custom_command(OUTPUT ${icns}
		COMMAND $<TARGET_FILE:iconset2icns> ${CMAKE_CURRENT_SOURCE_DIR}/${icon}.iconset ${icns}
		DEPENDS ${icon_images}
		COMMENT "Creating ${icon}.icns")
	list(APPEND TextEdit_icns ${icns})
endforeach()
add_custom_target(TextEdit_icons ALL DEPENDS ${TextEdit_icns})
add_dependencies(TextEdit_icons iconset2icns)

install(TARGETS TextEdit DESTINATION ${TextEdit_contents}/MacOS)
install(FILES
		${CMAKE_CURRENT_BINARY_DIR}/Info.plist
		${CMAKE_CURRENT_BINARY_DIR}/PkgInfo
	DESTINATION ${TextEdit_contents})
install(FILES
		${TextEdit_icns}
		TextEdit.scriptSuite
		TextEdit.scriptTerminology
	DESTINATION ${TextEdit_contents}/Resources)
# The archive's nibs are already compiled (keyedobjects.nib); designable.nib is
# only for Interface Builder
install(DIRECTORY
		Base.lproj
		English.lproj
		DocumentWindow.nib
	DESTINATION ${TextEdit_contents}/Resources
	PATTERN designable.nib EXCLUDE)
