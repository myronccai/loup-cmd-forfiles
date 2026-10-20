# Tasks: forfiles

- [x] 1. Copy the shared Windows code into `source/win/` with its tests
  - _Requirements: 1.2, 3.1, 3.2_
- [x] 2. Parse `/P`, `/M`, `/S`, `/C`; refuse operands, repeats and `/D` with forfiles' messages
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.7_
- [x] 3. Check the start directory
  - _Requirements: 1.1, 3.6_
- [x] 4. Select entries by mask, files and directories, `/S` order
  - _Requirements: 1.2, 1.3, 1.4, 1.5_
- [x] 5. `0xHH` escapes and the `@` variables
  - _Requirements: 2.2, 2.3_
- [x] 6. Translate `cmd /c` lines to sh; split and run other commands directly
  - _Requirements: 2.6, 2.7_
- [x] 7. Run each command in its entry's directory; the leading empty line; exit statuses
  - _Requirements: 2.1, 2.4, 2.5, 2.8_
- [x] 8. Unit tests and end-to-end tests of the native binary
  - _Requirements: all_
