#!/usr/bin/env bash

RELEASE_NAME="tmpchart"
NAMESPACE="default"
EXIT_CODE=0

function cleanUp() {
    echo "[INFO] Cleaning up any previous resources"
    helm -n ${NAMESPACE} uninstall ${RELEASE_NAME}
    kubectl -n ${NAMESPACE} delete secrets ${RELEASE_NAME}-secret
}

function install() {
    local -r _password="${1}"
    local -r _install_logs="$(helm -n ${NAMESPACE} upgrade --install ${RELEASE_NAME} . --set=providedPassword=${_password})"
    if [[ $? -ne 0 ]]; then
        echo "[ERROR] There was a Helm error"
        printf "\n%s\n" "${_install_logs}"
        exit 1
    fi
}

function rollback() {
    local -r _version="${1}"
    local -r _rollback_logs="$(helm -n ${NAMESPACE} rollback ${RELEASE_NAME} ${_version})"
    if [[ $? -ne 0 ]]; then
        echo "[ERROR] There was a Helm error"
        printf "\n%s\n" "${_rollback_logs}"
        exit 1
    fi
}

function getPasswordValue() {
    local -r _other_name="${1}"
    kubectl --namespace ${NAMESPACE} get secret ${RELEASE_NAME}${_other_name}-secret -o jsonpath='{.data.my-password}' | base64 -d
}

function isPasswordExpectedValue() {
    local -r _other_name="${1}"
    local -r _expected_password="${2:-"${EXPECTED_PASSWORD}"}"
    local -r _password_value="$(getPasswordValue ${_other_name})"
    if [[ "${_password_value}" == "${_expected_password}" ]]; then
        echo "[SUCCESS] ${RELEASE_NAME}${_other_name}-secret password matches expected value of ${_expected_password}"
    else
        echo "[FAIL] ${RELEASE_NAME}${_other_name}-secret password does not match expected value"
        echo "       Expected: ${_expected_password}"
        echo "       Actual:   ${_password_value}"
        ((EXIT_CODE += 1))
    fi
}

function arePasswordsExpectedValue() {
    isPasswordExpectedValue
    isPasswordExpectedValue "-other" "${EXPECTED_OTHER_PASSWORD}"
}

cleanUp
echo -e "\n---------------------------------------------------------------"
echo "-   Testing initial install with no password value"
echo "---------------------------------------------------------------"
install
INITIAL_PASSWORD="$(getPasswordValue)"
INITIAL_OTHER_PASSWORD="$(getPasswordValue "-other")"
EXPECTED_PASSWORD="${INITIAL_PASSWORD}"
EXPECTED_OTHER_PASSWORD="${INITIAL_OTHER_PASSWORD}"
echo "[INFO] Passwords are ${EXPECTED_PASSWORD} and ${EXPECTED_OTHER_PASSWORD} after initial install"

echo -e "\n[INFO] Upgrading with no password value"
install
arePasswordsExpectedValue

echo -e "\n[INFO] Upgrading again with no password value"
install
arePasswordsExpectedValue

EXPECTED_OTHER_PASSWORD=""
EXPECTED_PASSWORD="herp"
echo -e "\n[INFO] Upgrading again with ${EXPECTED_PASSWORD} as password value"
install ${EXPECTED_PASSWORD}
arePasswordsExpectedValue

echo -e "\n[INFO] Upgrading again with no password value"
install
arePasswordsExpectedValue

EXPECTED_PASSWORD="derp"
echo -e "\n[INFO] Upgrading again with ${EXPECTED_PASSWORD} as password value"
install ${EXPECTED_PASSWORD}
arePasswordsExpectedValue

EXPECTED_PASSWORD="derp"
echo -e "\n[INFO] Upgrading again with ${EXPECTED_PASSWORD} as password value"
install ${EXPECTED_PASSWORD}
arePasswordsExpectedValue

echo -e "\n[INFO] Upgrading again with no password value"
install
arePasswordsExpectedValue

EXPECTED_PASSWORD="${INITIAL_PASSWORD}"
EXPECTED_OTHER_PASSWORD="${INITIAL_OTHER_PASSWORD}"
echo -e "\n[INFO] Rolling back to release with value ${EXPECTED_PASSWORD}"
rollback 1
arePasswordsExpectedValue

EXPECTED_PASSWORD="herp"
EXPECTED_OTHER_PASSWORD=""
echo -e "\n[INFO] Rolling back to release with value ${EXPECTED_PASSWORD}"
rollback 4
arePasswordsExpectedValue

EXPECTED_PASSWORD="derp"
echo -e "\n[INFO] Rolling back to release with value ${EXPECTED_PASSWORD}"
rollback 6
arePasswordsExpectedValue

echo ""
cleanUp
echo -e "\n---------------------------------------------------------------"
echo "-   Testing initial install with provided password value"
echo "---------------------------------------------------------------"
EXPECTED_PASSWORD="herp"
install ${EXPECTED_PASSWORD}
arePasswordsExpectedValue

echo -e "\n[INFO] Upgrading with no password value"
install
arePasswordsExpectedValue

echo -e "\n[INFO] Upgrading again with no password value"
install
arePasswordsExpectedValue

EXPECTED_PASSWORD="herp"
echo -e "\n[INFO] Upgrading again with ${EXPECTED_PASSWORD} as password value"
install ${EXPECTED_PASSWORD}
arePasswordsExpectedValue

echo -e "\n[INFO] Upgrading again with no password value"
install
arePasswordsExpectedValue

EXPECTED_PASSWORD="derp"
echo -e "\n[INFO] Upgrading again with ${EXPECTED_PASSWORD} as password value"
install ${EXPECTED_PASSWORD}
arePasswordsExpectedValue

EXPECTED_PASSWORD="derp"
echo -e "\n[INFO] Upgrading again with ${EXPECTED_PASSWORD} as password value"
install ${EXPECTED_PASSWORD}
arePasswordsExpectedValue

echo -e "\n[INFO] Upgrading again with no password value"
install
arePasswordsExpectedValue

EXPECTED_PASSWORD="herp"
echo -e "\n[INFO] Rolling back to release with value ${EXPECTED_PASSWORD}"
rollback 4
arePasswordsExpectedValue

EXPECTED_PASSWORD="derp"
echo -e "\n[INFO] Rolling back to release with value ${EXPECTED_PASSWORD}"
rollback 7
arePasswordsExpectedValue

echo ""
if [[ ${EXIT_CODE} -eq 0 ]]; then
    echo "[SUCCESS] All tests passed"
else
    echo "[FAIL] Some tests failed"
fi

exit ${EXIT_CODE}
