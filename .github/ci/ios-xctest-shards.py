#!/usr/bin/env python3
"""Bound one original test partition, then account for every discovered selector."""
import collections
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time

MANIFEST = Path(__file__).with_name('ios-xctest-coverage.json')
ID = re.compile(r'iOSMerchandiseControl(?:UI)?Tests/[^/\s]+/test[^/\s]+')
# This finite16-selector exception records the user's2026-11-07 deferral.
# It changes CI dispatch only; source methods and complete discovery stay enabled.
T18_OS_OFFLINE = {
    f'iOSMerchandiseControlUITests/LocalAvailabilityRootUITests/testT18_{language}_{size}_{theme}_offline':
        f'ui-t18-{language}'
    for language in ('it', 'en', 'es', 'zh')
    for size in ('normal', 'max') for theme in ('light', 'dark')
}
USER_DEFERRAL = {
    'status': 'DEFERRED_USER', 'override': 'TASK146_USER_OVERRIDE_20261107',
    'reason': 'Questo lascialo per un altro momento, al momento non dispositivi fisici disponibili',
    'scope': 'CI_ONLY_REAL_IOS_OS_OFFLINE_T18',
}
QUALIFIED_STATUSES = {'PASS', 'COMPLETE_WITH_OPT_IN_SKIPS', 'COMPLETE_WITH_USER_DEFERRALS'}


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')


def load_manifest():
    manifest = json.loads(MANIFEST.read_text())
    ids = [case for shard in manifest['shards'] for case in shard['expected']]
    assert ids and len(ids) == len(set(ids))
    assert all(ID.fullmatch(case) for case in ids)
    assert set(manifest['allowedOptInSkips']).issubset(ids)
    if 'userDeferredTests' in manifest:
        policy = manifest['userDeferredTests']
        assert policy == dict(USER_DEFERRAL, selectors=sorted(T18_OS_OFFLINE)), 'invalid user deferral scope/reason/selectors'
        assert not set(T18_OS_OFFLINE) & set(manifest['allowedOptInSkips']), 'deferral is not an opt-in skip'
        for selector, shard_id in T18_OS_OFFLINE.items():
            owner = next(row for row in manifest['shards'] if selector in row['expected'])
            assert owner['id'] == shard_id and selector in owner['onlyTesting'], 'wrong deferred selector shard'
    return manifest


def shard_selection(manifest, shard):
    policy = manifest.get('userDeferredTests')
    deferred = sorted(set(shard['expected']) & set(policy['selectors'])) if policy else []
    if deferred:
        assert set(shard['onlyTesting']) == set(shard['expected']), 'deferred shard requires exact selectors'
    return {
        'activeExpected': [case for case in shard['expected'] if case not in deferred],
        'deferredIds': deferred,
        'selectedOnlyTesting': [case for case in shard['onlyTesting'] if case not in deferred],
        'userDeferral': USER_DEFERRAL if deferred else None,
    }


def qualified_status(counts):
    if counts.get('DEFERRED_USER'):
        return 'COMPLETE_WITH_USER_DEFERRALS'
    return 'COMPLETE_WITH_OPT_IN_SKIPS' if counts.get('Skipped') else 'PASS'


def current_provenance():
    return {'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
            'runId': os.environ['GITHUB_RUN_ID'], 'runAttempt': os.environ['GITHUB_RUN_ATTEMPT'],
            'manifestSHA256': hashlib.sha256(MANIFEST.read_bytes()).hexdigest()}


def enumerated_ids(value):
    # Qualified against the original Xcode flat JSON export; never count disabled tests.
    assert isinstance(value, dict) and set(value) == {'errors', 'values'}
    assert value['errors'] == [] and isinstance(value['values'], list) and value['values']
    found = []
    for plan in value['values']:
        assert isinstance(plan, dict) and set(plan) == {'disabledTests', 'enabledTests', 'testPlan'}
        assert plan['disabledTests'] == [] and isinstance(plan['enabledTests'], list)
        assert plan['testPlan'] == 'iOSMerchandiseControl'
        for case in plan['enabledTests']:
            assert isinstance(case, dict) and set(case) == {'identifier'}
            assert isinstance(case['identifier'], str)
            normalized = case['identifier'].removesuffix('()')
            assert ID.fullmatch(normalized), 'invalid enabled test selector'
            found.append(normalized)
    assert len(found) == len(set(found)), 'duplicate enumerated selector'
    return set(found)


