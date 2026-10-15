# Python-to-Dart audit

Audit date: 2026-09-21

## Decision

The repository contained 60 project-owned Python files. They were uncalled,
one-time text-rewrite programs from an earlier Flutter/Firebase-to-Supabase
repair session. They do not perform the live Firebase-to-Supabase data
migration, are not referenced by application code, documentation, IDE tasks,
or automation, and several scripts supersede or explicitly undo earlier ones.

Re-running them would be unsafe: seven root scripts target a different absolute
checkout, while many scratch scripts insert placeholders, broad regex changes,
or obsolete Firebase types. Their intended end state is already represented by
the current Dart sources. The current application was therefore validated with
a successful release web build before these artifacts were removed. Under the
project rule for an obsolete script whose working Dart result already exists,
no mutation-for-mutation port is required.

The maintained replacement is `tool/verify_no_python.dart`. It checks for
project-owned Python files, environments, configuration, executable commands,
and Dart attempts to launch Python. It deliberately ignores third-party/build
trees and Flutter's generated iOS LLDB helper.

## File-by-file classification

All entries below had the same runtime characteristics unless noted: called by
nothing; input was the named Dart source file(s); output was an in-place Dart
source rewrite or console diagnostics; external services were not contacted;
Dart replacement required: no, because the change is already embodied in the
current Dart code or the script is incomplete/unsafe/obsolete.

| File | Purpose |
|---|---|
| `fix_app_state.py` | Repaired duplicated nearby-driver mapping and a local SQL query in an older checkout. |
| `fix_overview.py` | Replaced the old admin overview stat-card grid in an older checkout. |
| `fix_syntax.py` | Partial Firestore nearby-driver method repair in an older checkout. |
| `fix_syntax_2.py` | Replaced the same Firestore nearby-driver method wholesale. |
| `fix_syntax_3.py` | Incomplete duplicate-line cleanup experiment; it never writes a result. |
| `fix_syntax_4.py` | Later replacement of the same Firestore nearby-driver method. |
| `fix_syntax_5.py` | Final variant of that obsolete Firestore method replacement. |
| `rewrite_supabase.py` | Broad regex experiment converting Firestore syntax to Supabase syntax. |
| `scratch/extract_extra_classes.py` | Copied model classes out of the former Firestore service. |
| `scratch/find_missing.py` | Reported facade stubs missing from concrete Supabase services. |
| `scratch/find_missing2.py` | Verbose/incomplete successor to the facade-stub report. |
| `scratch/fix_3.py` | Adjusted auth/facade/finance return types. |
| `scratch/fix_4.py` | Repaired early Supabase imports, calls, and duplicate service stubs. |
| `scratch/fix_5.py` | Repeated and extended early service import/stub repairs. |
| `scratch/fix_6.py` | Repeated UI/auth imports and removed duplicate service stubs. |
| `scratch/fix_7.py` | Repaired auth exceptions/password calls and inserted facade stubs. |
| `scratch/fix_8.py` | Repaired signatures/imports and removed more duplicate stubs. |
| `scratch/fix_9.py` | Adjusted location types, password updates, and trip-service calls. |
| `scratch/fix_10.py` | Deleted a temporary stub and adjusted facade/app-state types. |
| `scratch/fix_11.py` | Reversed location-type edits and adjusted facade signatures. |
| `scratch/fix_12.py` | Applied broad location/member regex changes later reversed. |
| `scratch/fix_13.py` | Reversed prior location edits and adjusted imports/calls. |
| `scratch/fix_14.py` | Partial facade/location repair experiment; contains contradictory edits. |
| `scratch/fix_15.py` | Adjusted nearby-driver, TODA, password, and notification calls. |
| `scratch/fix_16.py` | Follow-up app-state imports and nearby-driver/password repairs. |
| `scratch/fix_17.py` | Follow-up app-state password, UID, and TODA repairs. |
| `scratch/fix_20.py` | Adjusted facade driver types and removed duplicate driver models. |
| `scratch/fix_21.py` | Corrected the driver-service model import. |
| `scratch/fix_22.py` | Generated facade forwarding methods from concrete services. |
| `scratch/fix_23.py` | Repaired malformed generated facade arguments and return types. |
| `scratch/fix_24.py` | Follow-up facade return/call substitutions. |
| `scratch/fix_25.py` | Wired auth-helper facade methods. |
| `scratch/fix_26.py` | Redirected auth-helper calls through its singleton. |
| `scratch/fix_27.py` | Added an obsolete record-type cast to magic-link validation. |
| `scratch/fix_28.py` | Replaced one remaining email-OTP facade stub. |
| `scratch/fix_admin_auth.py` | Changed admin-auth creation to named Supabase arguments. |
| `scratch/fix_admin_auth2.py` | Removed a preceding admin-auth argument change. |
| `scratch/fix_admin_main.py` | Replaced Firebase admin initialization with Supabase initialization. |
| `scratch/fix_admin2.py` | Repaired admin account fields and named auth arguments. |
| `scratch/fix_all_ui.py` | Applied broad Firebase-to-Supabase regex replacements across `lib/`. |
| `scratch/fix_args.py` | Repaired admin auth arguments and literal newline artifacts. |
| `scratch/fix_auth_methods.py` | Replaced Firebase token/email-verification members with Supabase equivalents. |
| `scratch/fix_auth_service.py` | Removed Firebase imports and fixed a Supabase service call. |
| `scratch/fix_driver_home.py` | Replaced Firebase Auth references in the driver home page. |
| `scratch/fix_facade_and_admin.py` | Iterative admin/facade/magic-link fixes, some later reversed. |
| `scratch/fix_facade_more.py` | Inserted temporary facade stubs and changed account creation. |
| `scratch/fix_final.py` | Mixed final-pass auth/admin/deep-link type and import repairs. |
| `scratch/fix_final2.py` | Reversed and corrected parts of the preceding final pass. |
| `scratch/fix_imports_ui.py` | Added missing model imports to four UI pages. |
| `scratch/fix_ml.py` | Corrected a magic-link timestamp parenthesis. |
| `scratch/fix_models_import.py` | Added model imports and replaced legacy timestamp types. |
| `scratch/fix_more.py` | Iterative admin, magic-link, service-import, and return-type repairs. |
| `scratch/fix_newlines.py` | Converted literal backslash-n text in Supabase service files. |
| `scratch/fix_stub_imports.py` | Copied a temporary facade stub over the main facade with added imports. |
| `scratch/fix_supabase_auth_service.py` | Inserted a temporary admin-account helper. |
| `scratch/fix_ui_2.py` | Broad Firebase import/member replacement and unsafe account-store placeholders. |
| `scratch/fix3.py` | Replaced selected service stubs with direct Supabase calls or placeholders. |
| `scratch/generate_facade.py` | First generator for Supabase facade forwarding methods/imports. |
| `scratch/generate_facade2.py` | Second facade generator with revised argument parsing. |
| `tmp/fix_admin_portal.py` | One-time admin portal stream/copy/source rewrite. |

## Non-project Python retained

`ios/Flutter/ephemeral/flutter_lldb_helper.py` is generated by Flutter for LLDB
debugger integration and is referenced by the neighboring generated
`flutter_lldbinit`. It is SDK-generated infrastructure, not Sakay Ta logic, and
must not be edited or deleted. It may be regenerated by Flutter tooling.

## Commands

```text
dart run tool/verify_no_python.dart --help
dart run tool/verify_no_python.dart
```
