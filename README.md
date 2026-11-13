# darling-TextEdit

TextEdit for [Darling](https://github.com/darlinghq/darling), installed as
`/Applications/TextEdit.app`. It is built as part of Darling's `gui` component.

The source is Apple's TextEdit sample code, version 1.9 (2013), from
<https://developer.apple.com/library/archive/samplecode/TextEdit/Introduction/Intro.html>,
under the license stated at the top of each source file.

Changes from the sample code:

- `CMakeLists.txt` builds the application and its bundle within Darling's build:
  it fills in the build settings in `Info.plist`, converts the `.iconset`
  folders to `.icns` files and installs the compiled nibs from the archive.
- The bundle identifier, the help book name and the error domain use
  `org.darlinghq.TextEdit` instead of Apple's identifier.
