#!/usr/bin/env sh
set -eu

FAIL_FAST="${TEST_FAIL_FAST:-0}"

STAGE_1_STATUS="SKIPPED"
STAGE_2_STATUS="SKIPPED"
STAGE_3_STATUS="SKIPPED"
FAILED=0

run_stage() {
	stage_id="$1"
	stage_name="$2"
	stage_cmd="$3"

	echo "[$stage_name] starting"

	set +e
	sh -c "$stage_cmd"
	rc=$?
	set -e

	if [ "$rc" -eq 0 ]; then
		stage_status="PASS"
		echo "[$stage_name] passed"
	else
		stage_status="FAIL"
		FAILED=1
		echo "[$stage_name] failed (exit $rc)"
	fi

	case "$stage_id" in
		1) STAGE_1_STATUS="$stage_status" ;;
		2) STAGE_2_STATUS="$stage_status" ;;
		3) STAGE_3_STATUS="$stage_status" ;;
	esac

	if [ "$rc" -ne 0 ] && [ "$FAIL_FAST" = "1" ]; then
		echo "[local-test] fail-fast enabled; stopping after $stage_name"
		return "$rc"
	fi

	return 0
}

run_stage 1 "flutter pub get" "cd /workspace/app && flutter pub get" || true
if [ "$FAIL_FAST" = "1" ] && [ "$STAGE_1_STATUS" = "FAIL" ]; then
	:
else
	run_stage 2 "flutter test --reporter expanded" "cd /workspace/app && flutter test --reporter expanded" || true
fi

if [ "$FAIL_FAST" = "1" ] && { [ "$STAGE_1_STATUS" = "FAIL" ] || [ "$STAGE_2_STATUS" = "FAIL" ]; }; then
	:
else
	run_stage 3 "browser preflight + integration (xvfb-run -a dart run tool/start_test_infra.dart)" "cd /workspace/app && xvfb-run -a dart run tool/start_test_infra.dart" || true
if [ "$STAGE_3_STATUS" = "FAIL" ]; then
	echo "[local-test] integration stage failed; browser preflight output appears above in [infra] logs"
fi
fi

echo "[summary] final stage results"
echo "[summary] flutter pub get: $STAGE_1_STATUS"
echo "[summary] flutter test --reporter expanded: $STAGE_2_STATUS"
echo "[summary] browser preflight + integration: $STAGE_3_STATUS"

if [ "$FAILED" -ne 0 ]; then
	exit 1
fi

exit 0
