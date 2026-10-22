import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[2] / "scripts/prepare_coach_quality_phone_trial.sh"
REVISION = "0123456789abcdef0123456789abcdef01234567"


class PhoneTrialPreparationTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.calls = self.root / "calls"
        self.env = dict(os.environ, PATH=str(self.bin) + os.pathsep + os.environ["PATH"],
                        PHONE_TEST_CALLS=str(self.calls))
        self.tool("git", '''#!/bin/bash
if [[ "$1" == "status" ]]; then
  if [[ "${PHONE_TEST_DIRTY:-0}" == 1 ]]; then echo ' M source.swift'; fi
  exit 0
fi
if [[ "$1" == "rev-parse" ]]; then echo __REVISION__; exit 0; fi
exit 1
'''.replace("__REVISION__", REVISION))
        self.tool("xcrun", '''#!/bin/bash
echo "xcrun $*" >> "$PHONE_TEST_CALLS"
if [[ "$1" == "xctrace" ]]; then
  echo '== Devices =='
  echo 'Synthetic iPhone (26.6.2) (00008140-0019242901E8801C)'
  echo '== Simulators =='
  exit 0
fi
if [[ "$1 $2 $3" == "devicectl list devices" ]]; then exit 1; fi
if [[ "$1 $2 $3 $4" == "devicectl device process launch" ]]; then
  [[ "${PHONE_TEST_LAUNCH_FAIL:-0}" == 0 ]]; exit $?
fi
if [[ "$1 $2 $3 $4" == "devicectl device install app" ]]; then
  [[ "${PHONE_TEST_INSTALL_FAIL:-0}" == 0 ]]; exit $?
fi
exit 1
''')
        self.tool("xcodebuild", '''#!/bin/bash
echo "xcodebuild $*" >> "$PHONE_TEST_CALLS"
[[ "${PHONE_TEST_BUILD_FAIL:-0}" == 0 ]] || exit 1
config=Debug
source_revision=unknown
source_state=unknown
source_bundle=com.codex.mingsi
while [[ $# -gt 0 ]]; do
 case "$1" in
 -derivedDataPath) derived="$2"; shift 2;;
 -configuration) config="$2"; shift 2;;
 MINGSI_SOURCE_REVISION=*) source_revision="${1#*=}"; shift;;
 MINGSI_SOURCE_STATE=*) source_state="${1#*=}"; shift;;
 *) shift;;
 esac
done
if [[ "${PHONE_TEST_WRONG_CONFIG:-0}" == 1 ]]; then config=Old; fi
mkdir -p "$derived/Build/Products/$config-iphoneos/MingSi.app"
if [[ "${PHONE_TEST_MISSING_MARKER:-0}" == 1 ]]; then
  echo '<?xml version="1.0"?><plist version="1.0"><dict/></plist>' > "$derived/Build/Products/$config-iphoneos/MingSi.app/Info.plist"
else
  if [[ "${PHONE_TEST_WRONG_MARKER:-0}" == 1 ]]; then source_revision=ffffffffffffffffffffffffffffffffffffffff; fi
  if [[ "${PHONE_TEST_WRONG_STATE:-0}" == 1 ]]; then source_state=unknown; fi
  if [[ "${PHONE_TEST_WRONG_BUNDLE:-0}" == 1 ]]; then source_bundle=com.example.other-app; fi
  cat > "$derived/Build/Products/$config-iphoneos/MingSi.app/Info.plist" <<PLIST
<?xml version="1.0"?><plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>$source_bundle</string>
<key>MingSiSourceRevision</key><string>$source_revision</string>
<key>MingSiSourceState</key><string>$source_state</string>
</dict></plist>
PLIST
fi
''')

    def tool(self, name, source):
        path = self.bin / name
        path.write_text(source)
        path.chmod(0o700)

    def invoke(self, *extra, expected=0):
        result = subprocess.run(["bash", str(SCRIPT), "--derived-data-path", str(self.root / "derived"), *extra],
                                env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        calls = self.calls.read_text() if self.calls.exists() else ""
        return result.stdout + result.stderr, calls

    def test_build_only_never_launches_or_validates_an_old_installed_app(self):
        output, calls = self.invoke("--skip-install")
        self.assertIn("Build completed; installation and launch were skipped", output)
        self.assertIn("older revision", output)
        self.assertNotIn("device install app", calls)
        self.assertNotIn("device process launch", calls)
        self.assertNotIn("ready to start", output)

    def test_launch_only_does_not_build_install_or_claim_current_revision(self):
        output, calls = self.invoke("--launch-check-only")
        self.assertIn("Installed source revision is unverified", output)
        self.assertNotIn("xcodebuild", calls)
        self.assertNotIn("device install app", calls)
        self.assertIn("device process launch", calls)
        self.assertNotIn("Installed candidate source revision:", output)

    def test_install_without_launch_keeps_manual_acceptance_pending(self):
        output, calls = self.invoke("--skip-launch-check")
        self.assertIn("device install app", calls)
        self.assertNotIn("device process launch", calls)
        self.assertIn("Process launch checked: no", output)
        self.assertIn("not a manual acceptance pass", output)
        self.assertIn("docs/mingsi-phone-acceptance.md", output)

    def test_build_and_install_failure_never_claim_a_successful_delivery(self):
        self.env["PHONE_TEST_BUILD_FAIL"] = "1"
        output, calls = self.invoke(expected=1)
        self.assertIn("no installation or launch check", output)
        self.assertNotIn("device install app", calls)
        self.assertNotIn("device process launch", calls)
        self.env["PHONE_TEST_BUILD_FAIL"] = "0"
        self.env["PHONE_TEST_INSTALL_FAIL"] = "1"
        self.calls.unlink()
        output, calls = self.invoke(expected=1)
        self.assertIn("device install app", calls)
        self.assertNotIn("device process launch", calls)
        self.assertNotIn("Candidate installation completed", output)

    def test_wrong_configuration_does_not_substitute_an_old_candidate(self):
        self.env["PHONE_TEST_WRONG_CONFIG"] = "1"
        output, calls = self.invoke("--configuration", "Release", expected=1)
        self.assertIn("No older build will be substituted", output)
        self.assertNotIn("device install app", calls)

    def test_local_team_override_is_explicit_and_does_not_enable_provisioning(self):
        output, calls = self.invoke("--skip-install", "--team", "ABCDEFGHIJ")
        self.assertIn("DEVELOPMENT_TEAM=ABCDEFGHIJ", calls)
        self.assertIn("CODE_SIGN_STYLE=Automatic", calls)
        self.assertNotIn("-allowProvisioningUpdates", calls)
        self.assertNotIn("-allowProvisioningDeviceRegistration", calls)
        output, _ = self.invoke("--team", "invalid", expected=2)
        self.assertIn("10 uppercase", output)

    def test_launch_failure_does_not_guess_profile_trust_as_the_cause(self):
        self.env["PHONE_TEST_LAUNCH_FAIL"] = "1"
        output, calls = self.invoke(expected=1)
        self.assertIn("cannot\nidentify which one", output)
        self.assertNotIn("Candidate installation completed", output)

    def test_dry_run_build_only_has_no_build_install_or_launch_mutation(self):
        output, calls = self.invoke("--skip-install", "--dry-run")
        self.assertIn("launch check: skipped", output)
        self.assertNotIn("xcodebuild", calls)
        self.assertNotIn("device install app", calls)
        self.assertNotIn("device process launch", calls)

    def test_installed_and_launched_does_not_automatically_pass_manual_acceptance(self):
        output, calls = self.invoke()
        self.assertIn("device install app", calls)
        self.assertIn("device process launch", calls)
        self.assertIn("Installed candidate source revision: " + REVISION, output)
        self.assertIn("Process launch checked: yes", output)
        self.assertIn("not a manual acceptance pass", output)
        self.assertNotIn("Status: PASSED", output)

    def test_source_marker_is_injected_and_missing_or_old_candidate_is_never_installed(self):
        output, calls = self.invoke("--skip-install")
        self.assertIn("MINGSI_SOURCE_REVISION=" + REVISION, calls)
        self.assertIn("MINGSI_SOURCE_STATE=clean", calls)
        for flag in ("PHONE_TEST_WRONG_MARKER", "PHONE_TEST_MISSING_MARKER", "PHONE_TEST_WRONG_STATE"):
            self.env[flag] = "1"
            self.calls.unlink()
            output, calls = self.invoke(expected=1)
            self.assertIn("source marker is missing or mismatched", output)
            self.assertNotIn("device install app", calls)
            self.assertNotIn("device process launch", calls)
            self.env[flag] = "0"

    def test_dirty_override_records_actual_local_changes_in_built_marker(self):
        self.env["PHONE_TEST_DIRTY"] = "1"
        output, calls = self.invoke(expected=1)
        self.assertIn("Worktree is dirty", output)
        self.assertNotIn("xcodebuild", calls)
        output, calls = self.invoke("--skip-install", "--allow-dirty")
        self.assertIn("MINGSI_SOURCE_STATE=dirty", calls)
        self.assertIn("Built source state: dirty", output)

    def test_candidate_bundle_identifier_must_match_the_launch_target(self):
        self.env["PHONE_TEST_WRONG_BUNDLE"] = "1"
        output, calls = self.invoke(expected=1)
        self.assertIn("bundle identifier does not match the launch target", output)
        self.assertNotIn("device install app", calls)
        self.assertNotIn("device process launch", calls)


if __name__ == "__main__":
    unittest.main()
