# Third-party software

MacDictate Windows is free of charge and runs speech recognition locally.
The following components retain their own licenses:

- whisper.cpp and ggml: MIT; the Windows build applies a UTF-16 model-path compatibility patch recorded with before/after source hashes in `runtime-lock.json`; see the bundled `WHISPER-LICENSE` and pinned
  source identity in `runtime-lock.json`. Source: https://github.com/ggml-org/whisper.cpp
- Whisper multilingual model: MIT, downloaded separately after user confirmation.
  Source: https://huggingface.co/ggerganov/whisper.cpp
  Original model and license: https://github.com/openai/whisper/blob/main/LICENSE
- Microsoft .NET runtime and Windows Forms: MIT with third-party notices.
  License: https://github.com/dotnet/runtime/blob/main/LICENSE.TXT
  Notices: https://github.com/dotnet/runtime/blob/main/THIRD-PARTY-NOTICES.TXT
  Windows Forms: https://github.com/dotnet/winforms/blob/main/LICENSE.TXT

The installer is built with Inno Setup: https://jrsoftware.org/files/is/license.txt

Windows binaries currently have no Authenticode signature. The release checksums
identify the exact published bytes; they do not replace a publisher certificate.