def bounded(argv, log, deadline):
    assert time.monotonic() < deadline, 'export-reservation cutoff reached before dispatch'
    process = None
    try:
        with log.open('wb') as stream:
            process = subprocess.Popen(argv, stdout=stream, stderr=subprocess.STDOUT,
                                       stdin=subprocess.DEVNULL, start_new_session=True)
            return process.wait(timeout=max(0, deadline - time.monotonic()))
    finally:
        if process is not None and process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()


def run(shard_id):
    manifest = load_manifest()
    shard = next(row for row in manifest['shards'] if row['id'] == shard_id)
    selection = shard_selection(manifest, shard)
    output = Path(os.environ['RUNNER_TEMP']) / 'ios-xctest-shard'
    output.mkdir(exist_ok=False)
    record = dict(current_provenance(), shard=shard_id, status='NOT_RUN',
                  expected=shard['expected'], **selection,
                  cases={case: 'DEFERRED_USER' if case in selection['deferredIds'] else 'NOT_RUN'
                         for case in shard['expected']})
    write(output / 'run.json', record)
    base = ['xcodebuild', '-project', 'iOSMerchandiseControl.xcodeproj',
            '-scheme', 'iOSMerchandiseControl', '-configuration', 'Debug',
            '-destination', 'platform=iOS Simulator,id=' + os.environ['DEVICE_ID'],
            'CODE_SIGNING_ALLOWED=YES', 'CODE_SIGN_IDENTITY=-', 'test']
    cutoff_seconds = 4200 if shard_id == 'ui-core' else 3600
    cutoff = float((Path(os.environ['RUNNER_TEMP']) / 'ios-ci-start.monotonic').read_text()) + cutoff_seconds
    # Core used 61 minutes including preparation and was killed while finalizing
    # its result bundle. Allow 70 minutes from the recorded CI start for that
    # shard, with a nominal five-minute export/upload reserve in the 75-minute
    # job. Other shards retain 60 minutes from the same recorded start.
    record['xctestCutoffSecondsSinceRecordedCIStart'] = cutoff_seconds
    try:
        enumeration = output / 'enumeration.json'
        enum_argv = base + ['-enumerate-tests', '-test-enumeration-style', 'flat',
                            '-test-enumeration-format', 'json',
                            '-test-enumeration-output-path', str(enumeration)]
        record['enumerationArgv'] = enum_argv
        write(output / 'run.json', record)
        record['enumerationExit'] = bounded(enum_argv, output / 'enumeration.log',
                                             min(cutoff, time.monotonic() + 300))
        assert record['enumerationExit'] == 0
        discovered = enumerated_ids(json.loads(enumeration.read_text()))
        expected_all = {case for row in manifest['shards'] for case in row['expected']}
        record['discovery'] = {'missing': sorted(expected_all - discovered),
                               'unexpected': sorted(discovered - expected_all), 'count': len(discovered)}
        assert discovered == expected_all, 'runtime discovery differs from full coverage manifest'
        argv = base + ['-resultBundlePath', str(Path(os.environ['RUNNER_TEMP']) /
                                               'ios-merchandise-control-tests.xcresult')]
        argv += ['-only-testing:' + selector for selector in selection['selectedOnlyTesting']]
        record['testArgv'] = argv
        record['status'] = 'RUNNING'
        write(output / 'run.json', record)
        record['xcodeExit'] = bounded(argv, output / 'xcodebuild.log', cutoff)
        record['status'] = 'AWAITING_RESULT_EXPORT'
    except (AssertionError, KeyError, ValueError, OSError, subprocess.TimeoutExpired, InterruptedError) as error:
        record['status'] = 'FAIL'
        record['error'] = type(error).__name__ + ': ' + str(error)
    finally:
        write(output / 'run.json', record)
    return 0 if record.get('xcodeExit') == 0 else 1


