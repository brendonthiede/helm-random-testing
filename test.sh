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
    kubectl --namespace ${NAMESPACE} get secret ${RELEASE_NAME}-secret -o jsonpath='{.data.my-password}' | base64 -d
}

function isPasswordExpectedValue() {
    local -r _password_value="$(getPasswordValue)"
    if [[ "${_password_value}" == "${EXPECTED_PASSWORD}" ]]; then
        echo "[SUCCESS] Password matches expected value of ${EXPECTED_PASSWORD}"
    else
        echo "[FAIL] Password does not match expected value"
        echo "       Expected: ${EXPECTED_PASSWORD}"
        echo "       Actual:   ${_password_value}"
        ((EXIT_CODE += 1))
    fi
}

cleanUp
echo -e "\n---------------------------------------------------------------"
echo "-   Testing initial install with no password value"
echo "---------------------------------------------------------------"
install
INITIAL_PASSWORD="$(getPasswordValue)"
EXPECTED_PASSWORD="${INITIAL_PASSWORD}"
echo "[INFO] Password is ${EXPECTED_PASSWORD} after initial install"

echo -e "\n[INFO] Upgrading with no password value"
install
isPasswordExpectedValue

echo -e "\n[INFO] Upgrading again with no password value"
install
isPasswordExpectedValue

EXPECTED_PASSWORD="herp"
echo -e "\n[INFO] Upgrading again with ${EXPECTED_PASSWORD} as password value"
install ${EXPECTED_PASSWORD}
isPasswordExpectedValue

echo -e "\n[INFO] Upgrading again with no password value"
install
isPasswordExpectedValue

EXPECTED_PASSWORD="derp"
echo -e "\n[INFO] Upgrading again with ${EXPECTED_PASSWORD} as password value"
install ${EXPECTED_PASSWORD}
isPasswordExpectedValue

EXPECTED_PASSWORD="derp"
echo -e "\n[INFO] Upgrading again with ${EXPECTED_PASSWORD} as password value"
install ${EXPECTED_PASSWORD}
isPasswordExpectedValue

echo -e "\n[INFO] Upgrading again with no password value"
install
isPasswordExpectedValue

EXPECTED_PASSWORD="${INITIAL_PASSWORD}"
echo -e "\n[INFO] Rolling back to release with value ${EXPECTED_PASSWORD}"
rollback 1
isPasswordExpectedValue

EXPECTED_PASSWORD="herp"
echo -e "\n[INFO] Rolling back to release with value ${EXPECTED_PASSWORD}"
rollback 4
isPasswordExpectedValue

EXPECTED_PASSWORD="derp"
echo -e "\n[INFO] Rolling back to release with value ${EXPECTED_PASSWORD}"
rollback 6
isPasswordExpectedValue

echo ""
cleanUp
echo -e "\n---------------------------------------------------------------"
echo "-   Testing initial install with provided password value"
echo "---------------------------------------------------------------"
EXPECTED_PASSWORD="herp"
install ${EXPECTED_PASSWORD}
isPasswordExpectedValue

echo -e "\n[INFO] Upgrading with no password value"
install
isPasswordExpectedValue

echo -e "\n[INFO] Upgrading again with no password value"
install
isPasswordExpectedValue

EXPECTED_PASSWORD="herp"
echo -e "\n[INFO] Upgrading again with ${EXPECTED_PASSWORD} as password value"
install ${EXPECTED_PASSWORD}
isPasswordExpectedValue

echo -e "\n[INFO] Upgrading again with no password value"
install
isPasswordExpectedValue

EXPECTED_PASSWORD="derp"
echo -e "\n[INFO] Upgrading again with ${EXPECTED_PASSWORD} as password value"
install ${EXPECTED_PASSWORD}
isPasswordExpectedValue

EXPECTED_PASSWORD="derp"
echo -e "\n[INFO] Upgrading again with ${EXPECTED_PASSWORD} as password value"
install ${EXPECTED_PASSWORD}
isPasswordExpectedValue

echo -e "\n[INFO] Upgrading again with no password value"
install
isPasswordExpectedValue

EXPECTED_PASSWORD="herp"
echo -e "\n[INFO] Rolling back to release with value ${EXPECTED_PASSWORD}"
rollback 4
isPasswordExpectedValue

EXPECTED_PASSWORD="derp"
echo -e "\n[INFO] Rolling back to release with value ${EXPECTED_PASSWORD}"
rollback 7
isPasswordExpectedValue

echo ""
if [[ ${EXIT_CODE} -eq 0 ]]; then
    echo "[SUCCESS] All tests passed"
else
    echo "[FAIL] Some tests failed"
fi

exit ${EXIT_CODE}
