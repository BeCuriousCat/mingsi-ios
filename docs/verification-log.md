# MingSi Verification Log

This file records verification evidence for MVP slices. Each entry should include date, scope, commands, result, and residual risk.

## 2026-06-11: Prompt Asset Quality Rollback Readiness

Scope:

- Extend `PromptAssetQualityGate` so operational quality issues can attach rollback candidates when local fixed-suite eval history proves a compatible prior prompt asset passed.
- Match rollback readiness by prompt id, source kind, pack id, current pack version, rollback target version, system/context policy, input/output schema, eval suite, and runner version.
- Publish rollback-ready/manual-review asset counts from `AppStore.loadRecentPromptRuns(limit:)` using already loaded `recentPromptEvalRuns` and the effective `PromptProvider`.
- Surface those counts in the Settings Prompt asset quality text without changing Prompt execution, Today state ownership, or automatically applying rollback.

Changed areas:

- `Sources/Domain/Models.swift`
- `Sources/App/AppStore.swift`
- `Sources/Features/FeatureTabs.swift`
- `Tests/Services/PromptEvalFixtureTests.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PromptEvalFixtureTests/testPromptAssetQualityGate_marksImportedPackRollbackReadyFromPassingEvalHistory
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PromptEvalFixtureTests/testPromptAssetQualityGate_marksImportedPackRollbackReadyFromPassingEvalHistory
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadRecentPromptRuns_marksPromptAssetQualityRollbackReadinessFromEvalHistory
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadRecentPromptRuns_marksPromptAssetQualityRollbackReadinessFromEvalHistory
xcodebuild test -quiet -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PromptEvalFixtureTests/testPromptAssetQualityGate_flagsHighOperationalFailureSignalsAfterMinimumSample -only-testing:MingSiTests/PromptEvalFixtureTests/testPromptAssetQualityGate_marksImportedPackRollbackReadyFromPassingEvalHistory -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadRecentPromptRuns_updatesPromptAssetQualityGate -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadRecentPromptRuns_marksPromptAssetQualityRollbackReadinessFromEvalHistory
git diff --check
xcodebuild test -quiet -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests -resultBundlePath /tmp/mingsi-quality-gate-rollback-tests-20260611.xcresult
xcodebuild test -quiet -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests -resultBundlePath /tmp/mingsi-quality-gate-rollback-uitests-20260611.xcresult
xcrun xcresulttool get test-results summary --path /tmp/mingsi-quality-gate-rollback-tests-20260611.xcresult
xcrun xcresulttool get test-results summary --path /tmp/mingsi-quality-gate-rollback-uitests-20260611.xcresult
```

Result:

- Domain RED failed at compile time because `PromptAssetQualityGate.evaluate` had no eval-history/provider inputs and quality issues had no rollback candidate.
- Domain GREEN passed after adding `PromptAssetQualityGateRollbackCandidate`, rollback-ready/manual-review counts, and strict matching against provider-resolvable rollback target versions plus passing eval runs.
- AppStore RED failed with `rollbackReadyAssetCount == 0` because `loadRecentPromptRuns` did not feed eval history into the quality gate.
- AppStore GREEN passed after routing prompt-asset quality evaluation through a shared AppStore helper that uses `recentPromptEvalRuns` and `effectivePromptProvider`.
- Final verification passed: `git diff --check`, focused quality-gate/AppStore coverage with 4 tests and 0 failures, full `MingSiTests` with 571 passed, 1 skipped, and 0 failures, and full `MingSiUITests` with 11 tests and 0 failures.

Residual risk:

- This marks rollback readiness only; it does not automatically execute rollback for operational quality issues.
- Readiness depends on local eval history already being loaded and on the effective provider resolving the rollback target version.
- Real BYOK GLM network success, real publisher onboarding, remote prompt/lens registry rollout, external key distribution, and optional OS-level background refresh remain open.

## 2026-06-11: Prompt Asset Operational Quality Gate

Scope:

- Add `PromptAssetQualityGate` over `PromptAssetRunQualitySummary` so recent prompt asset-version quality can be evaluated as a machine-readable operational review gate.
- Flag high failure, empty-result, and user-denial rates only after a conservative minimum sample count.
- Publish the gate through `AppStore.loadRecentPromptRuns(limit:)` and show the Settings AI audit status plus the first issue message.
- Keep this as a review signal only; no Prompt execution behavior, Today state machine ownership, automatic rollback, live BYOK GLM call, publisher onboarding, or remote registry rollout is changed.

Changed areas:

- `Sources/Domain/Models.swift`
- `Sources/App/AppStore.swift`
- `Sources/Features/FeatureTabs.swift`
- `Tests/Services/PromptEvalFixtureTests.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PromptEvalFixtureTests/testPromptAssetQualityGate_flagsHighOperationalFailureSignalsAfterMinimumSample -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadRecentPromptRuns_updatesPromptAssetQualityGate
git diff --check
xcodebuild test -quiet -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PromptEvalFixtureTests -only-testing:MingSiTests/AppStoreStateMachineTests -resultBundlePath /tmp/mingsi-prompt-asset-quality-gate-affected-20260611.xcresult
xcodebuild test -quiet -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests -resultBundlePath /tmp/mingsi-prompt-asset-quality-gate-tests-20260611.xcresult
xcodebuild test -quiet -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests -resultBundlePath /tmp/mingsi-prompt-asset-quality-gate-uitests-20260611.xcresult
xcrun xcresulttool get test-results summary --path /tmp/mingsi-prompt-asset-quality-gate-affected-20260611.xcresult
xcrun xcresulttool get test-results summary --path /tmp/mingsi-prompt-asset-quality-gate-tests-20260611.xcresult
xcrun xcresulttool get test-results summary --path /tmp/mingsi-prompt-asset-quality-gate-uitests-20260611.xcresult
```

Result:

- Initial focused RED failed at compile time because the quality-gate model and `AppStore.promptAssetQualityGate` did not exist.
- Focused GREEN passed after adding the domain gate, AppStore publication, and Settings gate line.
- Final verification passed: `git diff --check`, affected `PromptEvalFixtureTests` + `AppStoreStateMachineTests` with 270 tests and 0 failures, full `MingSiTests` with 569 passed, 1 skipped, and 0 failures, and full `MingSiUITests` with 11 tests and 0 failures.

Residual risk:

- The gate evaluates the current recent-window summary only; it is not a long-term quality trend store or automatic rollback trigger.
- Real BYOK GLM network success, real publisher onboarding, remote prompt/lens registry rollout, external key distribution, and optional OS-level background refresh remain open.

## 2026-06-11: Settings Prompt Asset Quality Surface

Scope:

- Render `PromptAssetRunQualitySummary` data inside the Settings AI audit card as a compact `Prompt 资产质量` section.
- Show the top recent asset-version summaries with failure rate, empty-result rate, user-denial rate, pack/source provenance, and prompt/context/eval versions.
- Add stable accessibility identifiers for the section and per-asset rows so rendered Settings UI automation can prove the summary is visible.
- Keep this as an audit surface only; no Prompt execution behavior, Today state machine, live BYOK GLM call, publisher onboarding, or remote registry rollout is changed.

Changed areas:

- `Sources/Features/FeatureTabs.swift`
- `Tests/UI/MingSiUITests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests/MingSiUITests/testSettingsPromptAssetQualitySummaryRendersThroughIdentifier
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests/MingSiUITests/testSettingsPromptAssetQualitySummaryRendersThroughIdentifier
git diff --check
xcodebuild test -quiet -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests -resultBundlePath /tmp/mingsi-ui-prompt-asset-quality-20260611-0111.xcresult
xcodebuild test -quiet -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests -resultBundlePath /tmp/mingsi-tests-prompt-asset-quality-20260611-0113.xcresult
```

Result:

- RED failed as expected because `settings.prompt-asset-quality.section` was absent from the rendered Settings audit fixture.
- GREEN passed after adding the Settings prompt-asset quality section and row identifiers.
- Final verification passed: `git diff --check`, full `MingSiUITests` with 11 tests and 0 failures, and full `MingSiTests` with 568 total tests, 567 passed, 1 skipped, and 0 failures.

Residual risk:

- The section is a compact top-3 recent-window view, not a full prompt-pack quality explorer or rollback decision workflow.
- Real BYOK GLM network success, real publisher onboarding, remote prompt/lens registry rollout, and optional OS-level background refresh remain open.

## 2026-06-11: Prompt Asset Run Quality Summary

Scope:

- Add `PromptAssetRunQualitySummary` to group recent PromptRun outcomes by prompt id/version, source kind, prompt pack id/version/display name, system policy, context policy, input/output schema, and eval suite version.
- Add `PromptRunRepository.promptAssetRunQualitySummaries(limit:)` and the SQLite implementation by loading the recent PromptRun window and grouping domain models.
- Expose the summaries from `AppStore.loadRecentPromptRuns(limit:)` alongside existing recent runs and global PromptRun stats.
- Keep this as an audit/model boundary only; no new Settings rendering, live BYOK GLM confirmation, or remote registry rollout is added.

Changed areas:

- `Sources/Domain/Models.swift`
- `Sources/Services/PersistenceCore.swift`
- `Sources/App/AppStore.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testPromptRun_assetQualitySummariesSeparatePromptContextAndEvalVersions
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadRecentPromptRuns_loadsNewestFirstAuditRunsWithRefsAndErrors
git diff --check
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testPromptRun_assetQualitySummariesSeparatePromptContextAndEvalVersions -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadRecentPromptRuns_loadsNewestFirstAuditRunsWithRefsAndErrors
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests -only-testing:MingSiTests/PersistenceCoreTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests
```

Result:

- Initial persistence RED failed as expected because `PromptRunRepository` and `SQLitePromptRunRepository` had no asset-quality summary API.
- Focused persistence GREEN passed after adding the domain grouping model and SQLite repository method.
- Initial AppStore RED failed as expected because `AppStore` did not publish prompt asset run-quality summaries.
- Focused AppStore GREEN passed after loading summaries with recent PromptRun audit state.
- Final verification passed: `git diff --check`, focused 2-test prompt-asset summary coverage with 0 failures, affected `AppStoreStateMachineTests` + `PersistenceCoreTests` with 383 tests and 0 failures, and full `MingSiTests` with 568 tests, 1 skipped, and 0 failures.

Residual risk:

- The summaries are not yet rendered in Settings or a prompt-pack review UI.
- Real BYOK GLM network success, real publisher onboarding, remote prompt/lens registry rollout, and optional OS-level background refresh remain open.

## 2026-06-11: Asset Pack Registry Subscription Auto-Sync Policy

Scope:

- Add `AssetPackRegistrySubscriptionSyncSchedulePolicy` to select enabled registry subscriptions that are never synced, stale, or on an older sync-policy version.
- Add `AppStore.syncDueAssetPackRegistrySubscriptions(now:schedulePolicy:fetcher:)` to fetch only due subscriptions, record per-subscription results, and preserve fresh/disabled subscriptions without network requests.
- Run due subscription sync from `AppStore.loadPersistedState()` through injectable schedule-policy and fetcher boundaries.
- Keep this as app-load scheduled sync only; no iOS background task, real external registry service, publisher onboarding, external key-distribution UX, or live external registry acceptance run is added.

Changed areas:

- `Sources/App/AppStore.swift`
- `Sources/Services/PersistenceCore.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackRegistrySubscriptionSyncSchedulePolicy_selectsDueEnabledSubscriptions -only-testing:MingSiTests/AppStoreStateMachineTests/testSyncDueAssetPackRegistrySubscriptions_fetchesOnlyDueSubscriptions -only-testing:MingSiTests/AppStoreStateMachineTests/testSyncDueAssetPackRegistrySubscriptions_skipsNetworkWhenNothingIsDue
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_runsDueAssetPackRegistrySubscriptionSync
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackRegistrySubscriptionSyncSchedulePolicy_selectsDueEnabledSubscriptions -only-testing:MingSiTests/AppStoreStateMachineTests/testSyncDueAssetPackRegistrySubscriptions_fetchesOnlyDueSubscriptions -only-testing:MingSiTests/AppStoreStateMachineTests/testSyncDueAssetPackRegistrySubscriptions_skipsNetworkWhenNothingIsDue -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_runsDueAssetPackRegistrySubscriptionSync
git diff --check
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests
```

Result:

- RED first failed because `AssetPackRegistrySubscriptionSyncSchedulePolicy` did not exist.
- GREEN passed with 3 focused tests and 0 failures after adding the schedule policy and due-sync AppStore API.
- A second RED failed because `AppStore` could not inject an asset-pack registry sync policy/fetcher for `loadPersistedState()`.
- GREEN passed after adding injectable sync policy/fetcher and running due sync from persisted-state load.
- Final verification passed: `git diff --check`, full `AppStoreStateMachineTests` with 257 tests and 0 failures, full `PersistenceCoreTests` with 125 tests and 0 failures, and full `MingSiTests` with 567 tests, 1 skipped, and 0 failures.
- After fast-forwarding `main` to this commit, full `MingSiTests` also passed from the main worktree with 567 tests, 1 skipped, and 0 failures.

Residual risk:

- This is app-load scheduled catalog sync. It is not an iOS background refresh task and does not automatically install catalog entries.
- Real registry service, publisher onboarding, external key-distribution UX, remote prompt/lens rollout acceptance, and real BYOK GLM network confirmation remain open.

## 2026-06-11: Settings Asset Pack Registry Subscription Management Surface

Scope:

- Add product-facing Settings controls for persisted asset-pack registry subscriptions.
- Add `AppStore.loadAssetPackRegistrySubscriptions()`, `saveAssetPackRegistrySubscription(displayName:catalogURL:)`, and `setAssetPackRegistrySubscription(_:isEnabled:)`.
- Render subscription name/URL fields, save action, explicit sync action, persisted subscription rows, and per-subscription enable/disable controls in the existing Settings asset-pack card.
- Pin stable accessibility identifiers for subscription fields/actions and prove the rendered controls exist through XCTest UI automation.
- Keep this as explicit user-triggered management and sync only; no background scheduler is added.

Changed areas:

- `Sources/App/AppStore.swift`
- `Sources/Features/FeatureTabs.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `Tests/UI/MingSiUITests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testSaveAssetPackRegistrySubscription_persistsAndLoadsForSettingsManagement -only-testing:MingSiTests/AppStoreStateMachineTests/testSetAssetPackRegistrySubscriptionEnabled_updatesInventoryAndSyncScope -only-testing:MingSiTests/AppStoreStateMachineTests/testSettingsAutomationIdentifiers_areStableForAssetPackInstallManifest
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests/MingSiUITests/testSettingsAssetPackRegistrySubscriptionControlsRenderThroughIdentifiers
```

Result:

- RED failed at compile time because `AppStore` had no subscription load/save/toggle APIs and `SettingsAutomationID` had no registry-subscription identifiers.
- GREEN passed with 3 AppStore/identifier tests and 0 failures after adding the management APIs and Settings identifiers.
- Rendered UI automation passed with 1 UI test and 0 failures; the Settings fixture found `settings.asset-pack-registry.subscription-name-field`, `settings.asset-pack-registry.subscription-url-field`, `settings.asset-pack-registry.subscription-save-action`, and `settings.asset-pack-registry.subscription-sync-action` in the accessibility tree.

Residual risk:

- This is still manual Settings subscription management plus explicit sync. There is no background timer, remote scheduler policy, real registry service, publisher onboarding flow, external key-distribution channel, or live external registry acceptance run yet.
- Real BYOK GLM network success remains externally blocked until a user-provided key is configured and an external call window is approved.

## 2026-06-10: Asset Pack Registry Subscription Sync Boundary

Scope:

- Persist remote asset-pack registry catalog subscriptions in SQLite through `asset_pack_registry_subscriptions`.
- Add the v23 migration, `AssetPackRegistrySubscriptionRepository`, and `SQLiteAssetPackRegistrySubscriptionRepository`.
- Add per-subscription sync status, message, and timestamp recording for enabled catalog sync.
- Extend `AssetPackInstallManifestFetching` with `fetchRegistryCatalogData(from:)` so catalog fetches do not reuse the manifest fetch boundary.
- Add `AppStore.syncAssetPackRegistrySubscriptions(fetcher:)` to explicitly sync enabled subscriptions and update catalog entries.
- Export registry subscriptions through Data Export.

Changed areas:

- `Sources/Services/PersistenceCore.swift`
- `Sources/App/AppStore.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackRegistrySubscriptionRepository_saveLoadAndRecordSyncResult -only-testing:MingSiTests/PersistenceCoreTests/testMigration_v23_addsAssetPackRegistrySubscriptionsTableAndIndexes -only-testing:MingSiTests/AppStoreStateMachineTests/testSyncAssetPackRegistrySubscriptions_fetchesEnabledCatalogsAndRecordsStatus
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesAssetPackRegistrySubscriptions
git diff --check
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackRegistrySubscriptionRepository_saveLoadAndRecordSyncResult -only-testing:MingSiTests/PersistenceCoreTests/testMigration_v23_addsAssetPackRegistrySubscriptionsTableAndIndexes -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesAssetPackRegistrySubscriptions -only-testing:MingSiTests/AppStoreStateMachineTests/testSyncAssetPackRegistrySubscriptions_fetchesEnabledCatalogsAndRecordsStatus
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests
```

Result:

- RED first failed because `SQLiteAssetPackRegistrySubscriptionRepository`, `AssetPackRegistrySubscription`, and `AssetPackRegistrySyncStatus.succeeded` did not exist.
- GREEN focused coverage passed with 3 tests and 0 failures after adding the subscription model, repository, v23 table, sync method, and catalog-fetch boundary.
- Data Export RED failed because `sections["asset_pack_registry_subscriptions"]` was absent.
- Data Export GREEN passed with 1 test and 0 failures after adding `DataExportSectionName.assetPackRegistrySubscriptions`.
- Final branch verification passed after the docs update: `git diff --check`, the 4-test focused registry subscription suite, full `PersistenceCoreTests` with 124 tests and 0 failures, full `AppStoreStateMachineTests` with 252 tests and 0 failures, and full `MingSiTests` with 561 tests, 1 skipped, and 0 failures.

Residual risk:

- This is an explicit sync boundary only. There is no background timer, Settings subscription-management UI, real registry service, publisher onboarding flow, external key-distribution channel, or live external registry acceptance run yet.
- Real BYOK GLM network success remains externally blocked until a user-provided key is configured and an external call window is approved.

## 2026-06-10: Settings Remote Asset Pack Registry Catalog Surface

Scope:

- Render the remote asset-pack registry catalog boundary in Settings instead of leaving it AppStore-only.
- Add a catalog URL input and fetch action using `SettingsAutomationID.assetPackRegistryCatalogURLField` and `SettingsAutomationID.assetPackRegistryCatalogFetchAction`.
- Render fetched `AssetPackRegistryCatalogEntry` rows and expose per-entry install actions through `SettingsAutomationID.assetPackRegistryCatalogEntryInstallAction(entryId:)`.
- Keep entry install on the existing trusted manifest fetch/install path through `AppStore.installAssetPackRegistryCatalogEntry`.
- Prove the rendered fetch action is drivable through iOS UI automation and reports fetch failures through the existing asset-pack install message slot.

Changed areas:

- `Sources/Features/FeatureTabs.swift`
- `Tests/UI/MingSiUITests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests/MingSiUITests/testSettingsAssetPackRegistryCatalogFetchReportsFailureThroughIdentifier
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests
git diff --check
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests
```

Result:

- RED failed because `settings.asset-pack-registry.catalog-url-field` was absent from rendered Settings.
- GREEN passed with 1 UI test and 0 failures after adding the catalog URL input, fetch button, entry list, entry install buttons, and Settings helper actions.
- Full `MingSiUITests` passed with 9 tests and 0 failures after adding the rendered catalog surface.
- `git diff --check` passed with no output.
- Full `MingSiTests` passed with 557 tests, 1 skipped, and 0 failures.
- The UI test launches the Debug Settings asset-pack fixture, finds `settings.asset-pack-registry.catalog-url-field` prefilled with `http://127.0.0.1:1/mingsi-asset-pack-catalog.json`, taps `settings.asset-pack-registry.catalog-fetch-action`, and asserts `settings.asset-pack-manifest.message` contains `获取远程资产包目录失败`.

Residual risk:

- This is manual catalog browsing and install selection. It still does not add background registry sync, a real external registry service, publisher onboarding, key-distribution UX, or a live external registry acceptance run.
- Real BYOK GLM network success remains externally blocked until a user-provided key is configured and an external call window is approved.

## 2026-06-10: Remote Asset Pack Registry Catalog Boundary

Scope:

- Add `AssetPackRegistryCatalog` and `AssetPackRegistryCatalogEntry` as the remote marketplace catalog data boundary.
- Resolve relative catalog entry manifest URLs against the fetched catalog URL.
- Add `AppStore.fetchAssetPackRegistryCatalog(from:fetcher:)` for loading selectable remote entries.
- Add `AppStore.installAssetPackRegistryCatalogEntry(entryId:fetcher:)` so selected entries reuse the existing remote manifest fetch/install, trust gate, repository save, and runtime Prompt/Lens refresh path.
- Pin Settings automation identifiers for future catalog URL, fetch, and entry-install controls.

Changed areas:

- `Sources/Services/PersistenceCore.swift`
- `Sources/App/AppStore.swift`
- `Sources/Features/FeatureTabs.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackRegistryCatalog_decodesManifestEntries -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackRegistryCatalog_resolvesRelativeManifestURLsAgainstCatalogURL -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAssetPackRegistryCatalog_loadsRemoteEntriesForSettingsSelection -only-testing:MingSiTests/AppStoreStateMachineTests/testInstallAssetPackRegistryCatalogEntry_fetchesEntryManifestAndInstallsThroughTrustGate -only-testing:MingSiTests/AppStoreStateMachineTests/testSettingsAutomationIdentifiers_areStableForAssetPackInstallManifest
git diff --check
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/TodayAIServiceContextTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests
```

Result:

- Focused registry catalog coverage passed with 5 tests and 0 failures.
- `AssetPackRegistryCatalog` decodes remote entries and resolves relative manifest paths against the catalog URL.
- AppStore fetches remote catalog JSON into `assetPackRegistryCatalogEntries`.
- AppStore installs a selected entry by resolving its manifest URL and delegating to the existing trusted manifest fetch/install path.
- `git diff --check` passed.
- Follow-up regression verification passed: `TodayAIServiceContextTests` 24 tests / 0 failures, `AppStoreStateMachineTests` 251 tests / 0 failures, `PersistenceCoreTests` 121 tests / 0 failures, full `MingSiTests` 557 tests / 1 skipped / 0 failures, and full `MingSiUITests` 8 tests / 0 failures.

Residual risk:

- This is a manual catalog/API boundary with pinned automation ids, not a rendered marketplace browser, automatic registry sync scheduler, real publisher onboarding flow, external key-distribution channel, or live external registry acceptance run.
- Real BYOK GLM network success remains externally blocked until a user-provided key is configured and an external call window is approved.

## 2026-06-10: Remote Asset Trust Policy Document Signature Chain

Scope:

- Add a document-level trust proof to `AssetPackTrustPolicyDocument`.
- Verify trust-policy documents with a separate registry-root P-256 verifier before their publisher keys can authorize Prompt/Lens asset packs.
- Exclude unsigned, tampered, or expired trust-policy documents from install-time and restart-time runtime verifier composition.
- Save fetched remote trust policies only after their document-level signature is valid.

Changed areas:

- `Sources/Services/PersistenceCore.swift`
- `Sources/App/AppStore.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackTrustPolicyDocumentSignatureVerifier_allowsSignedDocuments -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackTrustPolicyDocumentSignatureVerifier_rejectsUnsignedAndTamperedDocuments -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_rejectsUnsignedRemoteTrustPolicy -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_excludesPacksAuthorizedOnlyByUnsignedRemoteTrustPolicy
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackInstallManifest_filtersInstallablePromptAndLensPacksThroughTrustGate -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackInstallManifestInstaller_savesOnlyValidatedPromptAndLensPacks -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackTrustPolicyDocumentSignatureVerifier_allowsSignedDocuments -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackTrustPolicyDocumentSignatureVerifier_rejectsUnsignedAndTamperedDocuments -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackTrustPolicyRepository_saveAndLoadDocuments -only-testing:MingSiTests/PersistenceCoreTests/testMigration_v22_addsAssetPackTrustPoliciesTableAndIndexes -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_usesRemoteTrustPolicyBeforeInstalling -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_rejectsUnsignedRemoteTrustPolicy -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_rejectsExpiredRemoteTrustPolicy -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_reportsRemoteTrustPolicyFetchFailure -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_usesPersistedRemoteTrustPolicyForPromptAssetPacks -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_excludesPacksAuthorizedOnlyByExpiredRemoteTrustPolicy -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_excludesPacksAuthorizedOnlyByUnsignedRemoteTrustPolicy -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_reusesTrustedInstallGateAndRefreshesRuntimeAssets
rg -n "jsonPayload|JSONPayload|legacyJSONPayload|ed25519:" Sources Tests
env | rg 'MINGSI_GLM_API_KEY|GLM_API_KEY|SIMCTL_CHILD_MINGSI_GLM_API_KEY|ZHIPU|GLM'
git diff --check
```

Result:

- RED first failed because `AssetPackTrustPolicyDocument` had no `trustMetadata` field, and `AssetPackIntegrity` had no trust-policy document hash/signature payload API.
- GREEN focused tests passed with 4 tests and 0 failures after adding document hash/signature payloads, `AssetPackTrustPolicySignatureVerifier`, registry-root test policy, signed-document gating, and AppStore filtering/caching rules.
- Broader trust-policy regression passed with 14 tests and 0 failures, covering signed remote policies, unsigned policy rejection, expired policy rejection, persisted signed-policy reuse, expired/unsigned persisted-policy exclusion, remote fetch failure, manifest validation, installer behavior, repository persistence, and v22 migration shape.
- Source/test search for removed prompt payload names and the old `ed25519:` signature format returned no matches; GLM/BYOK environment search returned no key; `git diff --check` passed with no output.

Residual risk:

- The registry root is still an in-app built-in policy for this slice; there is no external registry catalog sync, real publisher onboarding, key-rollover distribution, or live external registry acceptance run yet.
- Real BYOK GLM network success remains externally blocked until a user-provided key is configured and an external call window is approved.

## 2026-06-10: Remote Asset Trust Policy Freshness Boundary

Scope:

- Add optional `expiresAt` metadata to `AssetPackTrustPolicyDocument`.
- Treat expired trust-policy documents as non-authorizing: they return no publisher keys and are filtered out when `AppStore` composes persisted remote policies for runtime Prompt/Lens asset loading.
- Keep older trust-policy JSON compatible because `expiresAt` is optional.
- Align remote trust-policy decoding and test fixture encoding on ISO8601 dates.

Changed areas:

- `Sources/Services/PersistenceCore.swift`
- `Sources/App/AppStore.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_rejectsExpiredRemoteTrustPolicy -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_excludesPacksAuthorizedOnlyByExpiredRemoteTrustPolicy
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackInstallManifest_filtersInstallablePromptAndLensPacksThroughTrustGate -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackInstallManifestInstaller_savesOnlyValidatedPromptAndLensPacks -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackTrustPolicyRepository_saveAndLoadDocuments -only-testing:MingSiTests/PersistenceCoreTests/testMigration_v22_addsAssetPackTrustPoliciesTableAndIndexes -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_usesRemoteTrustPolicyBeforeInstalling -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_rejectsExpiredRemoteTrustPolicy -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_reportsRemoteTrustPolicyFetchFailure -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_usesPersistedRemoteTrustPolicyForPromptAssetPacks -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_excludesPacksAuthorizedOnlyByExpiredRemoteTrustPolicy -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_reusesTrustedInstallGateAndRefreshesRuntimeAssets
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testDeletePrinciple_removesPrincipleFromVisibleReadsAndExport -only-testing:MingSiTests/AppStoreStateMachineTests/testDeletePrinciple_removesNeedsReviewPrincipleFromRepositoryAndVisibleTrainingAssets -only-testing:MingSiTests/AppStoreStateMachineTests/testPreviousFromReviewCardsReturnsToCaptureWithoutClearingCards -only-testing:MingSiUITests/MingSiUITests/testTodayReviewCardsCanNavigateBackToCaptureWithPreviousAction
rg -n "jsonPayload|JSONPayload|legacyJSONPayload|ed25519:" Sources Tests
env | rg 'MINGSI_GLM_API_KEY|GLM_API_KEY|SIMCTL_CHILD_MINGSI_GLM_API_KEY|ZHIPU|GLM'
git diff --check
```

Result:

- RED first failed because `AssetPackTrustPolicyDocument` had no `expiresAt` field.
- GREEN focused tests passed with 2 tests and 0 failures after adding optional expiry metadata, expired-policy key suppression, persisted-cache filtering, and ISO8601 date handling.
- Trust-boundary regression passed with 10 focused tests and 0 failures, covering valid remote policies, expired remote policies, persisted policy reuse, expired persisted policy exclusion, remote fetch failure, manifest validation, installer behavior, and v22 migration shape.
- User-reported regressions passed with 3 model/persistence/AppStore tests plus 1 UI test and 0 failures.
- Removed-payload/old-signature search returned no matches; GLM/BYOK environment search returned no key; `git diff --check` passed.

Residual risk:

- The trust-policy cache still had no policy-document signature chain at this point; that gap is now covered by the later `Remote Asset Trust Policy Document Signature Chain` entry above. Registry catalog scheduler, real publisher onboarding, and live external registry acceptance run remain future work.
- Real BYOK GLM network success remains externally blocked until a user-provided key is configured and an external call window is approved.

## 2026-06-10: Persisted Remote Asset Trust Policy Cache

Scope:

- Persist fetched remote `AssetPackTrustPolicyDocument` records into SQLite.
- Add a v22 `asset_pack_trust_policies` table and repository boundary for source URL, document JSON, timestamps, and soft-delete metadata.
- Compose default local trust policy with persisted remote trust-policy documents when loading Prompt/Lens runtime asset packs after app restart.
- Keep the remote trust-policy fetch path on the same install-time trust gate while saving the fetched policy for future loads.

Changed areas:

- `Sources/Services/PersistenceCore.swift`
- `Sources/App/AppStore.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackTrustPolicyRepository_saveAndLoadDocuments -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_usesPersistedRemoteTrustPolicyForPromptAssetPacks
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackInstallManifest_filtersInstallablePromptAndLensPacksThroughTrustGate -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackInstallManifestInstaller_savesOnlyValidatedPromptAndLensPacks -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackTrustPolicyRepository_saveAndLoadDocuments -only-testing:MingSiTests/PersistenceCoreTests/testMigration_v22_addsAssetPackTrustPoliciesTableAndIndexes -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_usesRemoteTrustPolicyBeforeInstalling -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_reportsRemoteTrustPolicyFetchFailure -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_usesPersistedRemoteTrustPolicyForPromptAssetPacks -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_reusesTrustedInstallGateAndRefreshesRuntimeAssets
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testDeletePrinciple_removesPrincipleFromVisibleReadsAndExport -only-testing:MingSiTests/AppStoreStateMachineTests/testDeletePrinciple_removesNeedsReviewPrincipleFromRepositoryAndVisibleTrainingAssets -only-testing:MingSiTests/AppStoreStateMachineTests/testPreviousFromReviewCardsReturnsToCaptureWithoutClearingCards -only-testing:MingSiUITests/MingSiUITests/testTodayReviewCardsCanNavigateBackToCaptureWithPreviousAction
```

Result:

- RED first failed because `SQLiteAssetPackTrustPolicyRepository` did not exist.
- GREEN focused tests passed with 2 tests and 0 failures after adding the v22 table, trust-policy repository, verifier composition API, and restart-time persisted-policy runtime loading.
- Trust-boundary regression passed with 8 focused tests and 0 failures, covering manifest preflight, repository-backed install, remote policy fetch, remote policy fetch failure, persisted policy restart loading, and v22 migration shape.
- User-reported regressions passed with 3 model/persistence/AppStore tests plus 1 UI test and 0 failures, covering deleted/needs-review principles and ReviewCards `上一页` navigation.

Residual risk:

- Freshness/expiry and policy-document signature chain were still missing at this point and are now covered by later entries above. Registry catalog scheduler, real publisher onboarding, and live external registry acceptance run remain future work.
- Real BYOK GLM network success remains externally blocked until a user-provided key is configured and an external call window is approved.

## 2026-06-10: Remote Asset Trust Policy Fetch Boundary

Scope:

- Let remote `AssetPackInstallManifest` optionally declare a `trustPolicyURL`.
- Fetch a remote `AssetPackTrustPolicyDocument` before installation when the manifest declares a policy URL.
- Use the fetched policy to build the `AssetPackSignatureVerifier` for both manifest preflight validation and SQLite save-time signature validation.
- Keep local pasted manifests and remote manifests without a policy URL on the existing default local trust policy path.

Changed areas:

- `Sources/Services/PersistenceCore.swift`
- `Sources/App/AppStore.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_usesRemoteTrustPolicyBeforeInstalling
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_usesRemoteTrustPolicyBeforeInstalling -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_reportsRemoteTrustPolicyFetchFailure
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackInstallManifest_filtersInstallablePromptAndLensPacksThroughTrustGate -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackInstallManifestInstaller_savesOnlyValidatedPromptAndLensPacks -only-testing:MingSiTests/AppStoreStateMachineTests/testImportAssetPackInstallManifestFromJSON_savesValidatedPacksAndRefreshesRuntimeAssets -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_reusesTrustedInstallGateAndRefreshesRuntimeAssets -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_usesRemoteTrustPolicyBeforeInstalling -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_reportsRemoteTrustPolicyFetchFailure -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_reportsFetchFailure -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_keepsInstallFailureDistinctFromFetchFailure -only-testing:MingSiTests/AppStoreStateMachineTests/testSettingsAutomationIdentifiers_areStableForAssetPackInstallManifest -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQASettingsAssetPackManifestFixture_readsDirectAndSimctlChildFlags -only-testing:MingSiTests/PersistenceCoreTests/testDeletePrinciple_removesPrincipleFromVisibleReadsAndExport -only-testing:MingSiTests/AppStoreStateMachineTests/testDeletePrinciple_removesNeedsReviewPrincipleFromRepositoryAndVisibleTrainingAssets -only-testing:MingSiTests/AppStoreStateMachineTests/testPreviousFromReviewCardsReturnsToCaptureWithoutClearingCards -only-testing:MingSiUITests/MingSiUITests/testTodayReviewCardsCanNavigateBackToCaptureWithPreviousAction -only-testing:MingSiUITests/MingSiUITests/testSettingsAssetPackManifestInstallReportsInvalidJSONThroughIdentifier -only-testing:MingSiUITests/MingSiUITests/testSettingsAssetPackManifestRemoteURLInstallReportsFetchFailureThroughIdentifier
```

Result:

- RED first failed because `AssetPackInstallManifest` had no `trustPolicyURL`, `AssetPackTrustPolicyDocument` did not exist, and the fetcher could not fetch trust policy data.
- GREEN passed with 1 focused remote-policy install test and 0 failures after adding the policy document, fetcher boundary, manifest field, and install-time verifier injection.
- Remote trust policy failure coverage passed with 2 focused tests and 0 failures; policy fetch errors report `获取远程资产包信任策略失败` and stay distinct from manifest fetch failures.
- Final combined asset-pack/user regression verification passed with 13 model/persistence/AppStore tests plus 3 UI tests and 0 failures, covering default local trust policy installs, remote manifest fetch/install, remote trust policy fetch/install, Settings local/remote manifest actions, principle deletion, and ReviewCards `上一页` navigation.

Residual risk:

- Fetched trust policy is used for the current install transaction and current refreshed runtime state. It is not yet persisted as a registry trust-policy cache, so cross-restart remote policy reuse and long-lived revocation/key-rotation sync remain future work.
- There is still no marketplace catalog browsing/sync scheduler, real publisher onboarding, or live external registry acceptance run.
- Real BYOK GLM network success remains externally blocked until a user-provided key is configured and an external call window is approved.

## 2026-06-10: Settings Remote Manifest URL Install UI Automation

Scope:

- Add a product-facing Settings URL input for remote `AssetPackInstallManifest` JSON while keeping install behind the existing local trust gate.
- Expose stable identifiers for the URL field and remote install action: `settings.asset-pack-manifest.remote-url-field` and `settings.asset-pack-manifest.remote-install-action`.
- Prove the rendered Settings flow can be driven through XCTest by tapping `获取安装` against a Debug-only localhost fixture URL and reading the fetch-failure status identifier.
- Keep this as a URL install entry only; no marketplace catalog browsing, sync scheduler, real publisher onboarding, server revocation/key rotation feed, or remote trust-chain service is added.

Changed areas:

- `Sources/Features/FeatureTabs.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `Tests/UI/MingSiUITests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testSettingsAutomationIdentifiers_areStableForAssetPackInstallManifest -only-testing:MingSiUITests/MingSiUITests/testSettingsAssetPackManifestRemoteURLInstallReportsFetchFailureThroughIdentifier
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_reusesTrustedInstallGateAndRefreshesRuntimeAssets -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_reportsFetchFailure -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_keepsInstallFailureDistinctFromFetchFailure -only-testing:MingSiTests/AppStoreStateMachineTests/testSettingsAutomationIdentifiers_areStableForAssetPackInstallManifest -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQASettingsAssetPackManifestFixture_readsDirectAndSimctlChildFlags -only-testing:MingSiTests/PersistenceCoreTests/testDeletePrinciple_removesPrincipleFromVisibleReadsAndExport -only-testing:MingSiTests/AppStoreStateMachineTests/testDeletePrinciple_removesNeedsReviewPrincipleFromRepositoryAndVisibleTrainingAssets -only-testing:MingSiTests/AppStoreStateMachineTests/testPreviousFromReviewCardsReturnsToCaptureWithoutClearingCards -only-testing:MingSiUITests/MingSiUITests/testTodayReviewCardsCanNavigateBackToCaptureWithPreviousAction -only-testing:MingSiUITests/MingSiUITests/testSettingsAssetPackManifestInstallReportsInvalidJSONThroughIdentifier -only-testing:MingSiUITests/MingSiUITests/testSettingsAssetPackManifestRemoteURLInstallReportsFetchFailureThroughIdentifier
rg -n "jsonPayload|JSONPayload|legacyJSONPayload|ed25519:" Sources Tests
env | rg 'MINGSI_GLM_API_KEY|GLM_API_KEY|SIMCTL_CHILD_MINGSI_GLM_API_KEY|ZHIPU|GLM'
git diff --check
```

Result:

- RED first failed because `SettingsAutomationID` did not expose remote manifest URL/install identifiers.
- GREEN passed with 1 AppStore identifier contract test and 1 UI test, 0 failures.
- `testSettingsAssetPackManifestRemoteURLInstallReportsFetchFailureThroughIdentifier` launched the Settings fixture, found the URL field prefilled with `http://127.0.0.1:1/mingsi-asset-pack-manifest.json`, tapped `settings.asset-pack-manifest.remote-install-action`, and asserted `settings.asset-pack-manifest.message` contains `获取远程资产包清单失败`.
- Final combined verification passed with 8 model/persistence/AppStore tests plus 3 UI tests and 0 failures, covering remote manifest fetch/install service boundaries, Settings local/remote manifest action automation, user-reported principle deletion regression, and ReviewCards `上一页` navigation.
- Source/test search for removed prompt payload names and the old `ed25519:` signature format returned no matches; GLM/BYOK environment search returned no key; `git diff --check` passed with no output.

Residual risk:

- The Settings URL action proves a manually supplied manifest URL can drive the trusted install path through rendered UI automation. It is not marketplace catalog browsing, automatic registry sync, real publisher onboarding, server-provided revocation/key rotation, remote trust-chain validation, or a live external registry acceptance run.
- Real BYOK GLM network success remains externally blocked until a user-provided key is configured and an external call window is approved.

## 2026-06-10: Remote Asset Pack Install Manifest Fetch Boundary

Scope:

- Add a narrow remote fetch boundary for `AssetPackInstallManifest` without adding marketplace UI or touching the Today state machine.
- Introduce `AssetPackInstallManifestFetching` plus a default `URLSessionAssetPackInstallManifestFetcher`.
- Add `AppStore.fetchAndInstallAssetPackInstallManifest(from:fetcher:)`, which fetches manifest JSON data and then reuses the existing decode, repository-backed installer, trust metadata/content hash/P-256 signature/policy validation, and runtime refresh path.
- Keep fetch failures distinct from fetched-but-invalid install failures so Settings or future marketplace UI can report the right boundary.

Changed areas:

- `Sources/Services/PersistenceCore.swift`
- `Sources/App/AppStore.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_reusesTrustedInstallGateAndRefreshesRuntimeAssets -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_reportsFetchFailure
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_keepsInstallFailureDistinctFromFetchFailure
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_reusesTrustedInstallGateAndRefreshesRuntimeAssets -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_reportsFetchFailure -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_keepsInstallFailureDistinctFromFetchFailure
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_reusesTrustedInstallGateAndRefreshesRuntimeAssets -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_reportsFetchFailure -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_keepsInstallFailureDistinctFromFetchFailure -only-testing:MingSiTests/PersistenceCoreTests/testDeletePrinciple_removesPrincipleFromVisibleReadsAndExport -only-testing:MingSiTests/AppStoreStateMachineTests/testDeletePrinciple_removesNeedsReviewPrincipleFromRepositoryAndVisibleTrainingAssets -only-testing:MingSiTests/AppStoreStateMachineTests/testPreviousFromReviewCardsReturnsToCaptureWithoutClearingCards -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQASettingsAssetPackManifestFixture_readsDirectAndSimctlChildFlags -only-testing:MingSiTests/AppStoreStateMachineTests/testSettingsAutomationIdentifiers_areStableForAssetPackInstallManifest -only-testing:MingSiUITests/MingSiUITests/testTodayReviewCardsCanNavigateBackToCaptureWithPreviousAction -only-testing:MingSiUITests/MingSiUITests/testSettingsAssetPackManifestInstallReportsInvalidJSONThroughIdentifier
rg -n "jsonPayload|JSONPayload|legacyJSONPayload|ed25519:" Sources Tests
env | rg 'MINGSI_GLM_API_KEY|GLM_API_KEY|SIMCTL_CHILD_MINGSI_GLM_API_KEY|ZHIPU|GLM'
git diff --check
```

Result:

- RED first failed because `AssetPackInstallManifestFetching` did not exist.
- GREEN passed with 2 tests and 0 failures after adding the fetcher protocol/default implementation and the AppStore fetch/install entry.
- A follow-up RED proved fetched invalid JSON was incorrectly reported as a fetch failure because the AppStore catch covered both fetch and install; the fix split fetch error handling from install error handling.
- Final focused remote manifest tests passed with 3 tests and 0 failures.
- Final combined verification passed with 8 model/persistence/AppStore tests plus 2 UI tests and 0 failures, covering the new remote fetch boundary, the two user-reported regressions, and the Settings asset-pack manifest accessibility-driver proof.
- Source/test search for removed prompt payload names and the old `ed25519:` signature format returned no matches; GLM/BYOK environment search returned no key; `git diff --check` passed with no output.

Residual risk:

- This is a network-data boundary and AppStore install entry only. It still has no marketplace catalog browsing, registry sync scheduler, real publisher onboarding, server-provided revocation/key rotation feed, remote trust-chain validation, or live external registry acceptance run.
- Real BYOK GLM network success remains externally blocked until a user-provided key is configured and an external call window is approved.

## 2026-06-10: Settings Manifest UI Automation Proof / User Regression Recheck

Scope:

- Prove the Settings `资产包安装清单` surface is not only identifier-tagged but actually drivable through XCTest UI automation.
- Add a Debug-only Settings manifest fixture that renders the manifest card first and starts with invalid JSON so UI automation can tap install without pasteboard coupling.
- Preserve stable child accessibility identifiers by moving card-level markers onto card titles instead of outer SwiftUI card containers.
- Recheck the two user-reported regressions: deleting unfinished/needsReview principles and navigating back from thinking cards with `上一页`.

Changed areas:

- `Sources/App/AppStore.swift`
- `Sources/Features/FeatureTabs.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `Tests/UI/MingSiUITests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testDeletePrinciple_removesPrincipleFromVisibleReadsAndExport -only-testing:MingSiTests/AppStoreStateMachineTests/testDeletePrinciple_removesNeedsReviewPrincipleFromRepositoryAndVisibleTrainingAssets -only-testing:MingSiTests/AppStoreStateMachineTests/testPreviousFromReviewCardsReturnsToCaptureWithoutClearingCards -only-testing:MingSiUITests/MingSiUITests/testTodayReviewCardsCanNavigateBackToCaptureWithPreviousAction
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQASettingsAssetPackManifestFixture_readsDirectAndSimctlChildFlags -only-testing:MingSiTests/AppStoreStateMachineTests/testSettingsAutomationIdentifiers_areStableForAssetPackInstallManifest -only-testing:MingSiUITests/MingSiUITests/testSettingsAssetPackManifestInstallReportsInvalidJSONThroughIdentifier
rg -n "jsonPayload|JSONPayload|legacyJSONPayload|ed25519:" Sources Tests
env | rg 'MINGSI_GLM_API_KEY|GLM_API_KEY|SIMCTL_CHILD_MINGSI_GLM_API_KEY|ZHIPU|GLM'
git diff --check
```

Result:

- User-reported regression coverage passed: principle deletion and ReviewCards previous navigation ran 3 model/persistence tests plus 1 UI test with 0 failures.
- Settings manifest fixture and identifier contract passed with 2 unit tests and 0 failures.
- `testSettingsAssetPackManifestInstallReportsInvalidJSONThroughIdentifier` launched the rendered Settings fixture, found `settings.asset-pack-manifest.install-action`, tapped it, and asserted `settings.asset-pack-manifest.message` contains `安装资产包清单失败`; it passed with 0 failures.
- Source/test search for removed prompt payload names and the old `ed25519:` signature format returned no matches.
- No GLM/BYOK environment key is present, so the live GLM acceptance harness still cannot make a real external call in this environment.
- `git diff --check` passed with no output after this documentation update.

Residual risk:

- Settings UI automation proof covers a local invalid-JSON install path through XCTest accessibility identifiers; it is not a remote registry sync or marketplace install proof.
- Real BYOK GLM network success remains externally blocked until a user-provided key is configured and an external call window is approved.

## 2026-06-10: Asset Pack Install Manifest Settings Surface

Scope:

- Add the local Settings surface for pasted `AssetPackInstallManifest` JSON after the repository-backed installer boundary.
- Expose manifest import through `AppStore`, refreshing Prompt/Lens pack inventories and runtime providers after validated install.
- Add a compact Settings `资产包安装清单` card with JSON paste/install actions, status copy, and stable accessibility identifiers.
- Keep this local-only; no network fetch, marketplace sync, real publisher onboarding, or Today state-machine change is added.

Changed areas:

- `Sources/App/AppStore.swift`
- `Sources/Features/FeatureTabs.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `Sources/Services/PersistenceCore.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testImportAssetPackInstallManifestFromJSON_savesValidatedPacksAndRefreshesRuntimeAssets
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testSettingsAutomationIdentifiers_areStableForAssetPackInstallManifest
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testImportAssetPackInstallManifestFromJSON_savesValidatedPacksAndRefreshesRuntimeAssets -only-testing:MingSiTests/AppStoreStateMachineTests/testSettingsAutomationIdentifiers_areStableForAssetPackInstallManifest -only-testing:MingSiTests/AppStoreStateMachineTests/testSettingsAutomationIdentifiers_areStableForPromptPackManager -only-testing:MingSiTests/AppStoreStateMachineTests/testSettingsAutomationIdentifiers_areStableForLensPackManager
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/LocalPromptProviderTests/testEveryPromptTemplate_exposesVersionedPromptAssetMetadata -only-testing:MingSiTests/LocalPromptProviderTests/testGenerateQuestionsRollbackTarget_resolvesHistoricalPromptAsset -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetSelection_saveAndLoadSelectedVersions -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_saveAndLoadEnabledPacks -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_disabledPacksPersistButDoNotLoadAsEnabled -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRequiresTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRejectsMismatchedContentHash -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRejectsInvalidSignature -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRejectsUnknownVerificationPolicyVersion -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRejectsRevokedPublisherForPolicyVersion -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_verificationPolicyAllowsPublisherKeyRotationGracePeriod -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_enabledPacksExcludeLegacyExternalPacksWithoutTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_enabledPacksExcludeLegacyExternalPacksWithMismatchedContentHash -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_saveAndLoadEnabledPacks -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_disabledPacksPersistButDoNotLoadAsEnabled -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRequiresTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRejectsMismatchedContentHash -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRejectsInvalidSignature -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRejectsUnknownVerificationPolicyVersion -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRejectsRevokedPublisherForPolicyVersion -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_verificationPolicyAllowsPublisherKeyRotationGracePeriod -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_enabledPacksExcludeLegacyExternalPacksWithoutTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_enabledPacksExcludeLegacyExternalPacksWithMismatchedContentHash -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackInstallManifest_filtersInstallablePromptAndLensPacksThroughTrustGate -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackInstallManifestInstaller_savesOnlyValidatedPromptAndLensPacks -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesPromptAssetSelections -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesPromptAssetPacks -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesLensAssetPacks -only-testing:MingSiTests/PersistenceCoreTests/testPromptTracingLLMClient_recordsPromptAssetVersions -only-testing:MingSiTests/PersistenceCoreTests/testMigration_v21_addsPromptAssetPackProvenanceColumns -only-testing:MingSiTests/PersistenceCoreTests/testMigration_v17_addsPromptAssetSelectionsTableAndIndexes -only-testing:MingSiTests/PersistenceCoreTests/testMigration_v18_addsLensAssetPacksTableAndIndexes -only-testing:MingSiTests/PersistenceCoreTests/testMigration_v19_addsPromptAssetPacksTableAndIndexes -only-testing:MingSiTests/PersistenceCoreTests/testMigration_v20_addsAssetPackTrustMetadataColumns -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_loadsEnabledLensAssetPacksIntoRuntimeChoices -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_loadsEnabledPromptAssetPacksIntoEffectiveProvider -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_ignoresDisabledPromptAssetPacksForEffectiveProvider -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_promptRollbackSelectionOverridesEnabledPromptPack -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_scheduledPromptEvalUsesEnabledPromptPackVersions -only-testing:MingSiTests/AppStoreStateMachineTests/testRuntimeLensAssetSelectionUsesCustomLensStateWithoutChangingBuiltinLens -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadLensAssetPacks_listsAllPacksWithEnabledRuntimeCount -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadLensAssetPacks_keepsMismatchedExternalPackOutOfRuntimeChoices -only-testing:MingSiTests/AppStoreStateMachineTests/testSetLensAssetPackEnabled_updatesRuntimeChoicesAndClearsDisabledSelection -only-testing:MingSiTests/AppStoreStateMachineTests/testImportLensAssetPackFromJSON_persistsAndEnablesPack -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPromptAssetPacks_listsAllPacksWithEnabledRuntimeCount -only-testing:MingSiTests/AppStoreStateMachineTests/testSetPromptAssetPackEnabled_updatesRuntimePromptProvider -only-testing:MingSiTests/AppStoreStateMachineTests/testImportPromptAssetPackFromJSON_persistsAndEnablesPack -only-testing:MingSiTests/AppStoreStateMachineTests/testImportAssetPackInstallManifestFromJSON_savesValidatedPacksAndRefreshesRuntimeAssets -only-testing:MingSiTests/AppStoreStateMachineTests/testSettingsAutomationIdentifiers_areStableForLensPackManager -only-testing:MingSiTests/AppStoreStateMachineTests/testSettingsAutomationIdentifiers_areStableForPromptPackManager -only-testing:MingSiTests/AppStoreStateMachineTests/testSettingsAutomationIdentifiers_areStableForAssetPackInstallManifest -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_restoresHistoricalPromptAssetSelectionWithLocalProvider -only-testing:MingSiTests/AppStoreStateMachineTests/testLensLibrary_combinesEnabledMarketplaceLensPackAndIgnoresDisabledPacks
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testDeletePrinciple_removesPrincipleFromVisibleReadsAndExport -only-testing:MingSiTests/AppStoreStateMachineTests/testDeletePrinciple_removesNeedsReviewPrincipleFromRepositoryAndVisibleTrainingAssets -only-testing:MingSiTests/AppStoreStateMachineTests/testPreviousFromReviewCardsReturnsToCaptureWithoutClearingCards -only-testing:MingSiUITests/MingSiUITests/testTodayReviewCardsCanNavigateBackToCaptureWithPreviousAction
rg -n "jsonPayload|JSONPayload|legacyJSONPayload|ed25519:" Sources Tests
git diff --check
```

Result:

- AppStore manifest import passed with 1 test and 0 failures after decoding `AssetPackInstallManifest`, installing validated packs, refreshing Prompt/Lens runtime state, and reporting installed/rejected counts.
- Settings automation RED failed as intended before implementation because `SettingsAutomationID` had no Asset Pack Manifest identifiers.
- Focused Settings automation GREEN passed with 1 test and 0 failures.
- Manifest import plus Prompt/Lens/Manifest Settings automation coverage passed with 4 tests and 0 failures.
- Broader asset-pack matrix passed with 53 tests and 0 failures across Prompt/Lens pack persistence, trust gates, content hashes, P-256 signatures, policy/revocation, key rotation, manifest validation/install, Data Export, runtime providers, and Settings identifiers.
- User-reported regressions stayed covered: principle deletion and Today ReviewCards previous-navigation tests passed with 3 model/persistence tests plus 1 UI test and 0 failures.
- Source/test search for removed prompt payload names and the old `ed25519:` fake signature format returned no matches.
- `git diff --check` passed with no output after the documentation update.

Residual risk:

- This is local pasted-manifest installation only.
- Real network registry sync, real publisher onboarding, server-provided revocation/key rotation feeds, remote trust-chain validation, marketplace distribution UX, and real BYOK GLM confirmation remain future work.

## 2026-06-10: Prompt Pack Settings Management Surface

Scope:

- Add the local Prompt Pack management surface after runtime Prompt Pack wiring and repository-backed manifest install backend.
- Expose Prompt Pack inventory loading, deterministic enabled-first listing, enable/disable updates, JSON import validation, runtime `PromptProvider` refresh, and eval-gate recalculation through `AppStore`.
- Add a compact Settings `Prompt 包` card with refresh, status, enable/disable, pasted JSON import, and stable accessibility identifiers.
- Keep this local-only; no network fetch, remote registry sync, manifest install UI, real publisher onboarding, or Today state-machine change is added.

Changed areas:

- `Sources/App/AppStore.swift`
- `Sources/Features/FeatureTabs.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPromptAssetPacks_listsAllPacksWithEnabledRuntimeCount -only-testing:MingSiTests/AppStoreStateMachineTests/testSetPromptAssetPackEnabled_updatesRuntimePromptProvider -only-testing:MingSiTests/AppStoreStateMachineTests/testImportPromptAssetPackFromJSON_persistsAndEnablesPack
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testSettingsAutomationIdentifiers_areStableForPromptPackManager
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testSettingsAutomationIdentifiers_areStableForPromptPackManager -only-testing:MingSiTests/AppStoreStateMachineTests/testSettingsAutomationIdentifiers_areStableForLensPackManager -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPromptAssetPacks_listsAllPacksWithEnabledRuntimeCount -only-testing:MingSiTests/AppStoreStateMachineTests/testSetPromptAssetPackEnabled_updatesRuntimePromptProvider -only-testing:MingSiTests/AppStoreStateMachineTests/testImportPromptAssetPackFromJSON_persistsAndEnablesPack -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadLensAssetPacks_listsAllPacksWithEnabledRuntimeCount -only-testing:MingSiTests/AppStoreStateMachineTests/testSetLensAssetPackEnabled_updatesRuntimeChoicesAndClearsDisabledSelection -only-testing:MingSiTests/AppStoreStateMachineTests/testImportLensAssetPackFromJSON_persistsAndEnablesPack
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testDeletePrinciple_removesPrincipleFromVisibleReadsAndExport -only-testing:MingSiTests/AppStoreStateMachineTests/testDeletePrinciple_removesNeedsReviewPrincipleFromRepositoryAndVisibleTrainingAssets -only-testing:MingSiTests/AppStoreStateMachineTests/testPreviousFromReviewCardsReturnsToCaptureWithoutClearingCards -only-testing:MingSiUITests/MingSiUITests/testTodayReviewCardsCanNavigateBackToCaptureWithPreviousAction
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_saveAndLoadEnabledPacks -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_disabledPacksPersistButDoNotLoadAsEnabled -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRequiresTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRejectsMismatchedContentHash -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRejectsInvalidSignature -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRejectsUnknownVerificationPolicyVersion -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRejectsRevokedPublisherForPolicyVersion -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_verificationPolicyAllowsPublisherKeyRotationGracePeriod -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_enabledPacksExcludeLegacyExternalPacksWithoutTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_enabledPacksExcludeLegacyExternalPacksWithMismatchedContentHash -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_saveAndLoadEnabledPacks -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_disabledPacksPersistButDoNotLoadAsEnabled -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRequiresTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRejectsMismatchedContentHash -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRejectsInvalidSignature -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRejectsUnknownVerificationPolicyVersion -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRejectsRevokedPublisherForPolicyVersion -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_verificationPolicyAllowsPublisherKeyRotationGracePeriod -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_enabledPacksExcludeLegacyExternalPacksWithoutTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_enabledPacksExcludeLegacyExternalPacksWithMismatchedContentHash -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackInstallManifest_filtersInstallablePromptAndLensPacksThroughTrustGate -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackInstallManifestInstaller_savesOnlyValidatedPromptAndLensPacks -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_loadsEnabledLensAssetPacksIntoRuntimeChoices -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_loadsEnabledPromptAssetPacksIntoEffectiveProvider -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_ignoresDisabledPromptAssetPacksForEffectiveProvider -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadLensAssetPacks_listsAllPacksWithEnabledRuntimeCount -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadLensAssetPacks_keepsMismatchedExternalPackOutOfRuntimeChoices -only-testing:MingSiTests/AppStoreStateMachineTests/testSetLensAssetPackEnabled_updatesRuntimeChoicesAndClearsDisabledSelection -only-testing:MingSiTests/AppStoreStateMachineTests/testImportLensAssetPackFromJSON_persistsAndEnablesPack -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPromptAssetPacks_listsAllPacksWithEnabledRuntimeCount -only-testing:MingSiTests/AppStoreStateMachineTests/testSetPromptAssetPackEnabled_updatesRuntimePromptProvider -only-testing:MingSiTests/AppStoreStateMachineTests/testImportPromptAssetPackFromJSON_persistsAndEnablesPack -only-testing:MingSiTests/AppStoreStateMachineTests/testSettingsAutomationIdentifiers_areStableForLensPackManager -only-testing:MingSiTests/AppStoreStateMachineTests/testSettingsAutomationIdentifiers_areStableForPromptPackManager
rg -n "jsonPayload|JSONPayload|legacyJSONPayload|ed25519:" Sources Tests
git diff --check
```

Result:

- AppStore management RED failed as intended before implementation because `loadPromptAssetPacks`, `promptAssetPacks`, `promptAssetPackMessage`, `setPromptAssetPack`, and `importPromptAssetPack` were absent.
- Settings automation RED failed as intended because `SettingsAutomationID` had no Prompt Pack manager identifiers.
- Focused AppStore Prompt Pack management tests passed with 3 tests and 0 failures.
- Prompt/Lens Settings management and automation-id coverage passed with 8 tests and 0 failures.
- User-reported regressions stayed covered: principle deletion and Today ReviewCards previous-navigation tests passed with 3 model/persistence tests plus 1 UI test and 0 failures.
- Broader asset-pack trust/runtime/install matrix passed with 34 tests and 0 failures.
- Source/test search for removed prompt payload names and the old `ed25519:` fake signature format returned no matches.
- `git diff --check` passed with no output before the documentation update.

Residual risk:

- This is local Settings management/import for Prompt Packs only.
- Remote registry sync, manifest-install UI, real publisher onboarding, server-provided revocation/key rotation feeds, remote trust-chain validation, and remote install UX remain future work.
- Real BYOK GLM confirmation remains externally blocked until a user-provided key and approved external call window are available.

## 2026-06-10: Asset Pack Install Manifest Installer Boundary

Scope:

- Add a local backend install boundary after the Asset Pack manifest trust gate.
- Validate remote-like Prompt/Lens manifests before persistence.
- Save only installable Prompt/Lens packs through the existing repositories, leaving rejected packs out of `allPacks()` and runtime `enabledPacks()`.
- Return the validation/rejection report so future Settings or marketplace UI can explain rejected packs without changing Today state-machine behavior.
- Keep this local-only; no network fetch, remote registry sync, product install UI, or real publisher onboarding is added.

Changed areas:

- `Sources/Services/PersistenceCore.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackInstallManifestInstaller_savesOnlyValidatedPromptAndLensPacks
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackInstallManifest_filtersInstallablePromptAndLensPacksThroughTrustGate -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackInstallManifestInstaller_savesOnlyValidatedPromptAndLensPacks -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_saveAndLoadEnabledPacks -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_disabledPacksPersistButDoNotLoadAsEnabled -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRequiresTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRejectsMismatchedContentHash -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRejectsInvalidSignature -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRejectsUnknownVerificationPolicyVersion -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRejectsRevokedPublisherForPolicyVersion -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_verificationPolicyAllowsPublisherKeyRotationGracePeriod -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_enabledPacksExcludeLegacyExternalPacksWithoutTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_enabledPacksExcludeLegacyExternalPacksWithMismatchedContentHash -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_saveAndLoadEnabledPacks -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_disabledPacksPersistButDoNotLoadAsEnabled -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRequiresTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRejectsMismatchedContentHash -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRejectsInvalidSignature -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRejectsUnknownVerificationPolicyVersion -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRejectsRevokedPublisherForPolicyVersion -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_verificationPolicyAllowsPublisherKeyRotationGracePeriod -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_enabledPacksExcludeLegacyExternalPacksWithoutTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_enabledPacksExcludeLegacyExternalPacksWithMismatchedContentHash -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesPromptAssetPacks -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesLensAssetPacks -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_loadsEnabledLensAssetPacksIntoRuntimeChoices -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_loadsEnabledPromptAssetPacksIntoEffectiveProvider -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_ignoresDisabledPromptAssetPacksForEffectiveProvider -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_promptRollbackSelectionOverridesEnabledPromptPack -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_scheduledPromptEvalUsesEnabledPromptPackVersions -only-testing:MingSiTests/AppStoreStateMachineTests/testRuntimeLensAssetSelectionUsesCustomLensStateWithoutChangingBuiltinLens -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadLensAssetPacks_listsAllPacksWithEnabledRuntimeCount -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadLensAssetPacks_keepsMismatchedExternalPackOutOfRuntimeChoices -only-testing:MingSiTests/AppStoreStateMachineTests/testSetLensAssetPackEnabled_updatesRuntimeChoicesAndClearsDisabledSelection -only-testing:MingSiTests/AppStoreStateMachineTests/testImportLensAssetPackFromJSON_persistsAndEnablesPack
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testDeletePrinciple_removesPrincipleFromVisibleReadsAndExport -only-testing:MingSiTests/AppStoreStateMachineTests/testDeletePrinciple_removesNeedsReviewPrincipleFromRepositoryAndVisibleTrainingAssets -only-testing:MingSiTests/AppStoreStateMachineTests/testPreviousFromReviewCardsReturnsToCaptureWithoutClearingCards -only-testing:MingSiUITests/MingSiUITests/testTodayReviewCardsCanNavigateBackToCaptureWithPreviousAction
rg -n "jsonPayload|JSONPayload|legacyJSONPayload|ed25519:" Sources Tests
git diff --check
```

Result:

- RED failed as intended before implementation because `AssetPackInstallManifestInstaller` was not defined.
- Focused GREEN passed with 1 test and 0 failures after adding the installer.
- Broader asset-pack trust/runtime matrix passed with 34 tests and 0 failures.
- User-reported regressions stayed covered: principle deletion and Today ReviewCards previous-navigation tests passed with 3 model/persistence tests plus 1 UI test and 0 failures.
- Source/test search for removed prompt payload names and the old `ed25519:` fake signature format returned no matches.
- `git diff --check` passed with no output before the documentation update.

Residual risk:

- This is local backend installation after local trust validation only.
- Real remote registry sync, real publisher onboarding, server-provided revocation/key rotation feeds, remote trust-chain validation, and product install UX remain future work.
- Real BYOK GLM confirmation remains externally blocked until a user-provided key and approved external call window are available.

## 2026-06-10: Asset Pack Install Manifest Trust Gate

Scope:

- Add a local remote-registry/marketplace preflight boundary for Prompt and Lens asset packs.
- Let a remote-like manifest/catalog submit Prompt and Lens packs to the same local trust gate before any future install, sync, or UI writes them.
- Filter installable packs through trust metadata presence, required-field completeness, deterministic content hash, P-256 signature verification, policy-version lookup, revoked-publisher filtering, and key-rotation grace.
- Keep this as validation only; no network fetch, remote registry sync, database write, install UX, or Today state-machine change is added.

Changed areas:

- `Sources/Services/PersistenceCore.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackInstallManifest_filtersInstallablePromptAndLensPacksThroughTrustGate
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackInstallManifest_filtersInstallablePromptAndLensPacksThroughTrustGate -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_saveAndLoadEnabledPacks -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_disabledPacksPersistButDoNotLoadAsEnabled -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRequiresTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRejectsMismatchedContentHash -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRejectsInvalidSignature -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRejectsUnknownVerificationPolicyVersion -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRejectsRevokedPublisherForPolicyVersion -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_verificationPolicyAllowsPublisherKeyRotationGracePeriod -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_enabledPacksExcludeLegacyExternalPacksWithoutTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_enabledPacksExcludeLegacyExternalPacksWithMismatchedContentHash -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_saveAndLoadEnabledPacks -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_disabledPacksPersistButDoNotLoadAsEnabled -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRequiresTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRejectsMismatchedContentHash -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRejectsInvalidSignature -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRejectsUnknownVerificationPolicyVersion -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRejectsRevokedPublisherForPolicyVersion -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_verificationPolicyAllowsPublisherKeyRotationGracePeriod -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_enabledPacksExcludeLegacyExternalPacksWithoutTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_enabledPacksExcludeLegacyExternalPacksWithMismatchedContentHash -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesPromptAssetPacks -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesLensAssetPacks -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_loadsEnabledLensAssetPacksIntoRuntimeChoices -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_loadsEnabledPromptAssetPacksIntoEffectiveProvider -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_ignoresDisabledPromptAssetPacksForEffectiveProvider -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_promptRollbackSelectionOverridesEnabledPromptPack -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_scheduledPromptEvalUsesEnabledPromptPackVersions -only-testing:MingSiTests/AppStoreStateMachineTests/testRuntimeLensAssetSelectionUsesCustomLensStateWithoutChangingBuiltinLens -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadLensAssetPacks_listsAllPacksWithEnabledRuntimeCount -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadLensAssetPacks_keepsMismatchedExternalPackOutOfRuntimeChoices -only-testing:MingSiTests/AppStoreStateMachineTests/testSetLensAssetPackEnabled_updatesRuntimeChoicesAndClearsDisabledSelection -only-testing:MingSiTests/AppStoreStateMachineTests/testImportLensAssetPackFromJSON_persistsAndEnablesPack
rg -n "jsonPayload|JSONPayload|legacyJSONPayload|ed25519:" Sources Tests
git diff --check
```

Result:

- RED failed as intended before implementation because `AssetPackInstallManifest` and `AssetPackInstallManifestValidator` were not defined.
- Focused GREEN passed with 1 test and 0 failures after adding the manifest, validation report, rejection reasons, and validator.
- Broader asset-pack trust/runtime matrix passed with 33 tests and 0 failures.
- Source/test search for removed prompt payload names and the old `ed25519:` fake signature format returned no matches.
- `git diff --check` passed with no output before the documentation update.

Residual risk:

- This is local preflight validation only.
- Real remote registry sync, real publisher onboarding, server-provided revocation/key rotation feeds, remote trust-chain validation, and install UX remain future work.
- Real BYOK GLM confirmation remains externally blocked until a user-provided key and approved external call window are available.

## 2026-06-10: Asset Pack Publisher Key Rotation Grace Policy

Scope:

- Allow a local verification policy to trust more than one public key for the same publisher during a key-rotation grace window.
- Verify the behavior for both Prompt and Lens imported/marketplace asset packs using real P-256 signatures from two different local test publisher keys.
- Preserve existing trust gates for unknown policy versions, revoked publishers, missing trust metadata, mismatched content hashes, and invalid signatures.
- Keep this as local key-rotation prep only; no remote key rotation feed, publisher onboarding flow, remote revocation sync, or remote trust-chain validation is added.

Changed areas:

- `Sources/Services/PersistenceCore.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_verificationPolicyAllowsPublisherKeyRotationGracePeriod -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_verificationPolicyAllowsPublisherKeyRotationGracePeriod
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_saveAndLoadEnabledPacks -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_disabledPacksPersistButDoNotLoadAsEnabled -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRequiresTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRejectsMismatchedContentHash -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRejectsInvalidSignature -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRejectsUnknownVerificationPolicyVersion -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRejectsRevokedPublisherForPolicyVersion -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_verificationPolicyAllowsPublisherKeyRotationGracePeriod -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_enabledPacksExcludeLegacyExternalPacksWithoutTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_enabledPacksExcludeLegacyExternalPacksWithMismatchedContentHash -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_saveAndLoadEnabledPacks -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_disabledPacksPersistButDoNotLoadAsEnabled -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRequiresTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRejectsMismatchedContentHash -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRejectsInvalidSignature -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRejectsUnknownVerificationPolicyVersion -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRejectsRevokedPublisherForPolicyVersion -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_verificationPolicyAllowsPublisherKeyRotationGracePeriod -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_enabledPacksExcludeLegacyExternalPacksWithoutTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_enabledPacksExcludeLegacyExternalPacksWithMismatchedContentHash -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesPromptAssetPacks -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesLensAssetPacks -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_loadsEnabledLensAssetPacksIntoRuntimeChoices -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_loadsEnabledPromptAssetPacksIntoEffectiveProvider -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_ignoresDisabledPromptAssetPacksForEffectiveProvider -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_promptRollbackSelectionOverridesEnabledPromptPack -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_scheduledPromptEvalUsesEnabledPromptPackVersions -only-testing:MingSiTests/AppStoreStateMachineTests/testRuntimeLensAssetSelectionUsesCustomLensStateWithoutChangingBuiltinLens -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadLensAssetPacks_listsAllPacksWithEnabledRuntimeCount -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadLensAssetPacks_keepsMismatchedExternalPackOutOfRuntimeChoices -only-testing:MingSiTests/AppStoreStateMachineTests/testSetLensAssetPackEnabled_updatesRuntimeChoicesAndClearsDisabledSelection -only-testing:MingSiTests/AppStoreStateMachineTests/testImportLensAssetPackFromJSON_persistsAndEnablesPack
rg -n "jsonPayload|JSONPayload|legacyJSONPayload|ed25519:" Sources Tests
git diff --check
```

Result:

- RED failed as intended before implementation: both Prompt and Lens rotation tests rejected the rotated-policy packs with `trust metadata signature is invalid`.
- GREEN passed after `VerificationPolicy` began storing multiple public keys per publisher and `AssetPackSignatureVerifier` tried all trusted keys for the selected policy version.
- Focused key-rotation tests passed with 2 tests and 0 failures.
- Full asset-pack trust/runtime matrix passed with 32 tests and 0 failures.
- Source/test search for removed prompt payload names and the old `ed25519:` fake signature format returned no matches.
- `git diff --check` passed with no output.

Residual risk:

- This is a local policy fixture for key-rotation grace only.
- Remote key rotation feeds, real publisher onboarding, remote revocation sync, and remote trust-chain validation remain future work.
- Real BYOK GLM confirmation remains externally blocked until a user-provided key and approved external call window are available.

## 2026-06-10: Prompt Asset Pack Provenance Audit

Scope:

- Make Prompt Asset Pack provenance auditable from runtime template selection through prompt run tracing and fixed-suite eval history.
- Add prompt source kind, pack id, pack version, and pack display name to `PromptTemplate`, `PromptRun`, and `PromptEvalRun`.
- Stamp enabled prompt-pack templates when they enter the effective runtime `PromptProvider`.
- Backfill built-in provenance for existing prompt run and prompt eval run rows through SQLite v21.
- Keep this as local provenance only; no remote registry sync, publisher onboarding, revocation feed, key rotation, or remote trust-chain validation is added.

Changed areas:

- `Sources/Services/CoreProtocols.swift`
- `Sources/Domain/Models.swift`
- `Sources/App/AppStore.swift`
- `Sources/Services/PersistenceCore.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testMigration_v21_addsPromptAssetPackProvenanceColumns -only-testing:MingSiTests/PersistenceCoreTests/testSavePromptRun_andLoadRecent -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesSavedDraftAndPromptRun -only-testing:MingSiTests/PersistenceCoreTests/testPromptTracingLLMClient_recordsPromptAssetVersions -only-testing:MingSiTests/PersistenceCoreTests/testSavePromptEvalRun_andLoadRecent -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesPromptEvalRuns -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_scheduledPromptEvalUsesEnabledPromptPackVersions
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/LocalPromptProviderTests -only-testing:MingSiTests/PromptEvalFixtureTests -only-testing:MingSiTests/PersistenceCoreTests/testSavePromptRun_andLoadRecent -only-testing:MingSiTests/PersistenceCoreTests/testPromptRun_legacyRowsWithoutContextRefsFallbackToSourceRefs -only-testing:MingSiTests/PersistenceCoreTests/testPromptRun_unresolvedFailuresReturnsOnlyFailedRuns -only-testing:MingSiTests/PersistenceCoreTests/testPromptRun_unresolvedFailuresIgnoresFailureResolvedByLaterSuccess -only-testing:MingSiTests/PersistenceCoreTests/testPromptRun_updateFeedbackPersistsUserDenial -only-testing:MingSiTests/PersistenceCoreTests/testPromptRun_statsCalculatesFailureEmptyResultAndDenialRates -only-testing:MingSiTests/PersistenceCoreTests/testSavePromptEvalRun_andLoadRecent -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesSavedDraftAndPromptRun -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesPromptEvalRuns -only-testing:MingSiTests/PersistenceCoreTests/testPromptTracingLLMClient_recordsSuccessAndFailure -only-testing:MingSiTests/PersistenceCoreTests/testPromptTracingLLMClient_recordsPromptAssetVersions -only-testing:MingSiTests/PersistenceCoreTests/testMigration_v21_addsPromptAssetPackProvenanceColumns -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_loadsEnabledPromptAssetPacksIntoEffectiveProvider -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_ignoresDisabledPromptAssetPacksForEffectiveProvider -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_promptRollbackSelectionOverridesEnabledPromptPack -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_scheduledPromptEvalUsesEnabledPromptPackVersions -only-testing:MingSiTests/AppStoreStateMachineTests/testRunPromptEvalSuite_persistsRunsAndUpdatesReleaseGate -only-testing:MingSiTests/AppStoreStateMachineTests/testApplyPromptRollback_persistsSelectedVersionAcrossStoreReload
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testDeletePrinciple_removesPrincipleFromVisibleReadsAndExport -only-testing:MingSiTests/AppStoreStateMachineTests/testDeletePrinciple_removesNeedsReviewPrincipleFromRepositoryAndVisibleTrainingAssets -only-testing:MingSiTests/AppStoreStateMachineTests/testPreviousFromReviewCardsReturnsToCaptureWithoutClearingCards -only-testing:MingSiUITests/MingSiUITests/testTodayReviewCardsCanNavigateBackToCaptureWithPreviousAction
rg -n "jsonPayload|JSONPayload|legacyJSONPayload|ed25519:" Sources Tests
git diff --check
```

Result:

- RED failed as intended before implementation because `PromptRun` had no prompt-pack provenance fields.
- Focused GREEN passed with 7 tests and 0 failures after stamping prompt-pack metadata into runtime templates and persisting provenance into prompt run/eval run records.
- Wider prompt/persistence/AppStore coverage passed with 40 tests and 0 failures.
- User-reported regressions stayed covered: principle deletion and Today ReviewCards previous-navigation tests passed with 3 model/persistence tests plus 1 UI test and 0 failures.
- Source/test search for removed prompt payload names and the old `ed25519:` fake signature format returned no matches.
- `git diff --check` passed with no output.

Residual risk:

- This is local provenance/audit wiring only.
- Remote registry sync, real publisher onboarding, server-provided revocation feeds, public-key rotation, and remote trust-chain validation remain future work.
- Real BYOK GLM confirmation remains externally blocked until a user-provided key and approved external call window are available.

## 2026-06-10: Asset Pack Verification Policy Version / Publisher Revocation

Scope:

- Make `AssetTrustMetadata.verificationPolicyVersion` an enforceable local trust-policy boundary.
- Reject imported/marketplace Prompt and Lens asset packs when the policy version is unknown, even if the pack has a matching content hash and valid P-256 signature.
- Reject imported/marketplace Prompt and Lens asset packs when the selected local policy revokes the publisher id.
- Keep this as local trust-chain prep only; no remote registry sync, real publisher onboarding, remote revocation feed, or key rotation is added in this slice.

Changed areas:

- `Sources/Services/PersistenceCore.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRejectsUnknownVerificationPolicyVersion -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRejectsRevokedPublisherForPolicyVersion
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRejectsUnknownVerificationPolicyVersion -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRejectsRevokedPublisherForPolicyVersion
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_saveAndLoadEnabledPacks -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_disabledPacksPersistButDoNotLoadAsEnabled -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRequiresTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRejectsMismatchedContentHash -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRejectsInvalidSignature -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRejectsUnknownVerificationPolicyVersion -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRejectsRevokedPublisherForPolicyVersion -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_enabledPacksExcludeLegacyExternalPacksWithoutTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_enabledPacksExcludeLegacyExternalPacksWithMismatchedContentHash -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_saveAndLoadEnabledPacks -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_disabledPacksPersistButDoNotLoadAsEnabled -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRequiresTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRejectsMismatchedContentHash -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRejectsInvalidSignature -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRejectsUnknownVerificationPolicyVersion -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRejectsRevokedPublisherForPolicyVersion -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_enabledPacksExcludeLegacyExternalPacksWithoutTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_enabledPacksExcludeLegacyExternalPacksWithMismatchedContentHash -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesPromptAssetPacks -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesLensAssetPacks -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_loadsEnabledLensAssetPacksIntoRuntimeChoices -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_loadsEnabledPromptAssetPacksIntoEffectiveProvider -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_ignoresDisabledPromptAssetPacksForEffectiveProvider -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_promptRollbackSelectionOverridesEnabledPromptPack -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_scheduledPromptEvalUsesEnabledPromptPackVersions -only-testing:MingSiTests/AppStoreStateMachineTests/testRuntimeLensAssetSelectionUsesCustomLensStateWithoutChangingBuiltinLens -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadLensAssetPacks_listsAllPacksWithEnabledRuntimeCount -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadLensAssetPacks_keepsMismatchedExternalPackOutOfRuntimeChoices -only-testing:MingSiTests/AppStoreStateMachineTests/testSetLensAssetPackEnabled_updatesRuntimeChoicesAndClearsDisabledSelection -only-testing:MingSiTests/AppStoreStateMachineTests/testImportLensAssetPackFromJSON_persistsAndEnablesPack
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testDeletePrinciple_removesPrincipleFromVisibleReadsAndExport -only-testing:MingSiTests/AppStoreStateMachineTests/testDeletePrinciple_removesNeedsReviewPrincipleFromRepositoryAndVisibleTrainingAssets -only-testing:MingSiTests/AppStoreStateMachineTests/testPreviousFromReviewCardsReturnsToCaptureWithoutClearingCards -only-testing:MingSiUITests/MingSiUITests/testTodayReviewCardsCanNavigateBackToCaptureWithPreviousAction
rg -n "jsonPayload|JSONPayload|legacyJSONPayload|ed25519:" Sources Tests
git diff --check
```

Result:

- Prompt policy tests first failed before the shared verifier looked up publisher keys through `verificationPolicyVersion`; they passed after adding local verification policies and a revoked-publisher policy fixture.
- Lens parity policy tests passed with 2 tests and 0 failures.
- Full asset-pack persistence/runtime coverage, including policy-version and revoked-publisher tests, passed with 30 tests and 0 failures.
- User-reported regressions stayed covered: principle deletion and Today ReviewCards previous-navigation tests passed with 3 model/persistence tests plus 1 UI test and 0 failures.
- Source/test search for removed prompt payload names and the old `ed25519:` fake signature format returned no matches.
- `git diff --check` passed with no output.

Residual risk:

- This is local policy-version and publisher-revocation prep only.
- Remote registry sync, real publisher onboarding, server-provided revocation feeds, public-key rotation, and remote trust-chain validation remain future work.
- Real BYOK GLM confirmation remains externally blocked until a user-provided key and approved external call window are available.

## 2026-06-10: Asset Pack P-256 Signature Verification Boundary

Scope:

- Add local cryptographic signature verification for imported/marketplace Prompt and Lens asset packs.
- Verify signatures against the same canonical stable-content payload used for the asset pack content hash.
- Reject external packs with invalid signatures at save time.
- Keep legacy external rows visible through `allPacks()`, while excluding rows with missing, stale, or invalid trust proof from `enabledPacks()` runtime loading.

Changed areas:

- `Sources/Services/PersistenceCore.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRejectsInvalidSignature -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRejectsInvalidSignature
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_saveAndLoadEnabledPacks -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_disabledPacksPersistButDoNotLoadAsEnabled -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRequiresTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRejectsMismatchedContentHash -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRejectsInvalidSignature -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_enabledPacksExcludeLegacyExternalPacksWithoutTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_enabledPacksExcludeLegacyExternalPacksWithMismatchedContentHash -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_saveAndLoadEnabledPacks -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_disabledPacksPersistButDoNotLoadAsEnabled -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRequiresTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRejectsMismatchedContentHash -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRejectsInvalidSignature -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_enabledPacksExcludeLegacyExternalPacksWithoutTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_enabledPacksExcludeLegacyExternalPacksWithMismatchedContentHash -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesPromptAssetPacks -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesLensAssetPacks -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_loadsEnabledLensAssetPacksIntoRuntimeChoices -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_loadsEnabledPromptAssetPacksIntoEffectiveProvider -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_ignoresDisabledPromptAssetPacksForEffectiveProvider -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_promptRollbackSelectionOverridesEnabledPromptPack -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_scheduledPromptEvalUsesEnabledPromptPackVersions -only-testing:MingSiTests/AppStoreStateMachineTests/testRuntimeLensAssetSelectionUsesCustomLensStateWithoutChangingBuiltinLens -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadLensAssetPacks_listsAllPacksWithEnabledRuntimeCount -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadLensAssetPacks_keepsMismatchedExternalPackOutOfRuntimeChoices -only-testing:MingSiTests/AppStoreStateMachineTests/testSetLensAssetPackEnabled_updatesRuntimeChoicesAndClearsDisabledSelection -only-testing:MingSiTests/AppStoreStateMachineTests/testImportLensAssetPackFromJSON_persistsAndEnablesPack
rg -n "jsonPayload|JSONPayload|legacyJSONPayload|ed25519:" Sources Tests
git diff --check
```

Result:

- RED failed as intended because external Prompt/Lens packs with correct content hashes but invalid signatures could still be saved.
- GREEN passed after adding `AssetPackSignatureVerifier`, local trusted publisher public-key lookup, P-256 DER signature verification, save-time validation, and runtime `enabledPacks()` signature filtering.
- The focused invalid-signature tests passed with 2 tests and 0 failures.
- Full asset-pack persistence/runtime coverage passed with 26 tests and 0 failures.
- Source/test search for removed prompt payload names and the old `ed25519:` fake signature format returned no matches.
- `git diff --check` passed with no output.

Residual risk:

- This is a local cryptographic verification boundary, not remote marketplace sync.
- Remote publisher onboarding, server-provided revocation feeds, public-key rotation, and remote trust-chain validation remain future work.
- The only trusted publisher key currently registered is the local test publisher used by the existing imported/marketplace test fixtures.
- Real BYOK GLM confirmation remains externally blocked until a user-provided key and approved external call window are available.

## 2026-06-10: Asset Pack Trust Metadata Gate

Scope:

- Add first-class local trust metadata to Prompt and Lens asset packs.
- Require complete trust metadata before imported/marketplace packs can be saved through SQLite repositories.
- Keep legacy external rows visible in `allPacks()` and Data Export, while excluding untrusted legacy external rows from `enabledPacks()` runtime loading.
- Preserve Lens pack trust metadata when the Settings pack-management surface toggles enablement.

Changed areas:

- `Sources/Domain/Models.swift`
- `Sources/App/AppStore.swift`
- `Sources/Services/PersistenceCore.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRequiresTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRequiresTrustMetadata
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_enabledPacksExcludeLegacyExternalPacksWithoutTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_enabledPacksExcludeLegacyExternalPacksWithoutTrustMetadata
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_saveAndLoadEnabledPacks -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_disabledPacksPersistButDoNotLoadAsEnabled -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRequiresTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_saveAndLoadEnabledPacks -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_disabledPacksPersistButDoNotLoadAsEnabled -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRequiresTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesPromptAssetPacks -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesLensAssetPacks -only-testing:MingSiTests/PersistenceCoreTests/testMigration_v18_addsLensAssetPacksTableAndIndexes -only-testing:MingSiTests/PersistenceCoreTests/testMigration_v19_addsPromptAssetPacksTableAndIndexes -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_loadsEnabledLensAssetPacksIntoRuntimeChoices -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_loadsEnabledPromptAssetPacksIntoEffectiveProvider -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_ignoresDisabledPromptAssetPacksForEffectiveProvider -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_promptRollbackSelectionOverridesEnabledPromptPack -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_scheduledPromptEvalUsesEnabledPromptPackVersions -only-testing:MingSiTests/AppStoreStateMachineTests/testRuntimeLensAssetSelectionUsesCustomLensStateWithoutChangingBuiltinLens -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadLensAssetPacks_listsAllPacksWithEnabledRuntimeCount -only-testing:MingSiTests/AppStoreStateMachineTests/testSetLensAssetPackEnabled_updatesRuntimeChoicesAndClearsDisabledSelection -only-testing:MingSiTests/AppStoreStateMachineTests/testImportLensAssetPackFromJSON_persistsAndEnablesPack
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_saveAndLoadEnabledPacks -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_disabledPacksPersistButDoNotLoadAsEnabled -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_externalPackRequiresTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_enabledPacksExcludeLegacyExternalPacksWithoutTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_saveAndLoadEnabledPacks -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_disabledPacksPersistButDoNotLoadAsEnabled -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_externalPackRequiresTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_enabledPacksExcludeLegacyExternalPacksWithoutTrustMetadata -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesPromptAssetPacks -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesLensAssetPacks -only-testing:MingSiTests/PersistenceCoreTests/testMigration_v18_addsLensAssetPacksTableAndIndexes -only-testing:MingSiTests/PersistenceCoreTests/testMigration_v19_addsPromptAssetPacksTableAndIndexes -only-testing:MingSiTests/PersistenceCoreTests/testMigration_v20_addsAssetPackTrustMetadataColumns -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_loadsEnabledLensAssetPacksIntoRuntimeChoices -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_loadsEnabledPromptAssetPacksIntoEffectiveProvider -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_ignoresDisabledPromptAssetPacksForEffectiveProvider -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_promptRollbackSelectionOverridesEnabledPromptPack -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_scheduledPromptEvalUsesEnabledPromptPackVersions -only-testing:MingSiTests/AppStoreStateMachineTests/testRuntimeLensAssetSelectionUsesCustomLensStateWithoutChangingBuiltinLens -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadLensAssetPacks_listsAllPacksWithEnabledRuntimeCount -only-testing:MingSiTests/AppStoreStateMachineTests/testSetLensAssetPackEnabled_updatesRuntimeChoicesAndClearsDisabledSelection -only-testing:MingSiTests/AppStoreStateMachineTests/testImportLensAssetPackFromJSON_persistsAndEnablesPack
git diff --check
```

Result:

- Initial RED failed as intended because external Prompt/Lens packs without trust metadata could still be saved.
- A second RED failed as intended because legacy enabled external rows without trust metadata still entered `enabledPacks()`.
- Focused GREEN passed after adding `AssetTrustMetadata`, v20 `trust_metadata_json` columns, save-time validation, runtime enabled-pack filtering, export assertions, and AppStore enable/disable metadata preservation.
- Related Prompt/Lens pack persistence and AppStore runtime wiring coverage passed with 22 tests and 0 failures.
- `git diff --check` passed with no output.

Residual risk:

- This is a local trust-metadata gate and runtime filter. It does not perform remote registry discovery, cryptographic signature verification, publisher trust-chain validation, or remote marketplace sync.
- Existing untrusted external rows remain exportable/manageable through `allPacks()` but are intentionally excluded from runtime loading until re-saved with complete trust metadata.
- Real BYOK GLM confirmation remains externally blocked until a user-provided key and approved external call window are available.

## 2026-06-09: Subtask 118 Prompt Asset Pack Persistence / Export Registry

Scope:

- Add a local versioned Prompt Asset Pack registry for historical/imported/marketplace prompt packs.
- Persist prompt packs with source kind, enabled flag, version/display metadata, and JSON-encoded `PromptTemplate` assets.
- Export prompt packs through Data Export with both raw `templates_json` and decoded structured `templates`.
- Keep this slice registry-only: no remote sync, no Settings management UI, and no runtime prompt-provider wiring yet.

Changed areas:

- `Sources/Domain/Models.swift`
- `Sources/Services/CoreProtocols.swift`
- `Sources/Services/PersistenceCore.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-118-red -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_saveAndLoadEnabledPacks -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_disabledPacksPersistButDoNotLoadAsEnabled -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesPromptAssetPacks -only-testing:MingSiTests/PersistenceCoreTests/testMigration_v19_addsPromptAssetPacksTableAndIndexes test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-118-green -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_saveAndLoadEnabledPacks -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetPack_disabledPacksPersistButDoNotLoadAsEnabled -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesPromptAssetPacks -only-testing:MingSiTests/PersistenceCoreTests/testMigration_v19_addsPromptAssetPacksTableAndIndexes test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-118-persistence -only-testing:MingSiTests/PersistenceCoreTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-118-full-unit -only-testing:MingSiTests test
git diff --check
rg -n "jsonPayload|JSONPayload|legacyJSONPayload" Sources Tests
```

Result:

- Initial RED failed as intended because `PromptAssetPack`, `PromptAssetSourceKind`, and `SQLitePromptAssetPackRepository` did not exist.
- Focused GREEN passed with 4 tests and 0 failures after adding the domain model, v19 table/index migration, SQLite repository, and decoded export section.
- Full `PersistenceCoreTests` passed with 93 tests and 0 failures.
- Full `MingSiTests` passed with 501 tests executed, 1 skipped live-GLM acceptance gate, and 0 failures.
- `git diff --check` passed with no output.
- Source/test search for removed legacy payload names returned no matches under `Sources` or `Tests`.

Residual risk:

- This is a local persistence/export registry only. Runtime prompt-provider composition, Settings import/manage UI, remote prompt registry fetch, trust/signature verification, and remote distribution remain future slices.
- Stored prompt pack templates are `PromptTemplate` snapshots; compatibility with future schema changes should be handled through explicit migrations or decoder defaults when new required fields are introduced.
- Real BYOK GLM confirmation remains externally blocked until a user-provided key and approved external call window are available.

## 2026-06-09: Subtask 117 Scheduled Prompt Eval Execution

Scope:

- Add a local schedule policy for fixed-suite prompt evals so Prompt / Context assets are rechecked automatically when release-gate history is missing, stale, failed, runner-mismatched, or older than the configured interval.
- Run the fixed suite opportunistically during `AppStore.loadPersistedState()` after prompt selection and runtime lens-pack restore, while skipping fresh passing history to avoid duplicate writes.
- Keep Settings' manual prompt eval action intact and keep scheduling outside the Today state machine.

Changed areas:

- `Sources/Domain/Models.swift`
- `Sources/App/AppStore.swift`
- `Tests/Services/PromptEvalFixtureTests.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-117-red -only-testing:MingSiTests/PromptEvalFixtureTests/testPromptEvalSchedulePolicy_runsForMissingOrExpiredHistoryAndSkipsFreshPassingHistory -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_runsScheduledPromptEvalWhenHistoryIsMissing test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-117-green2 -only-testing:MingSiTests/PromptEvalFixtureTests/testPromptEvalSchedulePolicy_runsForMissingOrExpiredHistoryAndSkipsFreshPassingHistory -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_runsScheduledPromptEvalWhenHistoryIsMissing -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_skipsScheduledPromptEvalWhenHistoryIsFresh test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-117-focused -only-testing:MingSiTests/PromptEvalFixtureTests -only-testing:MingSiTests/PersistenceCoreTests -only-testing:MingSiTests/AppStoreStateMachineTests test
git diff --check
```

Result:

- Initial RED failed as intended because `PromptEvalSchedulePolicy` and load-time scheduled eval execution did not exist.
- Focused GREEN passed with the policy, missing-history auto-run, and fresh-history skip tests.
- Wider focused coverage passed with `PromptEvalFixtureTests`, `PersistenceCoreTests`, and `AppStoreStateMachineTests` totaling 324 tests and 0 failures.
- `git diff --check` passed.

Residual risk:

- This is a local opportunistic scheduler on persisted-state load, not a background timer, remote registry job, or live model eval runner.
- The fixed suite still evaluates local deterministic fixtures; real BYOK GLM confirmation remains externally blocked until a user-provided key and approved external call window are available.

## 2026-06-09: Subtask 116 Prompt Eval Case Artifacts

Scope:

- Make fixed-suite prompt eval case results more useful as versioned assets by recording per-case input summary, expected behavior, actual observation, and diagnostic reason.
- Populate those artifacts from `PromptEvalRunner` for both passing and failing fixed-suite cases.
- Keep existing `PromptEvalRun` persistence schema unchanged because case results are already stored as `case_results_json`.
- Add a structured `case_results` array to Data Export for `prompt_eval_runs` while retaining the original `case_results_json` compatibility field.

Changed areas:

- `Sources/Domain/Models.swift`
- `Sources/Services/CoreProtocols.swift`
- `Sources/Services/PersistenceCore.swift`
- `Tests/Services/PromptEvalFixtureTests.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-116-red -only-testing:MingSiTests/PromptEvalFixtureTests/testPromptEvalRunner_recordsSuiteMetadataAndCaseResults -only-testing:MingSiTests/PersistenceCoreTests/testSavePromptEvalRun_andLoadRecent -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesPromptEvalRuns test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-116-green2 -only-testing:MingSiTests/PromptEvalFixtureTests/testPromptEvalRunner_recordsSuiteMetadataAndCaseResults -only-testing:MingSiTests/PersistenceCoreTests/testSavePromptEvalRun_andLoadRecent -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesPromptEvalRuns test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-116-prompt-eval-suite-rerun -only-testing:MingSiTests/PromptEvalFixtureTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-116-persistence-suite-rerun -only-testing:MingSiTests/PersistenceCoreTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-116-appstore-eval-rerun -only-testing:MingSiTests/AppStoreStateMachineTests/testRunPromptEvalSuite_persistsRunsAndUpdatesReleaseGate -only-testing:MingSiTests/AppStoreStateMachineTests/testPromptEvalReleaseGateMessage_includesRollbackReadinessCounts -only-testing:MingSiTests/AppStoreStateMachineTests/testApplyPromptRollback_usesTargetTemplateAndRefreshesReleaseGate -only-testing:MingSiTests/AppStoreStateMachineTests/testApplyPromptRollback_persistsSelectedVersionAcrossStoreReload -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_restoresHistoricalPromptAssetSelectionWithLocalProvider test
rg -n "jsonPayload|JSONPayload|legacyJSONPayload" Sources Tests
git diff --check
```

Result:

- Initial RED failed as intended because `PromptEvalCaseResult` lacked the new artifact fields and Data Export did not expose structured `case_results`.
- Focused GREEN passed with 3 tests and 0 failures after the runner populated case artifacts and Data Export decoded `case_results_json`.
- `PromptEvalFixtureTests` passed with 10 tests and 0 failures.
- `PersistenceCoreTests` passed with 89 tests and 0 failures, including save/load and Data Export coverage for prompt eval runs.
- Focused AppStore prompt-eval/rollback coverage passed with 5 tests and 0 failures.
- Parallel broader suite attempts initially produced simulator test-host early exits before bootstrapping; serial reruns of the same suites passed, so no assertion failure was reproduced.
- Source/test search for removed legacy payload names returned no matches under `Sources` or `Tests`.
- `git diff --check` passed with no output.

Residual risk:

- This improves local fixed-suite case artifacts and export readability; it does not add scheduled eval execution, remote prompt registry distribution, or live model evals.
- Historical eval rows without the new JSON fields still decode through default empty strings.
- A real BYOK GLM network call remains unconfirmed until the user provides a key and approves the external call window.

## 2026-06-09: Subtask 115 Live GLM Acceptance Harness

Scope:

- Add a safe-by-default live BYOK GLM acceptance harness around the real `DirectGLMClient`.
- Require explicit `MINGSI_LIVE_GLM_ACCEPTANCE=1` opt-in before any live request can run.
- Support both host and simulator-prefixed environment keys for the live flag, API key, base URL, and model.
- Fall back to `KeychainAPIKeyStore().loadAPIKey()` when an environment API key is absent, without printing or exposing secrets.
- Use a structured `PromptContextPayload` probe request with prompt version `live-acceptance.v1`.

Changed areas:

- `Tests/Services/LiveGLMAcceptanceTests.swift`
- `MingSi.xcodeproj/project.pbxproj`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-115-suite2-green -only-testing:MingSiTests/LiveGLMAcceptanceTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-115-directglm-green -only-testing:MingSiTests/DirectGLMClientTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-115-final-live -only-testing:MingSiTests/LiveGLMAcceptanceTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-115-final-directglm -only-testing:MingSiTests/DirectGLMClientTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-115-final-full -only-testing:MingSiTests test
env | cut -d= -f1 | sort | rg -n "GLM|MINGSI|ZHIPU|ZAI|API|KEY"
security find-generic-password -s com.codex.mingsi.glm -a glm_api_key
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-115-final-injection -only-testing:MingSiTests/LiveGLMAcceptanceTests/testLiveGLMCompleteReturnsJSONWhenExplicitlyEnabled build-for-testing
cp /tmp/mingsi-dd-115-final-injection/Build/Products/MingSi_MingSi_iphonesimulator26.5-arm64.xctestrun /tmp/mingsi-dd-115-final-injection/Build/Products/MingSi_MingSi_live-flag.xctestrun
/usr/libexec/PlistBuddy -c 'Add :TestConfigurations:0:TestTargets:0:EnvironmentVariables:MINGSI_LIVE_GLM_ACCEPTANCE string 1' /tmp/mingsi-dd-115-final-injection/Build/Products/MingSi_MingSi_live-flag.xctestrun
/usr/libexec/PlistBuddy -c 'Add :TestConfigurations:0:TestTargets:0:TestingEnvironmentVariables:MINGSI_LIVE_GLM_ACCEPTANCE string 1' /tmp/mingsi-dd-115-final-injection/Build/Products/MingSi_MingSi_live-flag.xctestrun
xcodebuild -xctestrun /tmp/mingsi-dd-115-final-injection/Build/Products/MingSi_MingSi_live-flag.xctestrun -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-115-final-injection -only-testing:MingSiTests/LiveGLMAcceptanceTests/testLiveGLMCompleteReturnsJSONWhenExplicitlyEnabled test-without-building
rg -n "jsonPayload|JSONPayload|legacyJSONPayload" Sources Tests
git diff --check
```

Result:

- Initial RED failed as intended because `LiveGLMAcceptanceHarness` did not exist.
- Keychain fallback RED failed as intended before the harness accepted an injectable `keychainAPIKey` loader.
- Simulator-prefixed RED failed until `SIMCTL_CHILD_MINGSI_LIVE_GLM_*` key lookup was added.
- Earlier focused GREEN `LiveGLMAcceptanceTests` passed with 4 tests executed, 1 skipped, and 0 failures.
- Earlier focused GREEN `DirectGLMClientTests` passed with 9 tests and 0 failures.
- Default final `LiveGLMAcceptanceTests` passed with 4 tests executed, 1 skipped, and 0 failures; the live probe skipped at the opt-in flag gate.
- `DirectGLMClientTests` passed with 9 tests and 0 failures, preserving the structured context payload and response-format compatibility behavior.
- Full `MingSiTests` passed with 494 tests executed, 1 skipped, and 0 failures.
- Host environment scan returned no matching GLM/MingSi/Zhipu/ZAI/API key names.
- Keychain lookup for `com.codex.mingsi.glm` / `glm_api_key` returned exit code 44 (`errSecItemNotFound`).
- `build-for-testing` produced the `.xctestrun`; injecting `MINGSI_LIVE_GLM_ACCEPTANCE=1` into both environment dictionaries made `test-without-building` enter the live test path and skip at the API-key gate, proving the repeatable opt-in harness path without a secret.

Residual risk:

- A real BYOK GLM network call is still not confirmed because no API key is present in the shell environment or the expected Keychain item.
- Ordinary `xcodebuild test` did not reliably pass host live-test environment variables into the iOS unit-test process; the documented repeatable path is `.xctestrun` injection or an actual key available to `KeychainAPIKeyStore`.
- The live harness is intentionally skipped by default and should stay that way in CI unless an explicit external-network acceptance window and user-provided key are available.

## 2026-06-09: Subtask 114 LLMRequest Structured-Only Context Payload

Scope:

- Finish the Prompt / Context compatibility-removal slice by deleting the stored legacy `[String: String]` payload from `LLMRequest`.
- Keep prompt-facing compatibility keys available only as a derived `PromptContextPayload.legacyKeyValues` export for tests and old template assertions.
- Update DirectGLM, PromptRun, Project, Today, Growth, and AppStore tests so they observe typed context payloads instead of inspecting a stored request dictionary.
- Do not attempt live BYOK GLM confirmation without a real user key and approved network-call window.

Changed areas:

- `Sources/Services/CoreProtocols.swift`
- `Tests/Services/DirectGLMClientTests.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `Tests/Services/ProjectAIServiceContextTests.swift`
- `Tests/Services/TodayAIServiceContextTests.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-114-red -only-testing:MingSiTests/PersistenceCoreTests/testLLMRequest_hasNoStoredLegacyJSONPayloadField test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-114-green -only-testing:MingSiTests/PersistenceCoreTests/testLLMRequest_hasNoStoredLegacyPayloadField test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-114-focused -only-testing:MingSiTests/PersistenceCoreTests -only-testing:MingSiTests/DirectGLMClientTests -only-testing:MingSiTests/ProjectAIServiceContextTests -only-testing:MingSiTests/TodayAIServiceContextTests -only-testing:MingSiTests/AppStoreStateMachineTests/testGLMConnectionRefreshesPromptRunAuditAfterCompletion test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-114-full -only-testing:MingSiTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-114-ui -only-testing:MingSiUITests test
git diff --check
rg -n "jsonPayload|JSONPayload|legacyJSONPayload" Sources Tests
```

Result:

- RED failed as intended because `Mirror(reflecting: LLMRequest)` still exposed the stored legacy payload field.
- Focused GREEN passed with 1 test and 0 failures after `LLMRequest` stopped storing or accepting the legacy dictionary.
- Focused persistence/service/context coverage passed with 130 tests and 0 failures.
- Full `MingSiTests` passed with 490 tests and 0 failures.
- Full `MingSiUITests` passed with 4 tests and 0 failures, with the recurring Xcode debugger/accessibility warnings but no failures.
- `git diff --check` passed.
- Source/test search for the old payload API name returned no matches under `Sources` or `Tests`.

Residual risk:

- Prompt-facing compatibility key generation still exists as `PromptContextPayload.legacyKeyValues`; this is now a derived export rather than a stored request payload.
- Historical docs and old verification entries still mention the removed field because they preserve prior slice evidence.
- Live BYOK GLM confirmation remains externally blocked until a real user-provided key and approved network-call window are available.

## 2026-06-09: Subtask 113 PromptRun Structured-Only Session Audit

Scope:

- Continue Prompt / Context compatibility shrinkage after Subtask 112 removed DirectGLM's model-facing legacy payload fallback.
- Stop `PromptTracingLLMClient` from using legacy `LLMRequest.jsonPayload["sessionMode"]` as a PromptRun audit fallback.
- Keep PromptRun session-mode audit tied to structured `PromptContextPayload.userChoice.sessionMode`; requests without structured context now record `unknown`.
- Preserve `LLMRequest.jsonPayload` itself for remaining compatibility tests while removing the final production read outside the `LLMRequest` initializer.
- Do not attempt live BYOK GLM confirmation without a real user key and approved network-call window.

Changed areas:

- `Sources/Services/CoreProtocols.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-113-red -only-testing:MingSiTests/PersistenceCoreTests/testPromptTracingLLMClient_withoutStructuredContextDoesNotAuditLegacySessionMode test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-113-green -only-testing:MingSiTests/PersistenceCoreTests/testPromptTracingLLMClient_withoutStructuredContextDoesNotAuditLegacySessionMode test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-113-focused -only-testing:MingSiTests/PersistenceCoreTests -only-testing:MingSiTests/DirectGLMClientTests -only-testing:MingSiTests/ProjectAIServiceContextTests -only-testing:MingSiTests/TodayAIServiceContextTests -only-testing:MingSiTests/AppStoreStateMachineTests/testGLMConnectionRefreshesPromptRunAuditAfterCompletion test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-113-full -only-testing:MingSiTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-113-ui -only-testing:MingSiUITests test
git diff --check
rg -n "request\\.jsonPayload|jsonPayload\\[\\\"sessionMode\\\"\\]" Sources/App Sources/Services Tests/Services/PersistenceCoreTests.swift Tests/Services/DirectGLMClientTests.swift Tests/App/AppStoreStateMachineTests.swift | head -n 120
```

Result:

- RED failed as intended because a no-structured-context request still recorded PromptRun `sessionMode=deep` from `jsonPayload["sessionMode"]`; the new expected audit value is `unknown`.
- Focused GREEN passed with 1 test and 0 failures after `PromptTracingLLMClient.sessionMode(from:)` now only reads `request.contextPayload?.userChoice.sessionMode`, falling back directly to `unknown`.
- Focused persistence/service/context coverage passed with 129 tests and 0 failures.
- Full `MingSiTests` passed with 489 tests and 0 failures.
- Full `MingSiUITests` passed with 4 tests and 0 failures, with the recurring Xcode debugger/accessibility warnings but no failures.

Residual risk:

- `LLMRequest.jsonPayload` still exists as a compatibility field and tests still construct/inspect it, but production App/Services no longer read it outside `LLMRequest`'s own structured-context compatibility export.
- Full `LLMRequest.jsonPayload` removal remains a later, wider migration slice because existing compatibility tests need to move to typed `PromptContextPayload` assertions.
- Live BYOK GLM confirmation remains externally blocked until a real user-provided key and approved network-call window are available.

## 2026-06-09: Subtask 112 DirectGLM Structured-Only Model Payload

Scope:

- Continue Prompt / Context compatibility shrinkage after Subtask 111's typed Settings GLM connection request.
- Stop DirectGLM from rendering legacy flattened `LLMRequest.jsonPayload` lines into the model-facing user message when `PromptContextPayload` is absent.
- Preserve structured `PromptContextPayload.renderedJSON()` as the model-facing payload source when present.
- Keep `LLMRequest.jsonPayload` available for remaining audit/compatibility consumers outside DirectGLM model input.
- Do not attempt live BYOK GLM confirmation without a real user key and approved network-call window.

Changed areas:

- `Sources/Services/DirectGLMClient.swift`
- `Tests/Services/DirectGLMClientTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-112-red -only-testing:MingSiTests/DirectGLMClientTests/testComplete_withoutStructuredContextDoesNotRenderLegacyPayloadLines test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-112-green -only-testing:MingSiTests/DirectGLMClientTests/testComplete_withoutStructuredContextDoesNotRenderLegacyPayloadLines test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-112-services -only-testing:MingSiTests/DirectGLMClientTests -only-testing:MingSiTests/ProjectAIServiceContextTests -only-testing:MingSiTests/TodayAIServiceContextTests -only-testing:MingSiTests/PersistenceCoreTests -only-testing:MingSiTests/AppStoreStateMachineTests/testGLMConnectionRefreshesPromptRunAuditAfterCompletion test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-112-full -only-testing:MingSiTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-112-ui -only-testing:MingSiUITests test
git diff --check
rg -n "legacyPayloadLines|request\\.jsonPayload" Sources/Services/DirectGLMClient.swift Sources/Services/CoreProtocols.swift
rg -n "jsonPayload:|request\\.jsonPayload|legacyPayloadLines" Sources/App Sources/Services Tests/Services/DirectGLMClientTests.swift Tests/Services/PersistenceCoreTests.swift Tests/App/AppStoreStateMachineTests.swift | head -n 160
```

Result:

- RED failed as intended because DirectGLM still rendered a no-structured-context request's legacy `purpose: test` payload line into the model-facing user message.
- Focused GREEN passed with 1 test and 0 failures after DirectGLM now renders `Payload:\n{}` when `PromptContextPayload` is absent.
- Focused service/persistence coverage (`DirectGLMClientTests`, `ProjectAIServiceContextTests`, `TodayAIServiceContextTests`, `PersistenceCoreTests`, and the Settings GLM connection PromptRun audit test) passed with 128 tests and 0 failures.
- Full `MingSiTests` passed with 488 tests and 0 failures.
- Full `MingSiUITests` passed with 4 tests and 0 failures, including the rendered Today walkthrough through `session_complete`.
- `git diff --check`: exit 0, no output before documentation update.
- Search confirms `legacyPayloadLines` is gone and `DirectGLMClient.swift` no longer reads `request.jsonPayload`; at the time of this slice the remaining production read was `PromptTracingLLMClient`'s session-mode fallback in `CoreProtocols.swift`, which Subtask 113 superseded.
- Production App/Services search still shows no `jsonPayload:` construction outside `LLMRequest` itself; remaining call-site construction is confined to compatibility tests.

Residual risk:

- Superseded by Subtask 113: `PromptTracingLLMClient` no longer retains a legacy session-mode fallback, though `LLMRequest.jsonPayload` still exists as a compatibility field.
- Compatibility tests still construct and inspect `jsonPayload`; full field removal remains a later, wider migration slice.
- DirectGLM now requires structured context for model-facing request details; old/manual requests without `PromptContextPayload` intentionally send `{}` rather than flattened legacy lines.
- Live BYOK GLM confirmation remains externally blocked until a real user-provided key and approved network-call window are available.

## 2026-06-09: Subtask 111 Settings GLM Connection Structured Context

Scope:

- Continue Prompt / Context compatibility shrinkage after Subtask 110's `extra` export guard.
- Move Settings GLM connection-test request construction from a hand-written `[String: String]` payload to typed `PromptContextPayload`.
- Preserve missing-key audit behavior, PromptRun refresh behavior, and the no-live-network safety boundary.
- Keep no-structured-context `LLMRequest.jsonPayload` fallback behavior for DirectGLM tests and old/manual request construction.
- Do not attempt live BYOK GLM confirmation without a real user key and approved network-call window.

Changed areas:

- `Sources/App/AppStore.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-111-red -only-testing:MingSiTests/AppStoreStateMachineTests/testGLMConnectionRefreshesPromptRunAuditAfterCompletion test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-111-green -only-testing:MingSiTests/AppStoreStateMachineTests/testGLMConnectionRefreshesPromptRunAuditAfterCompletion test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-111-appstore -only-testing:MingSiTests/AppStoreStateMachineTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-111-services -only-testing:MingSiTests/DirectGLMClientTests -only-testing:MingSiTests/ProjectAIServiceContextTests -only-testing:MingSiTests/TodayAIServiceContextTests -only-testing:MingSiTests/PersistenceCoreTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-111-full -only-testing:MingSiTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-111-ui -only-testing:MingSiUITests test
git diff --check
rg -n "jsonPayload:" Sources/App Sources/Services Tests | head -n 120
rg -n "jsonPayload: \\[\\\"purpose\\\"|purpose.*test|contextPayload: contextPayload" Sources/App Sources/Services Tests/App Tests/Services | head -n 120
```

Result:

- RED failed as intended because the Settings connection-test PromptRun recorded `sessionMode=unknown` while the request still supplied only `jsonPayload: ["purpose": "test"]`.
- Focused GREEN passed with 1 test and 0 failures after `testGLMConnection()` now constructs a typed `PromptContextPayload` with standard session mode and raw connection-test input.
- `AppStoreStateMachineTests` passed with 222 tests and 0 failures.
- Focused service/persistence suites (`DirectGLMClientTests`, `ProjectAIServiceContextTests`, `TodayAIServiceContextTests`, `PersistenceCoreTests`) passed with 126 tests and 0 failures.
- Full `MingSiTests` passed with 487 tests and 0 failures.
- Full `MingSiUITests` passed with 4 tests and 0 failures, with the recurring Xcode `DebuggerVersionStore` / duplicate WebKit accessibility runtime warnings but no test failures.
- Production App/Services search now shows no `jsonPayload:` construction outside `LLMRequest` itself; remaining `jsonPayload` call-site construction is confined to compatibility tests.

Residual risk:

- `LLMRequest.jsonPayload` still exists as a compatibility export and no-structured-context fallback for DirectGLM/tests; removing it entirely remains a later compatibility-removal slice.
- Superseded by Subtask 112: DirectGLM no longer renders legacy payload lines for requests without structured context and now sends `{}` for model-facing payload details in that case.
- Live BYOK GLM confirmation remains externally blocked until a real user-provided key and approved network-call window are available.

## 2026-06-09: Subtask 110 PromptContextPayload Extra Legacy Export Guard

Scope:

- Continue Prompt / Context compatibility shrinkage after Subtask 109's centralized `LLMRequest` structured-context export.
- Prevent arbitrary `PromptContextPayload.extra` keys from leaking into the legacy compatibility dictionary.
- Keep typed `PromptContextPayload` sections as the only source for exported legacy keys while preserving `extra` storage for compatibility/debug context that is not model-facing.
- Keep old/no-structured-context `LLMRequest.jsonPayload` fallback behavior unchanged.
- Do not attempt live BYOK GLM confirmation without a real user key and approved network-call window.

Changed areas:

- `Sources/Services/CoreProtocols.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-110-red -only-testing:MingSiTests/PersistenceCoreTests/testPromptContextPayloadLegacyExportIgnoresUnstructuredExtraKeys test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-110-green -only-testing:MingSiTests/PersistenceCoreTests/testPromptContextPayloadLegacyExportIgnoresUnstructuredExtraKeys test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-110-persistence -only-testing:MingSiTests/PersistenceCoreTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-110-services -only-testing:MingSiTests/DirectGLMClientTests -only-testing:MingSiTests/ProjectAIServiceContextTests -only-testing:MingSiTests/TodayAIServiceContextTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-110-full -only-testing:MingSiTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-110-ui -only-testing:MingSiUITests test
git diff --check
```

Result:

- RED failed as intended because `PromptContextPayload.legacyKeyValues` started from `extra`, allowing stale/unstructured keys such as `purpose` to leak into DirectGLM compatibility export.
- Focused GREEN passed with 1 test and 0 failures after the export now starts from an empty dictionary and only adds typed structured-context fields.
- The regression proves typed values win for `rawText`, `sessionMode`, and `streamProtocol`, while an unrelated stale `extra["purpose"]` key is absent from the export.
- `PersistenceCoreTests` passed with 87 tests and 0 failures.
- Focused service suites (`DirectGLMClientTests`, `ProjectAIServiceContextTests`, `TodayAIServiceContextTests`) passed with 39 tests and 0 failures.
- Full `MingSiTests` passed with 487 tests and 0 failures.
- Full `MingSiUITests` passed with 4 tests and 0 failures.
- `git diff --check`: exit 0, no output before documentation update.

Residual risk:

- `PromptContextPayload.extra` still exists as a non-exported compatibility/debug bucket; it should not be used as a model-facing payload source in future service code.
- `LLMRequest.jsonPayload` still exists as a compatibility export and no-structured-context fallback for DirectGLM/tests; removing it entirely remains a later compatibility-removal slice.
- Live BYOK GLM confirmation remains externally blocked until a real user-provided key and approved network-call window are available.

## 2026-06-09: Subtask 109 Structured Context Without Caller Legacy Payload

Scope:

- Continue Prompt / Context compatibility shrinkage after Subtask 108's `LLMRequest` structured legacy export guard.
- Allow structured-context callers to construct `LLMRequest` without passing a caller-owned `[String: String]` compatibility payload.
- Remove explicit `jsonPayload: contextPayload.legacyKeyValues` construction from production Today, Growth, and Project AI service request call sites.
- Keep `jsonPayload` as a derived compatibility export for DirectGLM and older no-structured-context/manual request paths.
- Do not attempt live BYOK GLM confirmation without a real user key and approved network-call window.

Changed areas:

- `Sources/Services/CoreProtocols.swift`
- `Sources/Services/TodayAIService.swift`
- `Sources/Services/GrowthAIService.swift`
- `Sources/Services/ProjectAIService.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-109-red -only-testing:MingSiTests/PersistenceCoreTests/testLLMRequest_allowsStructuredContextWithoutCallerLegacyPayload test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-109-green -only-testing:MingSiTests/PersistenceCoreTests/testLLMRequest_allowsStructuredContextWithoutCallerLegacyPayload test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-109-services -only-testing:MingSiTests/DirectGLMClientTests -only-testing:MingSiTests/ProjectAIServiceContextTests -only-testing:MingSiTests/TodayAIServiceContextTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-109-persistence -only-testing:MingSiTests/PersistenceCoreTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-109-full -only-testing:MingSiTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-109-ui -only-testing:MingSiUITests test
git diff --check
rg -n "jsonPayload: contextPayload\\.legacyKeyValues|let mergedPayload = contextPayload\\.legacyKeyValues" Sources/Services
```

Result:

- RED failed as intended because `LLMRequest` still required a `jsonPayload` argument before the initializer default existed.
- Focused GREEN passed with 1 test and 0 failures after `LLMRequest.init` defaulted `jsonPayload` to `[:]` and continued deriving `jsonPayload` from `contextPayload.legacyKeyValues` when structured context is present.
- Production structured-context request call sites in `TodayAIService`, `GrowthAIService`, and `ProjectAIService` now omit explicit legacy dictionaries.
- A service-layer search found no remaining `jsonPayload: contextPayload.legacyKeyValues` or `let mergedPayload = contextPayload.legacyKeyValues` matches under `Sources/Services`.
- Focused service suites (`DirectGLMClientTests`, `ProjectAIServiceContextTests`, `TodayAIServiceContextTests`) passed with 39 tests and 0 failures.
- `PersistenceCoreTests` passed with 86 tests and 0 failures.
- Full `MingSiTests` passed with 486 tests and 0 failures.
- Full `MingSiUITests` passed with 4 tests and 0 failures, including accessibility-identifier-driven Today input and rendered-loop completion coverage.
- `git diff --check`: exit 0, no output.
- Earlier verification attempts for this slice hit environment failures: parallel simulator sessions caused an early bootstrap exit, one temporary DerivedData had a malformed copied GRDB package framework signature, and disk pressure reached "No space left on device". Temporary `/private/tmp/mingsi-dd-*` directories were removed, disk space recovered, and all final verification above was rerun sequentially with fresh DerivedData.

Residual risk:

- `LLMRequest.jsonPayload` still exists as a compatibility export and fallback for requests without structured context; removing it entirely remains a later compatibility-removal slice.
- DirectGLM compatibility and tests still intentionally read the derived legacy-key export even though production service callers now rely on structured context as the source of truth.
- Live BYOK GLM confirmation remains externally blocked until a real user-provided key and approved network-call window are available.

## 2026-06-09: Subtask 108 LLMRequest Structured Legacy Export Guard

Scope:

- Continue Prompt / Context compatibility shrinkage after Subtask 107's structured PromptRun audit source.
- Prevent `LLMRequest.jsonPayload` from diverging from structured `PromptContextPayload` when both are supplied.
- Keep `jsonPayload` available as a legacy/no-structured-context compatibility field for DirectGLM fallback and manual request construction.
- Do not attempt live BYOK GLM confirmation without a real user key and approved network-call window.

Changed areas:

- `Sources/Services/CoreProtocols.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-108-red -only-testing:MingSiTests/PersistenceCoreTests/testLLMRequest_derivesLegacyPayloadFromStructuredContextWhenAvailable test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-108-green -only-testing:MingSiTests/PersistenceCoreTests/testLLMRequest_derivesLegacyPayloadFromStructuredContextWhenAvailable test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-108-persistence -only-testing:MingSiTests/PersistenceCoreTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-108-services -only-testing:MingSiTests/DirectGLMClientTests -only-testing:MingSiTests/ProjectAIServiceContextTests -only-testing:MingSiTests/TodayAIServiceContextTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-108-full -only-testing:MingSiTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-108-ui -only-testing:MingSiUITests test
git diff --check
```

Result:

- RED failed as intended because a request with stale `jsonPayload` still exposed `sessionMode=standard`, omitted structured `rawText`, and retained a stale `purpose` key even though structured context carried `sessionMode=deep`.
- `LLMRequest` now has an explicit initializer that derives `jsonPayload` from `contextPayload.legacyKeyValues` whenever structured context is present, otherwise preserving the caller-provided legacy dictionary.
- Focused GREEN passed with 1 test and 0 failures.
- `PersistenceCoreTests` passed with 85 tests and 0 failures.
- Focused service suites (`DirectGLMClientTests`, `ProjectAIServiceContextTests`, `TodayAIServiceContextTests`) passed with 39 tests and 0 failures.
- Full `MingSiTests` passed with 485 tests and 0 failures.
- Full `MingSiUITests` passed with 4 tests and 0 failures.
- `git diff --check`: exit 0, no output.

Residual risk:

- `LLMRequest.jsonPayload` still exists as a compatibility export and fallback for requests without structured context; removing it entirely would require updating DirectGLM fallback expectations and old/manual request construction paths.
- Service-layer requests can now safely provide stale or empty legacy dictionaries when structured context exists, but tests still intentionally assert legacy-key compatibility through the request field.
- Live BYOK GLM confirmation remains externally blocked until a real user-provided key and approved network-call window are available.

## 2026-06-09: Subtask 107 PromptRun Structured Session Audit Source

Scope:

- Continue Prompt / Context compatibility shrinkage after Subtask 106's Lens Asset Settings surface.
- Move PromptRun tracing's `sessionMode` audit source from legacy `LLMRequest.jsonPayload` to structured `PromptContextPayload.userChoice.sessionMode`.
- Keep `jsonPayload` as a fallback for old/manual requests that still lack structured context.
- Do not attempt live BYOK GLM confirmation without a real user key and approved network-call window.

Changed areas:

- `Sources/Services/CoreProtocols.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-107-red -only-testing:MingSiTests/PersistenceCoreTests/testPromptTracingLLMClient_prefersStructuredContextSessionModeOverLegacyPayload test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-107-green -only-testing:MingSiTests/PersistenceCoreTests/testPromptTracingLLMClient_prefersStructuredContextSessionModeOverLegacyPayload test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-107-persistence -only-testing:MingSiTests/PersistenceCoreTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-107-full -only-testing:MingSiTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-107-ui -only-testing:MingSiUITests test
```

Result:

- RED failed as intended because `PromptTracingLLMClient` recorded `sessionMode` from `jsonPayload`, producing `standard` when structured context carried `deep`.
- `PromptTracingLLMClient.sessionMode(from:)` now prefers `request.contextPayload?.userChoice.sessionMode`, then falls back to `request.jsonPayload["sessionMode"]`, then `unknown`.
- Focused GREEN passed with 1 test and 0 failures.
- `PersistenceCoreTests` passed with 84 tests and 0 failures.
- Full `MingSiTests` passed with 484 tests and 0 failures.
- Full `MingSiUITests` passed with 4 tests and 0 failures.

Residual risk:

- `LLMRequest.jsonPayload` still exists for DirectGLM fallback compatibility and service-layer legacy export, and many tests still assert that compatibility surface.
- The next payload shrinkage should target consumers only when they can require `PromptContextPayload` directly; DirectGLM's no-structured-context fallback should stay until all manual/legacy request construction is removed.
- Live BYOK GLM confirmation remains externally blocked until a real user-provided key and approved network-call window are available.

## 2026-06-09: Subtask 106 Local Lens Pack Management Surface

Scope:

- Continue Lens Asset work after Subtask 105's runtime enabled-pack catalog wiring.
- Add a local product-facing Settings surface for persisted `LensAssetPack` inventory, enable/disable, and JSON import.
- Keep the slice local-only: no remote marketplace sync, signature verification, or Today state-machine branch.
- Add Settings automation identifiers for the new controls so UI automation can drive the surface by stable ids.

Changed areas:

- `Sources/App/AppStore.swift`
- `Sources/Features/FeatureTabs.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-106-red2 -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadLensAssetPacks_listsAllPacksWithEnabledRuntimeCount -only-testing:MingSiTests/AppStoreStateMachineTests/testSetLensAssetPackEnabled_updatesRuntimeChoicesAndClearsDisabledSelection -only-testing:MingSiTests/AppStoreStateMachineTests/testImportLensAssetPackFromJSON_persistsAndEnablesPack test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-106-green -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadLensAssetPacks_listsAllPacksWithEnabledRuntimeCount -only-testing:MingSiTests/AppStoreStateMachineTests/testSetLensAssetPackEnabled_updatesRuntimeChoicesAndClearsDisabledSelection -only-testing:MingSiTests/AppStoreStateMachineTests/testImportLensAssetPackFromJSON_persistsAndEnablesPack test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-106-app -only-testing:MingSiTests/AppStoreStateMachineTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-106-settings-red -only-testing:MingSiTests/AppStoreStateMachineTests/testSettingsAutomationIdentifiers_areStableForLensPackManager test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-106-settings-green -only-testing:MingSiTests/AppStoreStateMachineTests/testSettingsAutomationIdentifiers_areStableForLensPackManager test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-106-app2 -only-testing:MingSiTests/AppStoreStateMachineTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-106-full -only-testing:MingSiTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-106-ui -only-testing:MingSiUITests test
git diff --check
```

Result:

- Initial RED failed as intended because `AppStore` did not expose `loadLensAssetPacks`, `lensAssetPacks`, `lensAssetPackMessage`, `setLensAssetPack(_:isEnabled:)`, or `importLensAssetPack(from:)`.
- Added AppStore-managed local pack inventory with deterministic enabled-first sorting, runtime lens reload after pack changes, JSON import validation, and user-facing pack management status copy.
- Disabling a pack now removes its runtime lens choices and clears only the selected runtime lens id/questions when that disabled pack owned the current selection.
- Settings now has a compact `透镜包` card that loads persisted packs, shows source/version/item counts, toggles pack enabled state, and imports local pack JSON from text or paste.
- Added `SettingsAutomationID` and attached stable accessibility identifiers to the pack card, refresh action, JSON import field, paste action, import action, and per-pack toggle action.
- Settings identifier RED failed as intended because `SettingsAutomationID` did not exist.
- Focused lens-pack GREEN passed with 3 tests and 0 failures.
- First `AppStoreStateMachineTests` sweep passed with 221 tests and 0 failures before the automation-id guard was added.
- Settings identifier GREEN passed with 1 test and 0 failures.
- Final `AppStoreStateMachineTests` passed with 222 tests and 0 failures.
- Full `MingSiTests` passed with 483 tests and 0 failures.
- Full `MingSiUITests` passed with 4 tests and 0 failures.
- `git diff --check`: exit 0, no output.

Residual risk:

- This is a local JSON import and enable/disable management surface only; remote marketplace sync, remote registry discovery, trust/signature verification, and signed-pack install UX remain future Lens Asset work.
- The Settings card does not yet include file-picker import or pack deletion/version conflict resolution; those should be added only when a real pack distribution workflow exists.
- Live BYOK GLM confirmation remains externally blocked until a real user-provided key and approved network-call window are available.

## 2026-06-09: Subtask 105 Runtime Lens Pack Catalog Wiring

Scope:

- Continue Lens Asset work after Subtask 104's local pack persistence/export registry.
- Load persisted enabled `LensAssetPack` records into the runtime AppStore lens catalog.
- Allow imported/marketplace-style runtime lenses to be selected through the existing custom-lens state channel, without adding Today state-machine branches.
- Carry selected runtime lens pack metadata into structured Today prompt context.

Changed areas:

- `Sources/App/AppStore.swift`
- `Sources/Services/TodayAIService.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `Tests/Services/TodayAIServiceContextTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-105-red -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_loadsEnabledLensAssetPacksIntoRuntimeChoices -only-testing:MingSiTests/AppStoreStateMachineTests/testRuntimeLensAssetSelectionUsesCustomLensStateWithoutChangingBuiltinLens -only-testing:MingSiTests/TodayAIServiceContextTests/testStructuredContext_exposesRuntimeLensAssetMetadata test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-105-green -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_loadsEnabledLensAssetPacksIntoRuntimeChoices -only-testing:MingSiTests/AppStoreStateMachineTests/testRuntimeLensAssetSelectionUsesCustomLensStateWithoutChangingBuiltinLens -only-testing:MingSiTests/TodayAIServiceContextTests/testStructuredContext_exposesRuntimeLensAssetMetadata test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-105-app-today -only-testing:MingSiTests/AppStoreStateMachineTests -only-testing:MingSiTests/TodayAIServiceContextTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-105-full -only-testing:MingSiTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-105-ui -only-testing:MingSiUITests test
git diff --check
```

Result:

- RED failed as intended because `TodayAIContext` did not yet accept `selectedLensItem`, and `AppStore` had no runtime lens pack catalog wiring.
- `AppStore` now injects `LensAssetPackRepository`, loads enabled packs during `loadPersistedState()`, exposes them as `runtimeLensItems`, and includes them in `availableLensChoices`.
- Runtime pack lenses use the existing `selectedCustomLensId` path for selection, preserving the built-in `ThinkingLens` enum and Today main-state ownership.
- Local fallback questions and AI request contexts now resolve runtime lenses from the same selected lens item boundary.
- `TodayAIContext` can carry the selected `LensCatalogItem`, and structured `PromptContextPayload.userChoice.lensCatalog` preserves runtime pack id/version/source metadata.
- Focused GREEN passed with 3 tests and 0 failures.
- `AppStoreStateMachineTests` plus `TodayAIServiceContextTests` passed with 241 tests and 0 failures.
- Full `MingSiTests` passed with 479 tests and 0 failures.
- Full `MingSiUITests` passed with 4 tests and 0 failures.
- `git diff --check`: exit 0, no output.

Residual risk:

- Enabled local lens packs are now runtime selectable, but this does not add a product-facing import UI, marketplace sync, signature verification, or remote registry.
- Runtime pack selection intentionally reuses the custom-lens id channel; future product UI should make imported/marketplace provenance clearer without introducing Today state-machine branches.
- Live BYOK GLM confirmation remains externally blocked until a real user-provided key and approved network-call window are available.

## 2026-06-09: Subtask 104 Lens Asset Pack Persistence / Export Registry

Scope:

- Continue Lens Asset work after Subtask 103's pack/source provenance boundary.
- Persist local `LensAssetPack` records so imported/marketplace-style packs can be saved, loaded, enabled/disabled, and exported.
- Keep this as a local persistence/export registry only, without adding marketplace network behavior, Settings UI, or Today state-machine branches.

Changed areas:

- `Sources/Services/PersistenceCore.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-104-red -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_saveAndLoadEnabledPacks -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_disabledPacksPersistButDoNotLoadAsEnabled -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesLensAssetPacks -only-testing:MingSiTests/PersistenceCoreTests/testMigration_v18_addsLensAssetPacksTableAndIndexes test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-104-green -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_saveAndLoadEnabledPacks -only-testing:MingSiTests/PersistenceCoreTests/testLensAssetPack_disabledPacksPersistButDoNotLoadAsEnabled -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesLensAssetPacks -only-testing:MingSiTests/PersistenceCoreTests/testMigration_v18_addsLensAssetPacksTableAndIndexes test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-104-persistence -only-testing:MingSiTests/PersistenceCoreTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-104-full -only-testing:MingSiTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-104-ui -only-testing:MingSiUITests test
git diff --check
```

Result:

- RED failed as intended because `SQLiteLensAssetPackRepository` did not exist.
- Added `LensAssetPackRepository` plus `SQLiteLensAssetPackRepository` for saving packs, loading all non-deleted packs, and loading only enabled packs.
- Added SQLite migration `v18_lens_asset_packs` with `lens_asset_packs`, source-kind/enabled/updated-at indexes, and `items_json` storage for the pack's lens catalog items.
- Added `LensAssetPackRow` mapping that persists source kind, enabled state, timestamps, and JSON-encoded lens items while preserving existing `created_at` on upsert.
- Added `lens_asset_packs` to `DataExportSectionName`, so local lens packs are included in Data Export counts and sections.
- Focused GREEN passed with 4 tests and 0 failures.
- `PersistenceCoreTests` passed with 83 tests and 0 failures.
- Full `MingSiTests` passed with 476 tests and 0 failures.
- Full `MingSiUITests` passed with 4 tests and 0 failures.
- `git diff --check`: exit 0, no output.

Residual risk:

- This persists and exports local lens packs, but it does not add a product-facing import UI, marketplace sync, signature verification, or remote registry.
- Today still consumes the existing in-memory lens library boundary; wiring persisted packs into launch/runtime catalog selection remains a future product slice.
- Live BYOK GLM confirmation remains externally blocked until a real user-provided key and approved network-call window are available.

## 2026-06-09: Subtask 103 Lens Pack Source Metadata / Marketplace Boundary

Scope:

- Continue Lens Asset work after Subtasks 081 and 082.
- Add a versioned pack/source boundary for built-in, local custom, imported, and marketplace lens assets.
- Preserve stable `ThinkingLens` identities and the Today state machine.
- Carry lens pack/source metadata into structured prompt context and legacy DirectGLM compatibility payloads.

Changed areas:

- `Sources/Domain/Models.swift`
- `Sources/Services/CoreProtocols.swift`
- `Sources/Services/TodayAIService.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `Tests/Services/TodayAIServiceContextTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-103-red -only-testing:MingSiTests/AppStoreStateMachineTests/testBuiltinLensCatalog_packMetadataIsFirstPartyAndVersioned -only-testing:MingSiTests/AppStoreStateMachineTests/testLensLibrary_combinesEnabledMarketplaceLensPackAndIgnoresDisabledPacks -only-testing:MingSiTests/AppStoreStateMachineTests/testLensCatalogItem_decodesLegacyCustomLensJSONWithDefaultAssetFields -only-testing:MingSiTests/TodayAIServiceContextTests/testStructuredContext_exposesLensCatalogMetadata_forFirstPrinciples -only-testing:MingSiTests/TodayAIServiceContextTests/testGenerateQuestions_injectsLensPromptGuidance_fromCatalog test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-103-green-focused2 -only-testing:MingSiTests/AppStoreStateMachineTests/testBuiltinLensCatalog_packMetadataIsFirstPartyAndVersioned -only-testing:MingSiTests/AppStoreStateMachineTests/testLensLibrary_combinesEnabledMarketplaceLensPackAndIgnoresDisabledPacks -only-testing:MingSiTests/AppStoreStateMachineTests/testLensCatalogItem_decodesLegacyCustomLensJSONWithDefaultAssetFields -only-testing:MingSiTests/TodayAIServiceContextTests/testStructuredContext_exposesLensCatalogMetadata_forFirstPrinciples -only-testing:MingSiTests/TodayAIServiceContextTests/testGenerateQuestions_injectsLensPromptGuidance_fromCatalog test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-103-legacy-red -only-testing:MingSiTests/TodayAIServiceContextTests/testLensCatalogContext_decodesLegacyBuiltinContextWithBuiltinPackMetadata test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-103-legacy-green -only-testing:MingSiTests/TodayAIServiceContextTests/testLensCatalogContext_decodesLegacyBuiltinContextWithBuiltinPackMetadata test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-103-focused-suites -only-testing:MingSiTests/AppStoreStateMachineTests -only-testing:MingSiTests/TodayAIServiceContextTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-103-full-tests -only-testing:MingSiTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-dd-103-ui-tests -only-testing:MingSiUITests test
git diff --check
```

Result:

- RED failed as intended because `PromptContextPayload.LensCatalogContext` did not expose `sourceKind`, `packId`, `packVersion`, or `packDisplayName`.
- Added `LensAssetSourceKind`, `LensAssetPack`, and pack stamping so `LensLibrary` can compose enabled lens packs while ignoring disabled packs.
- Built-in lenses now resolve through a first-party pack: `mingsi.builtin.lenses@builtin.v1`.
- Legacy decoded custom lens JSON defaults to the local custom lens pack: `local.custom-lenses@session.v1`.
- Structured lens context now carries source kind and pack metadata, and legacy key export adds `lensSourceKind`, `lensPackId`, `lensPackVersion`, and `lensPackDisplayName`.
- Added a backward-compatible decoder test proving legacy built-in lens context without explicit pack fields is inferred back to the built-in pack rather than local custom provenance.
- Focused GREEN passed with 5 tests and 0 failures.
- Legacy context decoder RED/GREEN passed with 1 test and 0 failures after inference was added.
- `AppStoreStateMachineTests` plus `TodayAIServiceContextTests` passed with 238 tests and 0 failures.
- Full `MingSiTests` passed with 472 tests and 0 failures.
- Full `MingSiUITests` passed with 4 tests and 0 failures.
- `git diff --check`: exit 0, no output.

Residual risk:

- This is a local model/provider boundary for pack-aware lens assets, not a remote registry, import UI, marketplace sync, signature verification, or persistence store for downloaded packs.
- External lens packs can be represented and composed in-memory, but product-facing pack enable/disable and marketplace installation remain future work.
- Custom lenses still use the current local custom/session pack defaults unless a future persistence migration stores explicit pack provenance.
- Live BYOK GLM confirmation remains externally blocked until a real user-provided key and approved network-call window are available.

## 2026-06-09: Subtask 102 Local Historical Prompt Assets

Scope:

- Continue Prompt / Context assetization after Subtask 101.
- Make rollback target prompt versions resolvable by the real `LocalPromptProvider`.
- Preserve the current `PromptProvider` boundary while adding a narrow local historical prompt pack.
- Prove persisted prompt asset selections can restore a historical version with the real provider path, not only test fixture providers.

Changed areas:

- `Sources/Services/CoreProtocols.swift`
- `Tests/Services/LocalPromptProviderTests.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/superpowers/plans/2026-06-09-local-historical-prompt-assets.md`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-historical-prompts-red-dd -only-testing:MingSiTests/LocalPromptProviderTests/testGenerateQuestionsCurrentTemplate_declaresLocalRollbackTarget -only-testing:MingSiTests/LocalPromptProviderTests/testGenerateQuestionsRollbackTarget_resolvesHistoricalPromptAsset -only-testing:MingSiTests/LocalPromptProviderTests/testTemplateVersionLookup_returnsNilForUnknownHistoricalAsset test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-historical-prompts-red-dd -only-testing:MingSiTests/LocalPromptProviderTests/testGenerateQuestionsCurrentTemplate_declaresLocalRollbackTarget -only-testing:MingSiTests/LocalPromptProviderTests/testGenerateQuestionsRollbackTarget_resolvesHistoricalPromptAsset -only-testing:MingSiTests/LocalPromptProviderTests/testTemplateVersionLookup_returnsNilForUnknownHistoricalAsset test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-historical-prompts-app-dd -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_restoresHistoricalPromptAssetSelectionWithLocalProvider test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-historical-prompts-suites-dd -only-testing:MingSiTests/LocalPromptProviderTests -only-testing:MingSiTests/AppStoreStateMachineTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-historical-prompts-full-dd -only-testing:MingSiTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-historical-prompts-ui-dd -only-testing:MingSiUITests test
git diff --check
```

Result:

- Provider RED failed as intended: `generateQuestions` current template had no rollback target, and `LocalPromptProvider.template(for: .generateQuestions, mode: .standard, version: "0.9.0")` returned nil.
- Added real `LocalPromptProvider.template(for:mode:version:)` lookup that returns the current asset for its current version and resolves a local historical `generateQuestions@0.9.0` prompt asset.
- `generateQuestions` current metadata now declares `rollbackTargetVersion = "0.9.0"`.
- Historical `generateQuestions@0.9.0` preserves system/context/eval/schema metadata while carrying distinct prior user prompt text and no further rollback target.
- Added an AppStore persisted-selection restoration test that saves `PromptAssetSelection(generateQuestions, selectedVersion: "0.9.0")`, reloads through `LocalPromptProvider`, and proves `runPromptEvalSuite()` records `generateQuestions` at version `0.9.0`.
- Focused provider GREEN passed with 3 tests and 0 failures.
- Focused AppStore restoration test passed with 1 test and 0 failures.
- `LocalPromptProviderTests` plus `AppStoreStateMachineTests` passed with 225 tests and 0 failures.
- Full `MingSiTests` passed with 469 tests and 0 failures.
- Full `MingSiUITests` passed with 4 tests and 0 failures.
- `git diff --check`: exit 0, no output.

Residual risk:

- This is a local historical prompt pack for the first rollback target, not a remote prompt registry or marketplace.
- Future old versions still need to be added as local packs or supplied by a remote registry before arbitrary persisted selections can be restored after local assets change.
- This slice does not add scheduled eval execution, richer eval artifacts, or live model eval.
- Live BYOK GLM confirmation remains externally blocked until a real user-provided key and approved network-call window are available.

## 2026-06-09: Subtask 101 Prompt Asset Selection Persistence

Scope:

- Continue Prompt / Context assetization after Subtask 100.
- Persist selected prompt asset versions created by rollback execution.
- Restore persisted prompt version selections across AppStore reload before eval gates and AI services use prompt templates.
- Include prompt asset selection state in Data Export.

Changed areas:

- `Sources/Services/PersistenceCore.swift`
- `Sources/App/AppStore.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-prompt-selection-red-dd -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetSelection_saveAndLoadSelectedVersions -only-testing:MingSiTests/AppStoreStateMachineTests/testApplyPromptRollback_persistsSelectedVersionAcrossStoreReload test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-prompt-selection-green-dd -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetSelection_saveAndLoadSelectedVersions -only-testing:MingSiTests/AppStoreStateMachineTests/testApplyPromptRollback_persistsSelectedVersionAcrossStoreReload test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-prompt-selection-persistence-dd -only-testing:MingSiTests/PersistenceCoreTests/testPromptAssetSelection_saveAndLoadSelectedVersions -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesPromptAssetSelections -only-testing:MingSiTests/PersistenceCoreTests/testMigration_v17_addsPromptAssetSelectionsTableAndIndexes test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-prompt-selection-suites-dd -only-testing:MingSiTests/PersistenceCoreTests -only-testing:MingSiTests/AppStoreStateMachineTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-prompt-selection-final-full-dd -only-testing:MingSiTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-prompt-selection-final-ui-dd -only-testing:MingSiUITests test
git diff --check
```

Result:

- Initial RED failed at compile time because `PromptAssetSelection`, `SQLitePromptAssetSelectionRepository`, and AppStore's prompt asset selection injection point did not exist.
- Added `PromptAssetSelection` and `PromptAssetSelectionReason.rollback`.
- Added `PromptAssetSelectionRepository`, SQLite v17 `prompt_asset_selections` migration, row mapping, validation, and Data Export section coverage.
- `AppStore.live()` now injects `SQLitePromptAssetSelectionRepository`.
- `AppStore.loadPersistedState()` restores valid selected prompt versions through `PromptProvider.template(for:mode:version:)`, then rebuilds AI services through the effective provider.
- `applyPromptRollback(_:)` persists the selected rollback version before publishing the runtime override, so save failure does not leave an in-memory override behind.
- Focused selection + restart rollback tests passed with 2 tests and 0 failures.
- Focused persistence/export/migration tests passed with 3 tests and 0 failures.
- `AppStoreStateMachineTests` plus `PersistenceCoreTests` passed with 292 tests and 0 failures.
- Full `MingSiTests` passed with 465 tests and 0 failures.
- Full `MingSiUITests` passed with 4 tests and 0 failures.
- `git diff --check`: exit 0, no output.

Residual risk:

- Persisted selection only restores versions that the current `PromptProvider` can still resolve. The app still needs historical prompt packs or remote registry behavior before arbitrary old versions can be restored after assets are removed from the local provider.
- This slice does not add scheduled eval execution, richer eval artifacts, or live model eval.
- Live BYOK GLM confirmation remains externally blocked until a real user-provided key and approved network-call window are available.

## 2026-06-09: Subtask 100 Prompt Rollback Execution Runtime Override

Scope:

- Continue Prompt / Context assetization after Subtask 098.
- Move rollback from readiness-only detection to a narrow executable runtime path.
- Ensure a prompt asset rollback changes subsequent prompt template reads through the `PromptProvider` boundary.
- Preserve the current non-persistent local prompt registry; this slice does not add remote assets or cross-restart rollback persistence.

Changed areas:

- `Sources/Services/CoreProtocols.swift`
- `Sources/Domain/Models.swift`
- `Sources/App/AppStore.swift`
- `Sources/Features/FeatureTabs.swift`
- `Tests/Services/PromptEvalFixtureTests.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-prompt-rollback-exec-dd -only-testing:MingSiTests/PromptEvalFixtureTests/testPromptEvalReleaseGate_passesAfterPromptAssetRollbackUsesTargetVersionHistory test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-prompt-rollback-exec-dd -only-testing:MingSiTests/AppStoreStateMachineTests/testApplyPromptRollback_usesTargetTemplateAndRefreshesReleaseGate test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-prompt-rollback-exec-dd -only-testing:MingSiTests/PromptEvalFixtureTests/testPromptEvalReleaseGate_passesAfterPromptAssetRollbackUsesTargetVersionHistory -only-testing:MingSiTests/AppStoreStateMachineTests/testApplyPromptRollback_usesTargetTemplateAndRefreshesReleaseGate test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-prompt-rollback-exec-dd -only-testing:MingSiTests/PromptEvalFixtureTests -only-testing:MingSiTests/AppStoreStateMachineTests test
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-prompt-rollback-exec-dd -only-testing:MingSiTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-prompt-rollback-exec-dd -only-testing:MingSiUITests test
```

Result:

- Initial domain RED failed because after a provider had rolled `generateQuestions` back to `0.9.0`, `PromptEvalReleaseGate` still selected the newer superseded `1.0.0` failed run and stayed blocked.
- Initial AppStore RED failed at compile time because `AppStore.applyPromptRollback` did not exist.
- Added `PromptProvider.template(for:mode:version:)` with a default current-version implementation.
- `PromptEvalReleaseGate` now prefers eval runs matching the current template asset version and falls back to stale-history detection when only mismatched versions exist.
- Added `PromptRollbackOverrideProvider` and `AppStore.promptRollbackOverrides` so rollback candidates can override prompt templates at runtime.
- `applyPromptRollback(_:)` validates the candidate against the current gate, resolves the target version through the base provider, applies the runtime override, rebuilds AI services through the effective provider, and refreshes the gate/message.
- Settings `Prompt 固定评测` card now shows an `执行回滚` action for the first rollback-ready candidate.
- Project AI service creation now uses AppStore's effective prompt provider instead of hard-coded `LocalPromptProvider()`, so rollback overrides cover Today, Growth, and Project prompts.
- Focused RED/GREEN rollback tests passed with 2 tests and 0 failures.
- `PromptEvalFixtureTests` plus `AppStoreStateMachineTests` passed with 222 tests and 0 failures.
- `git diff --check`: exit 0, no output.
- Full `MingSiTests` passed with 461 tests and 0 failures.
- Full `MingSiUITests` passed with 4 tests and 0 failures.

Residual risk:

- Runtime rollback is not persisted across app restarts. A later Prompt Asset registry slice should persist current selected prompt versions and Data Export should expose that registry state.
- `LocalPromptProvider` still only ships current local assets unless a provider implementation supplies historical versions; this slice proves and wires the boundary rather than adding a historical prompt pack.
- Live BYOK GLM confirmation remains externally blocked until a real user-provided key and approved network-call window are available.

## 2026-06-09: Subtask 099 Principle NeedsReview Repair Workflow

Scope:

- Continue Principle Retrieval / Principle Training assetization after Subtask 093 and Subtask 098.
- Keep `needsReview` principles visible as training assets instead of hiding them behind the active-principle filter.
- Add a review-and-reactivate path for `needsReview` principles from Growth's Principle Asset list.
- Preserve Today main-state ownership: repairing a historical principle updates active prompt context and training summaries, but does not add that historical principle to today's candidate list unless it was already present there.

Changed areas:

- `Sources/Services/PersistenceCore.swift`
- `Sources/App/AppStore.swift`
- `Sources/Features/FeatureTabs.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-principle-repair-dd -only-testing:MingSiTests/PersistenceCoreTests/testUpdatePrinciple_reactivatesNeedsReviewPrincipleAndPreservesSourceLink -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_keepsNeedsReviewPrinciplesVisibleInTrainingSummaries -only-testing:MingSiTests/AppStoreStateMachineTests/testRepairPrinciple_reactivatesNeedsReviewPrincipleAndRefreshesTrainingSummary test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-principle-repair-dd -only-testing:MingSiTests/AppStoreStateMachineTests -only-testing:MingSiTests/PersistenceCoreTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-principle-repair-dd -only-testing:MingSiTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-principle-repair-dd -only-testing:MingSiUITests test
```

Result:

- Initial focused RED failed at compile time because `AppStore.repairPrinciple` did not exist.
- Added `PrincipleRepository.allPrinciples()` and `updatePrinciple(_:)`, with SQLite persistence preserving source links while reactivating a reviewed principle.
- `loadActivePrinciples()` now applies `needsReview` governance over all persisted principles, publishes only active principles to active prompt context, and derives training summaries from all non-archived principles.
- Growth's Principle Asset section now renders training summaries before the active-principle empty state, so `needsReview` rows remain visible and actionable.
- `ManualPrincipleFormSheet` supports repair mode with prefilled fields and calls `store.repairPrinciple(...)`.
- Repairing a historical `needsReview` principle refreshes `activePrinciples` and `principleTrainingSummaries`, while leaving `store.principles` empty when the principle was not part of today's candidate list.
- `git diff --check`: exit 0, no output.
- Focused repair tests passed with 3 tests and 0 failures.
- `AppStoreStateMachineTests` plus `PersistenceCoreTests` passed with 287 tests and 0 failures.
- Full `MingSiTests` passed with 459 tests and 0 failures.
- Full `MingSiUITests` passed with 4 tests and 0 failures.

Residual risk:

- This is a local review/reactivation workflow for existing persisted principle assets; it does not add remote principle review queues, bulk review, or marketplace behavior.
- Live BYOK GLM confirmation remains externally blocked until a real user-provided key and approved network-call window are available.

## 2026-06-09: Subtask 098 Prompt Eval Rollback Readiness

Scope:

- Continue Prompt / Context assetization after Subtask 097.
- Let the release gate identify rollback-ready blocking issues from previous passing fixed-suite history.
- Count rollback-ready versus manual-review prompt assets in AppStore and Settings status surfaces.
- Keep this as readiness detection only; do not execute prompt rollback or mutate current prompt assets.

Changed areas:

- `Sources/Domain/Models.swift`
- `Sources/App/AppStore.swift`
- `Sources/Features/FeatureTabs.swift`
- `Tests/Services/PromptEvalFixtureTests.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-rollback-gate-dd -only-testing:MingSiTests/PromptEvalFixtureTests/testPromptEvalReleaseGate_findsRollbackCandidatesFromPassingHistory test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-rollback-app-dd -only-testing:MingSiTests/AppStoreStateMachineTests/testPromptEvalReleaseGateMessage_includesRollbackReadinessCounts test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-rollback-gate-dd -only-testing:MingSiTests/PromptEvalFixtureTests -only-testing:MingSiTests/AppStoreStateMachineTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-rollback-gate-dd -only-testing:MingSiTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-rollback-gate-dd -only-testing:MingSiUITests test
git diff --check
```

Result:

- Initial domain RED failed because `PromptTemplate.rollbackTargetVersion`, rollback candidates, and release-gate rollback/manual-review counts did not exist.
- Initial AppStore RED failed because blocked gate copy did not expose `可回滚 / 需人工处理` readiness counts.
- Added `PromptEvalRollbackCandidate`, `PromptEvalReleaseGateIssue.rollbackCandidate`, `rollbackReadyCount`, `manualReviewCount`, and `rollbackCandidates`.
- Candidate matching requires prompt id, rollback target prompt version, system policy, context policy, input schema, output schema, eval suite, runner version, and a previously passed run.
- AppStore blocked-gate copy now includes rollback-ready and manual-review counts.
- Settings blocked-gate card shows the same readiness counts and previews issue candidates as `current -> target`.
- Focused domain GREEN passed with 1 test and 0 failures.
- Focused AppStore GREEN passed with 1 test and 0 failures.
- Combined `PromptEvalFixtureTests` plus `AppStoreStateMachineTests` passed with 218 tests and 0 failures.
- Full `MingSiTests` passed with 456 tests and 0 failures.
- Full `MingSiUITests` passed with 4 tests and 0 failures.
- `git diff --check`: exit 0, no output.

Residual risk:

- This identifies rollback-ready prompt assets from eval history; it does not provide a rollback execution UI, old prompt registry, scheduled eval runner, live model eval, or remote prompt asset marketplace.
- Live BYOK GLM confirmation remains externally blocked until a real user-provided key and approved network-call window are available.

## 2026-06-09: Subtask 097 Prompt Eval Release Gate / Settings Surface

Scope:

- Continue Prompt / Context assetization after Subtask 095.
- Convert fixed-suite `PromptEvalRun` history into an actionable release gate.
- Block prompt asset shipping when current prompt/system/context/schema/eval/runner versions are missing, stale, failed, or runner-mismatched.
- Add AppStore run/load/persist APIs and a compact Settings operation surface for the gate.

Changed areas:

- `Sources/Domain/Models.swift`
- `Sources/App/AppStore.swift`
- `Sources/Features/FeatureTabs.swift`
- `Tests/Services/PromptEvalFixtureTests.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-eval-gate-dd -only-testing:MingSiTests/PromptEvalFixtureTests/testPromptEvalReleaseGate_blocksMissingStaleAndFailedRuns test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-eval-gate-app-dd -only-testing:MingSiTests/AppStoreStateMachineTests/testRunPromptEvalSuite_persistsRunsAndUpdatesReleaseGate test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-eval-gate-dd -only-testing:MingSiTests/PromptEvalFixtureTests -only-testing:MingSiTests/AppStoreStateMachineTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-eval-gate-dd -only-testing:MingSiTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-eval-gate-dd -only-testing:MingSiUITests test
git diff --check
```

Result:

- Initial RED failed at compile time because `PromptEvalReleaseGate`, `recentPromptEvalRuns`, `promptEvalReleaseGate`, `promptEvalMessage`, `loadRecentPromptEvalRuns()`, `runPromptEvalSuite()`, and AppStore `promptEvalRunRepository` injection did not exist.
- Added `PromptEvalReleaseGateStatus`, issue reasons, blocking issues, and evaluator logic that chooses the latest run per `PromptID` and compares prompt version, system policy, context policy, input/output schema, eval suite, runner version, and case pass/fail status.
- Added AppStore eval-run repository wiring, live `SQLitePromptEvalRunRepository` injection, fixed-suite execution, persistence reload, gate publication, and Chinese status messages.
- Added a Settings `Prompt 固定评测` card with run action, ship-readiness status, counts, blocking issue preview, and recent-run summary.
- Focused release-gate GREEN passed with 1 test and 0 failures.
- Focused AppStore persistence/gate GREEN passed with 1 test and 0 failures.
- Combined `PromptEvalFixtureTests` plus `AppStoreStateMachineTests` passed with 216 tests and 0 failures.
- Full `MingSiTests` passed with 454 tests and 0 failures.
- Full `MingSiUITests` passed with 4 tests and 0 failures.
- `git diff --check`: exit 0, no output.

Residual risk:

- This is an offline local fixed-suite release gate, not a live model-eval run, rollback execution UI, scheduled/background eval job, or remote prompt asset marketplace.
- Live BYOK GLM confirmation remains externally blocked until a real user-provided key and approved network-call window are available.

## 2026-06-09: Subtask 096 Today Rendered Action-Driving Walkthrough

Scope:

- Close the post-MVP Alpha rendered action-driving prerequisite for Today.
- Extend the existing `MingSiUITests` driver beyond smoke checks into a full rendered Debug seed walkthrough.
- Drive the rendered Today loop from confirmed ReviewCards through lens selection, question entry, quest review, principle extraction, and session completion.
- Add stable state and lens action identifiers needed by the XCTest flow.

Changed areas:

- `Sources/Features/Today/TodayView.swift`
- `Tests/UI/MingSiUITests.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-ui-walkthrough-dd -only-testing:MingSiUITests/MingSiUITests/testTodayReviewCardsSeedCanDriveRenderedLoopToCompletion test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-ui-walkthrough-dd -only-testing:MingSiTests/AppStoreStateMachineTests/testTodayAutomationIdentifiers_areStableForRenderedWalkthroughControls test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-ui-walkthrough-dd -only-testing:MingSiUITests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-ui-contract-dd -only-testing:MingSiTests/AppStoreStateMachineTests/testTodayAutomationIdentifiers_areStableForRenderedWalkthroughControls test
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-ui-contract-dd -only-testing:MingSiTests/AppStoreStateMachineTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-ui-contract-dd -only-testing:MingSiTests test
```

Result:

- Initial RED failed after tapping the primary action from seeded ReviewCards because no rendered `today.state.select_lens` marker existed.
- An invisible/clear marker did not reliably enter the iOS accessibility tree. The accepted GREEN attaches the state identifier to the visible current-state title in the Today header.
- Added `TodayAutomationID.state(_:)` for all `DailyLoopState` values and `TodayAutomationID.lensAction(_:)` for lens catalog items.
- Added `testTodayReviewCardsSeedCanDriveRenderedLoopToCompletion`, which launches the Debug `review_cards_confirmed` seed, taps `today.primary-action`, selects `today.lens.firstPrinciples-action`, types into `today.question.answer-field`, and continues through `today.state.review_quests`, `today.state.extract_principle`, and `today.state.session_complete`.
- Focused rendered walkthrough GREEN passed with 1 UI test and 0 failures.
- A parallel focused AppStore identifier contract run against the same DerivedData failed with Xcode build database lock (`build.db`: database is locked). This was an environment/concurrency failure; it was rerun serially with isolated DerivedData at `/tmp/mingsi-ui-contract-dd`.
- Full `MingSiUITests` passed with 4 tests and 0 failures using `/tmp/mingsi-ui-walkthrough-dd`.
- Focused AppStore identifier contract passed with 1 test and 0 failures using `/tmp/mingsi-ui-contract-dd`.
- `git diff --check`: exit 0, no output.
- Full `AppStoreStateMachineTests` passed with 207 tests and 0 failures using `/tmp/mingsi-ui-contract-dd`.
- Full `MingSiTests` passed with 452 tests and 0 failures using `/tmp/mingsi-ui-contract-dd`.

Residual risk:

- This proves the rendered local/Debug Today action-driving loop through XCTest accessibility identifiers, not a live GLM network success.
- Live BYOK GLM confirmation remains externally blocked until a real user-provided key and approved network-call window are available.

## 2026-06-09: Subtask 095 Prompt Eval Runner History

Scope:

- Continue Prompt / Context assetization after Subtask 094.
- Add a first-class fixed eval runner/history surface for local prompt assets.
- Persist prompt eval runs with prompt/system/context/schema/eval/runner versions, aggregate counts, and per-case results.
- Include prompt eval history in Data Export.

Changed areas:

- `Sources/Domain/Models.swift`
- `Sources/Services/CoreProtocols.swift`
- `Sources/Services/PersistenceCore.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `Tests/Services/PromptEvalFixtureTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testSavePromptEvalRun_andLoadRecent -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesPromptEvalRuns -only-testing:MingSiTests/PersistenceCoreTests/testMigration_v16_addsPromptEvalRunsTableAndIndexes -only-testing:MingSiTests/PromptEvalFixtureTests/testPromptEvalRunner_recordsSuiteMetadataAndCaseResults test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-eval-dd -only-testing:MingSiTests/PersistenceCoreTests/testSavePromptEvalRun_andLoadRecent -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesPromptEvalRuns -only-testing:MingSiTests/PersistenceCoreTests/testMigration_v16_addsPromptEvalRunsTableAndIndexes -only-testing:MingSiTests/PromptEvalFixtureTests/testPromptEvalRunner_recordsSuiteMetadataAndCaseResults test
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-eval-dd -only-testing:MingSiTests/PersistenceCoreTests -only-testing:MingSiTests/PromptEvalFixtureTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-eval-dd -only-testing:MingSiTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-eval-dd -only-testing:MingSiUITests test
```

Result:

- Initial RED failed at compile time because `PromptEvalRunner`, `PromptEvalRun` eval-status APIs, and persistence/export history did not exist.
- Added `PromptEvalStatus`, `PromptEvalCaseResult`, and `PromptEvalRun` with derived total/pass/fail counts and pass rate.
- Added `PromptEvalRunner.currentRunnerVersion = "prompt-eval-runner.v1"` and a fixed suite covering all current first-party `PromptID` cases.
- The first isolated GREEN attempt found a real fixture failure in lens recommendations: the runner compared prompt-facing ids such as `evidence_check` against local `ThinkingLens.rawValue` ids such as `evidenceCheck`. The accepted fix uses `BuiltinLensCatalog.library.items.map(\.promptId)` for supported lens ids.
- Added `PromptEvalRunRepository`, `SQLitePromptEvalRunRepository`, v16 `prompt_eval_runs` migration, indexes, row mapper, recent-run loading, and Data Export section `prompt_eval_runs`.
- A shared DerivedData run hit an Xcode build database lock because another build was active. Verification continued with isolated DerivedData at `/tmp/mingsi-eval-dd`.
- Focused eval-history GREEN passed with 4 tests and 0 failures.
- `git diff --check`: exit 0, no output.
- Focused `PersistenceCoreTests` plus `PromptEvalFixtureTests` passed with 82 tests and 0 failures using isolated DerivedData.
- Full `MingSiTests` passed with 452 tests and 0 failures using isolated DerivedData.
- Full `MingSiUITests` passed with 3 tests and 0 failures using isolated DerivedData, confirming the existing XCTest driver can still type/tap through Today accessibility identifiers.

Residual risk:

- This is an offline fixed-suite runner/history slice, not a release gate, rollback UI, scheduled eval job, or live model-eval workflow.
- Live BYOK GLM confirmation remains externally blocked until a real user-provided key and approved network-call window are available.

## 2026-06-09: Subtask 094 PromptContextPayload Residual Source Cleanup

Scope:

- Close the remaining Prompt / Context assetization payload gap.
- Move Today prompt directives, VerifyQuest fields, Growth report context, Project context, project evidence, and project links into typed `PromptContextPayload` sections.
- Keep `LLMRequest.jsonPayload` only as the legacy DirectGLM compatibility export from `PromptContextPayload.legacyKeyValues`.

Changed areas:

- `Sources/Services/CoreProtocols.swift`
- `Sources/Services/TodayAIService.swift`
- `Sources/Services/ProjectAIService.swift`
- `Sources/Services/GrowthAIService.swift`
- `Tests/Services/TodayAIServiceContextTests.swift`
- `Tests/Services/ProjectAIServiceContextTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/ProjectAIServiceContextTests/testSuggestProjectLinks_sendsTypedProjectContextAndSourceIds -only-testing:MingSiTests/TodayAIServiceContextTests/testGrowthAIService_exposesStructuredGrowthContextPayload -only-testing:MingSiTests/TodayAIServiceContextTests/testVerifyQuest_usesStructuredContextAsLegacyPayloadSource test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/TodayAIServiceContextTests/testGrowthAIService_omitsPreviousScoresWhenSnapshotIsInsufficientEvidence test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/ProjectAIServiceContextTests/testSuggestProjectLinks_sendsTypedProjectContextAndSourceIds -only-testing:MingSiTests/ProjectAIServiceContextTests/testSuggestProjectLinks_usesStructuredContextAsLegacyPayloadSource -only-testing:MingSiTests/ProjectAIServiceContextTests/testGenerateProjectInsights_sendsTypedProjectContextAndEvidenceSourceRefs -only-testing:MingSiTests/ProjectAIServiceContextTests/testSuggestProjectMerges_sendsTypedProjectContextWithSourceAndContextRefs -only-testing:MingSiTests/TodayAIServiceContextTests/testGrowthAIService_exposesStructuredGrowthContextPayload -only-testing:MingSiTests/TodayAIServiceContextTests/testGrowthAIService_usesStructuredContextAsLegacyPayloadSource -only-testing:MingSiTests/TodayAIServiceContextTests/testVerifyQuest_usesStructuredContextAsLegacyPayloadSource test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/TodayAIServiceContextTests -only-testing:MingSiTests/ProjectAIServiceContextTests -only-testing:MingSiTests/DirectGLMClientTests test
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests test
```

Result:

- Initial RED failed at compile time because `PromptContextPayload` had no typed `verification` section and VerifyQuest still depended on `extra`.
- A second RED caught a behavior-preservation bug: insufficient-evidence previous Growth snapshots were incorrectly exported as previous score context during the typed migration.
- Added typed sections for prompt directives, verification, richer project context, project evidence, project links, and Growth legacy export derivation.
- Removed service-layer `buildPayload(from:)` legacy dictionaries from Project and Growth services.
- Removed Today request `payload: [String: String]` merging and replaced it with typed prompt directives.
- Growth typed context now keeps the old `canDisplayScores` guard before exporting previous scores.
- The positive previous-score fixture was corrected to satisfy the real display rule (`completeLoopCount >= 3` plus contribution refs), so the test now separates displayable and insufficient previous snapshots explicitly.
- Focused GREEN passed with 7 tests and 0 failures.
- Service context regression suite passed with 37 tests and 0 failures.
- `git diff --check`: exit 0, no output.
- Full `MingSiTests` passed with 448 tests and 0 failures.
- Full `MingSiUITests` passed with 3 tests and 0 failures.

Residual risk:

- `LLMRequest.jsonPayload` and `PromptContextPayload.extra` remain as compatibility surfaces for legacy DirectGLM fallback and exceptional future keys, but current Today / Project / Growth service source construction no longer depends on them.
- A richer eval runner history remains future work beyond fixed eval suite metadata.
- Live BYOK GLM success still requires a real user-provided key and an approved external network call window.

## 2026-06-09: Subtask 092 Principle Training-State Summary

Scope:

- Continue the Principle Training track after Subtask 091.
- Derive principle training state from durable practice evidence, recall feedback, and principle status.
- Make the state available as AppStore state for Growth and later prompt/context use without changing the Today state machine.
- Add a minimal Growth display hook so the Principle Asset list can show training state and evidence counts.

Changed areas:

- `Sources/Domain/Models.swift`
- `Sources/App/AppStore.swift`
- `Sources/Features/FeatureTabs.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testPrincipleTrainingSummary_classifiesKnownPracticedInternalizedAndNeedsReview
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testRefreshPrincipleTrainingSummaries_loadsPracticeEvidenceForActivePrinciples
```

Result:

- Initial RED failed at compile time because `PrincipleTrainingSummary`, training-state cases, `AppStore.principleTrainingSummaries`, and `refreshPrincipleTrainingSummaries()` did not exist.
- Added `PrincipleTrainingState` cases: `known_but_unused`, `consciously_practiced`, `stably_internalized`, and `needs_review`.
- Added `PrincipleTrainingSummary` with principle, state, practice evidence counts, intentional/internalized counts, helpful/negative recall feedback counts, and latest practice evidence timestamp.
- Added conservative classification: `needsReview` status or repeated negative feedback wins; internalized evidence or at least three distinct practice days becomes `stably_internalized`; intentional practice or helpful feedback becomes `consciously_practiced`; otherwise the principle remains `known_but_unused`.
- Added `AppStore.principleTrainingSummaries` and repository-backed refresh after active principles load.
- The first AppStore path run failed because the test fixture did not provide a daily repository, so `loadPersistedState()` returned before loading active principles. The fixture was corrected to match the real persisted-state path.
- Focused classification test passed with 1 test and 0 failures.
- Focused AppStore repository-to-summary test passed with 1 test and 0 failures.

Residual risk:

- Training summaries are derived and visible in Growth, but the app does not yet expose Today UI controls to mark a recalled principle helpful / not applicable / misrecalled.
- `needsReview` principles still do not have a repair inbox or edit/re-activate workflow.
- Positive practice evidence is summarized but does not yet boost retrieval ranking.

## 2026-06-09: Subtask 091 Automatic Practice Evidence Capture from Verification

Scope:

- Continue the Principle Training track after Subtask 090.
- Automatically record practice evidence when Yesterday verification proves that an active principle was intentionally practiced through the verified main quest.
- Keep matching conservative and local: only capture evidence when quest / verification / current verification text contains a normalized active-principle title, summary, trigger, success criterion, or action.
- Avoid duplicate verification evidence for the same principle, source DailyEntry, and Quest even if the verification flow is repeated.

Changed areas:

- `Sources/App/AppStore.swift`
- `Sources/Services/PersistenceCore.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testPrinciplePracticeEvidence_loadsVerificationEvidenceByBusinessKey
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testVerifyYesterday_recordsPrinciplePracticeEvidenceWhenQuestMatchesActivePrinciple
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testVerifyYesterday_recordsPrinciplePracticeEvidenceOnlyOnceForSameVerification
git diff --check
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/TodayAIServiceContextTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests
```

Result:

- Initial AppStore RED failed at compile time because `AppStore` had no `principlePracticeEvidenceRepository` dependency and did not capture practice evidence from verification.
- Added `principlePracticeEvidenceRepository` injection to `AppStore` and live wiring to `SQLitePrinciplePracticeEvidenceRepository`.
- After verification persistence and quest status update, `AppStore` now attempts to record principle practice evidence for matching active principles.
- Evidence is saved as `evidenceSource: .verification`, `strength: .intentionalPractice`, and links `sourceDailyEntryId`, `questId`, and `verificationId`.
- Added a repeated-verification regression test. The initial verification-id based dedupe allowed duplicates because each repeated verification has a new `Verification.id`; the accepted behavior dedupes by principle id, source DailyEntry id, Quest id, and `.verification` source.
- Added repository-level lookup for the practice evidence business key and changed AppStore to use that lookup instead of scanning a recent principle evidence window.
- Persistence lookup RED failed because the repository did not yet support source DailyEntry + Quest + evidence source lookup. GREEN passed after adding the API and SQLite filters.
- Focused persistence lookup test passed with 1 test and 0 failures.
- Focused AppStore capture test passed with 1 test and 0 failures.
- A concurrent run of the duplicate AppStore test failed before test bootstrap with `Early unexpected exit`; this was treated as an environment failure because another `xcodebuild` was running at the same time and there was no XCTest assertion output.
- The duplicate AppStore test passed when rerun serially with 1 test and 0 failures.
- `git diff --check`: exit 0, no output.
- `AppStoreStateMachineTests` passed with 204 tests and 0 failures.
- `PersistenceCoreTests` passed with 72 tests and 0 failures.
- `TodayAIServiceContextTests` passed with 20 tests and 0 failures.
- Full `MingSiTests` passed with 444 tests and 0 failures.
- `MingSiUITests` passed with 2 tests and 0 failures.

Residual risk:

- Matching remains deliberately conservative local text matching. It avoids model-costly interpretation but may miss practice evidence when the quest practices a principle through paraphrase only.
- There is still no user-facing control to mark recalled principles helpful / not applicable / misrecalled from the Today UI.
- Practice evidence is captured, but the app does not yet summarize principle training state as "known but unused", "consciously practiced", or "stably internalized".
- Retrieval does not yet use positive practice evidence to boost or classify principles.

## 2026-06-09: Subtask 090 Principle Practice Evidence Persistence

Scope:

- Continue the Principle Retrieval / Principle Training track after Subtask 089.
- Add a structured persistence asset for evidence that a recalled or saved principle was practiced.
- Keep this slice at the Domain/Persistence/Data Export layer; do not change Today UI or main state-machine behavior yet.

Changed areas:

- `Sources/Domain/Models.swift`
- `Sources/Services/PersistenceCore.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testPrinciplePracticeEvidence_persistsPracticeEvidenceForPrinciple
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testMigration_v15_addsPrinciplePracticeEvidenceTableAndIndexes -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesPrinciplePracticeEvidence
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests
git diff --check
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/TodayAIServiceContextTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests
```

Result:

- Initial RED failed at compile time because `PrinciplePracticeEvidence`, `PrinciplePracticeEvidenceSource`, `PrinciplePracticeEvidenceStrength`, and `SQLitePrinciplePracticeEvidenceRepository` did not exist.
- Added `PrinciplePracticeEvidence` with principle id, source DailyEntry id, optional Quest/Verification ids, evidence source, strength, summary, and timestamps.
- Added `PrinciplePracticeEvidenceRepository` plus `SQLitePrinciplePracticeEvidenceRepository`.
- Added SQLite migration `v15_principle_practice_evidence` with indexes on principle id, source DailyEntry id, and strength.
- Added Data Export section `principle_practice_evidence`.
- Focused practice evidence persistence test passed with 1 test and 0 failures.
- Focused v15 migration and Data Export tests passed with 2 tests and 0 failures.
- `PersistenceCoreTests` passed with 71 tests and 0 failures.
- `git diff --check`: exit 0, no output.
- `AppStoreStateMachineTests` passed with 202 tests and 0 failures.
- `TodayAIServiceContextTests` passed with 20 tests and 0 failures.
- Full `MingSiTests` passed with 441 tests and 0 failures.

Residual risk:

- Practice evidence is not yet captured automatically from Today quest review or verification.
- There is no user-facing practice marker or principle training-state summary yet.
- Retrieval does not yet use practice evidence to boost or classify principles.

## 2026-06-09: Subtask 089 Automatic Principle NeedsReview Governance

Scope:

- Continue the Principle Retrieval / Principle Training track after Subtask 088.
- Move active principles with repeated negative recall feedback into `needsReview` so uncertain rules stop entering active prompt context.
- Preserve the Subtask 088 behavior where one negative feedback event only demotes retrieval and does not force review.
- Add repository support for individual principle status updates.

Changed areas:

- `Sources/App/AppStore.swift`
- `Sources/Services/PersistenceCore.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
git diff --check
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_marksRepeatedNegativeRecallFeedbackNeedsReview
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testSelectLens_generateQuestionsUsesSingleRecallFeedbackToDemoteReferencesBeforeReviewThreshold
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testUpdatePrincipleStatus_movesActivePrincipleToNeedsReview
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/TodayAIServiceContextTests
```

Result:

- Initial RED for the persistence test failed because `PrincipleRepository` had no `updatePrincipleStatus` API.
- Added `updatePrincipleStatus(_:, principleId:)` to the repository contract, SQLite implementation, and test in-memory repository.
- Added AppStore governance threshold `principleNeedsReviewNegativeFeedbackThreshold = 2`.
- `loadActivePrinciples()` now checks recent negative recall feedback and updates repeatedly problematic active principles to `.needsReview`.
- `contextPrinciplesForAI()` uses the same governance path, so same-session question/quest generation excludes principles that just crossed the review threshold.
- One negative feedback event still only demotes retrieval before the review threshold.
- `git diff --check`: exit 0, no output.
- Focused AppStore `needsReview` test passed with 1 test and 0 failures.
- Focused single-feedback threshold regression test passed with 1 test and 0 failures.
- Focused persistence status update test passed with 1 test and 0 failures.
- `AppStoreStateMachineTests` passed with 202 tests and 0 failures.
- `PersistenceCoreTests` passed with 68 tests and 0 failures.
- `TodayAIServiceContextTests` passed with 20 tests and 0 failures.

Residual risk:

- There is still no user-facing control to mark a recalled principle helpful / not applicable / misrecalled.
- Practice evidence is still missing, so the app cannot yet distinguish "known but unused", "consciously practiced", and "stably internalized".
- There is no review inbox or repair workflow for `needsReview` principles yet; the current slice only stops repeatedly disputed principles from staying active.

## 2026-06-08: Subtask 088 Feedback-Weighted Principle Retrieval

Scope:

- Continue the Principle Retrieval / Principle Training track after Subtask 087.
- Make saved not-applicable / misrecalled principle recall feedback affect future local principle retrieval.
- Carry recall feedback through the product path: SQLite repository -> AppStore -> TodayAIContext -> LocalPrincipleRetriever.
- Preserve the existing `PrincipleRetriever.relevantPrinciples(...)` compatibility API while exposing adjusted scores and audit reasons through `retrievePrinciples(...)`.

Changed areas:

- `Sources/App/AppStore.swift`
- `Sources/Services/TodayAIService.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `Tests/Services/TodayAIServiceContextTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/TodayAIServiceContextTests/testRelevantPrinciples_negativeRecallFeedbackDemotesMisrecalledPrinciples
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testSelectLens_generateQuestionsUsesRecallFeedbackToDemoteReferences
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/TodayAIServiceContextTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests
xcodebuild build -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17'
git diff --check
```

Result:

- Initial RED for the retriever test failed at compile time because `TodayAIContext` did not carry `principleRecallFeedback`; this proved the missing feedback input boundary.
- `TodayAIContext` now carries `principleRecallFeedback`, defaulting to an empty array for existing callers.
- `LocalPrincipleRetriever.policyVersion` is now `principle-retrieval.local-keyword-feedback.v2`.
- Local keyword retrieval now applies a one-point penalty per `notApplicable` or `misrecalled` feedback event for the principle, preserves helpful feedback as neutral, and emits the penalty in `retrievalReason`.
- Initial RED for the AppStore path failed because `AppStore` had no `principleRecallFeedbackRepository` dependency.
- `AppStore.live()` now wires `SQLitePrincipleRecallFeedbackRepository`; question/quest generation and referenced-principle refresh now load recent feedback for candidate principles and pass it into `TodayAIContext`.
- Focused pure retriever RED/GREEN test passed: 1 test, 0 failures.
- Focused AppStore repository-to-retriever path test passed: 1 test, 0 failures.
- `TodayAIServiceContextTests` passed with 20 tests and 0 failures.
- `AppStoreStateMachineTests` passed with 201 tests and 0 failures.
- `PersistenceCoreTests` passed with 67 tests and 0 failures.
- Full `MingSiTests` passed with 436 tests and 0 failures.
- Full `MingSiUITests` passed with 2 tests and 0 failures.
- iPhone 17 simulator build succeeded.
- `git diff --check`: exit 0, no output.

Residual risk:

- There is still no user-facing control to mark a recalled principle helpful / not applicable / misrecalled.
- Negative feedback demotes retrieval but does not yet automatically change `PrincipleAsset.status` to `needsReview`.
- Practice evidence is still missing, so retrieval does not yet include verified success/practice boosts.

## 2026-06-08: Subtask 087 Principle Recall Feedback Persistence

Scope:

- Continue the Principle Retrieval / Principle Training track after Subtask 086.
- Add durable storage for user feedback on recalled principles: helpful, not applicable, and misrecalled.
- Preserve retrieval audit details with each feedback event so future policy upgrades can learn from concrete recall mistakes.
- Include principle recall feedback in local Data Export.

Changed areas:

- `Sources/Domain/Models.swift`
- `Sources/Services/PersistenceCore.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testPrincipleRecallFeedback_persistsNotApplicableAndMisrecalledEvents
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testMigration_v14_addsPrincipleRecallFeedbackTableAndIndexes
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesPrincipleRecallFeedback
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests
xcodebuild build -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17'
git diff --check
```

Result:

- Initial persistence RED failed because no feedback model/repository/table existed.
- Added `PrincipleRecallFeedbackValue` and `PrincipleRecallFeedback`.
- Added `PrincipleRecallFeedbackRepository` and `SQLitePrincipleRecallFeedbackRepository`.
- Added SQLite migration `v14_principle_recall_feedback` with indexes on principle id, prompt run id, and feedback value.
- Added Data Export section `principle_recall_feedback`.
- Focused persistence, migration, and Data Export tests passed.
- `PersistenceCoreTests` passed with 67 tests and 0 failures.
- Full `MingSiTests` passed with 434 tests and 0 failures.
- Full `MingSiUITests` passed with 2 tests and 0 failures.
- iPhone 17 simulator build succeeded.
- `git diff --check`: exit 0, no output.

Residual risk:

- This persists recall feedback but does not by itself collect feedback in UI.
- This does not yet affect retrieval ranking, `needsReview`, or practice evidence; those require follow-up slices.

## 2026-06-08: Subtask 086 Principle Retrieval Metadata

Scope:

- Continue the Principle Retrieval / Prompt Context audit track after Subtask 085.
- Add structured recall reasons and retrieval policy versioning to principles injected into Today prompt context.
- Preserve the existing `PrincipleRetriever.relevantPrinciples(...)` compatibility API for callers that only need `[PrincipleAsset]`.
- Preserve legacy DirectGLM compatibility by rendering retrieval metadata through `PromptContextPayload.legacyKeyValues`.

Changed areas:

- `Sources/Services/CoreProtocols.swift`
- `Sources/Services/TodayAIService.swift`
- `Tests/Services/TodayAIServiceContextTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/TodayAIServiceContextTests/testGenerateQuestions_exposesStructuredContextPayloadWithCardsLensModeAndPrinciples
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/TodayAIServiceContextTests
git diff --check
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests
xcodebuild build -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17'
```

Result:

- Initial RED failed because `PromptContextPayload.PrincipleContext` had no `retrievalReason` / `retrievalPolicyVersion`, and `LocalPrincipleRetriever` had no policy version.
- Added `retrievalReason` and `retrievalPolicyVersion` to structured principle context with default initializer values for compatibility.
- Added `RetrievedPrinciple` and `PrincipleRetriever.retrievePrinciples(...)`, while the existing `relevantPrinciples(...)` API now delegates to the richer retrieval result.
- `LocalPrincipleRetriever.policyVersion` is `principle-retrieval.local-keyword.v1`, and local keyword recall now emits a readable matched-term reason plus score.
- `DefaultContextAssembler` maps retrieved-principle metadata into `PromptContextPayload.PrincipleContext`.
- Focused RED/GREEN test passed with 1 test and 0 failures.
- `TodayAIServiceContextTests` passed with 19 tests and 0 failures.
- Full `MingSiTests` passed with 431 tests and 0 failures.
- Full `MingSiUITests` passed with 2 tests and 0 failures.
- iPhone 17 simulator build succeeded.
- `git diff --check`: exit 0, no output.

Residual risk:

- This adds recall observability, but not user-facing principle recall feedback yet.
- No persistence table records per-recall feedback, not-applicable/misrecall decisions, or practice evidence yet.
- Retrieval remains local keyword scoring; embedding, feedback-weighted ranking, and practice-evidence weighting remain later upgrades.

## 2026-06-08: Subtask 082 Lens Asset Context Wiring

Scope:

- Continue the Lens Asset / Prompt Context assetization track after Subtask 081.
- Make `PromptContextPayload.LensCatalogContext` carry Lens Asset fields, not only title / method line / prompt guidance.
- Expose lens purpose, question strategy, task selection rule, applicability, disable conditions, and UI metadata in structured Today prompt context.
- Preserve DirectGLM compatibility by continuing to emit legacy `[String: String]` payload keys for lens asset fields.
- Keep Today state-machine behavior and prompt-facing lens ids unchanged.

Changed areas:

- `Sources/Services/CoreProtocols.swift`
- `Sources/Services/TodayAIService.swift`
- `Tests/Services/TodayAIServiceContextTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/TodayAIServiceContextTests/testStructuredContext_exposesLensCatalogMetadata_forFirstPrinciples -only-testing:MingSiTests/TodayAIServiceContextTests/testGenerateQuestions_injectsLensPromptGuidance_fromCatalog test
xcodebuild -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/TodayAIServiceContextTests test
xcodebuild -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests test
xcodebuild -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests test
xcodebuild -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
git diff --check
```

Result:

- Initial RED failed because `PromptContextPayload.LensCatalogContext` had no `purpose`, `questionStrategy`, `taskSelectionRule`, `applicability`, `disableConditions`, or `uiMetadata`.
- Added structured Lens Asset fields and UI metadata to `PromptContextPayload.LensCatalogContext`.
- `DefaultContextAssembler` now maps selected built-in lens catalog items into the structured context with full Lens Asset metadata.
- `PromptContextPayload.legacyKeyValues` now emits `lensPurpose`, `lensQuestionStrategy`, `lensTaskSelectionRule`, `lensApplicability`, and `lensDisableConditions` while preserving existing `selectedLens`, `lensTitle`, `lensMethodLine`, and `lensPromptGuidance`.
- Focused RED/GREEN tests passed with 2 tests and 0 failures.
- `TodayAIServiceContextTests` passed with 17 tests and 0 failures.
- Full `MingSiTests` passed with 427 tests and 0 failures.
- Full `MingSiUITests` passed with 2 tests and 0 failures.
- iPhone 17 simulator build succeeded.
- `git diff --check`: exit 0, no output.

Residual risk:

- This wires Lens Asset metadata into Today prompt context, but it is not a full removal of legacy `[String: String]` payload compatibility.
- Custom lenses are still session-local/domain-persisted assets, not a full user-authored lens pack lifecycle with marketplace governance.
- First-class eval runner/history, broader Project/Growth payload cleanup, principle retrieval feedback, and live GLM proof remain open.

## 2026-06-08: Subtask 081 Lens Asset Schema

Scope:

- Continue the post-MVP algorithm-asset track by upgrading built-in lens catalog items into explicit Lens Assets.
- Add structured lens fields for purpose, question strategy, task selection rule, applicability, disable conditions, and UI metadata.
- Preserve stable `ThinkingLens.rawValue` local ids and prompt-facing ids.
- Preserve persisted custom lens compatibility by decoding legacy custom lens JSON with safe default Lens Asset fields.
- Keep Today state-machine behavior unchanged; this slice only changes the domain lens asset boundary.

Changed areas:

- `Sources/Domain/Models.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testBuiltinLensCatalog_methodAssetMetadataIsComplete -only-testing:MingSiTests/AppStoreStateMachineTests/testLensCatalogItem_decodesLegacyCustomLensJSONWithDefaultAssetFields test
xcodebuild -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
xcodebuild -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests test
xcodebuild -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests test
xcodebuild -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests test
xcodebuild -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
git diff --check
```

Result:

- Initial RED failed because `LensCatalogItem` had no `purpose`, `questionStrategy`, `taskSelectionRule`, `applicability`, `disableConditions`, or `uiMetadata`.
- `LensCatalogItem` now has explicit Lens Asset fields plus nested `UIMetadata`.
- Built-in lenses now define purpose, question strategy, task selection rule, applicability, and disable conditions as first-party catalog data.
- `LensCatalogItem` has a custom decoder that backfills missing asset fields for legacy persisted custom lens JSON.
- Focused Lens Asset tests passed with 2 tests and 0 failures.
- `AppStoreStateMachineTests` passed with 200 tests and 0 failures.
- `PersistenceCoreTests` passed with 64 tests and 0 failures.
- Full `MingSiTests` passed with 427 tests and 0 failures.
- Full `MingSiUITests` passed with 2 tests and 0 failures.
- iPhone 17 simulator build succeeded.
- `git diff --check`: exit 0, no output.

Residual risk:

- Lens Asset metadata is now structured in the domain catalog, but the full PromptContextPayload migration is not complete.
- The model prompt payload still keeps legacy `[String: String]` compatibility where DirectGLM needs it.
- Remote lens packs, marketplace behavior, richer role/framework cards, and user-authored lens lifecycle governance remain future work.
- Principle recall feedback, eval runner/history, and live GLM confirmation remain open.

## 2026-06-08: Subtask 080 PromptRun Quality Statistics

Scope:

- Continue the post-MVP Prompt / Context assetization track after Subtask 079.
- Add PromptRun-level user feedback needed for user denial rate statistics.
- Add repository and AppStore support for recent PromptRun quality statistics: failure rate, empty result rate, and user denial rate.
- Persist/export the new audit feedback field through SQLite and Data Export.
- Keep PromptProvider / LLMClient / parser / SwiftUI boundaries intact; this slice does not change model calling behavior.

Changed areas:

- `Sources/Domain/Models.swift`
- `Sources/App/AppStore.swift`
- `Sources/Features/FeatureTabs.swift`
- `Sources/Services/PersistenceCore.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testPromptRun_updateFeedbackPersistsUserDenial -only-testing:MingSiTests/PersistenceCoreTests/testPromptRun_statsCalculatesFailureEmptyResultAndDenialRates test
xcodebuild -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests test
xcodebuild -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadRecentPromptRuns_loadsNewestFirstAuditRunsWithRefsAndErrors test
xcodebuild -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
xcodebuild -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests test
xcodebuild -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests test
xcodebuild -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
git diff --check
```

Result:

- Initial RED failed because `SQLitePromptRunRepository` had no `updatePromptRunFeedback` or `promptRunStats`, `PromptRun` had no `userFeedback`, and `PromptRunFeedback.denied` did not exist.
- Added `PromptRunFeedback` and `PromptRunStats` domain models.
- Added `PromptRun.userFeedback`, `PromptRunRepository.updatePromptRunFeedback`, and `PromptRunRepository.promptRunStats(limit:)`.
- Added v13 `prompt_runs.user_feedback` migration; fresh v1 `prompt_runs` includes the column directly.
- Data Export now includes `prompt_runs.user_feedback`.
- `AppStore.loadRecentPromptRuns(limit:)` now also publishes `promptRunStats` for the same recent-window limit.
- Settings AI audit summary now displays recent failure rate, empty result rate, and user denial rate when stats are available.
- Focused PromptRun stats tests passed with 2 tests and 0 failures.
- `PersistenceCoreTests` passed with 64 tests and 0 failures.
- Focused AppStore PromptRun audit/stats test passed with 1 test and 0 failures.
- `AppStoreStateMachineTests` passed with 199 tests and 0 failures.
- Full `MingSiTests` passed with 426 tests and 0 failures.
- Full `MingSiUITests` passed with 2 tests and 0 failures.
- iPhone 17 simulator build succeeded.
- `git diff --check`: exit 0, no output.

Residual risk:

- User denial feedback is now persisted and counted at the PromptRun audit layer, but there is not yet a first-class UI action for users to deny every PromptRun directly.
- Empty result classification currently uses persisted error text containing `emptyResult` / `empty result`; a future typed error classification would be stronger.
- Fixed eval suites still exist only as XCTest fixtures; first-class eval runner/history and release gates remain open.
- Full legacy `[String: String]` payload removal and principle recall feedback remain open.
- Live GLM confirmation still requires a real BYOK key and user-approved external network-call window.

## 2026-06-08: Subtask 079 Prompt Asset Audit Versions

Scope:

- Start the post-MVP Prompt / Context assetization track.
- Add prompt asset metadata to local prompt templates: system policy version, context policy version, eval suite version, and optional rollback target.
- Persist those versions through `PromptTracingLLMClient` into `PromptRun` / `prompt_runs`.
- Keep legacy PromptRun records readable and protect partial migration fixtures.
- Preserve existing PromptProvider / LLMClient / parser / SwiftUI boundaries.

Changed areas:

- `Sources/Services/CoreProtocols.swift`
- `Sources/Domain/Models.swift`
- `Sources/Services/PersistenceCore.swift`
- `Tests/Services/LocalPromptProviderTests.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/LocalPromptProviderTests/testEveryPromptTemplate_exposesVersionedPromptAssetMetadata test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testPromptTracingLLMClient_recordsPromptAssetVersions test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testDataExport_includesSavedDraftAndPromptRun test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/LocalPromptProviderTests -only-testing:MingSiTests/PersistenceCoreTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
git diff --check
```

Result:

- Initial RED failed because `PromptTemplate` had no `systemPolicyVersion`, `contextPolicyVersion`, or `evalSuiteVersion`.
- `PromptTemplate` now carries prompt asset metadata with defaults for existing construction sites.
- `LocalPromptProvider` now emits per-prompt context policy and eval suite version metadata instead of only a single prompt version.
- `PromptTracingLLMClient` records system policy, context policy, eval suite, and rollback target versions into `PromptRun`.
- `prompt_runs` now has `system_policy_version`, `context_policy_version`, `eval_suite_version`, and `rollback_target_version` columns through v12 migration; fresh v1 tables include the columns directly.
- The v12 migration now no-ops when a partial migration fixture does not contain `prompt_runs`, preserving existing migration tests for custom lens fields.
- Data export includes the new PromptRun asset-version columns.
- `LocalPromptProviderTests` plus `PersistenceCoreTests` passed with 69 tests and 0 failures.
- Full `MingSiTests` passed with 423 tests and 0 failures.
- Full `MingSiUITests` passed with 2 tests and 0 failures.
- iPhone 17 simulator build succeeded.
- `git diff --check`: exit 0, no output.

Residual risk:

- This is the first Prompt Asset audit slice, not the full asset platform.
- Fixed eval suites still exist only as XCTest fixtures; there is not yet a first-class eval runner, score history, or release gate.
- Failure rate, empty result rate, and user denial rate statistics are not implemented yet.
- Remaining legacy `[String: String]` payload compatibility is still present; full migration to structured `PromptContextPayload` remains open.
- Live GLM confirmation still requires a real BYOK key and user-approved external network-call window.

## 2026-06-08: Subtask 078 MingSi UI Test Driver

Scope:

- Convert the post-MVP Today action-driving prerequisite from "stable identifiers exist" into a real XCTest UI automation path.
- Add a `MingSiUITests` target to the shared `MingSi` scheme.
- Prove XCTest can launch the Debug visual QA Today seed, locate existing accessibility identifiers, tap/type into the rendered iOS app, and observe enabled primary actions.
- Preserve product behavior, state-machine semantics, prompt/LLM boundaries, persistence, and existing 077 Lens/Data Export work.

Changed areas:

- `MingSi.xcodeproj/project.pbxproj`
- `MingSi.xcodeproj/xcshareddata/xcschemes/MingSi.xcscheme`
- `Tests/UI/MingSiUITests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests/MingSiUITests/testTodayReviewCardsSeedExposesActionAndCardControls test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests/MingSiUITests/testTodayAnswerQuestionsSeedCanTypeThroughAccessibilityIdentifier test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
git diff --check
```

Result:

- Initial RED failed because `MingSiUITests` was not a member of the `MingSi` scheme.
- Added a UI test target and explicit shared scheme membership for `MingSiTests` and `MingSiUITests`.
- `testTodayReviewCardsSeedExposesActionAndCardControls` proves XCTest can launch the seeded rendered Today ReviewCards state and find `today.primary-action`, `today.card.confirm-action`, and `today.card.exclude-action`.
- `testTodayAnswerQuestionsSeedCanTypeThroughAccessibilityIdentifier` initially exposed SwiftUI's duplicated `TextField` / `TextView` accessibility match for vertical text fields; the UI test now uses the first matching element and proves tap + `typeText` work against `today.question.answer-field`.
- Full `MingSiUITests` passed with 2 tests and 0 failures.
- Unit `MingSiTests` passed with 421 tests and 0 failures.
- iPhone 17 simulator build succeeded.
- `git diff --check`: exit 0, no output.

Residual risk:

- This closes the local "need an iOS-accessibility-aware action driver or UI Test target" prerequisite for Today rendered automation.
- It does not yet prove a full end-to-end Today -> History -> Project/Growth UI walkthrough; the new target is the driver foundation for that next slice.
- Live GLM failure/success confirmation remains externally blocked until a real BYOK key is configured and an external network-call window is approved.

## 2026-06-07: Subtask 076 Today Primary-Action Prerequisite Guidance

Scope:

- Keep MVP acceptance closed while improving post-MVP operation flow smoothness in Today.
- Prevent the bottom primary action from feeling clickable when the current step is missing required prerequisites.
- Preserve existing Today state-machine guards, persistence, prompt, LLM, History, Projects, Growth, and Settings semantics.

Changed areas:

- `Sources/App/AppStore.swift`
- `Sources/Features/Today/TodayView.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testTodayPrimaryActionBlockerExplainsMissingPrerequisites test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testTodayPrimaryActionBlockerExplainsMissingPrerequisites -only-testing:MingSiTests/AppStoreStateMachineTests/testTodayAutomationIdentifiers_areStableForRenderedWalkthroughControls test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
git diff --check
```

Result:

- Initial RED failed with `Value of type 'AppStore' has no member 'todayPrimaryActionBlocker'`, proving the new prerequisite-guidance contract was absent.
- Added `todayPrimaryActionBlocker` as a pure AppStore-derived state for Today prerequisites.
- Today action row now disables the primary action when prerequisites are missing and shows a stable, low-noise hint with automation id `today.primary-action-hint`.
- Focused GREEN passed with 2 tests and 0 failures.
- Full `AppStoreStateMachineTests` passed with 186 tests and 0 failures.
- `git diff --check`: exit 0, no output.

Residual risk:

- This is a source/test polish slice only; no new rendered simulator screenshot was captured for the disabled-button hint.
- The external live-GLM and rendered action-driving prerequisites remain post-MVP follow-up items.

## 2026-06-07: Final MVP Acceptance Clarification

Scope:

- Address skeptical Oracle verification blockers after the loop rejected a premature `<promise>DONE</promise>`.
- Independently verify Subtask 073 Project Detail bottom-scroll screenshots rather than relying only on doc claims.
- Clarify that live GLM confirmation and rendered Today action-driving are post-MVP external prerequisites, not current MVP blockers.

Changed areas:

- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands and checks run:

```text
Image analysis: docs/subtasks/screenshots/073-project-detail-bottom-scroll-reserve/09-project-detail-minimal-bottom-reserve-scrolled-light.png
Image analysis: docs/subtasks/screenshots/073-project-detail-bottom-scroll-reserve/10-project-detail-minimal-bottom-reserve-scrolled-dark.png
```

Result:

- Independent light screenshot analysis confirms the final Evidence Timeline row is fully visible above the floating tab bar with clear reserve space.
- Independent dark screenshot analysis confirms the same Project Detail bottom-scroll reserve condition in dark mode.
- `docs/mvp-stage-progress.md` now records MVP acceptance as complete and moves the remaining live GLM / rendered action-driving gaps under post-MVP external prerequisites.
- The remaining external prerequisites require a real BYOK key/network approval or an iOS-accessibility-aware action driver / UI Test target; their absence is documented and non-blocking for MVP acceptance.

Residual risk:

- Live GLM evidence still cannot be produced without user-provided BYOK credentials and an approved external network-call window.
- Rendered Today action-driving still requires tooling that can actuate iOS accessibility identifiers directly.

## 2026-06-07: Subtask 075 Live GLM Acceptance Preflight

Scope:

- Verify whether the current booted iPhone 17 simulator has a real BYOK GLM configuration available for safe live GLM confirmation.
- Avoid exposing secrets and avoid fabricating live model evidence.
- Preserve app data while installing the latest Debug build.

Changed areas:

- `docs/subtasks/screenshots/075-live-glm-acceptance-check/`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcrun simctl install booted /Users/chenzewei/Library/Developer/Xcode/DerivedData/MingSi-gjyhvrbegnakhuawwtmljadsxwwc/Build/Products/Debug-iphonesimulator/MingSi.app
SIMCTL_CHILD_MINGSI_VISUAL_QA_TAB=settings xcrun simctl launch --terminate-running-process booted com.codex.mingsi MINGSI_VISUAL_QA_TAB
xcrun simctl io booted screenshot docs/subtasks/screenshots/075-live-glm-acceptance-check/01-settings-normal-persisted-byok-status-light.png
```

Result:

- Normal Settings launch preserved app data and did not use the Debug Settings audit-proof fixture.
- Screenshot shows `尚未配置 GLM API Key` and no recent AI call audit rows.
- Live GLM confirmation was not run because no real BYOK key is configured in this simulator state.

Residual risk:

- Live GLM failure/success confirmation remains externally blocked until a real BYOK key is configured and an external network-call window is approved.
- This preflight proves the blocker; it is not live GLM model evidence.

## 2026-06-07: Subtask 074 Today Rendered Walkthrough Automation Hooks

Scope:

- Add stable accessibility identifiers for existing Today controls needed by rendered walkthrough automation.
- Avoid visual, layout, state-machine, persistence, prompt, LLM, or product-semantic changes.
- Re-test the real iPhone 17 rendered review-cards surface and document whether host automation can now actuate the primary action.

Changed areas:

- `Sources/Features/Today/TodayView.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/subtasks/screenshots/074-today-rendered-walkthrough-automation/`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testTodayAutomationIdentifiers_areStableForRenderedWalkthroughControls test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
git diff --check
SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_INPUT='今天用自动化确认 Today 主按钮可继续流程。' SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_STAGE=review_cards_confirmed xcrun simctl launch --terminate-running-process booted com.codex.mingsi MINGSI_VISUAL_QA_TODAY_INPUT MINGSI_VISUAL_QA_TODAY_STAGE
xcrun simctl io booted screenshot docs/subtasks/screenshots/074-today-rendered-walkthrough-automation/01-review-cards-before-primary-action.png
osascript -e 'tell application "System Events" to tell process "Simulator" to get name of UI elements of window 1'
osascript -e 'tell application "Simulator" to activate' -e 'delay 0.2' -e 'tell application "System Events" to click at {1569, 852}'
xcrun simctl io booted screenshot docs/subtasks/screenshots/074-today-rendered-walkthrough-automation/06-after-system-events-primary-click.png
```

Result:

- Focused RED failed before implementation with `cannot find 'TodayAutomationID' in scope`.
- After adding `TodayAutomationID` and applying identifiers to existing controls, the focused test passed with 1 test and 0 failures.
- `AppStoreStateMachineTests` passed with 185 tests and 0 failures.
- Full MingSi test suite passed with 402 tests and 0 failures.
- `lsp_diagnostics` returned no diagnostics for `Sources/Features/Today/TodayView.swift` and `Tests/App/AppStoreStateMachineTests.swift`.
- iPhone 17 simulator build: `BUILD SUCCEEDED`.
- `git diff --check`: exit 0, no output.
- Real iPhone 17 screenshots show the seeded ReviewCards state before action and the unchanged state after host System Events click, confirming the host-click blocker remains in this environment.

Residual risk:

- This slice provides stable identifiers for a real UI-test or accessibility-aware automation tool, but macOS `System Events` and coordinate injection still cannot actuate the iOS primary action through the local Simulator host.
- The remaining rendered Today walkthrough gap requires a tool that can target iOS accessibility identifiers directly, or a proper UI Test target.

## 2026-06-07: Subtask 073 Project Detail Bottom-Scroll Reserve Proof

Scope:

- Close the residual Project Detail floating-tab reserve evidence gap from Subtask 058.
- Capture real iPhone 17 simulator proof without source changes.

Changed areas:

- `docs/subtasks/screenshots/073-project-detail-bottom-scroll-reserve/`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
SIMCTL_CHILD_MINGSI_VISUAL_QA_PROJECT_DETAIL=1 SIMCTL_CHILD_MINGSI_VISUAL_QA_PROJECT_DETAIL_VARIANT=long_timeline xcrun simctl launch --terminate-running-process booted com.codex.mingsi MINGSI_VISUAL_QA_PROJECT_DETAIL
xcrun simctl io booted screenshot docs/subtasks/screenshots/073-project-detail-bottom-scroll-reserve/01-project-detail-long_timeline-top-light.png
SIMCTL_CHILD_MINGSI_VISUAL_QA_PROJECT_DETAIL=1 SIMCTL_CHILD_MINGSI_VISUAL_QA_PROJECT_DETAIL_VARIANT=minimal xcrun simctl launch --terminate-running-process booted com.codex.mingsi MINGSI_VISUAL_QA_PROJECT_DETAIL
xcrun simctl io booted screenshot docs/subtasks/screenshots/073-project-detail-bottom-scroll-reserve/09-project-detail-minimal-bottom-reserve-scrolled-light.png
xcrun simctl ui booted appearance dark
xcrun simctl io booted screenshot docs/subtasks/screenshots/073-project-detail-bottom-scroll-reserve/10-project-detail-minimal-bottom-reserve-scrolled-dark.png
git diff --check
```

Result:

- Top reference screenshot captured for the long-timeline Project Detail fixture.
- Final light screenshot shows the minimal Project Detail Evidence Timeline row fully above the floating tab bar with visible bottom reserve.
- Final dark screenshot shows the same bottom reserve condition in dark mode.
- No Swift source files changed for this screenshot-only proof slice.

Residual risk:

- Host scroll automation was unreliable on the long-timeline fixture, so the accepted bottom-reserve proof uses the shorter minimal fixture to reach the content end deterministically.
- This is rendered visual evidence only; no new production behavior was introduced.

## 2026-06-07: Subtask 072 Settings BYOK/PromptRun Rendered Proof

Scope:

- Capture rendered Settings proof for unconfigured and configured GLM BYOK states on a real iPhone 17 simulator.
- Prove configured Settings can show GLM connection failure copy plus PromptRun audit grouping without real credentials or network calls.
- Keep production Settings semantics, persistence schema, LLM clients, Keychain storage, prompt templates, Today/History/Projects/Growth behavior, and Release builds unchanged.

Changed areas:

- `Sources/App/AppStore.swift`
- `Sources/App/MingSiApp.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/subtasks/screenshots/072-settings-byok-promptrun-rendered-proof/`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQASettingsAuditProof_appliesSettingsFailureAuditState test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQASettingsAuditProof_loadRecentPromptRunsKeepsFixtureRows test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQASettingsAuditProof_appliesSettingsFailureAuditState -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQASettingsAuditProof_withoutFlagDoesNothing -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQASettingsAuditProof_readsSimctlChildFlag -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQASettingsAuditProof_preventsProjectDetailFixtureMarker -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQASettingsAuditProof_loadRecentPromptRunsKeepsFixtureRows test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
git diff --check
xcrun simctl uninstall booted com.codex.mingsi
xcrun simctl install booted /Users/chenzewei/Library/Developer/Xcode/DerivedData/MingSi-gjyhvrbegnakhuawwtmljadsxwwc/Build/Products/Debug-iphonesimulator/MingSi.app
SIMCTL_CHILD_MINGSI_VISUAL_QA_SETTINGS_AUDIT_PROOF=1 xcrun simctl launch --terminate-running-process booted com.codex.mingsi MINGSI_VISUAL_QA_SETTINGS_AUDIT_PROOF
xcrun simctl io booted screenshot docs/subtasks/screenshots/072-settings-byok-promptrun-rendered-proof/02-settings-audit-proof-light.png
xcrun simctl ui booted appearance dark
xcrun simctl io booted screenshot docs/subtasks/screenshots/072-settings-byok-promptrun-rendered-proof/03-settings-audit-proof-dark.png
```

Result:

- Fresh unconfigured Settings screenshot captured at `docs/subtasks/screenshots/072-settings-byok-promptrun-rendered-proof/01-settings-unconfigured-light.png`.
- Initial focused RED confirmed the fixture APIs were absent: `Value of type AppStore has no member applyVisualQASettingsAuditProof`.
- Lifecycle RED confirmed the rendered proof bug: after `loadRecentPromptRuns()`, `recentPromptRuns.first` was nil and the audit list returned to empty.
- After the Debug-only fixture and sticky lifecycle guard, the 5 focused Settings audit proof tests passed with 0 failures.
- Full `AppStoreStateMachineTests` passed with 184 tests and 0 failures.
- Full MingSi test suite passed with 401 tests and 0 failures.
- iPhone 17 simulator build: `BUILD SUCCEEDED`.
- `git diff --check`: exit 0, no output.
- Final light/dark screenshots show Settings selected, configured GLM API status, connection failure copy, and PromptRun audit summary/grouping.

Residual risk:

- This proves rendered Settings BYOK/PromptRun audit behavior through a Debug-only visual QA fixture, not a live GLM network request.
- Live BYOK success/failure confirmation still requires a real user-provided API key and safe external-call window.

## 2026-06-07: Subtask 071 Settings Connection Audit Visibility

Scope:

- Ensure Settings connection tests refresh the user-visible PromptRun audit list after completion.
- Prove the connection test PromptRun is visible without requiring a manual audit refresh tap.
- Keep LLM client construction, PromptRun persistence schema, Keychain storage, prompt templates, Settings layout, and Project/Growth semantics unchanged.

Changed areas:

- `Sources/App/AppStore.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testGLMConnectionRefreshesPromptRunAuditAfterCompletion test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
git diff --check
```

Result:

- Focused RED confirmed before implementation: connection test finished but `recentPromptRuns` stayed empty until manual reload.
- After the AppStore completion-path fix, the focused test passed with 1 test and 0 failures.
- Full `AppStoreStateMachineTests` passed with 179 tests and 0 failures.
- `HistoryFeatureTests` passed with 71 tests and 0 failures.
- iPhone 17 simulator build: `BUILD SUCCEEDED`.
- `git diff --check`: exit 0, no output.

Residual risk:

- This is state-machine evidence, not a rendered Settings screenshot.
- The focused test uses the missing-key audited client path to avoid network calls and to avoid touching the user's real Keychain service.

## 2026-06-07: Subtask 070 Settings/Growth AI Service Refresh

Scope:

- Fix Settings BYOK refresh so Growth weekly/monthly reports use the current Keychain/Base URL/model configuration after Settings changes.
- Reuse the same audited `makeLLMClient` boundary for Growth AI service creation as Today AI service creation.
- Keep SwiftUI views, persistence schema, migrations, PromptProvider, DirectGLMClient behavior, Growth prompt semantics, and Project/Growth evidence rules unchanged.

Changed areas:

- `Sources/App/AppStore.swift`
- `Sources/Services/KeychainAPIKeyStore.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testKeychainRefreshRoutesGrowthReportsThroughAuditedMissingKeyClient test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
git diff --check
```

Result:

- Focused RED confirmed before implementation: after `refreshAIServiceFromKeychainIfNeeded()`, Growth report generation still returned `Growth AI service unavailable` instead of routing through an audited GLM client.
- After the AppStore refresh fix, the focused test passed with 1 test and 0 failures.
- Full `AppStoreStateMachineTests` passed with 178 tests and 0 failures.
- `HistoryFeatureTests` passed with 71 tests and 0 failures.
- iPhone 17 simulator build: `BUILD SUCCEEDED`.
- `git diff --check`: exit 0, no output.

Residual risk:

- This proves the missing-key/audit route and service refresh boundary, not a successful live GLM Growth report with a real API key.
- The test uses an isolated Keychain service name to avoid contaminating the user's real BYOK credentials.

## 2026-06-07: Subtask 069 Project/Growth Evidence Chain Hardening

Scope:

- Add Project Detail Principles evidence display only for principle ProjectLinks that resolve to real History `PrincipleAsset` evidence.
- Degrade persisted Growth snapshots to insufficient evidence when they claim displayable scores but no accepted/source-linked MetricContribution records resolve.
- Let Growth project-source drilldowns locate and highlight matching History project evidence rows.
- Ensure inaccurate/dismissed Growth contribution feedback from the latest snapshot enters the next weekly/monthly Growth AI context.

Changed areas:

- `Sources/App/AppStore.swift`
- `Sources/Domain/Models.swift`
- `Sources/Features/FeatureTabs.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `Tests/Features/HistoryFeatureTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testGenerateWeeklyGrowthReport_includesDismissedContributionFeedbackFromLatestSnapshot test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
git diff --check
```

Result:

- Focused Growth feedback-context test first failed as expected: `dismissed_contributions` was nil and structured Growth context contained an empty dismissed list.
- After the AppStore context fix, the focused test passed with 1 test and 0 failures.
- Full `AppStoreStateMachineTests` passed with 177 tests and 0 failures.
- `HistoryFeatureTests` passed with 71 tests and 0 failures.
- iPhone 17 simulator build: `BUILD SUCCEEDED`.
- `git diff --check`: exit 0, no output.

Residual risk:

- This is build/test evidence, not rendered screenshot evidence for the new Project Principles section or project-evidence highlight state.
- This does not prove live GLM output quality; it proves the app now passes prior user feedback into the Growth AI request context.

## 2026-06-07: Subtask 068 Production Project And Growth Evidence Chain Proof

Scope:

- Prove production Today evidence reloaded into History can continue into user-confirmed Project links and local Growth attribution.
- Use SQLite repositories and the normal AppStore Today state machine, not Debug visual QA seed state.
- Seed only enough historical verified loops to satisfy the existing Growth complete-loop threshold.
- Keep production source, persistence schema, migrations, PromptProvider, parser, LLM clients, Keychain, SwiftUI views, Debug visual QA behavior, and product semantics unchanged.

Changed areas:

- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/subtasks/068-production-project-growth-evidence-chain-prd.md`
- `docs/subtasks/068-production-project-growth-evidence-chain-progress.md`
- Process docs for stage progress, verification, delegation, continuation context, and current Claude status.

Commands run:

```bash
git status --short
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testProductionTodayEvidence_canBackProjectLinkAndGrowthContributionsThroughHistoryReload test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

- First focused run failed at compile because the new test helper used obsolete type names `QuestCompletion` and `QuestValueRating`; the current domain types are `YesterdayCompletion` and `YesterdayValueRating`.
- Focused 068 test passed after the test helper type correction: 1 test, 0 failures.
- Full `AppStoreStateMachineTests` passed with 175 tests and 0 failures.
- `git diff --check`: exit 0, no output.
- iPhone 17 simulator build: `BUILD SUCCEEDED`.
- The proof test drives Today through the normal production state machine using SQLite repositories.
- A fresh `AppStore` reloads History and verifies raw input, first-principles lens session, main quest, and source-linked Growth contributions for the completed DailyEntry.
- The test creates a Project from the reloaded History quest through `createProjectFromQuest`, then reloads History again through another fresh `AppStore`.
- The final reload verifies the ProjectLink points to the real quest source id, `projectNames` resolves the created Project name, and Growth contributions still point to source ids present in the History record.
- No production source change was required after the proof test reached runtime.

Residual risk:

- This is not live GLM proof because the test path uses local/test AI behavior.
- This does not prove AI-generated ProjectInsights or AI Growth reports.
- This does not add rendered simulator screenshot evidence.

## 2026-06-07: Subtask 067 Production History Persistence Proof

Scope:

- Prove the production Today completion path persists into SQLite and can reload into History through repository abstractions.
- Use the normal AppStore Today state machine, not Debug visual QA seed state.
- Keep persistence schema, migrations, PromptProvider, parser, LLM clients, Keychain, SwiftUI views, Projects, Growth, Settings, and product semantics unchanged.
- Include the scoped AppStore persistence-ordering fix that the proof test exposed.

Changed areas:

- `Sources/App/AppStore.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/subtasks/067-production-history-persistence-proof-prd.md`
- `docs/subtasks/067-production-history-persistence-proof-progress.md`
- Process docs for stage progress, verification, delegation, continuation context, and current Claude status.

Commands run:

```bash
git status --short
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testProductionTodayCompletion_persistsHistoryEvidenceThroughSQLiteReload test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

- Focused 067 test passed with 1 test and 0 failures.
- Full `AppStoreStateMachineTests` passed with 174 tests and 0 failures.
- `git diff --check`: exit 0, no output.
- iPhone 17 simulator build: `BUILD SUCCEEDED`.
- The proof test drives Today through VerifyYesterday, Capture, Organizing, ReviewCards, SelectLens, AnswerQuestions, ReviewQuests, ExtractPrinciple, and SessionComplete using SQLite repositories.
- The proof test exposed a production AppStore persistence ordering race. Today local persistence writes are now queued before History/Growth refresh so older snapshots cannot overwrite newer confirmed evidence.
- A fresh `AppStore` using the same repositories reloads History and verifies raw input, `sessionComplete`, 3 confirmed cards, first-principles lens session, at least one answered lens question, main quest, principle evidence, and the completed DailyEntry source id.

Residual risk:

- This is not live GLM proof because the test path uses local fallback in the test environment.
- This does not add rendered screenshots; Subtask 066 already covers deterministic rendered Today/History first-viewport evidence through Debug visual QA.
- This does not prove Projects/Growth cross-feature attribution beyond Today -> History archive reload.

## 2026-06-07: Subtask 066 Today Session Complete History Seed

Scope:

- Add a Debug-only `session_complete` Today stage seed so rendered iPhone 17 visual QA can reach Today `SessionComplete` and History archive evidence without host coordinate clicks.
- Keep Release behavior, persistence schema, migrations, PromptProvider, parser, LLM clients, Keychain, History, Projects, Growth, Settings, and production Today semantics unchanged.
- Verify that the Debug-seeded History archive exposes raw input, confirmed cards, first-principles lens questions, quests, and a principle candidate while visibly marking local fallback.

Changed areas:

- `Sources/App/AppStore.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/subtasks/066-today-session-complete-history-seed-prd.md`
- `docs/subtasks/066-today-session-complete-history-seed-progress.md`
- `docs/subtasks/screenshots/066-today-session-complete-history-seed/*.png`
- Process docs for stage progress, verification, delegation, continuation context, and current Claude status.

Commands run:

```bash
git status --short
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodayStageSeed_sessionCompleteSeedsHistoryArchiveAndHonorsHistoryTab test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -project MingSi.xcodeproj -scheme MingSi -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17' build
xcrun simctl uninstall booted com.codex.mingsi
xcrun simctl install booted /Users/chenzewei/Library/Developer/Xcode/DerivedData/MingSi-erjzdsaapaoobtcrmiwnfyqrwdqr/Build/Products/Debug-iphonesimulator/MingSi.app
SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_INPUT='今天要把会议目标拆成一个可以明天验证的行动，并沉淀一个可复用原则。' SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_MODE=standard SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_STAGE=session_complete SIMCTL_CHILD_MINGSI_VISUAL_QA_TAB=today xcrun simctl launch --terminate-running-process booted com.codex.mingsi
xcrun simctl io booted screenshot docs/subtasks/screenshots/066-today-session-complete-history-seed/01-today-session-complete.png
SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_INPUT='今天要把会议目标拆成一个可以明天验证的行动，并沉淀一个可复用原则。' SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_MODE=standard SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_STAGE=session_complete SIMCTL_CHILD_MINGSI_VISUAL_QA_TAB=history xcrun simctl launch --terminate-running-process booted com.codex.mingsi
xcrun simctl io booted screenshot docs/subtasks/screenshots/066-today-session-complete-history-seed/02-history-archive.png
```

Result:

- RED focused test failed for the expected reasons before implementation: selected tab stayed `today`, Today state stayed `capture`, and History had no seeded record.
- GREEN focused test passed after implementation.
- Full `AppStoreStateMachineTests` passed with 173 tests and 0 failures.
- `git diff --check`: exit 0, no output.
- Debug iPhone 17 simulator build: `BUILD SUCCEEDED`.
- Release iPhone 17 simulator build: `BUILD SUCCEEDED`.
- Today screenshot shows `今日完成`, local fallback copy, main quest, principle, growth snapshot, and no floating-tab overlap.
- History screenshot shows the seeded completed record summary with raw input evidence and source card evidence visible.

Screenshots:

- `docs/subtasks/screenshots/066-today-session-complete-history-seed/01-today-session-complete.png`
- `docs/subtasks/screenshots/066-today-session-complete-history-seed/02-history-archive.png`

Residual risk:

- This is a Debug-only deterministic visual QA accelerator.
- It does not prove live GLM success.
- It does not prove production SQLite persistence through the real Today completion path; that remains the recommended next product slice.

## 2026-06-06: Subtask 065 Today Completion And History Archive Walkthrough Partial Verification

Scope:

- Use the Subtask 064 Debug-only Today stage seed to launch the rendered iPhone 17 app at `ExtractPrinciple`.
- Attempt to drive the visible `保存原则` action into `SessionComplete`, then inspect History archive evidence.
- Keep Swift source, tests, persistence, migrations, PromptProvider, parser, LLM clients, Keychain, History, Projects, Growth, Settings, and Today product semantics unchanged.

Changed areas:

- `docs/subtasks/065-today-completion-history-archive-walkthrough-prd.md`
- `docs/subtasks/065-today-completion-history-archive-walkthrough-progress.md`
- `docs/subtasks/screenshots/065-today-completion-history-archive-walkthrough/*.png`
- Process docs for stage progress, verification, delegation, continuation context, and current Claude status.

Commands run:

```bash
git status --short
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
xcrun simctl uninstall booted com.codex.mingsi
xcrun simctl install booted /Users/chenzewei/Library/Developer/Xcode/DerivedData/MingSi-erjzdsaapaoobtcrmiwnfyqrwdqr/Build/Products/Debug-iphonesimulator/MingSi.app
SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_INPUT='今天要把会议目标拆成一个可以明天验证的行动，并沉淀一个可复用原则。' SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_MODE=standard SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_STAGE=extract_principle SIMCTL_CHILD_MINGSI_VISUAL_QA_TAB=today xcrun simctl launch --terminate-running-process booted com.codex.mingsi
xcrun simctl io booted screenshot docs/subtasks/screenshots/065-today-completion-history-archive-walkthrough/<state>.png
osascript / System Events coordinate interaction against Simulator
git diff --check
```

Result:

- First rendered capture after launch was blank:
  - `docs/subtasks/screenshots/065-today-completion-history-archive-walkthrough/01-extract-principle.png`
  - `docs/subtasks/screenshots/065-today-completion-history-archive-walkthrough/01b-extract-principle-after-wait.png`
- Relaunch with the same environment rendered `原则沉淀` correctly:
  - `docs/subtasks/screenshots/065-today-completion-history-archive-walkthrough/02-extract-principle-relaunch.png`
- The rendered screen shows the Debug/local fallback warning, principle candidate content, and visible `保存原则` action.
- Host AppleScript/System Events automation could not click `保存原则`: `System Events` raised error `-25208`, could see the Simulator process as frontmost/visible, but reported no usable Simulator windows.
- `xcrun simctl` has no tap/click operation and `cliclick` is not installed.
- `git diff --check`: exit 0, no output.

Screenshots:

- `docs/subtasks/screenshots/065-today-completion-history-archive-walkthrough/01-extract-principle.png`
- `docs/subtasks/screenshots/065-today-completion-history-archive-walkthrough/01b-extract-principle-after-wait.png`
- `docs/subtasks/screenshots/065-today-completion-history-archive-walkthrough/02-extract-principle-relaunch.png`

Residual risk:

- This is not full Today completion or History archive acceptance.
- `SessionComplete`, History archive evidence, live GLM success, and Projects/Growth evidence-chain proof remain unverified in the rendered app.
- Recommended next slice: add a narrow Debug-only completion/history archive launch path or action seed, then repeat rendered verification without macOS coordinate clicks.

## 2026-06-06: Subtask 064 Today Debug Stage Seed

Scope:

- Add a Debug-only Today stage seed so rendered iPhone 17 visual QA can continue after the Subtask 063 card-confirmation automation blocker.
- Preserve Release behavior and keep persistence, migrations, PromptProvider, parser, LLM clients, Keychain, History, Projects, Growth, Settings, and Today product semantics unchanged.
- Verify that SelectLens, AnswerQuestions, ReviewQuests, and ExtractPrinciple render from stage seed with visible local fallback messaging.

Changed areas:

- `Sources/App/AppStore.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/subtasks/064-today-debug-stage-seed-prd.md`
- `docs/subtasks/064-today-debug-stage-seed-progress.md`
- `docs/subtasks/screenshots/064-today-debug-stage-seed/*.png`
- Process docs for stage progress, verification, delegation, continuation context, and current Claude status.

Commands run:

```bash
git status --short
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodayStageSeed_selectLensSeedsConfirmedFallbackCards -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodayStageSeed_withoutInputDoesNothing -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodayStageSeed_readsSimctlChildStage -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodayStageSeed_answerQuestionsSeedsLensQuestions -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodayStageSeed_reviewQuestsSeedsAnsweredQuestionsAndQuests -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodayStageSeed_extractPrincipleSeedsQuestsAndPrinciple test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -project MingSi.xcodeproj -scheme MingSi -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17' build
xcrun simctl uninstall booted com.codex.mingsi
xcrun simctl install booted /Users/chenzewei/Library/Developer/Xcode/DerivedData/MingSi-erjzdsaapaoobtcrmiwnfyqrwdqr/Build/Products/Debug-iphonesimulator/MingSi.app
SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_INPUT='今天要把会议目标拆成一个可以明天验证的行动，并沉淀一个可复用原则。' SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_MODE=standard SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_STAGE=<stage> SIMCTL_CHILD_MINGSI_VISUAL_QA_TAB=today xcrun simctl launch --terminate-running-process booted com.codex.mingsi
xcrun simctl io booted screenshot docs/subtasks/screenshots/064-today-debug-stage-seed/<stage>.png
```

Result:

- RED test failed for the expected reason: stage seed was ignored and Today stayed at `capture`.
- Focused 064 tests passed: 6 tests, 0 failures.
- Full `AppStoreStateMachineTests` passed: 172 tests, 0 failures.
- `git diff --check`: exit 0, no output.
- Debug iPhone 17 simulator build: `BUILD SUCCEEDED`.
- Release iPhone 17 simulator build: `BUILD SUCCEEDED`.
- Real iPhone 17 simulator screenshots show SelectLens, AnswerQuestions, ReviewQuests, and ExtractPrinciple rendered from stage seed.
- Each rendered seeded stage shows visible Debug/local fallback copy and does not represent AI success.

Screenshots:

- `docs/subtasks/screenshots/064-today-debug-stage-seed/select_lens.png`
- `docs/subtasks/screenshots/064-today-debug-stage-seed/answer_questions.png`
- `docs/subtasks/screenshots/064-today-debug-stage-seed/review_quests.png`
- `docs/subtasks/screenshots/064-today-debug-stage-seed/extract_principle.png`

Residual risk:

- This does not verify live GLM success because the simulator has no API Key configured.
- This does not prove final Today completion persistence into History or Projects/Growth evidence chains.
- This is a Debug-only visual QA accelerator, not a production user feature.

## 2026-06-06: Subtask 063 Today Rendered Post-Card Walkthrough Partial Verification

Scope:

- Use the Subtask 062 Debug-only Today seed path to continue rendered iPhone 17 walkthrough evidence after `思考卡片`.
- Verify whether ReviewCards can be driven into SelectLens through host Simulator automation.
- Keep Swift source, tests, persistence, migrations, PromptProvider, parser, LLM clients, Keychain, and product semantics unchanged.

Changed areas:

- `docs/subtasks/063-today-rendered-post-card-walkthrough-prd.md`
- `docs/subtasks/063-today-rendered-post-card-walkthrough-progress.md`
- `docs/subtasks/screenshots/063-today-rendered-post-card-walkthrough/*.png`
- Process docs for stage progress, verification, delegation, continuation context, and current Claude status.

Commands run:

```bash
git status --short
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
xcrun simctl uninstall booted com.codex.mingsi
xcrun simctl install booted /Users/chenzewei/Library/Developer/Xcode/DerivedData/MingSi-erjzdsaapaoobtcrmiwnfyqrwdqr/Build/Products/Debug-iphonesimulator/MingSi.app
SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_INPUT='今天需要先明确会议目标。明天要确认一个可以当天完成的行动。' SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_MODE=standard SIMCTL_CHILD_MINGSI_VISUAL_QA_TAB=today xcrun simctl launch --terminate-running-process booted com.codex.mingsi
xcrun simctl io booted screenshot docs/subtasks/screenshots/063-today-rendered-post-card-walkthrough/<state>.png
osascript / System Events coordinate interaction against Simulator
sips -g pixelWidth -g pixelHeight docs/subtasks/screenshots/063-today-rendered-post-card-walkthrough/*.png
git status --short
```

Result:

- Debug iPhone 17 simulator build: `BUILD SUCCEEDED`.
- Rendered Today reached `今日输入` with seeded raw input after relaunch.
- Rendered Today reached `整理中` with missing API Key failure visible, local fallback clearly marked, repair banner visible, and `查看卡片` available.
- Rendered Today reached `思考卡片` / ReviewCards with fallback cards and bottom `确认卡片` action.
- Host coordinate clicks did not reliably toggle card-level `确认`; the bottom action showed `至少确认一张卡片，才能进入思考透镜选择。`
- AppleScript accessibility enumeration failed to provide a reliable nested Simulator button-click path.

Screenshots:

- `docs/subtasks/screenshots/063-today-rendered-post-card-walkthrough/02-returned-today.png`
- `docs/subtasks/screenshots/063-today-rendered-post-card-walkthrough/03-organizing-or-review.png`
- `docs/subtasks/screenshots/063-today-rendered-post-card-walkthrough/04-review-cards.png`
- `docs/subtasks/screenshots/063-today-rendered-post-card-walkthrough/06-after-confirm-cards.png`

Residual risk:

- This is not full rendered Today post-card walkthrough acceptance.
- SelectLens, AnswerQuestions, ReviewQuests, ExtractPrinciple, and live GLM success remain unverified in the rendered app.
- Recommended next slice: add a narrow Debug-only Today stage seed or stable UI automation path, then continue screenshot verification from confirmed cards onward.

## 2026-06-06: Subtask 062 Today Debug Seed Input

Scope:

- Add a Debug-only Today launch seed so the iPhone 17 rendered Today walkthrough can bypass unreliable Simulator text input automation.
- Preserve Release behavior and keep persistence, migrations, PromptProvider, parser, LLM clients, Keychain, History, Projects, Growth, Settings, and Today AI semantics unchanged.
- Verify that seeded input can render in Today, trigger local fallback card organization, and reach ReviewCards on a real iPhone 17 simulator.

Changed areas:

- `Sources/App/AppStore.swift`
- `Sources/App/MingSiApp.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/subtasks/062-today-debug-seed-input-prd.md`
- `docs/subtasks/062-today-debug-seed-input-progress.md`
- `docs/subtasks/screenshots/062-today-debug-seed-input/*.png`
- Process docs for stage progress, verification, delegation, and current Claude status.

Commands run:

```bash
git status --short
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodaySeedInput_appliesCaptureTextModeAndSkipsPersistedLoad -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodaySeedInput_withoutInputDoesNotChangeNormalLaunchState test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodaySeedInput_appliesCaptureTextModeAndSkipsPersistedLoad -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodaySeedInput_withoutInputDoesNotChangeNormalLaunchState -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodaySeedInput_readsSimctlChildEnvironmentAndDefaultsUnknownMode -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodaySeedInput_preventsProjectDetailFixtureMarker test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -project MingSi.xcodeproj -scheme MingSi -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17' build
git diff --check
xcrun simctl uninstall booted com.codex.mingsi
xcrun simctl install booted /Users/chenzewei/Library/Developer/Xcode/DerivedData/MingSi-erjzdsaapaoobtcrmiwnfyqrwdqr/Build/Products/Debug-iphonesimulator/MingSi.app
SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_INPUT='今天需要先明确会议目标。明天要确认一个可以当天完成的行动。' SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_MODE=standard SIMCTL_CHILD_MINGSI_VISUAL_QA_TAB=today xcrun simctl launch --terminate-running-process booted com.codex.mingsi
xcrun simctl io booted screenshot docs/subtasks/screenshots/062-today-debug-seed-input/<state>.png
osascript / System Events coordinate interaction against Simulator
```

Result:

- RED test failed for the expected reason: `AppStore` had no `applyVisualQATodaySeed`.
- Focused 062 tests passed: 4 tests, 0 failures.
- Full `AppStoreStateMachineTests` passed: 166 tests, 0 failures.
- Debug iPhone 17 simulator build: `BUILD SUCCEEDED`.
- Release iPhone 17 simulator build: `BUILD SUCCEEDED`, confirming the Debug-only launch code does not leak into Release behavior.
- `git diff --check`: exit 0, no output.
- Real iPhone 17 simulator launch with Today seed showed `今日输入`, `Standard`, and the seeded raw input.
- Clicking the main Today action advanced into `整理中`, where missing API Key was visibly reported, local fallback was clearly marked, and the pending repair banner appeared.
- Clicking `查看卡片` reached `思考卡片` review with generated local fallback cards and confirmation controls.

Screenshots:

- `docs/subtasks/screenshots/062-today-debug-seed-input/01-seeded-capture.png`
- `docs/subtasks/screenshots/062-today-debug-seed-input/02-organizing-fallback.png`
- `docs/subtasks/screenshots/062-today-debug-seed-input/03-review-cards-fallback.png`

Residual risk:

- This does not verify live GLM success in the rendered app because the simulator has no API Key configured.
- This does not complete the full Today -> lens -> quest -> principle -> History/Projects/Growth screenshot walkthrough.
- Coordinate-based Simulator clicking is still brittle; the important 061 blocker, repeatable raw-text entry, is now removed by Debug seed launch.

## 2026-06-06: Subtask 061 Today Core Loop Walkthrough Partial Verification

Scope:

- Start a real iPhone 17 simulator Today walkthrough after Subtask 060 fresh-data root visuals.
- Verify whether the rendered app can move from `验证昨日` into `今日输入`.
- Attempt automated text input into Today capture.
- Cross-check Today logical core-loop and AI failure/retry behavior with focused AppStore tests.
- Keep Swift source, tests, persistence, migrations, PromptProvider, parser, LLM clients, Keychain, and Today semantics unchanged.

Changed areas:

- `docs/subtasks/061-today-core-loop-walkthrough-prd.md`
- `docs/subtasks/061-today-core-loop-walkthrough-progress.md`
- `docs/subtasks/screenshots/061-today-core-loop-walkthrough/*.png`
- Process docs for stage progress, verification, delegation, and current Claude status.

Commands run:

```bash
git status --short
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -showBuildSettings
xcrun simctl uninstall booted com.codex.mingsi
xcrun simctl install booted /Users/chenzewei/Library/Developer/Xcode/DerivedData/MingSi-erjzdsaapaoobtcrmiwnfyqrwdqr/Build/Products/Debug-iphonesimulator/MingSi.app
SIMCTL_CHILD_MINGSI_VISUAL_QA_TAB=today xcrun simctl launch --terminate-running-process booted com.codex.mingsi MINGSI_VISUAL_QA_TAB
xcrun simctl pbcopy booted
xcrun simctl pbpaste booted
osascript / System Events coordinate interaction against Simulator
xcrun simctl io booted screenshot docs/subtasks/screenshots/061-today-core-loop-walkthrough/<state>.png
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testFullLoop_canCompleteWithLocalFallback -only-testing:MingSiTests/AppStoreStateMachineTests/testAIFailure_usesVisibleFallbackAndCanRetrySameStep -only-testing:MingSiTests/AppStoreStateMachineTests/testAIRetryFailure_keepsExistingFallbackWithoutIncreasingRepairCount test
```

Result:

- Debug iPhone 17 simulator build: `BUILD SUCCEEDED`.
- The first install attempt selected an `Index.noindex/.../MingSi.app` product and failed with `Missing bundle ID`; Codex corrected the path through `TARGET_BUILD_DIR` / `WRAPPER_NAME` and installed the real Debug app.
- Fresh Today launch showed `验证昨日`.
- A Simulator coordinate click on the main action advanced the rendered app from `验证昨日` to `今日输入`.
- Simulator pasteboard contained the intended non-sensitive test input, but coordinate click on `粘贴剪贴板` and `Command+V` after focusing controls did not insert text into `CaptureTextView`.
- One `osascript` coordinate-input attempt hung; Codex killed only the just-started `osascript` / zsh pair and verified no owned script process remained.
- Focused AppStore tests passed: 3 tests, 0 failures. Covered full local-fallback Today logical loop, visible AI fallback/retry success, and retry-failure repair count stability.

Screenshots:

- `docs/subtasks/screenshots/061-today-core-loop-walkthrough/01-today-fresh-light.png`
- `docs/subtasks/screenshots/061-today-core-loop-walkthrough/02-after-save-verification.png`
- `docs/subtasks/screenshots/061-today-core-loop-walkthrough/03-after-paste-input.png`
- `docs/subtasks/screenshots/061-today-core-loop-walkthrough/04-after-start-input-command-v.png`

Residual risk:

- This is not full rendered Today UI walkthrough acceptance.
- The app has no UI Test target, host `simctl` has no direct tap/type command, and core Today controls do not expose stable `accessibilityIdentifier`s.
- Live GLM success/failure behavior remains unverified in the rendered app because automated input could not reach card generation.
- Recommended next slice: add a minimal Today testability/accessibility path, then repeat the real iPhone 17 walkthrough.

## 2026-06-06: Subtask 060 Fresh-Data Alpha Root Visual Pass

Scope:

- Repeat the Subtask 059 root-tab Alpha visual pass after clearing the booted iPhone 17 simulator app data container.
- Verify Today, History, Projects, Growth, and Settings first-viewport visuals from a freshly reinstalled Debug app.
- Close the Subtask 059 residual risk that Projects/History screenshots contained prior visual QA fixture evidence.
- Keep Swift source, tests, persistence, migrations, PromptProvider, parser, LLM clients, Keychain, and product semantics unchanged.

Changed areas:

- `docs/subtasks/060-fresh-data-alpha-root-visual-prd.md`
- `docs/subtasks/060-fresh-data-alpha-root-visual-progress.md`
- `docs/subtasks/screenshots/060-fresh-data-alpha-root-visual/*.png`
- Process docs for stage progress, verification, delegation, and current Claude status.

Commands run:

```bash
git status --short
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
xcrun simctl uninstall booted com.codex.mingsi
xcrun simctl install booted /Users/chenzewei/Library/Developer/Xcode/DerivedData/MingSi-erjzdsaapaoobtcrmiwnfyqrwdqr/Build/Products/Debug-iphonesimulator/MingSi.app
SIMCTL_CHILD_MINGSI_VISUAL_QA_TAB=<tab> xcrun simctl launch --terminate-running-process booted com.codex.mingsi MINGSI_VISUAL_QA_TAB
xcrun simctl io booted screenshot docs/subtasks/screenshots/060-fresh-data-alpha-root-visual/<index>-<tab>-<appearance>.png
```

Result:

- Debug iPhone 17 simulator build: `BUILD SUCCEEDED`.
- App data was cleared by uninstalling the app before reinstall.
- Captured 10 fresh-data root-tab screenshots for Today, History, Projects, Growth, and Settings in light/dark mode.
- Projects root shows a clean evidence-gated state with `0 个证据项目` and `尚无长期议题证据`; no prior `Visual QA` fixture project remains.
- History root shows the current date with no stale visual QA evidence.
- Growth dark mode remains readable and evidence-gated.
- Settings dark mode remains readable and shows the fresh-state AI audit copy `还没有 AI 调用记录。`

Screenshots:

- `docs/subtasks/screenshots/060-fresh-data-alpha-root-visual/01-today-light.png`
- `docs/subtasks/screenshots/060-fresh-data-alpha-root-visual/02-history-light.png`
- `docs/subtasks/screenshots/060-fresh-data-alpha-root-visual/03-projects-light.png`
- `docs/subtasks/screenshots/060-fresh-data-alpha-root-visual/04-growth-light.png`
- `docs/subtasks/screenshots/060-fresh-data-alpha-root-visual/05-settings-light.png`
- `docs/subtasks/screenshots/060-fresh-data-alpha-root-visual/06-today-dark.png`
- `docs/subtasks/screenshots/060-fresh-data-alpha-root-visual/07-history-dark.png`
- `docs/subtasks/screenshots/060-fresh-data-alpha-root-visual/08-projects-dark.png`
- `docs/subtasks/screenshots/060-fresh-data-alpha-root-visual/09-growth-dark.png`
- `docs/subtasks/screenshots/060-fresh-data-alpha-root-visual/10-settings-dark.png`

Residual risk:

- This is first-viewport visual evidence only; it does not replace a complete interactive Today core-loop walkthrough.
- Live GLM failure/retry confirmation remains a separate MVP hardening slice.
- Growth/Settings bottom-scroll evidence was not repeated in this fresh-data pass because the shared scroll reserve was already accepted in Subtask 029.

## 2026-06-06: Subtask 059 Alpha Root-Tab Visual Regression

Scope:

- Add a Debug-only root-tab launch selector for repeatable iPhone 17 screenshots.
- Capture Today, History, Projects, Growth, and Settings in light/dark mode.
- Keep Release launch behavior, persistence, migrations, PromptProvider, parser, LLM clients, Keychain, and product semantics unchanged.

Changed areas:

- `Sources/App/AppStore.swift`
- `Sources/App/MingSiApp.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/subtasks/059-alpha-core-visual-regression-prd.md`
- `docs/subtasks/059-alpha-core-visual-regression-progress.md`
- `docs/subtasks/screenshots/059-alpha-core-visual-regression/*.png`
- Process docs for stage progress, verification, delegation, and current Claude status.

Commands run:

```bash
git status --short
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
xcrun simctl install booted /Users/chenzewei/Library/Developer/Xcode/DerivedData/MingSi-erjzdsaapaoobtcrmiwnfyqrwdqr/Build/Products/Debug-iphonesimulator/MingSi.app
SIMCTL_CHILD_MINGSI_VISUAL_QA_TAB=<tab> xcrun simctl launch --terminate-running-process booted com.codex.mingsi MINGSI_VISUAL_QA_TAB
xcrun simctl io booted screenshot docs/subtasks/screenshots/059-alpha-core-visual-regression/<index>-<tab>-<appearance>.png
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

- Debug iPhone 17 simulator build: `BUILD SUCCEEDED`.
- Captured root-tab screenshots for Today, History, Projects, Growth, and Settings in light/dark mode.
- Screenshot review confirmed root-tab selection works, stale Project Detail marker files no longer hijack root-tab captures, History stays below the Dynamic Island/status area, Projects remains on the Projects root tab, and Settings dark placeholder/disabled text is readable enough for Alpha.
- `AppStoreStateMachineTests`: passed with 162 tests and 0 failures.
- `git diff --check`: passed.
- iPhone 17 Release simulator build: `BUILD SUCCEEDED`.

Screenshots:

- `docs/subtasks/screenshots/059-alpha-core-visual-regression/01-current-light.png` - early Today light baseline before final root-tab matrix recapture
- `docs/subtasks/screenshots/059-alpha-core-visual-regression/02-today-light.png`
- `docs/subtasks/screenshots/059-alpha-core-visual-regression/03-history-light.png`
- `docs/subtasks/screenshots/059-alpha-core-visual-regression/04-projects-light.png`
- `docs/subtasks/screenshots/059-alpha-core-visual-regression/05-growth-light.png`
- `docs/subtasks/screenshots/059-alpha-core-visual-regression/06-settings-light.png`
- `docs/subtasks/screenshots/059-alpha-core-visual-regression/07-today-dark.png`
- `docs/subtasks/screenshots/059-alpha-core-visual-regression/08-history-dark.png`
- `docs/subtasks/screenshots/059-alpha-core-visual-regression/09-projects-dark.png`
- `docs/subtasks/screenshots/059-alpha-core-visual-regression/10-growth-dark.png`
- `docs/subtasks/screenshots/059-alpha-core-visual-regression/11-settings-dark.png`

Residual risk:

- The booted simulator still contains prior visual QA project evidence, so Projects root screenshots are not a clean first-run empty state. This is acceptable for root-tab selector/layout verification but should be repeated with erased app data before a final fresh-user Alpha pass.
- This visual regression does not replace a live GLM failure-path confirmation or a complete interactive Today loop walkthrough.

## 2026-06-06: Subtask 058 Project Detail Display Polish

Scope:

- Accept display-only Project Detail fixes based on Subtask 049 real iPhone 17 findings.
- Keep AppStore orchestration, persistence, migrations, repositories, PromptProvider, parser, LLM clients, Keychain, and Project semantics unchanged.
- Record that Claude Code was not launched because the delegation resource guard blocked new workers.

Changed areas:

- `Sources/Features/FeatureTabs.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/subtasks/058-project-detail-display-polish-progress.md`
- `docs/subtasks/screenshots/058-project-detail-display-polish/*.png`
- Process docs for stage progress, verification, delegation, and current Claude status.

Commands run:

```bash
scripts/claude_delegate.sh health 058-project-detail-display-polish docs/subtasks/058-project-detail-display-polish-progress.md
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

- Delegation health blocked worker launch: `codex_direct_zombies=53/20`, `codex_tree_zombies=53/20`, `total_zombies=55/80`, `active_processes=0`.
- `AppStoreStateMachineTests`: passed with 157 tests and 0 failures.
- `git diff --check`: passed.
- iPhone 17 Release simulator build: `BUILD SUCCEEDED`.
- Screenshot review accepted Chinese Project status labels, readable dark Project Detail surfaces, collapsed long progress signals, and hidden empty thinking-change card states.

Screenshots:

- `docs/subtasks/screenshots/058-project-detail-display-polish/01-project-detail-normal-light.png`
- `docs/subtasks/screenshots/058-project-detail-display-polish/02-project-detail-normal-dark.png`
- `docs/subtasks/screenshots/058-project-detail-display-polish/03-project-detail-long_timeline-light.png`
- `docs/subtasks/screenshots/058-project-detail-display-polish/04-project-detail-long_timeline-dark.png`
- `docs/subtasks/screenshots/058-project-detail-display-polish/05-project-detail-sparse_next_bet-light.png`
- `docs/subtasks/screenshots/058-project-detail-display-polish/06-project-detail-sparse_next_bet-dark.png`

Residual risk:

- Dedicated bottom-scroll Project Detail screenshot evidence is still missing; implementation uses the shared `DS.primaryScrollBottomReserve`.
- New Claude Code launches remain blocked until the Codex process-tree zombie pressure clears or delegation is moved behind a safer supervisor.

## 2026-06-06: Subtask 049 Project Detail Fixture Variant Screenshot Matrix

Scope:

- Capture the full Project Detail visual QA fixture matrix on a real iPhone 17 simulator.
- Use Debug-only fixture variants from Subtask 057.
- Keep Swift source, tests, persistence, migrations, PromptProvider, parser, LLM clients, and Keychain unchanged.

Changed areas:

- `docs/subtasks/049-project-detail-real-simulator-visual-qa-findings.md`
- `docs/subtasks/049-project-detail-real-simulator-visual-qa-progress.md`
- `docs/subtasks/screenshots/049-project-detail-real-simulator-visual-qa/18...37*.png`

Commands run:

```bash
xcrun simctl install booted /Users/chenzewei/Library/Developer/Xcode/DerivedData/MingSi-fzvxdxbuzzkbvfctglvogodxewmw/Build/Products/Debug-iphonesimulator/MingSi.app
xcrun simctl ui booted appearance light
SIMCTL_CHILD_MINGSI_VISUAL_QA_PROJECT_DETAIL=1 SIMCTL_CHILD_MINGSI_VISUAL_QA_PROJECT_DETAIL_VARIANT=<variant> xcrun simctl launch --terminate-running-process booted com.codex.mingsi MINGSI_VISUAL_QA_PROJECT_DETAIL
xcrun simctl io booted screenshot docs/subtasks/screenshots/049-project-detail-real-simulator-visual-qa/<index>-project-detail-<variant>-<appearance>.png
```

Result:

- Captured 20 screenshots: 10 variants x light/dark.
- Real screenshots confirm the next Project Detail follow-up should be narrow and display-only.
- Confirmed risks: English `active` status chip, dark summary surface tonal mismatch, empty thinking-change card noise, long timeline first-viewport dominance, and lower first-viewport content appearing under the floating tab in some states.

Residual risk:

- First-viewport screenshots do not fully verify lower accepted/pending/merge sections.
- Project Detail bottom-scroll evidence is still missing.
- The Codex process-tree zombie count remains over the delegation wrapper threshold, so new Claude Code worker launches should wait until resource health recovers.

## 2026-06-06: Subtask 057 Project Detail Visual QA Fixture Variants

Scope:

- Accept Claude Code implementation of Debug-only Project Detail visual QA fixture variants for the Subtask 048 screenshot matrix.
- Keep production persistence, migrations, repositories, PromptProvider, parser, LLM clients, Keychain, Project semantics, and Project Detail visual polish unchanged.

Changed areas:

- `Sources/App/AppStore.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/subtasks/057-project-detail-visual-qa-fixture-variants-*`
- `docs/subtasks/logs/057-project-detail-visual-qa-fixture-variants-*`
- `docs/subtasks/049-project-detail-real-simulator-visual-qa-progress.md`
- `docs/mvp-stage-progress.md`
- `docs/agent-delegation-log.md`
- `docs/subtasks/claude-code-current-status.md`

Commands run:

```bash
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

- Claude Code reached `HANDOFF/DONE` in the worker progress file.
- Codex accepted after manager fixes for fixture ProjectLink source resolution and true sparse next-bet derivation.
- `git diff --check` passed.
- AppStoreStateMachineTests passed with 153 tests and 0 failures.
- iPhone 17 Release simulator build passed.

Residual risk:

- This is code/test/build verified. Real iPhone 17 screenshots for the 10 variants are still required before Subtask 049 visual acceptance can close.
- Delegation framework follow-up: print-mode launch exit reported no handoff while wrapper `status` surfaced worker `HANDOFF/DONE`.

## 2026-06-06: Subtask 056 Project Detail Debug Direct Entry

Scope:

- Accept Claude Code implementation of a Debug-only Project Detail direct-entry path for the visual QA fixture.
- Keep production persistence, migrations, PromptProvider, parser, LLM clients, Keychain, and Project semantics unchanged.

Changed areas:

- `Sources/App/AppStore.swift`
- `Sources/Features/FeatureTabs.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/subtasks/056-project-detail-debug-direct-entry-*`
- `docs/subtasks/logs/056-project-detail-debug-direct-entry-*`
- `docs/subtasks/screenshots/049-project-detail-real-simulator-visual-qa/16-project-detail-direct-entry-light.png`

Commands run:

```bash
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -project MingSi.xcodeproj -scheme MingSi -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17' build
xcrun simctl install booted /Users/chenzewei/Library/Developer/Xcode/DerivedData/MingSi-fzvxdxbuzzkbvfctglvogodxewmw/Build/Products/Debug-iphonesimulator/MingSi.app
CONTAINER=$(xcrun simctl get_app_container booted com.codex.mingsi data) && mkdir -p "$CONTAINER/Documents" && touch "$CONTAINER/Documents/.visual_qa_project_detail"
xcrun simctl launch --terminate-running-process booted com.codex.mingsi
xcrun simctl io booted screenshot docs/subtasks/screenshots/049-project-detail-real-simulator-visual-qa/16-project-detail-direct-entry-light.png
```

Result:

- Claude Code reached `HANDOFF/DONE_WITH_CONCERNS`.
- Codex accepted the scoped worker diff without manager source fixes.
- `git diff --check` passed.
- AppStoreStateMachineTests passed with 132 tests and 0 failures.
- iPhone 17 Debug simulator build passed.
- iPhone 17 Release simulator build passed.
- Real iPhone 17 screenshot `16-project-detail-direct-entry-light.png` shows Project Detail (`长期议题`) for `Visual QA - 会议机制优化`.

Residual risk:

- This removes the navigation blocker for Subtask 049 but does not complete the full Project Detail light/dark screenshot matrix.
- The accepted screenshot confirms the known Subtask 048 status-chip issue: the Project Detail header still displays English `active`.

## 2026-06-06: Subtask 049 Project Detail Current Fixture Dark Screenshot

Scope:

- Capture the current visual QA Project Detail fixture in dark mode after Subtask 056 direct entry.
- Keep source code unchanged.

Changed areas:

- `docs/subtasks/049-project-detail-real-simulator-visual-qa-progress.md`
- `docs/subtasks/screenshots/049-project-detail-real-simulator-visual-qa/17-project-detail-direct-entry-dark.png`

Commands run:

```bash
xcrun simctl ui booted appearance dark
xcrun simctl launch --terminate-running-process booted com.codex.mingsi
xcrun simctl io booted screenshot docs/subtasks/screenshots/049-project-detail-real-simulator-visual-qa/17-project-detail-direct-entry-dark.png
```

Result:

- Screenshot shows Project Detail (`长期议题`) for `Visual QA - 会议机制优化` in dark mode.
- Header and top content are below the Dynamic Island/status area.
- Text is readable in dark mode.
- The screenshot confirms the existing Subtask 048 concerns: English `active` status chip and a very dark `summarySurface()` against warm dark background.

Residual risk:

- This is only the current fixture top state, not the full Subtask 048 10-state light/dark matrix.
- Bottom-scroll and lower sections such as accepted/pending insights and merge audit still need dedicated screenshots or fixture/harness support.

## 2026-06-06: Subtasks 054/055 Project Detail Visual QA Fixture Activation

Scope:

- Accept Claude Code Debug-only visual QA fixture launch reliability and marker-file activation work.
- Add Codex manager acceptance fix for the real simulator reload overwrite discovered by screenshots.
- Keep production persistence, migrations, PromptProvider, parser, LLM clients, Keychain, and product semantics unchanged.

Changed areas:

- `Sources/App/AppStore.swift`
- `Sources/App/MingSiApp.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/subtasks/049-project-detail-real-simulator-visual-qa-progress.md`
- `docs/subtasks/054-visual-qa-fixture-launch-reliability-*`
- `docs/subtasks/055-visual-qa-fixture-marker-activation-*`
- `docs/subtasks/logs/054-*`
- `docs/subtasks/logs/055-*`
- `docs/subtasks/screenshots/049-project-detail-real-simulator-visual-qa/05...15*.png`

Commands run:

```bash
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQAFixture_loadHistoryRecordsKeepsFixtureProjectEvidence test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -project MingSi.xcodeproj -scheme MingSi -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17' build
xcrun simctl install booted /Users/chenzewei/Library/Developer/Xcode/DerivedData/MingSi-fzvxdxbuzzkbvfctglvogodxewmw/Build/Products/Debug-iphonesimulator/MingSi.app
xcrun simctl spawn booted defaults delete com.codex.mingsi MINGSI_VISUAL_QA_PROJECT_DETAIL || true
CONTAINER=$(xcrun simctl get_app_container booted com.codex.mingsi data) && mkdir -p "$CONTAINER/Documents" && touch "$CONTAINER/Documents/.visual_qa_project_detail"
xcrun simctl launch --terminate-running-process booted com.codex.mingsi
xcrun simctl io booted screenshot docs/subtasks/screenshots/049-project-detail-real-simulator-visual-qa/15-projects-fixture-top-light-load-guard.png
```

Result:

- `git diff --check` passed.
- The new RED test first failed because `loadHistoryRecords()` replaced fixture evidence with live empty history.
- After the manager fix, the new test passed.
- Full `AppStoreStateMachineTests` passed with 128 tests and 0 failures.
- iPhone 17 Debug simulator build passed.
- iPhone 17 Release simulator build passed, confirming Debug-only fixture symbols do not leak into Release.
- Real iPhone 17 screenshot `15-projects-fixture-top-light-load-guard.png` shows `1 个证据项目` and the fixture project `Visual QA - 会议机制优化`.

Residual risk:

- This verifies Project top fixture activation and makes Project Detail navigation feasible. It does not complete the Subtask 048 Project Detail light/dark screenshot matrix.

## 2026-06-06: Subtask 053 Delegation Resource Tree Guard

Scope:

- Harden reusable delegation framework resource hygiene.
- Keep MingSi product source unchanged.
- Preserve conclusion-first monitoring and flow-log separation.

Changed areas:

- `scripts/claude_delegate.sh`
- `delegation-framework/claude-code-managed-delegation/SKILL.md`
- local installed `claude-code-managed-delegation` skill
- `docs/subtasks/053-delegation-resource-tree-guard-prd.md`
- `docs/subtasks/053-delegation-resource-tree-guard-progress.md`
- `docs/subtasks/claude-code-current-status.md`
- `docs/agent-delegation-log.md`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
bash -n scripts/claude_delegate.sh
scripts/claude_delegate.sh health
CLAUDE_DELEGATE_MAX_CODEX_ZOMBIES=0 scripts/claude_delegate.sh prepare 050-project-detail-visual-qa-launch-fixture docs/subtasks/050-project-detail-visual-qa-launch-fixture-progress.md
scripts/claude_delegate.sh status 050-project-detail-visual-qa-launch-fixture docs/subtasks/050-project-detail-visual-qa-launch-fixture-progress.md
PATH="$tmpdir:$PATH" CLAUDE_DELEGATE_MODE=print CLAUDE_DELEGATE_LOG_DIR="$tmpdir/logs" scripts/claude_delegate.sh launch 053-delegation-resource-tree-guard docs/subtasks/053-delegation-resource-tree-guard-prd.md docs/subtasks/053-delegation-resource-tree-guard-progress.md
git worktree remove .claude/worktrees/subtask-053-delegation-resource-tree-guard --force
git branch -D worker-subtask-053-delegation-resource-tree-guard
git worktree list --porcelain | rg -n "subtask-053|worker-subtask-053" || true
git branch --list worker-subtask-053-delegation-resource-tree-guard
git diff --check
```

Result:

- Syntax check passed.
- `health` reports direct Codex zombies, Codex process-tree zombies, Codex process-tree size, total zombies, and task-scoped liveness.
- Current post-restart health observed Codex tree zombies below the default threshold but not zero.
- Guard blocking regression passed with `CLAUDE_DELEGATE_MAX_CODEX_ZOMBIES=0`; `prepare` exited `75`.
- Existing 050 `status` still surfaces manager-side `CODEX_ACCEPTED` progress.
- Fake print-mode Claude exited `0` without writing `HANDOFF`; wrapper returned `75` instead of quiet success.
- Temporary fake 053 worker worktree and branch were removed.
- `git diff --check` passed.

Residual risk:

- A shell wrapper cannot reap existing zombies if their parent process is Codex and Codex does not reap them.
- Real tmux-mode launches still require a usable TTY/session path; print mode remains an explicit fallback, now with stricter lifecycle checks.

## 2026-06-06: Subtask 050 Project Detail Visual QA Launch Fixture

Scope:

- Accept Claude Code implementation of a Debug-only Project Detail visual QA launch fixture.
- Keep fixture in memory and outside production persistence.
- Preserve normal `AppStore.live()` launch behavior.

Changed areas:

- `Sources/App/AppStore.swift`
- `Sources/App/MingSiApp.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/subtasks/050-project-detail-visual-qa-launch-fixture-progress.md`
- `docs/subtasks/logs/050-project-detail-visual-qa-launch-fixture-events.jsonl`
- `docs/subtasks/logs/050-project-detail-visual-qa-launch-fixture-claude-run.jsonl`

Commands run:

```bash
CLAUDE_DELEGATE_MODE=print CLAUDE_DELEGATE_MAX_BUDGET_USD=60.00 scripts/claude_delegate.sh launch 050-project-detail-visual-qa-launch-fixture docs/subtasks/050-project-detail-visual-qa-launch-fixture-claude-prompt.md docs/subtasks/050-project-detail-visual-qa-launch-fixture-progress.md
scripts/claude_delegate.sh status 050-project-detail-visual-qa-launch-fixture docs/subtasks/050-project-detail-visual-qa-launch-fixture-progress.md
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -project MingSi.xcodeproj -scheme MingSi -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

- Claude Code reached `HANDOFF/DONE`.
- Codex accepted only the allowed 050 source/test/progress diff and ignored worker-worktree `scripts/claude_delegate.sh` sync noise.
- Codex added a manager fix: `#if DEBUG` guards around the fixture API and launch branch.
- `git diff --check` passed.
- `AppStoreStateMachineTests` passed: 115 tests, 0 failures.
- iPhone 17 Debug simulator build passed.
- iPhone 17 Release simulator build passed, proving production builds do not reference Debug-only fixture APIs.

Residual risk:

- This enables Project Detail visual QA but does not itself capture Project Detail screenshots.
- The fixture data is explicitly visual QA data and must not be interpreted as real user evidence.

## 2026-06-06: Subtask 052 Delegation Tmux Flag Compatibility

Scope:

- Fix wrapper tmux flag compatibility for the current local Claude CLI.
- Keep MingSi product source unchanged.

Changed areas:

- `scripts/claude_delegate.sh`
- `delegation-framework/claude-code-managed-delegation/SKILL.md`
- local installed `claude-code-managed-delegation` skill
- `docs/subtasks/052-delegation-tmux-flag-compatibility-prd.md`
- `docs/subtasks/052-delegation-tmux-flag-compatibility-progress.md`
- `docs/subtasks/claude-code-current-status.md`
- `docs/agent-delegation-log.md`
- `docs/verification-log.md`

Commands run:

```bash
claude --help
bash -n scripts/claude_delegate.sh
if rg -q -- '--tmux="\$tmux_style"|--tmux=native' scripts/claude_delegate.sh; then echo 'FAIL: invalid native tmux invocation remains'; exit 1; else echo 'PASS: native tmux does not use --tmux=native'; fi
scripts/claude_delegate.sh --help
rg -n 'open terminal failed: not a terminal|unknown option' docs/subtasks/logs/050-project-detail-visual-qa-launch-fixture-after-051-classic-claude-run.jsonl docs/subtasks/logs/050-project-detail-visual-qa-launch-fixture-claude-run.jsonl
git diff --check
```

Result:

- `claude --help` confirms native tmux is bare `--tmux`; classic is `--tmux=classic`.
- Syntax check passed.
- Static tmux flag regression passed.
- Wrapper help now shows default `CLAUDE_DELEGATE_TMUX_STYLE=native`.
- Flow-log evidence was preserved for the classic non-TTY false success and invalid native flag attempt.
- `git diff --check` passed.

Residual risk:

- This verifies wrapper flag generation and false-success detection; it still needs a fresh 050 relaunch to prove the local Claude CLI can start a real worker from Codex.

## 2026-06-06: Subtask 051 Delegation Lifecycle Cleanup

Scope:

- Fix the reusable delegation wrapper lifecycle issue reported by the user.
- Keep MingSi product source unchanged.
- Preserve conclusion-first monitoring and flow-log separation.

Changed areas:

- `scripts/claude_delegate.sh`
- `delegation-framework/claude-code-managed-delegation/SKILL.md`
- local installed `claude-code-managed-delegation` skill
- `docs/subtasks/051-delegation-lifecycle-cleanup-prd.md`
- `docs/subtasks/051-delegation-lifecycle-cleanup-progress.md`
- `docs/subtasks/claude-code-current-status.md`
- `docs/agent-delegation-log.md`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
if rg -q '> "\$raw_log" 2>&1 &' scripts/claude_delegate.sh; then echo 'RED: tmux launch still backgrounds claude and cannot observe launch exit'; exit 1; fi
bash -n scripts/claude_delegate.sh
if rg -q '> "\$raw_log" 2>&1 &' scripts/claude_delegate.sh; then echo 'FAIL: tmux launch still backgrounds claude'; exit 1; else echo 'PASS: tmux launch no longer backgrounds claude'; fi
scripts/claude_delegate.sh status 050-project-detail-visual-qa-launch-fixture docs/subtasks/050-project-detail-visual-qa-launch-fixture-progress.md
scripts/claude_delegate.sh cleanup 050-project-detail-visual-qa-launch-fixture docs/subtasks/050-project-detail-visual-qa-launch-fixture-progress.md
scripts/claude_delegate.sh wait 050-project-detail-visual-qa-launch-fixture docs/subtasks/050-project-detail-visual-qa-launch-fixture-progress.md 0 1
git diff --check
ps -axo pid=,ppid=,stat=,command= | awk '$3 ~ /^Z/ {total++; if ($2==77268) codex++} END {printf "codex_zombies=%d total_zombies=%d\n", codex+0, total+0}'
CLAUDE_DELEGATE_MAX_CODEX_ZOMBIES=0 scripts/claude_delegate.sh prepare 050-project-detail-visual-qa-launch-fixture docs/subtasks/050-project-detail-visual-qa-launch-fixture-progress.md
```

Result:

- RED check failed before the fix because tmux launch still backgrounded `claude`.
- Syntax check passed after the fix.
- Static tmux-background regression passed after the fix.
- 050 `status` now reports `active_processes=0` and warns that launch likely failed before `START`.
- 050 `cleanup` is a safe no-op when no active worker process remains.
- 050 `wait 0 1` exits `75` immediately with launch-before-START classification.
- `git diff --check` passed.
- Resource count after verification: Codex-owned zombies 5, total zombies 7; below the wrapper thresholds of 20/80.
- Resource guard regression passed: with `CLAUDE_DELEGATE_MAX_CODEX_ZOMBIES=0`, `prepare` exited `75` and blocked launch.

Residual risk:

- Existing Codex-owned zombies cannot be reaped by a shell wrapper if the Codex parent process does not reap them; the wrapper now reduces new leaks, reports liveness, and blocks/cleans task-scoped stale processes.
- Subtask 050 still has no accepted worker output and must be relaunched under the fixed wrapper if it remains the next priority.

## 2026-06-06: Subtask 048 Project Detail Visual-Smoke Readiness and Delegation Resource Guard

Scope:

- Accept Claude Code read-only findings for Project Detail visual-smoke readiness.
- Verify the delegation wrapper resource guard after Codex restart cleared the prior zombie buildup.
- Keep flow logs diagnostic-only and accept only conclusion progress/HANDOFF plus findings.

Changed areas:

- `docs/subtasks/048-project-detail-visual-smoke-readiness-progress.md`
- `docs/subtasks/048-project-detail-visual-smoke-readiness-findings.md`
- `docs/subtasks/logs/048-project-detail-visual-smoke-readiness-events.jsonl`
- `docs/subtasks/logs/048-project-detail-visual-smoke-readiness-claude-run.jsonl`
- `scripts/claude_delegate.sh`
- `delegation-framework/claude-code-managed-delegation/SKILL.md`
- local installed `claude-code-managed-delegation` skill
- `docs/subtasks/claude-code-current-status.md`
- `docs/agent-delegation-log.md`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
scripts/claude_delegate.sh prepare 048-project-detail-visual-smoke-readiness docs/subtasks/048-project-detail-visual-smoke-readiness-progress.md
CLAUDE_DELEGATE_MAX_BUDGET_USD=30.00 scripts/claude_delegate.sh launch 048-project-detail-visual-smoke-readiness docs/subtasks/048-project-detail-visual-smoke-readiness-claude-prompt.md docs/subtasks/048-project-detail-visual-smoke-readiness-progress.md
scripts/claude_delegate.sh status 048-project-detail-visual-smoke-readiness docs/subtasks/048-project-detail-visual-smoke-readiness-progress.md
bash -n scripts/claude_delegate.sh
command -v tmux
scripts/claude_delegate.sh --help
CLAUDE_DELEGATE_MAX_CODEX_ZOMBIES=0 scripts/claude_delegate.sh status 048-project-detail-visual-smoke-readiness docs/subtasks/048-project-detail-visual-smoke-readiness-progress.md
CLAUDE_DELEGATE_MAX_CODEX_ZOMBIES=0 scripts/claude_delegate.sh prepare 048-project-detail-visual-smoke-readiness docs/subtasks/048-project-detail-visual-smoke-readiness-progress.md
scripts/claude_delegate.sh prepare 048-project-detail-visual-smoke-readiness docs/subtasks/048-project-detail-visual-smoke-readiness-progress.md
git diff --check
```

Result:

- After Codex restart, Codex-owned zombies dropped from 260+ to 0 and `prepare` succeeded.
- Claude Code reached `HANDOFF/DONE`.
- Worker findings identify 10 Project Detail screenshot states, 6 source-inferred visual risks, and 3 narrow follow-up candidates.
- Worker reported `git diff --check` passed for the progress/findings files and no Swift source/test edits.
- Wrapper syntax check passed.
- `tmux` exists at `/opt/homebrew/bin/tmux`.
- Wrapper help shows the new resource guard and non-interactive tmux defaults.
- `status` with `CLAUDE_DELEGATE_MAX_CODEX_ZOMBIES=0` warned but still surfaced conclusion progress.
- `prepare` with `CLAUDE_DELEGATE_MAX_CODEX_ZOMBIES=0` blocked with exit `75`, preventing new worker launch under zombie pressure.
- Normal `prepare` kept `mode_effective="tmux"` in the event log.

Residual risk:

- Real iPhone 17 Project Detail screenshots are still required before confirming any visual risk.
- The resource guard cannot fix Codex App's parent-process reaping bug; it prevents new worker launch when thresholds are exceeded and reduces extra Claude/MCP preflight processes.
- Future delegated implementation should validate tmux-mode launch under load and confirm no post-handoff process remains.

## 2026-06-05: Subtask 046 Delegation Strict Handoff Detection

Scope:

- Tighten `scripts/claude_delegate.sh` handoff detection.
- Require a real final status token before `status` displays an active handoff summary or `wait` exits success.
- Preserve manager-side `Status: CODEX_ACCEPTED`.
- Keep flow logs diagnostic-only.
- Avoid MingSi product source changes.

Changed areas:

- `scripts/claude_delegate.sh`
- `docs/subtasks/046-delegation-strict-handoff-detection-prd.md`
- `docs/subtasks/046-delegation-strict-handoff-detection-progress.md`
- `docs/subtasks/046-delegation-strict-handoff-detection-claude-prompt.md`
- `docs/subtasks/logs/046-delegation-strict-handoff-detection-events.jsonl`
- `docs/subtasks/claude-code-current-status.md`
- `docs/agent-delegation-log.md`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
bash -n scripts/claude_delegate.sh
scripts/claude_delegate.sh status 044-project-status-filter docs/subtasks/044-project-status-filter-progress.md
scripts/claude_delegate.sh status 046-placeholder "$tmp_progress"
scripts/claude_delegate.sh wait 046-placeholder "$tmp_progress" 0 1
scripts/claude_delegate.sh wait 029-safe-area-floating-tab docs/subtasks/029-safe-area-floating-tab-progress.md 0 1
git diff --check
```

Result:

- Syntax check passed.
- 044 real handoff still surfaces `Status: DONE_WITH_CONCERNS`.
- Placeholder `## HANDOFF` does not print `active handoff summary`.
- Placeholder `wait` exits `75`.
- 029 pending/non-worker progress still exits `75`.
- External temporary progress fixtures do not print `path is outside repo` noise.
- `git diff --check` passed.

Residual risk:

- Claude Code did not implement this slice because three launch attempts failed before worker start. This is accepted as a verified framework fix, not as evidence of improved worker utilization.

## 2026-06-05: Subtask 047 First Principles Lens Prompt Guidance

Scope:

- Keep `第一性原理` as an MVP built-in lens under the extensible lens library.
- Add library-owned prompt guidance for built-in lenses.
- Expose selected lens title, method line, and prompt guidance through `PromptContextPayload` and legacy GLM payload keys.
- Avoid UI-specific or prompt-call-site lens branches.

Changed areas:

- `Sources/Domain/Models.swift`
- `Sources/Services/CoreProtocols.swift`
- `Sources/Services/TodayAIService.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `Tests/Services/TodayAIServiceContextTests.swift`
- `docs/subtasks/047-first-principles-lens-prompt-guidance-progress.md`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/TodayAIServiceContextTests -only-testing:MingSiTests/AppStoreStateMachineTests/testFirstPrinciples_metadata test
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

- Targeted tests passed: 18 tests, 0 failures.
- `git diff --check` passed.
- iPhone 17 simulator build passed.

Residual risk:

- This slice is request/context verified, not screenshot verified. It does not change Today UI layout.

## 2026-06-05: Subtask 045 Extensible Lens Library Boundary

Scope:

- Add a small Domain-level extensible lens catalog/provider boundary.
- Keep `第一性原理` as an MVP built-in lens inside the library.
- Preserve existing local raw ids and prompt-facing ids.
- Do not change SwiftUI, AppStore orchestration, persistence, migrations, PromptProvider, prompt text, parser, LLM clients, Keychain, History, Projects, Growth, or Settings.

Changed areas:

- `Sources/Domain/Models.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/subtasks/045-extensible-lens-library-boundary-*`
- `docs/subtasks/claude-code-current-status.md`
- `docs/agent-delegation-log.md`
- `docs/verification-log.md`

Commands attempted:

```bash
scripts/claude_delegate.sh prepare 045-extensible-lens-library-boundary docs/subtasks/045-extensible-lens-library-boundary-progress.md
CLAUDE_DELEGATE_MAX_BUDGET_USD=30.00 scripts/claude_delegate.sh launch 045-extensible-lens-library-boundary docs/subtasks/045-extensible-lens-library-boundary-claude-prompt.md docs/subtasks/045-extensible-lens-library-boundary-progress.md
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
git diff --check
```

Result:

- Claude Code wrapper `prepare` and `launch` were blocked before execution by OS process creation error `spawn /bin/sh EAGAIN`.
- No Claude Code worker reached `START` or `HANDOFF`.
- Codex directly implemented the narrow Domain/test slice.
- Initial `xcodebuild` and `git diff --check` attempts were also blocked before execution by `spawn /bin/sh EAGAIN`.
- After process creation recovered, Codex reran fresh verification in the manager checkout.

Verification:

- `AppStoreStateMachineTests` passed: 110 tests, 0 failures.
- `git diff --check` passed.
- iPhone 17 simulator build passed.
- Codex accepted the slice.

Residual risk:

- This was build/test verified but not screenshot verified because the slice changes Domain catalog boundary and tests only; it does not change SwiftUI.
- Claude Code could not be used for the implementation because the worker process never launched.

## 2026-06-05: Subtask 044 Project Status Filter

Scope:

- Add display-only status filtering to the Projects top-level board.
- Expose existing `ProjectStatus` values through local `ProjectsView` state.
- Preserve Project semantics, AppStore orchestration, persistence, migrations, repositories, PromptProvider, parser, LLM clients, Keychain, Today, History behavior, Growth, and Settings.
- Accept Claude Code worker output only after `HANDOFF`, then rerun fresh verification in the manager checkout.

Changed areas:

- `Sources/Features/FeatureTabs.swift`
- `Tests/Features/HistoryFeatureTests.swift`
- `docs/subtasks/044-project-status-filter-*`
- `docs/subtasks/logs/044-project-status-filter-*`
- `docs/subtasks/claude-code-current-status.md`
- `docs/agent-delegation-log.md`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
scripts/claude_delegate.sh prepare 044-project-status-filter docs/subtasks/044-project-status-filter-progress.md
CLAUDE_DELEGATE_MAX_BUDGET_USD=30.00 scripts/claude_delegate.sh launch 044-project-status-filter docs/subtasks/044-project-status-filter-claude-prompt.md docs/subtasks/044-project-status-filter-progress.md
scripts/claude_delegate.sh status 044-project-status-filter docs/subtasks/044-project-status-filter-progress.md
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

- Claude Code reached `HANDOFF/DONE_WITH_CONCERNS`.
- Worker `git diff --check` passed; worker `xcodebuild` was blocked by the known GRDB worktree package issue.
- Codex reran verification in the main checkout.
- `HistoryFeatureTests` passed: 65 tests, 0 failures.
- `git diff --check` passed.
- iPhone 17 simulator build passed.

Residual risk:

- This was build/test verified but not screenshot verified. A later visual smoke pass should inspect Projects with enough active/watching/paused/archived evidence-backed items to confirm chip wrapping and empty filtered state.
- Delegation wrapper `status` displayed a template `## HANDOFF` placeholder before real handoff; this should be handled as a separate framework follow-up.

## 2026-06-05: Subtask 043 Delegation Status Handoff Summary

Scope:

- Fix the reusable delegation wrapper status view so conclusion-first monitoring shows active handoff summaries and final status tokens.
- Prefer manager-side `CODEX_ACCEPTED` progress after Codex acceptance.
- Keep raw/event flow logs out of routine status consumption.
- Preserve strict pending-handoff handling.
- Do not change MingSi product source, tests, persistence, migrations, prompt, parser, LLM, Keychain, AppStore orchestration, or SwiftUI behavior.

Changed areas:

- `scripts/claude_delegate.sh`
- `delegation-framework/claude-code-managed-delegation/SKILL.md`
- `delegation-framework/claude-code-managed-delegation/references/conclusion-first-monitoring.md`
- `docs/delegation-framework-boundary.md`
- `docs/subtasks/043-delegation-status-handoff-summary-prd.md`
- `docs/subtasks/043-delegation-status-handoff-summary-progress.md`
- `docs/subtasks/claude-code-current-status.md`
- `docs/agent-delegation-log.md`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`
- `docs/project-continuation-context.md`

Commands run:

```bash
bash -n scripts/claude_delegate.sh
scripts/claude_delegate.sh status 042-lens-prompt-context-wiring docs/subtasks/042-lens-prompt-context-wiring-progress.md | rg -q 'Status: DONE_WITH_CONCERNS'
scripts/claude_delegate.sh status 042-lens-prompt-context-wiring docs/subtasks/042-lens-prompt-context-wiring-progress.md | rg -q 'active progress: .*/docs/subtasks/042-lens-prompt-context-wiring-progress.md'
scripts/claude_delegate.sh wait 029-safe-area-floating-tab docs/subtasks/029-safe-area-floating-tab-progress.md 0 1
git diff --check
```

Result:

- Wrapper syntax check passed.
- 042 regression fixture showed `Status: DONE_WITH_CONCERNS` in the routine status output.
- 042 status now prefers the manager-side accepted progress file after `CODEX_ACCEPTED`.
- 029 pending handoff wait guard exited `75` as expected, proving `HANDOFF: pending` is not accepted as completion.
- `git diff --check` passed.

Residual risk:

- This is wrapper-level verification only. The next real Claude Code implementation slice should dogfood the improved status display under a live worker handoff.

## 2026-06-05: Subtask 042 Lens Prompt Context Wiring

Scope:

- Wire existing built-in lens catalog metadata into Today AI request/context payloads.
- Keep local persisted `ThinkingLens.rawValue` stable while model-facing `selectedLens` uses `LensCatalogItem.promptId`.
- Preserve PromptProvider text, parser behavior, LLM transport, persistence, migrations, AppStore orchestration, and SwiftUI.
- Accept Claude Code worker output only after `HANDOFF`, then rerun fresh verification in the manager checkout.

Changed areas:

- `Sources/Services/CoreProtocols.swift`
- `Sources/Services/TodayAIService.swift`
- `Tests/Services/TodayAIServiceContextTests.swift`
- `docs/subtasks/042-lens-prompt-context-wiring-*`
- `docs/subtasks/logs/042-lens-prompt-context-wiring-*`
- `docs/subtasks/claude-code-current-status.md`
- `docs/agent-delegation-log.md`
- `docs/mvp-stage-progress.md`
- `docs/project-continuation-context.md`
- `docs/verification-log.md`

Commands run:

```bash
scripts/claude_delegate.sh prepare 042-lens-prompt-context-wiring docs/subtasks/042-lens-prompt-context-wiring-progress.md
CLAUDE_DELEGATE_MAX_BUDGET_USD=30.00 scripts/claude_delegate.sh launch 042-lens-prompt-context-wiring docs/subtasks/042-lens-prompt-context-wiring-claude-prompt.md docs/subtasks/042-lens-prompt-context-wiring-progress.md
scripts/claude_delegate.sh status 042-lens-prompt-context-wiring docs/subtasks/042-lens-prompt-context-wiring-progress.md
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/TodayAIServiceContextTests test
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

- Claude Code reached `HANDOFF/DONE_WITH_CONCERNS`.
- Worker `git diff --check` passed; worker `xcodebuild` was blocked by the known GRDB worktree package issue.
- Raw model telemetry recorded real `glm-5.1` usage: 53,901 input tokens, 12,659 output tokens, 1,209,536 cache-read input tokens, estimated cost 1.190748 USD.
- Codex reran verification in the main checkout.
- Focused `TodayAIServiceContextTests` passed: 16 tests, 0 failures.
- `git diff --check` passed.
- iPhone 17 simulator build passed.

Residual risk:

- This is request/context contract work, not a live GLM semantic-quality test. A later live GLM run can confirm the model's behavior under `first_principles` once the History repair live failure-path slice is scheduled.
- Delegation wrapper `status` briefly showed stale progress after worker `HANDOFF`; this should be handled as a framework follow-up.

## 2026-06-05: Subtask 041 Project Detail Hierarchy Cleanup

Scope:

- Implement display-only Project Detail hierarchy cleanup from Subtask 040 findings.
- Keep Project semantics, AppStore orchestration, persistence, migrations, repositories, PromptProvider, parser, LLM clients, Keychain, Today, History, Growth, and Settings unchanged.
- Accept Claude Code worker output only after `HANDOFF`, then apply Codex manager display-helper fix and fresh verification.

Changed areas:

- `Sources/Features/FeatureTabs.swift`
- `Tests/Features/HistoryFeatureTests.swift`
- `docs/subtasks/041-project-detail-hierarchy-cleanup-*`
- `docs/subtasks/logs/041-project-detail-hierarchy-cleanup-*`
- `docs/subtasks/claude-code-current-status.md`
- `docs/agent-delegation-log.md`
- `docs/mvp-stage-progress.md`
- `docs/project-continuation-context.md`
- `docs/verification-log.md`

Commands run:

```bash
scripts/claude_delegate.sh prepare 041-project-detail-hierarchy-cleanup docs/subtasks/041-project-detail-hierarchy-cleanup-progress.md
CLAUDE_DELEGATE_MAX_BUDGET_USD=30.00 scripts/claude_delegate.sh launch 041-project-detail-hierarchy-cleanup docs/subtasks/041-project-detail-hierarchy-cleanup-claude-prompt.md docs/subtasks/041-project-detail-hierarchy-cleanup-progress.md
scripts/claude_delegate.sh status 041-project-detail-hierarchy-cleanup docs/subtasks/041-project-detail-hierarchy-cleanup-progress.md
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

- Claude Code reached `HANDOFF/DONE_WITH_CONCERNS`.
- Worker `git diff --check` passed; worker `xcodebuild` was blocked by the known GRDB worktree package issue.
- Codex reran verification in the main checkout.
- Focused `HistoryFeatureTests` passed: 61 tests, 0 failures.
- `git diff --check` passed.
- iPhone 17 simulator build passed.

Residual risk:

- This is build/test verified but not screenshot verified. Because it changes Project Detail display hierarchy, a later simulator visual smoke pass should inspect a project with populated overview/progress/insight/evidence sections.
- Project top-level status filtering and evidence timeline pagination remain separate future slices.

## 2026-06-05: Subtask 040 Project Overview Hierarchy Audit

Scope:

- Delegate a read-only audit of current Projects overview and Project Detail hierarchy.
- Identify the next narrow implementation slice without changing Project semantics.
- Preserve the rule that Projects remain evidence-backed and History remains the evidence archive.

Changed areas:

- `docs/subtasks/040-project-overview-hierarchy-audit-prd.md`
- `docs/subtasks/040-project-overview-hierarchy-audit-progress.md`
- `docs/subtasks/040-project-overview-hierarchy-audit-claude-prompt.md`
- `docs/subtasks/040-project-overview-hierarchy-audit-findings.md`
- `docs/subtasks/logs/040-project-overview-hierarchy-audit-*`
- `docs/subtasks/claude-code-current-status.md`
- `docs/agent-delegation-log.md`
- `docs/mvp-stage-progress.md`
- `docs/project-continuation-context.md`
- `docs/verification-log.md`

Commands run:

```bash
scripts/claude_delegate.sh prepare 040-project-overview-hierarchy-audit docs/subtasks/040-project-overview-hierarchy-audit-progress.md
CLAUDE_DELEGATE_MAX_BUDGET_USD=30.00 scripts/claude_delegate.sh launch 040-project-overview-hierarchy-audit docs/subtasks/040-project-overview-hierarchy-audit-claude-prompt.md docs/subtasks/040-project-overview-hierarchy-audit-progress.md
scripts/claude_delegate.sh status 040-project-overview-hierarchy-audit docs/subtasks/040-project-overview-hierarchy-audit-progress.md
git diff --check
```

Result:

- Claude Code reached `HANDOFF/DONE`.
- Worker findings cite concrete Project view symbols and recommend a display-only Project Detail hierarchy slice.
- Worker `git diff --check -- docs/subtasks/040-project-overview-hierarchy-audit-progress.md docs/subtasks/040-project-overview-hierarchy-audit-findings.md` passed.
- Manager `git diff --check` passed.

Residual risk:

- This is an audit/documentation slice, not a source implementation.
- The recommended implementation still needs a separate PRD, tests, build, and simulator review according to risk.

## 2026-06-05: Subtask 039 First Principles Lens Catalog

Scope:

- Add MVP built-in `第一性原理` as a first-party ThinkingLens.
- Establish a lightweight built-in lens catalog boundary for local id, prompt-facing id, version, title, subtitle, short label, method line, and symbol metadata.
- Preserve existing persisted `ThinkingLens.rawValue` values.
- Keep changes out of persistence, migrations, PromptProvider, parser, LLM clients, Keychain, AppStore orchestration, History, Projects, Growth, and Settings.

Changed areas:

- `Sources/Domain/Models.swift`
- `Sources/Features/Today/TodayView.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/subtasks/039-first-principles-lens-catalog-*`
- `docs/subtasks/logs/039-first-principles-lens-catalog-*`
- `docs/subtasks/claude-code-current-status.md`
- `docs/agent-delegation-log.md`
- `docs/mvp-stage-progress.md`
- `docs/project-continuation-context.md`
- `docs/verification-log.md`

Commands run:

```bash
scripts/claude_delegate.sh status 039-first-principles-lens-catalog docs/subtasks/039-first-principles-lens-catalog-progress.md
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

- Claude Code reached `HANDOFF/DONE_WITH_CONCERNS`.
- Worker `git diff --check` passed; worker `xcodebuild` was blocked by the known GRDB worktree package issue.
- Codex reran verification in the main checkout.
- Focused `AppStoreStateMachineTests` passed: 105 tests, 0 failures.
- `git diff --check` passed.
- iPhone 17 simulator build passed.

Residual risk:

- Catalog `promptId` is stored as metadata but is not yet wired into prompt payloads.
- No simulator screenshot was captured because this is a metadata/catalog and unit-test-covered UI availability slice.

## 2026-06-05: Subtask 038 Growth Report Drilldown Polish

Scope:

- Improve display-only Growth report review rows and metric detail explanation.
- Preserve Growth attribution behavior, AppStore orchestration, persistence, migrations, PromptProvider, LLM clients, parser, Keychain, and Project semantics.
- Accept Claude Code worker output only after `HANDOFF`, then apply Codex manager fix and fresh verification.
- Verify the delegation wrapper relaunch-safety follow-up exposed by this slice.

Changed areas:

- `Sources/Features/FeatureTabs.swift`
- `Tests/Features/HistoryFeatureTests.swift`
- `scripts/claude_delegate.sh`
- `delegation-framework/claude-code-managed-delegation/SKILL.md`
- `delegation-framework/claude-code-managed-delegation/references/conclusion-first-monitoring.md`
- `docs/subtasks/038-growth-report-drilldown-polish-*`
- `docs/subtasks/logs/038-growth-report-drilldown-polish-*`
- `docs/subtasks/claude-code-current-status.md`
- `docs/agent-delegation-log.md`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
bash -n scripts/claude_delegate.sh
scripts/claude_delegate.sh --help
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
scripts/claude_delegate.sh status 038-growth-report-drilldown-polish docs/subtasks/038-growth-report-drilldown-polish-progress.md
scripts/claude_delegate.sh wait 038-growth-report-drilldown-polish docs/subtasks/038-growth-report-drilldown-polish-progress.md auto 1
```

Result:

- Claude Code reached `HANDOFF/DONE_WITH_CONCERNS`.
- Raw log recorded real `glm-5.1` usage, including 54,504 input tokens, 6,439 output tokens, and 1,140,800 cache-read input tokens.
- Codex accepted the helper/test direction and added a manager fix so report rows show the stored metric reason or conservative fallback copy.
- Focused `HistoryFeatureTests` passed: 53 tests, 0 failures.
- `git diff --check` passed.
- iPhone 17 simulator build passed.
- Wrapper `bash -n`, `--help`, `status`, and `wait` smoke checks passed; `wait` found worker `HANDOFF` while keeping raw/event logs diagnostic-only.

Residual risk:

- No simulator screenshot was captured for this small display text/helper polish; acceptance is based on source review, focused tests, wrapper smoke checks, and simulator build.
- Worker Bash failed in the handoff session, so worker self-verification remained incomplete; Codex reran the required checks in the manager worktree before acceptance.

## 2026-06-04: Subtask 037 Project Merge Audit Display

Scope:

- Improve display-only Project merge review and accepted merge-history audit visibility.
- Preserve AppStore merge behavior, persistence, migrations, PromptProvider, LLM clients, parser, Keychain, and Growth semantics.
- Accept Claude Code worker output only after `HANDOFF`.

Changed areas:

- `Sources/Features/FeatureTabs.swift`
- `Tests/Features/HistoryFeatureTests.swift`
- `docs/subtasks/037-project-merge-audit-display-*`
- `docs/subtasks/logs/037-project-merge-audit-display-*`
- `docs/subtasks/claude-code-current-status.md`
- `docs/agent-delegation-log.md`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
scripts/claude_delegate.sh prepare 037-project-merge-audit-display docs/subtasks/037-project-merge-audit-display-progress.md
CLAUDE_DELEGATE_MAX_BUDGET_USD=30.00 scripts/claude_delegate.sh launch 037-project-merge-audit-display docs/subtasks/037-project-merge-audit-display-claude-prompt.md docs/subtasks/037-project-merge-audit-display-progress.md
scripts/claude_delegate.sh status 037-project-merge-audit-display docs/subtasks/037-project-merge-audit-display-progress.md
scripts/claude_delegate.sh wait 037-project-merge-audit-display docs/subtasks/037-project-merge-audit-display-progress.md
git -C .claude/worktrees/subtask-037-project-merge-audit-display diff -- Sources/Features/FeatureTabs.swift Tests/Features/HistoryFeatureTests.swift | git apply -
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

- Claude Code reached `HANDOFF/DONE`.
- Codex accepted the scoped display-only diff.
- Focused `HistoryFeatureTests` passed: 42 tests, 0 failures.
- `git diff --check` passed.
- iPhone 17 simulator build passed.

Residual risk:

- No simulator screenshot was captured for this small display text/section polish; acceptance is based on source review, focused tests, and simulator build.
- The worker worktree again needed local GRDB test resources restored for its own xcodebuild run; this remains a worker-worktree setup issue.

## 2026-06-04: Delegation Wait Policy Refinement

Scope:

- Align the reusable Codex-to-Claude Code delegation framework with the user's requested low-frequency monitoring policy.
- Keep MingSi product source untouched.
- Refresh stale process docs after Subtask 036.

Changed areas:

- `scripts/claude_delegate.sh`
- `delegation-framework/claude-code-managed-delegation/SKILL.md`
- `delegation-framework/claude-code-managed-delegation/references/conclusion-first-monitoring.md`
- `docs/project-continuation-context.md`
- `docs/subtasks/claude-code-current-status.md`
- `docs/subtasks/036-ai-repair-status-feedback-progress.md`
- `docs/mvp-stage-progress.md`
- `docs/agent-delegation-log.md`
- `docs/verification-log.md`

Commands run:

```bash
bash -n scripts/claude_delegate.sh
scripts/claude_delegate.sh --help
CLAUDE_DELEGATE_WAIT_SCHEDULE=0 scripts/claude_delegate.sh wait 036-ai-repair-status-feedback docs/subtasks/036-ai-repair-status-feedback-progress.md auto 1
CLAUDE_DELEGATE_WAIT_SCHEDULE=0,0,0 scripts/claude_delegate.sh wait 029-safe-area-floating-tab docs/subtasks/029-safe-area-floating-tab-progress.md auto 3
git diff --check
```

Result:

- `bash -n` passed.
- `--help` showed the default 3/6/9-minute auto wait policy.
- `wait ... 036 ... auto 1` found the accepted `HANDOFF`.
- `wait ... 029 ... auto 3` exited 75 and reported no conclusion-progress movement before manager intervention, which is expected for the historical non-delivery progress file.
- `git diff --check` passed.

Residual risk:

- This is a wrapper/process refinement only; no new Claude Code worker was launched.
- No iPhone simulator build was run because no product source, tests, or app assets changed.

## 2026-06-04: Subtask 036 AI Repair Status Feedback Polish

Scope:

- Improve display-only per-run/per-candidate AI repair feedback in History and Settings.
- Preserve retry behavior, persistence, migrations, PromptProvider, LLM clients, parser, Keychain, and AppStore orchestration.
- Accept Claude Code worker output only after `HANDOFF`, then apply Codex copy fix.

Changed areas:

- `Sources/Features/FeatureTabs.swift`
- `Tests/Features/HistoryFeatureTests.swift`
- `docs/subtasks/036-ai-repair-status-feedback-*`
- `docs/subtasks/logs/036-ai-repair-status-feedback-*`
- `docs/subtasks/claude-code-current-status.md`
- `docs/agent-delegation-log.md`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
scripts/claude_delegate.sh prepare 036-ai-repair-status-feedback docs/subtasks/036-ai-repair-status-feedback-progress.md
CLAUDE_DELEGATE_MAX_BUDGET_USD=30.00 scripts/claude_delegate.sh launch 036-ai-repair-status-feedback docs/subtasks/036-ai-repair-status-feedback-claude-prompt.md docs/subtasks/036-ai-repair-status-feedback-progress.md
scripts/claude_delegate.sh status 036-ai-repair-status-feedback docs/subtasks/036-ai-repair-status-feedback-progress.md
git -C .claude/worktrees/subtask-036-ai-repair-status-feedback diff -- Sources/Features/FeatureTabs.swift Tests/Features/HistoryFeatureTests.swift | git apply -
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test
```

Result:

- Claude Code attempt 1 consumed GLM tokens but exited before `START` due an API socket close; no source diff accepted.
- Relaunch reached `HANDOFF/DONE`.
- Codex accepted the worker direction after fixing candidate status copy that overstated persistence behavior.
- `git diff --check` passed.
- iPhone 17 simulator build passed.
- Focused `HistoryFeatureTests` passed on sequential rerun: 36 tests, 0 failures.

Residual risk:

- No new simulator screenshot was captured for this UI text polish; acceptance is based on source review, focused tests, and simulator build.
- A first focused-test attempt failed because it ran concurrently with the build and Xcode locked `build.db`; the sequential rerun passed.

## 2026-06-04: Subtask 035 Prompt Inspector Read-Only View

Scope:

- Add a read-only Settings Prompt inspector for current first-party prompt templates.
- Preserve PromptProvider / LLM / persistence / Keychain / parser boundaries.
- Accept Claude Code worker output only after `HANDOFF`, then apply Codex boundary fix.

Changed areas:

- `Sources/App/AppStore.swift`
- `Sources/Features/FeatureTabs.swift`
- `Tests/Services/LocalPromptProviderTests.swift`
- `docs/subtasks/035-prompt-inspector-readonly-*`
- `docs/subtasks/logs/035-prompt-inspector-readonly-*`
- `docs/subtasks/claude-code-current-status.md`
- `docs/agent-delegation-log.md`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
scripts/claude_delegate.sh prepare 035-prompt-inspector-readonly docs/subtasks/035-prompt-inspector-readonly-progress.md
CLAUDE_DELEGATE_MAX_BUDGET_USD=30.00 scripts/claude_delegate.sh launch 035-prompt-inspector-readonly docs/subtasks/035-prompt-inspector-readonly-claude-prompt.md docs/subtasks/035-prompt-inspector-readonly-progress.md
scripts/claude_delegate.sh status 035-prompt-inspector-readonly docs/subtasks/035-prompt-inspector-readonly-progress.md
git -C .claude/worktrees/subtask-035-prompt-inspector-readonly diff -- Sources/Features/FeatureTabs.swift Tests/Services/LocalPromptProviderTests.swift | git apply -
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/LocalPromptProviderTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

- Claude Code reached `HANDOFF/DONE`.
- Codex accepted the worker UI/test direction after moving template access behind `AppStore.promptTemplate(for:mode:)`.
- Focused `LocalPromptProviderTests` passed: 7 tests, 0 failures.
- `git diff --check` passed after documentation updates.
- iPhone 17 simulator build passed.

Residual risk:

- No extra flicker validation is included because the user already confirmed the Settings AI audit flicker fix and asked not to repeat it.
- No new screenshot was captured for the Prompt inspector in this slice; acceptance is based on source review, focused tests, and simulator build.

## 2026-06-04: Subtask 029 Safe Area Visual Acceptance

Scope:

- Complete final iPhone 17 simulator visual acceptance for Subtask 029.
- Verify Today, History, Projects, Growth, and Settings in light/dark modes after the safe-area and floating Tab bar source fix.
- Use the user's confirmation that Settings AI audit expand/collapse flicker is fixed; do not repeat that video validation in this pass.

Changed areas:

- `docs/subtasks/029-safe-area-floating-tab-progress.md`
- `docs/subtasks/claude-code-current-status.md`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`
- `docs/subtasks/screenshots/029-safe-area-floating-tab/10-today-light-final.png`
- `docs/subtasks/screenshots/029-safe-area-floating-tab/11-history-light-final.png`
- `docs/subtasks/screenshots/029-safe-area-floating-tab/12-projects-light-final.png`
- `docs/subtasks/screenshots/029-safe-area-floating-tab/13-growth-light-final.png`
- `docs/subtasks/screenshots/029-safe-area-floating-tab/14-settings-light-final.png`
- `docs/subtasks/screenshots/029-safe-area-floating-tab/15-today-dark-final.png`
- `docs/subtasks/screenshots/029-safe-area-floating-tab/16-history-dark-final.png`
- `docs/subtasks/screenshots/029-safe-area-floating-tab/17-projects-dark-final.png`
- `docs/subtasks/screenshots/029-safe-area-floating-tab/18-growth-dark-final.png`
- `docs/subtasks/screenshots/029-safe-area-floating-tab/19-settings-dark-final.png`
- `docs/subtasks/screenshots/029-safe-area-floating-tab/20-settings-dark-scrolled-final.png`
- `docs/subtasks/screenshots/029-safe-area-floating-tab/21-growth-dark-scrolled-final.png`
- `docs/subtasks/screenshots/029-safe-area-floating-tab/22-settings-light-scrolled-final.png`
- `docs/subtasks/screenshots/029-safe-area-floating-tab/23-growth-light-scrolled-final.png`
- `docs/subtasks/screenshots/029-safe-area-floating-tab/24-growth-light-drag-scrolled-final.png`
- `docs/subtasks/screenshots/029-safe-area-floating-tab/25-growth-dark-drag-scrolled-final.png`
- `docs/subtasks/screenshots/029-safe-area-floating-tab/26-settings-dark-drag-scrolled-final.png`

Commands run:

```bash
git status --short
xcrun simctl list devices | rg 'iPhone 17|Booted'
xcrun simctl get_app_container booted com.codex.mingsi app
xcrun simctl io booted screenshot /tmp/mingsi-current.png
osascript -e 'tell application "System Events" to tell process "Simulator" to get {position, size} of window 1'
xcrun simctl ui booted appearance light
osascript -e 'tell application "System Events" to tell process "Simulator" to click at {...}'
xcrun simctl io booted screenshot docs/subtasks/screenshots/029-safe-area-floating-tab/10-today-light-final.png
xcrun simctl io booted screenshot docs/subtasks/screenshots/029-safe-area-floating-tab/11-history-light-final.png
xcrun simctl io booted screenshot docs/subtasks/screenshots/029-safe-area-floating-tab/12-projects-light-final.png
xcrun simctl io booted screenshot docs/subtasks/screenshots/029-safe-area-floating-tab/13-growth-light-final.png
xcrun simctl io booted screenshot docs/subtasks/screenshots/029-safe-area-floating-tab/14-settings-light-final.png
xcrun simctl ui booted appearance dark
xcrun simctl io booted screenshot docs/subtasks/screenshots/029-safe-area-floating-tab/15-today-dark-final.png
xcrun simctl io booted screenshot docs/subtasks/screenshots/029-safe-area-floating-tab/16-history-dark-final.png
xcrun simctl io booted screenshot docs/subtasks/screenshots/029-safe-area-floating-tab/17-projects-dark-final.png
xcrun simctl io booted screenshot docs/subtasks/screenshots/029-safe-area-floating-tab/18-growth-dark-final.png
xcrun simctl io booted screenshot docs/subtasks/screenshots/029-safe-area-floating-tab/19-settings-dark-final.png
swift - <<'SWIFT' ... CGEvent drag gesture ... SWIFT
xcrun simctl io booted screenshot docs/subtasks/screenshots/029-safe-area-floating-tab/24-growth-light-drag-scrolled-final.png
xcrun simctl io booted screenshot docs/subtasks/screenshots/029-safe-area-floating-tab/25-growth-dark-drag-scrolled-final.png
xcrun simctl io booted screenshot docs/subtasks/screenshots/029-safe-area-floating-tab/26-settings-dark-drag-scrolled-final.png
```

Result:

- `git status --short` started clean before new screenshot/doc evidence was created.
- iPhone 17 simulator was booted and the installed MingSi app container was present.
- Real simulator screenshots were captured for Today, History, Projects, Growth, and Settings in light and dark modes.
- History top content no longer enters the status bar / Dynamic Island area in light or dark screenshots.
- Today bottom action row remains above the floating Tab bar without an obvious double bottom gap.
- Projects keeps full-width background treatment and did not regain left/right gutters.
- Growth principle asset content can be dragged above the floating Tab bar in light and dark screenshots.
- Settings AI audit and settings rows can scroll above the floating Tab bar, and dark-mode placeholder/disabled text is readable enough for the current alpha visual bar.
- No Subtask 029 Claude Code worker implementation was accepted; acceptance is based on Codex source changes plus simulator evidence.

Residual risk:

- This pass is visual smoke acceptance, not exhaustive UI automation.
- Simulator navigation used macOS `System Events` coordinate clicks because the project currently has no UI test target for screenshot capture.
- Settings audit flicker was not re-recorded because the user explicitly confirmed it was fixed.

## 2026-06-04: Active Goal Recovery Verification

Scope:

- Recover from the temporary `EAGAIN` process-spawn blockage.
- Re-verify the Claude Code delegation pipeline evidence after the worktree returned to a commandable state.
- Re-run the iPhone 17 simulator build for the current clean worktree.
- Accept the user's direct confirmation that the Settings AI audit expand/collapse flicker is fixed, without spending another screenshot/recording pass on the same visual behavior.

Commands run:

```bash
git status --short
bash -n scripts/claude_delegate.sh
bash -n scripts/claude_event_bridge.sh
CLAUDE_DELEGATE_WAIT_SCHEDULE=0 scripts/claude_delegate.sh wait 034-manual-principle-creation docs/subtasks/034-manual-principle-creation-progress.md auto 1
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

- `git status --short` returned clean output.
- `bash -n` passed for both delegation scripts.
- `wait ... auto 1` found `HANDOFF` in the 034 worker progress file, proving the conclusion-first worker progress path is still readable.
- `git diff --check` passed.
- iPhone 17 simulator build passed.
- User-facing Settings AI audit flicker was manually confirmed fixed by the user in-thread; no additional screenshot/recording was captured in this pass per user instruction.

Residual risk:

- This entry verifies the active goal recovery path, delegation pipeline evidence, and current build state.
- Full Subtask 029 safe-area visual acceptance remains separate and still requires Today/History/Growth/Settings light/dark simulator screenshots.

## 2026-06-04: Manual Principle Creation And Delegation Dogfood

Scope:

- Add direct manual Principle creation from Growth.
- Dogfood the reusable Codex-to-Claude Code delegation framework on a real MingSi business slice.
- Preserve long-lived active principles separately from Today's resettable principle candidates.
- Add dynamic delegation wait backoff to the wrapper and generic skill prototype.

Changed areas:

- `Sources/App/AppStore.swift`
- `Sources/Features/FeatureTabs.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `scripts/claude_delegate.sh`
- `delegation-framework/claude-code-managed-delegation/SKILL.md`
- `delegation-framework/claude-code-managed-delegation/references/conclusion-first-monitoring.md`
- `docs/subtasks/034-manual-principle-creation-*`
- `docs/subtasks/logs/034-manual-principle-creation-*`

Commands run:

```bash
scripts/claude_delegate.sh prepare 034-manual-principle-creation docs/subtasks/034-manual-principle-creation-progress.md
CLAUDE_DELEGATE_MAX_BUDGET_USD=30.00 scripts/claude_delegate.sh launch 034-manual-principle-creation docs/subtasks/034-manual-principle-creation-claude-prompt.md docs/subtasks/034-manual-principle-creation-progress.md
scripts/claude_delegate.sh status 034-manual-principle-creation docs/subtasks/034-manual-principle-creation-progress.md
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testAddManualPrinciple_persistsActivePrincipleAndLinksToToday -only-testing:MingSiTests/AppStoreStateMachineTests/testAddManualPrinciple_rejectsMissingRequiredText -only-testing:MingSiTests/AppStoreStateMachineTests/testResetTodayLoop_keepsActiveManualPrinciplesVisibleInGrowthState test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
xcrun simctl install booted /Users/chenzewei/Library/Developer/Xcode/DerivedData/MingSi-fzvxdxbuzzkbvfctglvogodxewmw/Build/Products/Debug-iphonesimulator/MingSi.app
xcrun simctl launch booted com.codex.mingsi
xcrun simctl io booted screenshot docs/subtasks/screenshots/034-manual-principle-creation/02-launch-after-wait.png
```

Result:

- Claude Code reached `HANDOFF/DONE`.
- Codex accepted the worker direction but fixed the long-lived principle source after the worker flagged it as a concern.
- Focused manual principle tests passed: 3 tests, 0 failures.
- Full `AppStoreStateMachineTests` passed: 98 tests, 0 failures.
- `git diff --check` passed.
- iPhone 17 simulator build passed.
- App installed/launched on the booted iPhone 17 simulator and a nonblank launch screenshot was captured:
  - `docs/subtasks/screenshots/034-manual-principle-creation/02-launch-after-wait.png`

Residual risk:

- Growth manual principle sheet has build/test coverage and app launch verification, but still needs a direct Growth-tab interaction screenshot in a later visual QA pass.
- Flow logs for this dogfood run are stored as evidence and should not be routinely consumed.

## 2026-06-04: Claude Conclusion-First Delegation Pipeline And Settings Audit Visual Check

Scope:

- Reconcile the user's Claude Code utilization concern with a two-layer delegation log model.
- Verify that Claude Code can run from an isolated worker worktree, write worker progress, and reach `HANDOFF`.
- Ensure flow logs are retained but not routinely consumed by the manager.
- Raise the default print-mode Claude budget guard so ordinary GLM coding tasks are not starved before `HANDOFF`.
- Build the app after Settings audit flicker and safe-area/floating-tab source changes.
- Capture Settings audit expand/collapse evidence and Settings bottom scroll evidence.

Changed areas:

- `.gitignore`
- `scripts/claude_delegate.sh`
- `scripts/claude_event_bridge.sh`
- `docs/subtasks/032-claude-code-worker-fallback-smoke-*`
- `docs/subtasks/033-claude-code-conclusion-log-smoke-*`
- `docs/subtasks/logs/032-*`
- `docs/subtasks/logs/033-*`
- `docs/subtasks/claude-code-current-status.md`
- `docs/agent-delegation-log.md`
- `docs/mvp-current-goal.md`
- `docs/mvp-stage-progress.md`
- `docs/project-continuation-context.md`
- `docs/subtasks/screenshots/029-safe-area-floating-tab/05-today-light-after-build.png`
- `docs/subtasks/screenshots/029-safe-area-floating-tab/06-settings-light-after-build.png`
- `docs/subtasks/screenshots/029-safe-area-floating-tab/07-settings-light-scrolled.png`
- `docs/subtasks/screenshots/029-safe-area-floating-tab/08-settings-audit-toggle-light.mov`
- `docs/subtasks/screenshots/029-safe-area-floating-tab/08-settings-audit-toggle-light-frame-*.png`
- `docs/subtasks/screenshots/029-safe-area-floating-tab/09-settings-audit-collapsed-after-toggle-light.png`

Commands run:

```bash
bash -n scripts/claude_delegate.sh
bash -n scripts/claude_event_bridge.sh
CLAUDE_DELEGATE_MAX_BUDGET_USD=1.00 scripts/claude_delegate.sh launch 032-claude-code-worker-fallback-smoke docs/subtasks/032-claude-code-worker-fallback-smoke-claude-prompt.md docs/subtasks/032-claude-code-worker-fallback-smoke-progress.md
scripts/claude_delegate.sh wait 032-claude-code-worker-fallback-smoke docs/subtasks/032-claude-code-worker-fallback-smoke-progress.md 0 1
scripts/claude_delegate.sh status 032-claude-code-worker-fallback-smoke docs/subtasks/032-claude-code-worker-fallback-smoke-progress.md
CLAUDE_DELEGATE_MAX_BUDGET_USD=1.00 scripts/claude_delegate.sh launch 033-claude-code-conclusion-log-smoke docs/subtasks/033-claude-code-conclusion-log-smoke-claude-prompt.md docs/subtasks/033-claude-code-conclusion-log-smoke-progress.md
scripts/claude_delegate.sh wait 033-claude-code-conclusion-log-smoke docs/subtasks/033-claude-code-conclusion-log-smoke-progress.md 0 1
scripts/claude_delegate.sh status 033-claude-code-conclusion-log-smoke docs/subtasks/033-claude-code-conclusion-log-smoke-progress.md
ls -l docs/subtasks/logs/033-claude-code-conclusion-log-smoke-events.jsonl docs/subtasks/logs/033-claude-code-conclusion-log-smoke-claude-run.jsonl
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
xcrun simctl install booted /Users/chenzewei/Library/Developer/Xcode/DerivedData/MingSi-fzvxdxbuzzkbvfctglvogodxewmw/Build/Products/Debug-iphonesimulator/MingSi.app
xcrun simctl launch booted com.codex.mingsi
xcrun simctl io booted screenshot docs/subtasks/screenshots/029-safe-area-floating-tab/05-today-light-after-build.png
xcrun simctl io booted screenshot docs/subtasks/screenshots/029-safe-area-floating-tab/06-settings-light-after-build.png
xcrun simctl io booted screenshot docs/subtasks/screenshots/029-safe-area-floating-tab/07-settings-light-scrolled.png
xcrun simctl io booted recordVideo --codec h264 docs/subtasks/screenshots/029-safe-area-floating-tab/08-settings-audit-toggle-light.mov
ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 docs/subtasks/screenshots/029-safe-area-floating-tab/08-settings-audit-toggle-light.mov
ffmpeg -y -i docs/subtasks/screenshots/029-safe-area-floating-tab/08-settings-audit-toggle-light.mov ...
```

Result:

- `bash -n` passed for both delegation scripts.
- Subtask 032 reached worker-progress `HANDOFF` with final token `DONE`; Codex accepted it with follow-up because it exposed raw-stream and script-sync gaps.
- Subtask 033 reached worker-progress `HANDOFF` with final token `DONE`; Codex accepted it.
- Default print fallback now keeps raw model JSONL in the raw flow log instead of streaming it to the manager terminal.
- `status` / `wait` consume worker progress as the conclusion source and show retained flow-log paths without tailing event/raw logs by default.
- The wrapper syncs `scripts/claude_delegate.sh` and `scripts/claude_event_bridge.sh` into worker worktrees.
- Flow logs for 033 were retained on disk: raw log 247799 bytes, event log 75787 bytes.
- Default `CLAUDE_DELEGATE_MAX_BUDGET_USD` was raised from `0.50` to `30.00`; large delegated tasks should explicitly use `60.00` or higher.
- `git diff --check` passed.
- iPhone 17 simulator build passed.
- Settings bottom scroll screenshot shows bottom content can rest above the floating Tab bar.
- Settings audit expanded screenshot frames show stable expanded content with no visible overlapping row residue; the source fix removes group-level animation/transition and disables implicit transaction animation for the audit group.

Residual risk:

- Settings audit collapse was exercised, but the short video's second click did not capture a collapsed frame reliably; a separate collapsed screenshot was captured afterward.
- Full Subtask 029 visual acceptance is still incomplete: Today/History/Growth/Settings must still be recaptured in both light and dark modes after final scroll positions.
- The newly reported manual Principle creation feature is not implemented in this slice and should be handled as a separate atomic product task.

## 2026-06-04: Claude Delegation Pipeline Hardening And Settings Audit Flicker Fix

Scope:

- Set the active Codex pursuit goal in repo-owned documentation.
- Harden Claude Code delegation pipeline after Subtask 029 non-delivery and unreliable GLM usage telemetry.
- Fix Settings AI audit success/failure group expand-collapse flicker.
- Continue Subtask 029 safe-area/floating-tab work with build and partial simulator screenshot verification.

Changed areas:

- `scripts/claude_delegate.sh`
- `scripts/claude_event_bridge.sh`
- `.claude/delegation/030-claude-code-pipeline-hardening-settings.json`
- `docs/subtasks/030-claude-code-pipeline-hardening-prd.md`
- `docs/subtasks/030-claude-code-pipeline-hardening-progress.md`
- `docs/subtasks/logs/030-claude-code-pipeline-hardening-events.jsonl`
- `docs/mvp-current-goal.md`
- `docs/project-continuation-context.md`
- `docs/subtasks/claude-code-current-status.md`
- `docs/subtasks/029-safe-area-floating-tab-progress.md`
- `docs/agent-delegation-log.md`
- `docs/mvp-stage-progress.md`
- `Sources/DesignSystem/Theme.swift`
- `Sources/Features/FeatureTabs.swift`
- `Sources/Features/Today/TodayView.swift`
- `docs/subtasks/screenshots/029-safe-area-floating-tab/04-settings-audit-after-toggle-light.png`

Commands run:

```bash
git status --short
claude --help
claude agents --help
scripts/claude_delegate.sh --help
scripts/claude_delegate.sh prepare 030-claude-code-pipeline-hardening docs/subtasks/030-claude-code-pipeline-hardening-progress.md
scripts/claude_delegate.sh status 030-claude-code-pipeline-hardening docs/subtasks/030-claude-code-pipeline-hardening-progress.md
scripts/claude_delegate.sh wait 029-safe-area-floating-tab docs/subtasks/029-safe-area-floating-tab-progress.md 0 1
scripts/claude_delegate.sh wait 027-history-repair-ui docs/subtasks/027-history-repair-ui-progress.md 0 1
printf '{"probe":"bridge"}' | scripts/claude_event_bridge.sh docs/subtasks/logs/030-claude-code-pipeline-hardening-events.jsonl manual_probe
bash -n scripts/claude_delegate.sh
bash -n scripts/claude_event_bridge.sh
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
git diff --check
xcrun simctl io booted screenshot docs/subtasks/screenshots/029-safe-area-floating-tab/04-settings-audit-after-toggle-light.png
```

Result:

- `claude --help` confirmed `--worktree`, `--tmux`, `--agent`, `--settings`, `--allowedTools`, `--permission-mode`, and `--effort` are available.
- `claude agents --help` confirmed JSON status support through `claude agents --json`.
- `scripts/claude_delegate.sh --help` passed.
- `prepare` passed and generated task-local hook settings without changing global Claude settings.
- `status` passed and showed one idle interactive Claude agent; no Subtask 030 implementation worker was launched.
- `wait` correctly rejected Subtask 029 `HANDOFF: pending` with exit 75.
- `wait` correctly accepted Subtask 027 real handoff with exit 0 by reading `.claude/worktrees/subtask-027-history-repair-ui/docs/subtasks/027-history-repair-ui-progress.md`.
- Wrapper now creates/reuses the worker worktree on launch and syncs matching `docs/subtasks/<id-topic>*` files so untracked PRD/prompt/progress docs are available to the worker.
- `status` now prints active, manager, and worker progress paths so Codex can see which truth source is being monitored.
- `bash -n` passed for both wrapper scripts.
- Event bridge manual probe appended JSONL evidence with base64 payload.
- Initial pipeline verification exposed a macOS `date -Is` incompatibility; wrapper and bridge were fixed to use portable timestamps.
- Settings AI audit flicker root cause was removed by deleting the group-wide SwiftUI animation and row transition while keeping chevron-only animation.
- App build passed after source changes.
- `git diff --check` passed after final source/script/documentation updates.
- Screenshot `04-settings-audit-after-toggle-light.png` captured the Settings audit group expanded stable state.

Residual risk:

- Settings flicker was verified by code-level root cause removal and stable screenshots, but not yet by recorded video of the transient animation.
- Subtask 029 safe-area/floating-tab visual acceptance is incomplete; Settings audit content still appears close to the floating Tab bar boundary in partial screenshots.
- No new Claude Code worker was launched through the wrapper yet, so actual worker utilization improvement is ready to test but not proven on an implementation slice.

## 2026-06-03: Context Preservation And Subtask 029 Delegation Audit

Scope:

- Preserve current thread/project context into repository-owned docs.
- Record Subtask 029 Claude Code launch attempts and non-delivery status.
- Ensure no active Claude worker remains running.
- Do not accept any Subtask 029 implementation because no worker `HANDOFF` occurred.

Changed areas:

- `docs/project-continuation-context.md`
- `docs/subtasks/029-safe-area-floating-tab-prd.md`
- `docs/subtasks/029-safe-area-floating-tab-progress.md`
- `docs/subtasks/029-safe-area-floating-tab-claude-prompt.md`
- `docs/subtasks/claude-code-current-status.md`
- `docs/subtasks/logs/README.md`
- `docs/agent-delegation-log.md`
- `docs/mvp-stage-progress.md`

Commands run:

```bash
git status --short
git worktree add -b worker-subtask-029-safe-area-floating-tab .claude/worktrees/subtask-029-safe-area-floating-tab HEAD
claude -p --output-format stream-json --verbose --include-hook-events --permission-mode dontAsk --model glm-5.1 ...
ps -axo pid,etime,command | rg 'subtask-029-safe-area-floating-tab|029-claude-run-focused|claude -p'
kill 13981
kill 18237
```

Result:

- Subtask 029 delegation package was created.
- First Claude launch failed before `START` due CLI prompt parsing.
- Second Claude launch was stopped after no `START`.
- Focused Claude launch reached `START` but did not reach `RED`, `IMPLEMENTED`, `TARGETED_VERIFIED`, or `HANDOFF`.
- No Subtask 029 source implementation was accepted.
- Current status file records no active Claude worker.

Residual risk:

- Subtask 029 remains unimplemented.
- No build or simulator verification was run for Subtask 029 because there is no accepted implementation yet.
- Further Claude Code implementation attempts should use a stronger wrapper or a different launch mode.

## 2026-06-03: AI Language, Busy State, Recoverable GLM Retry, And History Repair Helpers

Scope:

- Enforce Chinese-first prompt language behavior while preserving input-language following.
- Add bounded retry for recoverable GLM 429/529/5xx responses in normal and SSE streaming calls.
- Expose AppStore AI busy state and disable duplicate Today/background retry actions while a request is running.
- Bring Subtask 027 local History repair helper tests to green so the worktree is testable again.

Changed areas:

- `Sources/Services/CoreProtocols.swift`
- `Sources/Services/DirectGLMClient.swift`
- `Sources/App/AppStore.swift`
- `Sources/App/AppRootView.swift`
- `Sources/Features/Today/TodayView.swift`
- `Sources/Features/FeatureTabs.swift`
- `Tests/Services/LocalPromptProviderTests.swift`
- `Tests/Services/DirectGLMClientTests.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `Tests/Features/HistoryFeatureTests.swift`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/LocalPromptProviderTests/testEveryPromptTemplate_hasCommonThinkingCoachGuardrails -only-testing:MingSiTests/DirectGLMClientTests/testComplete_retriesRecoverableRateLimitStatus -only-testing:MingSiTests/DirectGLMClientTests/testStream_retriesRecoverableRateLimitStatusBeforeYieldingTokens -only-testing:MingSiTests/AppStoreStateMachineTests/testAIGenerationBusyStateBlocksDuplicateRetryRequests -only-testing:MingSiTests/HistoryFeatureTests/testHistoryRepairCardPreview_decodesValidCandidatePayload -only-testing:MingSiTests/HistoryFeatureTests/testHistoryRepairCardPreview_invalidPayloadReturnsEmpty -only-testing:MingSiTests/HistoryFeatureTests/testHistoricalRetryCandidateStatus_historyRepairTitleCoversReviewStates -only-testing:MingSiTests/HistoryFeatureTests/testHistoryRepairPromptSupport_onlyOrganizeCardsCanStartHistoricalRetry test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/DirectGLMClientTests -only-testing:MingSiTests/LocalPromptProviderTests -only-testing:MingSiTests/HistoryFeatureTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
git diff --check
```

Result:

- Targeted tests passed: 8 tests, 0 failures.
- DirectGLMClientTests + LocalPromptProviderTests + HistoryFeatureTests passed: 41 tests, 0 failures.
- AppStoreStateMachineTests passed: 95 tests, 0 failures.
- App build succeeded.
- `git diff --check` passed.

Residual risk:

- Simulator/manual visual QA was not run in this slice.
- Detailed per-run background repair progress/result presentation remains a follow-up.

## 2026-06-03: Historical AI Retry AppStore Guard

Scope:

- Add AppStore/use-case orchestration for historical `organizeCards` retry.
- Keep retry output as a reviewable `HistoricalRetryCandidate` payload.
- Ensure historical retry does not mutate current-day cards.
- Reject unsupported historical prompt types.
- Block candidate acceptance when confirmed cards already exist.

Changed areas:

- `Sources/App/AppStore.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`
- `docs/agent-delegation-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testStartHistoricalOrganizeCardsRetry_createsCandidateWithoutChangingCurrentCards test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testStartHistoricalOrganizeCardsRetry_rejectsUnsupportedPrompt -only-testing:MingSiTests/AppStoreStateMachineTests/testAcceptHistoricalRetryCandidate_blocksWhenConfirmedCardsExist test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
git diff --check
```

Result:

- Historical retry success test passed: 1 test, 0 failures.
- Unsupported prompt and confirmed-card guard tests passed: 2 tests, 0 failures.
- AppStoreStateMachineTests passed: 94 tests, 0 failures.
- PersistenceCoreTests passed on rerun: 55 tests, 0 failures.
- App build succeeded.
- Whitespace check passed.

Notes:

- The first PersistenceCoreTests attempt failed before tests loaded due to a simulator test bundle loading error; rerunning the same command succeeded with 55 tests and 0 failures.
- `repairPromptRunId` is attached only when a real PromptRun can be discovered from prompt tracing. Tests do not require a fake repair PromptRun id.

Residual risk:

- No History UI entry point or candidate sheet exists yet for this AppStore action.
- Acceptance guards currently cover confirmed cards only; PRD still requires future checks for lens sessions, questions, quests, principles, project links, project insights, and growth contributions sourced from the entry.

## 2026-06-03: HistoricalRetryCandidate Migration And Repository

Scope:

- Add `HistoricalRetryCandidate` domain status/model.
- Add v8 SQLite migration for `historical_retry_candidates`.
- Add `HistoricalRetryCandidateRepository` and `SQLiteHistoricalRetryCandidateRepository`.
- Add persistence tests for create/query, attach repair run, status update, soft delete, PromptRun preservation, and migration indexes.

Changed areas:

- `Sources/Domain/Models.swift`
- `Sources/Services/PersistenceCore.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`
- `docs/agent-delegation-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testHistoricalRetryCandidate_createAttachAndQueryByEntry test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
git diff --check
```

Result:

- RED confirmed before implementation: build failed because `SQLiteHistoricalRetryCandidateRepository` and `HistoricalRetryCandidate` did not exist.
- First target GREEN passed: 1 test, 0 failures.
- Full PersistenceCoreTests passed: 55 tests, 0 failures.
- AppStoreStateMachineTests passed: 91 tests, 0 failures.
- App build succeeded.
- Whitespace check passed.

Residual risk:

- This only establishes durable candidate storage.
- Historical retry still needs AppStore/use-case orchestration, acceptance guards against downstream evidence, GLM retry execution, and History candidate review UI.
- Two parallel single-test xcodebuild runs hit simulator bootstrapping early-exit; the same coverage passed in the serial full PersistenceCoreTests run.

## 2026-06-03: Historical AI Retry Candidate Review PRD

Scope:

- Convert the Subtask 025 audit into a product and architecture decision for historical AI retry.
- Specify candidate review semantics, first-prompt scope, data model, migration requirement, guards, UI states, and delegatable follow-up slices.
- Align `docs/data-architecture.md` with the new `HistoricalRetryCandidate` entity.

Changed areas:

- `docs/subtasks/026-historical-ai-retry-candidate-review-prd.md`
- `docs/data-architecture.md`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
git status --short
git diff --check
```

Result:

- `git diff --check` passed.

Residual risk:

- This is a PRD/architecture alignment slice, not an implementation.
- The next code slice still needs migration, repository, AppStore guard, and History UI tests.

## 2026-06-03: Historical AI Retry Read-Only Audit

Scope:

- Delegate a read-only audit of current historical AI retry capability.
- Identify existing retry infrastructure, blockers, and the safest next slice without changing Swift source or tests.
- Record Codex acceptance and rejection of Claude Code findings.

Changed areas:

- `docs/subtasks/025-historical-ai-retry-audit-prd.md`
- `docs/subtasks/025-historical-ai-retry-audit-progress.md`
- `docs/subtasks/025-historical-ai-retry-audit-claude-prompt.md`
- `docs/subtasks/025-historical-ai-retry-audit-findings.md`
- `docs/agent-delegation-log.md`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`
- `docs/architecture-decisions.md`

Commands run:

```bash
git diff --check -- docs/subtasks/025-historical-ai-retry-audit-progress.md docs/subtasks/025-historical-ai-retry-audit-findings.md
```

Result:

- Whitespace check passed for the delegated audit outputs.
- Claude Code reached `HANDOFF` with status `DONE`.
- Codex accepted the implementation map and rejected the direct implementation recommendation because it contradicted migration requirements and touched product-sensitive retry semantics.

Residual risk:

- This was a code/document audit, not a runtime feature implementation.
- Historical retry still needs a Codex-owned PRD/architecture pass before any implementation delegation.

## 2026-06-03: Settings AI Audit Grouping

Scope:

- Make Settings AI audit usable when many PromptRun records exist.
- Group recent calls into failed and successful sections without changing PromptRun persistence or LLM behavior.
- Keep History advanced-filter stability covered because the newest user report mentioned dropdown bounce/clipping.

Changed areas:

- `Sources/Features/FeatureTabs.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/subtasks/024-settings-ai-audit-grouping-progress.md`
- `docs/agent-delegation-log.md`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' clean test -only-testing:MingSiTests/AppStoreStateMachineTests
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:MingSiTests/AppStoreStateMachineTests
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:MingSiTests/HistoryFeatureTests
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
git diff --check
```

Result:

- RED confirmed: clean test failed before implementation because `PromptRunAuditSummary` was missing.
- AppStoreStateMachineTests passed: 91 tests, 0 failures.
- HistoryFeatureTests passed: 24 tests, 0 failures.
- App build succeeded.
- Whitespace check passed.

Residual risk:

- Settings grouping is code/test verified, not screenshot verified. Manual simulator visual QA should confirm the collapsed success section and expanded failure section with a long audit list.
- History advanced-filter bounce/clipping is covered by fixed chip metrics and disabled implicit animations, but real Menu popover geometry should still be checked manually in the simulator with long option labels.

## 2026-06-03: History Advanced Filter Visual Stability

Scope:

- Fix History advanced filter dropdown selection bounce and partial top clipping.
- Keep change local to History filter UI metrics and animation behavior.

Changed areas:

- `Sources/Features/FeatureTabs.swift`
- `Tests/Features/HistoryFeatureTests.swift`

Commands run:

```bash
## 2026-06-03: Subtask 027 History Repair UI Acceptance

Scope:

- Accept Claude Code worker handoff for fixed-contract History repair UI.
- Add Codex manager fix so historical repair warnings cover confirmed cards and downstream evidence, not only confirmed cards.
- Verify the accepted implementation from the manager worktree.

Changed areas:

- `Sources/App/AppStore.swift`
- `Sources/Features/FeatureTabs.swift`
- `Sources/Domain/Models.swift`
- `Tests/Features/HistoryFeatureTests.swift`
- `docs/subtasks/027-history-repair-ui-progress.md`
- `docs/mvp-stage-progress.md`
- `docs/agent-delegation-log.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests/testHistoryRecordRepairBlockingEvidence_includesConfirmedCardsAndDownstreamEvidence test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
git diff --check
```

Result:

- New RED/GREEN downstream-evidence guard test passed: 1 test, 0 failures.
- HistoryFeatureTests passed: 29 tests, 0 failures.
- AppStoreStateMachineTests passed: 95 tests, 0 failures.
- App build succeeded.
- Whitespace check passed.

Residual risk:

- This was code/test verified. Manual simulator QA should still inspect History repair presentation, dark mode contrast, and long failed/candidate lists.

xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests/testHistoryFilterChipMetrics_keepAdvancedFilterWidthStable test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
git diff --check
```

Result:

- Stable chip metric test passed: 1 test, 0 failures.
- HistoryFeatureTests passed: 24 tests, 0 failures.
- App build succeeded.
- Whitespace check passed.

Residual risk:

- This was build/test verified. Manual visual smoke on simulator should still confirm the dropdown presentation under real interaction, especially with long project names and with the global AI repair banner visible.

## 2026-06-08: Subtask 084 Project/Growth Structured Payload Source Cleanup

Scope:

- Continue the Prompt / Context migration after Subtask 083.
- Make Project and Growth AI requests derive the legacy `LLMRequest.jsonPayload` compatibility dictionary from `PromptContextPayload.legacyKeyValues`.
- Keep structured `PromptContextPayload` as the source request payload for Project/Growth context while preserving existing DirectGLM compatibility and tests.

Changed areas:

- `Sources/Services/ProjectAIService.swift`
- `Sources/Services/GrowthAIService.swift`
- `Tests/Services/ProjectAIServiceContextTests.swift`
- `Tests/Services/TodayAIServiceContextTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/ProjectAIServiceContextTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/TodayAIServiceContextTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests
xcodebuild build -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17'
git diff --check
```

Result:

- `ProjectAIServiceContextTests/testSuggestProjectLinks_usesStructuredContextAsLegacyPayloadSource` proves Project link suggestion requests keep legacy compatibility by exporting `PromptContextPayload.legacyKeyValues`.
- `TodayAIServiceContextTests/testGrowthAIService_usesStructuredContextAsLegacyPayloadSource` proves Growth weekly/monthly report requests follow the same structured-context source pattern.
- `ProjectAIServiceContextTests` passed: 8 tests, 0 failures.
- `TodayAIServiceContextTests` passed: 18 tests, 0 failures.
- Full `MingSiTests` passed: 430 tests, 0 failures.
- Full `MingSiUITests` passed: 2 tests, 0 failures.
- iPhone 17 simulator build succeeded.
- `git diff --check`: exit 0, no output.

Residual risk:

- `LLMRequest.jsonPayload` remains a compatibility field because `PromptTracingLLMClient` and existing tests still inspect legacy keys.
- `ProjectAIService` and `GrowthAIService` still construct legacy dictionaries before inserting them into `PromptContextPayload.extra`; a later migration should type more Project/Growth-specific fields directly into `PromptContextPayload`.
- `TodayAIService.verifyQuest` still constructs an explicit legacy payload while also carrying structured context; it is the next narrow payload-cleanup target.
- First-class eval runner/history and principle recall feedback remain open.

## 2026-06-08: Subtask 085 VerifyQuest Structured Payload Source Cleanup

Scope:

- Continue the Prompt / Context migration after Subtask 084.
- Make `TodayAIService.verifyQuest` derive legacy `LLMRequest.jsonPayload` compatibility from `PromptContextPayload.legacyKeyValues`.
- Preserve verification source/context ids and parser behavior.

Changed areas:

- `Sources/Services/TodayAIService.swift`
- `Tests/Services/TodayAIServiceContextTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/TodayAIServiceContextTests/testVerifyQuest_usesStructuredContextAsLegacyPayloadSource
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/TodayAIServiceContextTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests
```

Result:

- Initial RED failed as expected because `verifyQuest` used a hand-written legacy dictionary that diverged from `PromptContextPayload.legacyKeyValues` and omitted `sessionMode`.
- `verifyQuest` now constructs `PromptContextPayload` first and passes `jsonPayload: contextPayload.legacyKeyValues`.
- Focused RED/GREEN test passed: 1 test, 0 failures.
- `TodayAIServiceContextTests` passed: 19 tests, 0 failures.
- Full `MingSiTests` passed: 431 tests, 0 failures.

Residual risk:

- `LLMRequest.jsonPayload` remains a compatibility field because shared tracing/tests still inspect it.
- Project/Growth context still stores some domain-specific legacy text in `PromptContextPayload.extra`; a later slice should promote important Project/Growth fields into typed `PromptContextPayload` members.
- Full legacy payload removal, first-class eval runner/history, and principle recall feedback remain open.

## 2026-06-08: Subtask 083 Today Structured Payload Source Cleanup

Scope:

- Add a DirectGLM request-body regression proving `PromptContextPayload` is the model-facing payload when present.
- Remove Today assembler's duplicate legacy `[String: String]` payload tree.
- Keep `PromptContextPayload.legacyKeyValues` as the final compatibility export only.

Changed areas:

- `Sources/Services/TodayAIService.swift`
- `Tests/Services/DirectGLMClientTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/DirectGLMClientTests/testComplete_prefersStructuredContextPayloadOverLegacyFlattenedPayload
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/TodayAIServiceContextTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/DirectGLMClientTests
rg -n "PromptContext\(|\.payload\b|basePayload\(|cardsPayload\(|questionsPayload\(|questsPayload\(|principlesPayload\(" Sources/Services/TodayAIService.swift Tests/Services/TodayAIServiceContextTests.swift
git diff --check
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests
xcodebuild build -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17'
```

Result:

- Initial DirectGLM assertion failed because it inspected escaped transport JSON instead of the decoded model-facing user message; the test was corrected to parse the request body and inspect the user message content.
- Structured DirectGLM payload test passed: 1 test, 0 failures.
- `TodayAIServiceContextTests` passed: 17 tests, 0 failures.
- `DirectGLMClientTests` passed: 8 tests, 0 failures.
- Dead Today legacy payload helper search now only finds the `PromptContext(` constructor.
- `git diff --check` passed.
- `MingSiTests` passed: 428 tests, 0 failures.
- `MingSiUITests` passed: 2 tests, 0 failures.
- iPhone 17 simulator build succeeded.

Residual risk:

- ProjectAIService and GrowthAIService still build explicit legacy payload dictionaries alongside structured `PromptContextPayload`; those paths remain the next payload-cleanup target.
- `LLMRequest.jsonPayload` remains for compatibility and tests. Full removal requires migrating all Project/Growth call sites and updating consumers that still inspect legacy keys.

## 2026-06-03: Process Document Alignment

Scope:

- Add missing process documents required by the active project operating model.
- Re-align current MVP stop condition, stage progress, architecture decisions, and verification trace.

Changed areas:

- `docs/mvp-current-goal.md`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`
- `docs/architecture-decisions.md`
- `docs/agent-delegation-log.md`

Commands run:

```bash
git status --short
git diff --check
```

Result:

- Required process files now exist.
- `git diff --check` passed.

Residual risk:

- Process docs summarize current repo evidence but do not replace full runtime visual QA.

## 2026-06-03: Claude Code Visual Smoke Audit

Scope:

- Delegate a read-only visual and interaction smoke audit across Today, History, Projects, Growth, and Settings.
- Identify top user-facing visual/interaction hardening work without modifying source code.

Changed areas:

- `docs/subtasks/023-visual-smoke-audit-prd.md`
- `docs/subtasks/023-visual-smoke-audit-progress.md`
- `docs/subtasks/023-visual-smoke-audit-claude-prompt.md`
- `docs/subtasks/023-visual-smoke-audit-findings.md`
- `docs/agent-delegation-log.md`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
claude -p --output-format stream-json --verbose --permission-mode dontAsk --model glm-4.6 --allowedTools Read,LS,Grep,Glob,Bash -- "Read docs/subtasks/023-visual-smoke-audit-claude-prompt.md ..."
```

Result:

- Claude Code completed with final token `DONE_WITH_CONCERNS`.
- Audit was code-informed only; no simulator visual launch was performed.
- Codex accepted Settings AI audit list scalability as the top actionable next slice.

Residual risk:

- Findings are not visually confirmed. Real simulator smoke QA is still required before claiming MVP visual readiness.

## 2026-06-10: PromptContextPayload Extra Removal / Prompt Pack Runtime Audit

Scope:

- Continue Prompt / Context assetization by removing the remaining arbitrary `PromptContextPayload.extra` dictionary from the encoded payload schema.
- Preserve derived `legacyKeyValues` only as a prompt-rendering compatibility adapter sourced from typed fields.
- Audit current Prompt Asset Pack runtime wiring and Alpha GLM prerequisite state.

Changed areas:

- `Sources/Services/CoreProtocols.swift`
- `Tests/Services/TodayAIServiceContextTests.swift`
- `Tests/Services/ProjectAIServiceContextTests.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/TodayAIServiceContextTests/testPromptContextPayloadEncodingOmitsUnstructuredExtraDictionary
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/TodayAIServiceContextTests -only-testing:MingSiTests/ProjectAIServiceContextTests -only-testing:MingSiTests/DirectGLMClientTests -only-testing:MingSiTests/PersistenceCoreTests/testPromptTracingLLMClient_recordsSuccessAndFailure -only-testing:MingSiTests/PersistenceCoreTests/testPromptTracingLLMClient_recordsPromptAssetVersions -only-testing:MingSiTests/PersistenceCoreTests/testPromptTracingLLMClient_prefersStructuredContextSessionModeOverLegacyPayload -only-testing:MingSiTests/PersistenceCoreTests/testPromptTracingLLMClient_withoutStructuredContextDoesNotAuditLegacySessionMode -only-testing:MingSiTests/PersistenceCoreTests/testLLMRequest_hasNoStoredLegacyPayloadField -only-testing:MingSiTests/PersistenceCoreTests/testLLMRequest_exposesStructuredContextForLegacyCompatibilityExport -only-testing:MingSiTests/PersistenceCoreTests/testLLMRequest_allowsStructuredContextWithoutCallerLegacyPayload -only-testing:MingSiTests/PersistenceCoreTests/testPromptContextPayloadLegacyExportUsesOnlyStructuredFields
rg -n "extra:|\\.extra\\b|var extra|let extra|\"extra\"" Sources Tests docs/prompt-spec.md docs/technical-architecture.md docs/mvp-stage-progress.md -g '!docs/subtasks/screenshots/**'
git diff --check
```

Result:

- RED first failed because encoding a typed `PromptContextPayload` still produced `"extra": {}`.
- Removed the stored/encoded `extra` field and constructor parameter from `PromptContextPayload`.
- Updated service and persistence tests so they verify typed `growth`, `project`, `verification`, and derived compatibility output rather than an empty extra dictionary.
- Focused GREEN passed: `testPromptContextPayloadEncodingOmitsUnstructuredExtraDictionary`, 1 test, 0 failures.
- Related service/audit suite passed: 49 tests, 0 failures across Today context, Project context, DirectGLM, and touched PromptRun/Persistence structured-context tests.
- Search found no production or test reference to `PromptContextPayload.extra`; the only `"extra"` hit is the new schema-absence assertion.
- `git diff --check` passed.
- Prompt Asset Pack runtime wiring was audited in current AppStore code/tests: enabled packs feed `PromptAssetPackProvider`, disabled packs are ignored, persisted rollback selections override enabled pack current versions, and scheduled eval records enabled pack prompt versions.

Residual risk:

- A real BYOK GLM network success is still not proven in this environment because `MINGSI_GLM_API_KEY`, `GLM_API_KEY`, and `SIMCTL_CHILD_MINGSI_GLM_API_KEY` are absent. Keep Subtask 115 live harness as the acceptance path once a key/network window is available.
- Remote prompt/lens registry, source trust, and signature verification remain future work.

## 2026-06-11: Asset Pack Registry Publisher Trust Metadata

Scope:

- Continue remote registry / publisher-onboarding readiness without requiring an external registry or BYOK GLM key.
- Add publisher and trust-policy metadata to remote asset-pack catalog entries.
- Let catalog entry trust-policy metadata authorize a selected entry install when the fetched manifest omits `trustPolicyURL`.
- Surface publisher/policy metadata in Settings remote catalog rows.

Changed areas:

- `Sources/Services/PersistenceCore.swift`
- `Sources/App/AppStore.swift`
- `Sources/Features/FeatureTabs.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackRegistryCatalog_decodesPublisherAndTrustPolicyMetadata -only-testing:MingSiTests/AppStoreStateMachineTests/testInstallAssetPackRegistryCatalogEntry_usesCatalogTrustPolicyWhenManifestOmitsPolicy
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackRegistryCatalog_decodesManifestEntries -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackRegistryCatalog_resolvesRelativeManifestURLsAgainstCatalogURL -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackRegistryCatalog_decodesPublisherAndTrustPolicyMetadata -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackInstallManifest_filtersInstallablePromptAndLensPacksThroughTrustGate -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackInstallManifestInstaller_savesOnlyValidatedPromptAndLensPacks -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_reusesTrustedInstallGateAndRefreshesRuntimeAssets -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_usesRemoteTrustPolicyBeforeInstalling -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAssetPackRegistryCatalog_loadsRemoteEntriesForSettingsSelection -only-testing:MingSiTests/AppStoreStateMachineTests/testSyncAssetPackRegistrySubscriptions_fetchesEnabledCatalogsAndRecordsStatus -only-testing:MingSiTests/AppStoreStateMachineTests/testSyncDueAssetPackRegistrySubscriptions_fetchesOnlyDueSubscriptions -only-testing:MingSiTests/AppStoreStateMachineTests/testInstallAssetPackRegistryCatalogEntry_fetchesEntryManifestAndInstallsThroughTrustGate -only-testing:MingSiTests/AppStoreStateMachineTests/testInstallAssetPackRegistryCatalogEntry_usesCatalogTrustPolicyWhenManifestOmitsPolicy -only-testing:MingSiTests/AppStoreStateMachineTests/testSettingsAutomationIdentifiers_areStableForAssetPackInstallManifest
git diff --check
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests
```

Result:

- RED first failed as intended because `AssetPackRegistryCatalogEntry` did not accept publisher/trust-policy metadata and did not expose `trustPolicySourceURL(baseURL:)`.
- Added optional `publisherId`, `publisherDisplayName`, `trustPolicyURL`, and `requiredVerificationPolicyVersion` catalog-entry fields with relative trust-policy URL resolution.
- `AppStore.installAssetPackRegistryCatalogEntry` now passes a catalog-entry trust-policy URL as the fallback policy for `fetchAndInstallAssetPackInstallManifest` when the manifest itself has no `trustPolicyURL`.
- Settings remote catalog rows now display publisher and trust-policy metadata.
- Focused GREEN passed with 2 tests and 0 failures.
- Registry/manifest regression coverage passed with 13 tests and 0 failures.
- `git diff --check` passed.
- Full `MingSiTests` passed with 574 tests executed, 1 skipped, and 0 failures.
- Full `MingSiUITests` passed with 11 tests and 0 failures.

Residual risk:

- This is still local/test registry readiness. There is no real external registry service, publisher onboarding workflow, external key-distribution UX, or live registry acceptance run yet.

## 2026-06-11: Asset Pack Registry Required Trust Policy Enforcement

Scope:

- Enforce `AssetPackRegistryCatalogEntry.requiredVerificationPolicyVersion` during catalog-entry installs instead of treating it as display-only metadata.
- Reject Prompt/Lens packs whose trust metadata was signed under a different verification policy version, even if the fetched trust policy document contains keys for both policy versions.
- Preserve the existing remote trust-policy fetch/cache and signed-pack validation path.

Changed areas:

- `Sources/Services/PersistenceCore.swift`
- `Sources/App/AppStore.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testInstallAssetPackRegistryCatalogEntry_rejectsPackWhenRequiredPolicyVersionDiffers
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackInstallManifest_filtersInstallablePromptAndLensPacksThroughTrustGate -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackInstallManifestInstaller_savesOnlyValidatedPromptAndLensPacks -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_usesRemoteTrustPolicyBeforeInstalling -only-testing:MingSiTests/AppStoreStateMachineTests/testInstallAssetPackRegistryCatalogEntry_fetchesEntryManifestAndInstallsThroughTrustGate -only-testing:MingSiTests/AppStoreStateMachineTests/testInstallAssetPackRegistryCatalogEntry_usesCatalogTrustPolicyWhenManifestOmitsPolicy -only-testing:MingSiTests/AppStoreStateMachineTests/testInstallAssetPackRegistryCatalogEntry_rejectsPackWhenRequiredPolicyVersionDiffers
git diff --check
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests
```

Result:

- RED first failed because `AssetPackInstallRejectionReason` had no `.unexpectedVerificationPolicyVersion` case and catalog-entry installs did not pass the required policy version into manifest validation.
- Added `.unexpectedVerificationPolicyVersion` and made `AssetPackInstallManifestValidator` compare Prompt/Lens trust metadata against the catalog entry's required policy version before content-hash and signature verification.
- `AppStore.installAssetPackRegistryCatalogEntry` now forwards `entry.requiredVerificationPolicyVersion` through the remote manifest fetch/install path.
- Focused GREEN passed with 1 test and 0 failures.
- Related registry/manifest regression coverage passed with 6 tests and 0 failures.
- `git diff --check` passed.
- Full `MingSiTests` passed with 575 tests executed, 1 skipped, and 0 failures.
- Full `MingSiUITests` passed with 11 tests executed and 0 failures.

Residual risk:

- Real BYOK GLM confirmation is still not proven in this environment because `MINGSI_GLM_API_KEY`, `GLM_API_KEY`, and `SIMCTL_CHILD_MINGSI_GLM_API_KEY` are absent.
- This is still local/test registry readiness; it does not add a real external registry service, real publisher onboarding workflow, external key-distribution UX, or live registry acceptance run.

## 2026-06-11: Asset Pack Install Rejection Reason Surface

Scope:

- Improve remote asset-pack distribution diagnostics without adding a new install state machine.
- Preserve existing installed/rejected count messages.
- Append grouped rejection reasons for Prompt and Lens packs when an install report rejects any packs.

Changed areas:

- `Sources/App/AppStore.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testImportAssetPackInstallManifestFromJSON_savesValidatedPacksAndRefreshesRuntimeAssets -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_reusesTrustedInstallGateAndRefreshesRuntimeAssets -only-testing:MingSiTests/AppStoreStateMachineTests/testInstallAssetPackRegistryCatalogEntry_rejectsPackWhenRequiredPolicyVersionDiffers
rg -n "assetPackInstallMessage, \".*拒绝|assetPackInstallMessage\\.contains\\(\".*拒绝|拒绝原因" Tests Sources docs/mvp-stage-progress.md docs/verification-log.md
git diff --check
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests
```

Result:

- RED first failed because local/remote rejected installs only reported counts and the catalog policy-version mismatch message did not include the concrete reason.
- `AppStore.assetPackInstallSummary` now appends grouped reason text when Prompt/Lens packs are rejected.
- Rejection labels cover missing trust metadata, incomplete trust metadata, policy-version mismatch, content-hash mismatch, and invalid signature/trust proof.
- Focused GREEN passed with 3 AppStore state-machine tests and 0 failures.
- Search audit found only the expected message assertions, no-rejection exact assertions, the implementation, and this verification-log command.
- `git diff --check` passed.
- Full `MingSiTests` passed with 575 tests executed, 1 skipped, and 0 failures.
- Full `MingSiUITests` passed with 11 tests executed and 0 failures.

Residual risk:

- This improves local and test-backed install diagnostics only; it does not add real external registry onboarding, remote prompt/lens rollout, or live BYOK GLM confirmation.

## 2026-06-11: Live GLM BYOK Environment Alias Compatibility

Scope:

- Make the live GLM acceptance harness accept the same BYOK environment names used by setup docs and simulator launch flows.
- Preserve `MINGSI_LIVE_GLM_API_KEY` precedence for explicit live acceptance runs.
- Keep `SIMCTL_CHILD_` environment forwarding and Keychain fallback behavior intact.

Changed areas:

- `Tests/Services/LiveGLMAcceptanceTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/LiveGLMAcceptanceTests/testHarnessAcceptsStandardBYOKEnvironmentKeys
git diff --check
bash -lc 'for key in MINGSI_LIVE_GLM_API_KEY MINGSI_GLM_API_KEY GLM_API_KEY SIMCTL_CHILD_MINGSI_LIVE_GLM_API_KEY SIMCTL_CHILD_MINGSI_GLM_API_KEY SIMCTL_CHILD_GLM_API_KEY; do if [ -n "${!key:-}" ]; then printf "%s=present\n" "$key"; else printf "%s=missing\n" "$key"; fi; done'
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/LiveGLMAcceptanceTests
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests
```

Result:

- RED first failed because `MINGSI_GLM_API_KEY` and `GLM_API_KEY` resolved to `nil`; the live-specific precedence case already passed.
- `LiveGLMAcceptanceHarness.resolvedAPIKey()` now checks `MINGSI_LIVE_GLM_API_KEY`, `MINGSI_GLM_API_KEY`, and `GLM_API_KEY` in order before Keychain fallback.
- Skip guidance now lists the accepted BYOK key names instead of only the live-specific key.
- Focused GREEN passed with 1 test and 0 failures.
- `git diff --check` passed.
- Local environment check found all host and `SIMCTL_CHILD_` BYOK key variables missing without printing secret values.
- Full `LiveGLMAcceptanceTests` passed with 5 tests executed, 1 skipped, and 0 failures.
- Full `MingSiTests` passed with 576 tests executed, 1 skipped, and 0 failures.
- Full `MingSiUITests` passed with 11 tests executed and 0 failures.

Residual risk:

- Real BYOK GLM network success remains externally blocked until a user-provided key is configured and an external call window is approved.

## 2026-06-11: Remote Trust Policy Publisher Profile Boundary

Scope:

- Add signed publisher profile metadata to remote trust-policy documents so publisher onboarding has an auditable identity boundary, not only a publisher id to public-key map.
- Keep legacy trust-policy JSON compatible and preserve no-profile policy signatures by omitting empty profile arrays during encoding.
- Surface signed publisher display names in remote manifest install status messages.

Changed areas:

- `Sources/Services/PersistenceCore.swift`
- `Sources/App/AppStore.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackTrustPolicy_decodesPublisherProfilesAndDefaultsLegacyDocuments -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackTrustPolicyDocumentSignatureVerifier_rejectsPublisherProfileTampering
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_surfacesRemotePublisherProfiles
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackTrustPolicyDocumentSignatureVerifier_allowsSignedDocuments -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackTrustPolicyDocumentSignatureVerifier_rejectsUnsignedAndTamperedDocuments -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackTrustPolicyRepository_saveAndLoadDocuments -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackTrustPolicy_decodesPublisherProfilesAndDefaultsLegacyDocuments -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackTrustPolicyDocumentSignatureVerifier_rejectsPublisherProfileTampering -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_reusesTrustedInstallGateAndRefreshesRuntimeAssets -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_usesRemoteTrustPolicyBeforeInstalling -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_surfacesRemotePublisherProfiles -only-testing:MingSiTests/AppStoreStateMachineTests/testInstallAssetPackRegistryCatalogEntry_usesCatalogTrustPolicyWhenManifestOmitsPolicy
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests
git diff --check
```

Result:

- RED first failed at compile time because `AssetPackPublisherProfile`, `AssetPackTrustPolicy.publisherProfiles`, and `publisherProfile(for:)` did not exist.
- Added `AssetPackPublisherProfile` with `id`, `displayName`, `websiteURL`, and `trustSummary`.
- `AssetPackTrustPolicy` now decodes missing `publisherProfiles` as `[]`, omits empty profiles during encoding, and can look up a publisher profile by id.
- RED then failed at the AppStore layer because a valid remote trust policy with publisher profiles installed successfully but did not surface the signed publisher display name.
- Remote manifest install messages now append `信任发布者：...` when the fetched trust policy has a valid registry-root signature and publisher profiles.
- Focused profile model/signature GREEN passed with 2 tests and 0 failures.
- Focused AppStore GREEN passed with 1 test and 0 failures.
- Related trust-policy/remote-install regression coverage passed with 9 tests and 0 failures.
- Full `MingSiTests` passed with 579 executed, 1 skipped, and 0 failures.
- Full `MingSiUITests` passed with 11 executed and 0 failures.
- `git diff --check` passed.

Residual risk:

- This adds local trust-policy identity metadata and install visibility only; it does not add a real external publisher onboarding service, external key-distribution portal, remote registry acceptance run, or live BYOK GLM confirmation.

## 2026-06-11: Remote Install Publisher Profile Scope

Scope:

- Narrow remote install success messages so signed publisher names come only from Prompt/Lens packs that actually installed.
- Preserve signed trust-policy profile verification and persisted policy caching.
- Avoid showing unrelated publishers that are present in the same broad trust-policy document but did not participate in the current install.

Changed areas:

- `Sources/App/AppStore.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_surfacesOnlyInstalledPublisherProfiles
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_surfacesRemotePublisherProfiles -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_surfacesOnlyInstalledPublisherProfiles -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_reusesTrustedInstallGateAndRefreshesRuntimeAssets -only-testing:MingSiTests/AppStoreStateMachineTests/testFetchAndInstallAssetPackInstallManifest_usesRemoteTrustPolicyBeforeInstalling -only-testing:MingSiTests/AppStoreStateMachineTests/testInstallAssetPackRegistryCatalogEntry_usesCatalogTrustPolicyWhenManifestOmitsPolicy -only-testing:MingSiTests/AppStoreStateMachineTests/testInstallAssetPackRegistryCatalogEntry_rejectsPackWhenRequiredPolicyVersionDiffers -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackTrustPolicy_decodesPublisherProfilesAndDefaultsLegacyDocuments -only-testing:MingSiTests/PersistenceCoreTests/testAssetPackTrustPolicyDocumentSignatureVerifier_rejectsPublisherProfileTampering
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests
git diff --check
```

Result:

- RED first failed with 1 executed test and 2 expected assertion failures: the install message did not include the expected exact installed-publisher summary and did include `Other Publisher` from an unrelated policy profile.
- `AppStore.fetchAndInstallAssetPackInstallManifest` now keeps the signed trust-policy document until after manifest installation, then builds the publisher summary from `report.installablePromptPacks` and `report.installableLensPacks`.
- `assetPackTrustPolicyPublisherSummary` now filters policy profiles by installed pack `trustMetadata.publisherId`, de-duplicates installed publisher ids, and falls back to publisher id only for an installed profile with an empty display name.
- Focused GREEN passed with 1 test and 0 failures.
- Related remote trust-policy/catalog regression coverage passed with 8 tests and 0 failures.
- Full `MingSiTests` passed with 580 executed, 1 skipped, and 0 failures.
- Full `MingSiUITests` passed with 11 executed and 0 failures.
- `git diff --check` passed.

Residual risk:

- This narrows local install-message trust visibility only; it does not add a real external publisher onboarding service, external key-distribution portal, remote registry acceptance run, or live BYOK GLM confirmation.

## 2026-06-11: Live GLM Acceptance Runner Script

Scope:

- Turn the Subtask 115 manual `.xctestrun` injection recipe into a reusable local command.
- Keep the live GLM acceptance path explicit and safe-by-default: no live request runs unless the script injects `MINGSI_LIVE_GLM_ACCEPTANCE=1` into the XCTest environment.
- Avoid leaking API keys in script output while still allowing user-provided BYOK keys through `MINGSI_LIVE_GLM_API_KEY`, `MINGSI_GLM_API_KEY`, `GLM_API_KEY`, or `--api-key`.

Changed areas:

- `scripts/run_live_glm_acceptance.sh`
- `Tests/Scripts/test_live_glm_acceptance_script.sh`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
bash Tests/Scripts/test_live_glm_acceptance_script.sh
chmod +x scripts/run_live_glm_acceptance.sh Tests/Scripts/test_live_glm_acceptance_script.sh && bash Tests/Scripts/test_live_glm_acceptance_script.sh
scripts/run_live_glm_acceptance.sh --dry-run
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/LiveGLMAcceptanceTests
bash -n scripts/run_live_glm_acceptance.sh Tests/Scripts/test_live_glm_acceptance_script.sh
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests
git diff --check
```

Result:

- RED first failed because `scripts/run_live_glm_acceptance.sh` did not exist.
- After adding the script, the contract test failed again because the script file was not executable; setting the executable bit made the same test pass.
- The shell contract test verifies `--dry-run` prints sanitized commands without writing an output `.xctestrun`, and `--prepare-only` copies a source `.xctestrun` while injecting `MINGSI_LIVE_GLM_ACCEPTANCE`, `MINGSI_LIVE_GLM_API_KEY`, optional base URL, and optional model into both `EnvironmentVariables` and `TestingEnvironmentVariables`.
- `scripts/run_live_glm_acceptance.sh --dry-run` passed without a local key and showed `MINGSI_LIVE_GLM_API_KEY=<missing; Keychain fallback may still be used>` rather than printing a secret.
- `LiveGLMAcceptanceTests` passed with 5 executed, 1 skipped, and 0 failures; the live probe still skips before network without the opt-in/key path.
- `bash -n` passed for the runner and script test.
- Full `MingSiTests` passed with 580 executed, 1 skipped, and 0 failures.
- Full `MingSiUITests` passed with 11 executed and 0 failures.
- `git diff --check` passed.

Residual risk:

- This automates the acceptance harness path only. A real BYOK GLM network success still requires a real user-provided key and an approved external call window.
- `shellcheck` is not installed in this local environment, so script static verification used `bash -n` plus the repository shell contract test.

## 2026-06-11: UI Automation Runner Script

Scope:

- Turn the rendered XCTest accessibility-driver path into a reusable local command.
- Keep Alpha UI automation repeatable with configurable destination, DerivedData, result bundle, and focused `--only-testing` selector.
- Preserve a safe `--dry-run` mode that prints the exact command without creating an `.xcresult`.

Changed areas:

- `scripts/run_ui_automation.sh`
- `Tests/Scripts/test_ui_automation_runner_script.sh`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
bash Tests/Scripts/test_ui_automation_runner_script.sh
chmod +x scripts/run_ui_automation.sh Tests/Scripts/test_ui_automation_runner_script.sh && bash Tests/Scripts/test_ui_automation_runner_script.sh
bash -n scripts/run_ui_automation.sh Tests/Scripts/test_ui_automation_runner_script.sh
scripts/run_ui_automation.sh --dry-run
scripts/run_ui_automation.sh --derived-data-path /tmp/mingsi-ui-automation-runner-dd --result-bundle-path /tmp/mingsi-ui-automation-runner.xcresult
xcodebuild test -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests
git diff --check
```

Result:

- RED first failed because `scripts/run_ui_automation.sh` did not exist.
- The first GREEN attempt exposed that the dry-run command escaped the destination string, so the runner now prints readable configuration lines plus the copyable shell-escaped `xcodebuild` command.
- The shell contract test verifies custom destination, DerivedData path, result bundle path, focused `--only-testing`, default `MingSiUITests`, and dry-run not creating an `.xcresult`.
- `bash -n` passed for the runner and script test.
- `scripts/run_ui_automation.sh --dry-run` passed and printed the default `MingSiUITests` command.
- A real runner invocation passed `MingSiUITests` with 11 executed and 0 failures, writing `/tmp/mingsi-ui-automation-runner.xcresult`.
- Full `MingSiTests` passed with 580 executed, 1 skipped, and 0 failures.
- `git diff --check` passed.

Residual risk:

- This adds a repeatable runner for existing UI automation. It does not add new rendered UI coverage beyond the current `MingSiUITests` suite.
- Real simulator execution still depends on an available iPhone 17 simulator and the local Xcode runtime.