def test_cases(value):
    found = []
    def visit(node, module=None):
        if isinstance(node, dict):
            if node.get('nodeType') in {'Unit test bundle', 'UI test bundle'}:
                module = node.get('name')
            if node.get('nodeType') == 'Test Case':
                selector = node['nodeIdentifier'].removesuffix('()')
                if not selector.startswith('iOSMerchandiseControl'):
                    selector = str(module) + '/' + selector
                assert ID.fullmatch(selector), 'unknown exported test selector'
                found.append((selector, node['result']))
            for child in node.values():
                visit(child, module)
        elif isinstance(node, list):
            for child in node:
                visit(child, module)
    visit(value)
    assert len(found) == len(dict(found)), 'duplicate exported test selector'
    return dict(found)


def qualify(shard_id):
    manifest = load_manifest()
    shard = next(row for row in manifest['shards'] if row['id'] == shard_id)
    expected = shard['expected']
    selection = shard_selection(manifest, shard)
    active = selection['activeExpected']
    output = Path(os.environ['RUNNER_TEMP']) / 'ios-xctest-shard'
    report = dict(current_provenance(), shard=shard_id, status='FAIL', **selection,
                  expectedTotal=len(expected), observedTotal=0, deferredTotal=len(selection['deferredIds']),
                  cases={case: 'DEFERRED_USER' if case in selection['deferredIds'] else 'NOT_RUN'
                         for case in expected}, errors=[])
    try:
        run_record = json.loads((output / 'run.json').read_text())
        assert {key: run_record[key] for key in current_provenance()} == current_provenance()
        assert run_record['shard'] == shard_id and run_record['expected'] == expected
        assert all(run_record[key] == value for key, value in selection.items()), 'wrong user deferral record'
        assert [arg.removeprefix('-only-testing:') for arg in run_record['testArgv']
                if arg.startswith('-only-testing:')] == selection['selectedOnlyTesting'], 'wrong active CI selection'
        discovery_count = sum(len(row['expected']) for row in manifest['shards'])
        assert run_record['discovery'] == {'missing': [], 'unexpected': [], 'count': discovery_count}
        exported = Path(os.environ['RUNNER_TEMP']) / 'ios-xctest-failure-summary'
        provenance = json.loads((exported / 'provenance.json').read_text())
        for name in ['summary.json', 'tests.json']:
            entry = next(item for item in provenance['exports'] if item['stdout'] == name)
            assert entry['complete'] is True, 'incomplete bounded result export'
        summary = json.loads((exported / 'summary.json').read_text())
        observed = test_cases(json.loads((exported / 'tests.json').read_text()))
        report['unexpected'] = sorted(set(observed) - set(active))
        report['missing'] = sorted(set(active) - set(observed))
        report['observedTotal'] = len(observed)
        for selector in set(active) & set(observed):
            report['cases'][selector] = observed[selector]
        counts = collections.Counter(observed.values())
        report['observedCounts'] = dict(counts)
        report['counts'] = dict(collections.Counter(report['cases'].values()))
        report['xcodeExit'] = run_record.get('xcodeExit')
        report['unexpectedSkips'] = sorted(case for case, result in observed.items()
                                           if result == 'Skipped' and case not in manifest['allowedOptInSkips'])
        assert not report['unexpected'] and not report['missing'], 'missing/unexpected active result cases'
        assert summary['totalTestCount'] == len(active)
        assert summary['passedTests'] == counts['Passed'] and summary['failedTests'] == counts['Failed']
        assert summary['skippedTests'] == counts['Skipped']
        assert set(counts).issubset({'Passed', 'Failed', 'Skipped'}), 'unterminated result case'
        assert not report['unexpectedSkips'], 'unapproved skip'
        assert run_record.get('xcodeExit') == 0 and counts['Failed'] == 0
        report['status'] = qualified_status(report['counts'])
    except (AssertionError, KeyError, ValueError, OSError, StopIteration) as error:
        report['errors'].append(type(error).__name__ + ': ' + str(error))
    write(output / 'coverage.json', report)
    return 0 if report['status'] in QUALIFIED_STATUSES else 1


