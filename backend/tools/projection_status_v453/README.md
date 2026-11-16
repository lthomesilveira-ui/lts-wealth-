# Projection status and worker compatibility

The first V452 readiness candidate passed isolated status tests but failed real worker validation because the shared cache predicate is also used before the worker publishes its new projection memo. That candidate was rolled back.

V453 keeps the shared cache predicate byte-identical. Only the browser status boundary checks the private projection-evidence predicate and joins the existing coalescing queue. It never changes a financial reader, source guard, policy calculation, worker body, claim or access grant. The actual worker may validate the core product before publishing its guarded memo; browser status waits for the complete publication.

The exact predecessor, ACL and configuration guards protect install/rollback and reject concurrent changes. Native PostgreSQL17 verification now includes the worker pre-publication cache contract while its queue is running and its projection memo is still obsolete, in addition to concurrent callers, all stale-evidence variants, disabled policy, source preservation, authorization and lifecycle. Public fixtures are invented. Real-session performance remains a separate acceptance step.
