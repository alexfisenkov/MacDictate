# PRIVACY POLICY
For MacDictate Software and MacDictate.pro website

This Policy regulates the collection, use, and protection of personal and technical data of Users of the "MacDictate" application and visitors of the MacDictate.pro website.

## 1. INTRODUCTION AND ARCHITECTURE (IMPORTANT!)
**1.1. Local Speech and Text Processing:** The main principle of MacDictate is ABSOLUTE PRIVACY. The application uses the offline neural network OpenAI Whisper for speech recognition and may use a local Qwen model for improving recognized text.
Your voice, audio recordings, background noise, transcribed text, and text passed to the improvement feature are processed EXCLUSIVELY on your device's processor (locally on macOS). **Not a single byte of dictation audio or text is sent to our servers or third-party servers.**

**1.2. Local Diagnostic Logs:** During testing, the user or support may explicitly enable a local debug mode. In this mode, the application stores diagnostic dictation files on the device: a copy of the audio, Whisper output, the prompt and outputs of the local Qwen model, the final inserted text, and service events. These files are stored locally in `~/.macdictate/debug-sessions/`, are not sent to any server, and may contain sensitive information that the user dictated or processed. When debug mode is disabled, these session files are not created.

## 2. DATA USED
**2.1. Free macOS version:** local dictation requires no account, email address, or hardware identifier. The application does not obtain a Machine ID or contact a license verification server. New local diagnostic files contain no Machine ID; previously created files are not rewritten.

**2.2. Downloads and updates:** to download models and check for updates, the application contacts file and update hosting servers. These requests may disclose the IP address and standard HTTP request information to the recipient; they do not contain dictation audio or text.

**2.3. Support requests:** if the User voluntarily contacts a.fisenkov@gmail.com, we use the contact information and message they provide to respond and resolve the issue. Sending dictation audio or text to support is a separate action by the User.

**2.4. Previous purchases and old versions:** previously received order information, email addresses, and device identifiers may be retained for support, handling previous orders, and fulfilling applicable obligations. Old versions may contact the compatible license API. The current free version does not request this data or create new payments. We do not store full bank card numbers; previous payments were processed within the payment provider's secure environment.

## 3. DATA PROTECTION
3.1. Access to previous order information and support requests is restricted. This data is not made publicly available.
3.2. Email addresses are not shared with advertising networks or third-party mailing services for advertising.
3.3. Previous payment information may be processed by the relevant payment provider to fulfill previously placed orders and applicable obligations.

## 4. COOKIES
4.1. Local free dictation does not require cookies. Website visitors may restrict cookies in their browser settings.

## 5. YOUR RIGHTS
5.1. For questions about processing or deleting provided data, contact a.fisenkov@gmail.com. Requests are handled with regard to applicable retention requirements for previous orders.
5.2. Deleting previously stored license data does not block the current free macOS version.

## 6. DATA OPERATOR DETAILS
**Individual Entrepreneur:** ALEXANDER ANDREEVICH FISENKOV
**Tax ID (INN):** 772607547835
**Contact (Email):** a.fisenkov@gmail.com
**Operating from:** Russian Federation

Updated: October 19, 2026.
