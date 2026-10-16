# Invitation image sharing local checks

Run against a separately booted disposable iOS Simulator:

```
python3 Scripts/QA/product-v4/family-invitation-share/run.py SIMULATOR_UDID OUTPUT_DIRECTORY
```

The runner extracts unchanged production `FamilyInvitationSharePolicy` and `FamilyInvitationImageItem` from FamilyCircleViewController.swift and compiles them with the simulator UIKit SDK. It never logs in, contacts a backend, creates an invitation, sends a message, boots a device, or modifies the real phone.

35 checks cover real UIKit rendering, single image item/PNG type, PNG decoding and size, exact 24-character and 128-character code OCR with Vision, invalid code rejection, owner invalidation, completion outcome distinction, and exact copying to a disposable simulator pasteboard. Generated images contain synthetic unissued codes only. The temporary pasteboard is removed after success.

These checks do not prove WeChat acceptance, remote delivery, real alert transition/cancellation, or phone clipboard behavior. Real-device gates remain in the archived repair design. Existing family authorization checks are run separately and not counted among these 35 checks.
