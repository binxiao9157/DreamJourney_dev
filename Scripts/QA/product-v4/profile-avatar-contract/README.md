# Profile avatar contract checks

- `python3 Scripts/QA/product-v4/profile-avatar-contract/run.py`: ten production avatar state-method checks; transport, auth session and disk are boundary doubles. No server/iPhone required.
- `python3 Scripts/QA/product-v4/profile-avatar-contract/run-image-tests.py SIMULATOR_UDID`: uses the production ImageIO/renderer function on an already booted Apple Silicon simulator. Synthetic inputs only; no app account/network calls. Does not boot/erase a simulator.
- Backend: `python -m unittest tests.test_profile_avatar` plus existing profile/auth/deletion protection tests. Use local dependency environment, never production credentials.

Manual simulator acceptance: use an isolated bundle and local API. Verify the **built and installed** Info.plist endpoint (build arguments may be overridden). Use a correctly signed test package for authenticated cold-start checks; an unsigned package may fail Keychain with -34018. Never compensate by changing product authentication.

Select synthetic photo -> cancel picker -> no upload; select -> inline avatar changes without uploading; tap the single bottom Save -> server-confirmed avatar and profile; modify nickname -> unchanged avatar; relaunch/read; fail local API -> save fails -> cancel returns to previous avatar. The system Photos picker is a remote UI and may not appear in in-process snapshots; inspect it in Device Hub.

Design and acceptance record (workspace): `02-设计文档/产品设计/2026-10-13-个人头像相册上传/`.
Evidence: `outputs/2026-10-13-profile-avatar/` (no production images or accounts).

Policy expiry regression (2026-10-13): run the seven testProfilePolicy tests in OwnerTruthContractsTests. They use the real gate, policy decoder/cache and HTTP client, with URLProtocol at the network boundary. The late-result test waits the actual 15-second bound. Valid authority must still be checked after refresh; failures cannot trigger a profile POST.

Device acceptance uses USB/devicectl only. Before installing/relaunching, inspect active account state and cached identity; do not continue with a suspended identity. The user operates the system picker. Keep the profile form open at least six real minutes, confirm the cached policy has expired, then tap bottom Save once. Verify policy GET, existing avatar/profile POSTs, server avatar digest, user-visible success and reopened display. Do not refresh/restart during the wait, change TTL, inspect unrelated photos, or use iPhone Mirroring.