def aggregate(directory):
    manifest = load_manifest()
    expected_shards = {row['id']: set(row['expected']) for row in manifest['shards']}
    selections = {row['id']: shard_selection(manifest, row) for row in manifest['shards']}
    reports = {}
    errors = []
    for path in Path(directory).glob('*/ios-xctest-shard/coverage.json'):
        report = json.loads(path.read_text())
        shard = report['shard']
        if shard in reports or shard not in expected_shards:
            errors.append('duplicate/unknown shard: ' + shard)
        reports[shard] = report
    all_cases = {}
    for shard, expected in expected_shards.items():
        report = reports.get(shard, {})
        if report.get('head') != os.environ['EXPECTED_HEAD']:
            errors.append(shard + ': missing/wrong-head report')
        if report.get('runId') != os.environ['GITHUB_RUN_ID'] or report.get('runAttempt') != os.environ['GITHUB_RUN_ATTEMPT']:
            errors.append(shard + ': wrong run/attempt')
        if report.get('manifestSHA256') != hashlib.sha256(MANIFEST.read_bytes()).hexdigest():
            errors.append(shard + ': wrong manifest')
        cases = report.get('cases', {})
        selection = selections[shard]
        if set(cases) != expected or report.get('status') not in QUALIFIED_STATUSES:
            errors.append(shard + ': FAIL/NOT_RUN/incomplete')
        if any(report.get(key) != value for key, value in selection.items()):
            errors.append(shard + ': wrong user deferral scope/reason/selection')
        deferred = set(selection['deferredIds'])
        if {case for case, result in cases.items() if result == 'DEFERRED_USER'} != deferred:
            errors.append(shard + ': wrong deferred case identities')
        if any(result == 'Skipped' and case not in manifest['allowedOptInSkips'] for case, result in cases.items()):
            errors.append(shard + ': unapproved skip')
        case_counts = collections.Counter(cases.values())
        observed_counts = collections.Counter(cases.get(case, 'NOT_RUN') for case in selection['activeExpected'])
        if report.get('counts') != dict(case_counts) or report.get('observedCounts') != dict(observed_counts):
            errors.append(shard + ': inconsistent result counts')
        if (report.get('expectedTotal') != len(expected)
                or report.get('observedTotal') != len(selection['activeExpected'])
                or report.get('deferredTotal') != len(deferred)):
            errors.append(shard + ': inconsistent observed/deferred totals')
        if report.get('status') != qualified_status(case_counts):
            errors.append(shard + ': status does not preserve deferral/skip result')
        if report.get('errors') != []:
            errors.append(shard + ': qualification errors')
        all_cases.update({case: cases.get(case, 'NOT_RUN') for case in expected})
    counts = dict(collections.Counter(all_cases.values()))
    if os.environ['MATRIX_RESULT'] != 'success':
        errors.append('matrix job result: ' + os.environ['MATRIX_RESULT'])
    if set(counts) - {'Passed', 'Skipped', 'DEFERRED_USER'}:
        errors.append('FAIL/NOT_RUN/unknown case result')
    status = 'FAIL' if errors else qualified_status(counts)
    result = {'status': status, 'head': os.environ['EXPECTED_HEAD'], 'counts': counts,
              'errors': errors, 'cases': all_cases,
              'expectedTotal': len(all_cases),
              'observedTotal': sum(value != 'DEFERRED_USER' and value != 'NOT_RUN' for value in all_cases.values()),
              'deferredTotal': counts.get('DEFERRED_USER', 0),
              'deferredIds': sorted(case for case, value in all_cases.items() if value == 'DEFERRED_USER'),
              'userDeferral': manifest.get('userDeferredTests'),
              'acceptanceLimit': 'Opt-in skips remain Skipped; DEFERRED_USER cases are not run or Passed. '
                                 'CI does not qualify deferred real iOS OS-offline or authenticated/native B6 acceptance.'}
    write(Path(directory) / 'aggregate.json', result)
    print(json.dumps({key: value for key, value in result.items() if key != 'cases'}))
    return 1 if errors else 0


if __name__ == '__main__':
    def interrupted(_signal, _frame):
        raise InterruptedError('runner cancellation; unobserved cases remain NOT_RUN')
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    sys.exit({'run': run, 'qualify': qualify, 'aggregate': aggregate}[sys.argv[1]](sys.argv[2]))
