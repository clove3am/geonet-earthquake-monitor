#!/bin/bash

set -uo pipefail

SCRIPT_NAME=$(basename "${0}")
VERSION="1.0.1"
CACHE_FILE="${HOME}/.local/state/geonet-earthquake-monitor/notified.cache"

mkdir -p "$(dirname "${CACHE_FILE}")"
touch "${CACHE_FILE}"

usage() {
	cat <<EOF
Usage: ${SCRIPT_NAME} -m MMI -p PRIORITY

Monitor NZ earthquakes using the GeoNet API and send notifications via ntfy.

Required arguments:
    -m, --mmi MMI       Minimum MMI intensity (0-8)
    -p, --priority PRI  Notification priority (1-5)

Optional arguments:
    -h, --help          Show this help message and exit
    -v, --version       Show version information and exit

Environment variables required:
    NTFY_TOKEN_DEVICES  Authentication token for ntfy
    NTFY_GEONET_URL     The ntfy URL to publish to

Example:
    ${SCRIPT_NAME} -m 4 -p 4
EOF
}

check_dependencies() {
	local DEPS=(curl jq)
	for DEP in "${DEPS[@]}"; do
		if ! command -v "${DEP}" >/dev/null 2>&1; then
			echo "Error: Required dependency '${DEP}' is not installed." >&2
			exit 1
		fi
	done
}

check_env_vars() {
	if [[ -z "${NTFY_TOKEN_DEVICES:-}" ]]; then
		echo "Error: NTFY_TOKEN_DEVICES environment variable is not set." >&2
		exit 1
	fi
	if [[ -z "${NTFY_GEONET_URL:-}" ]]; then
		echo "Error: NTFY_GEONET_URL environment variable is not set." >&2
		exit 1
	fi
}

validate_args() {
	if [[ ! "${MMI}" =~ ^[0-8]$ ]]; then
		echo "Error: MMI must be between 0 and 8." >&2
		exit 1
	fi

	if [[ ! "${PRIORITY}" =~ ^[1-5]$ ]]; then
		echo "Error: Priority must be between 1 and 5." >&2
		exit 1
	fi
}

send_notification() {
	local PUBLIC_ID="${1}"
	local MAGNITUDE="${2}"
	local LOCALITY="${3}"
	local DEPTH="${4}"
	local TIME="${5}"
	local DISPLAY_TIME

	DISPLAY_TIME=$(date -d "${TIME}" "+%a %b %-d %Y %H:%M")

	if ! curl -s \
		-H "Authorization: Bearer ${NTFY_TOKEN_DEVICES}" \
		-H "Title: ${MAGNITUDE}M earthquake ${LOCALITY}" \
		-H "Tags: chart_with_upwards_trend" \
		-H "Priority: ${PRIORITY}" \
		-H "Click: https://www.geonet.org.nz/earthquake/${PUBLIC_ID}" \
		-d "Depth: ${DEPTH}km at ${DISPLAY_TIME}" \
		"${NTFY_GEONET_URL}"; then
		echo "Error: curl failed to send message"
		exit 1
	fi

	echo "${PUBLIC_ID}" >>"${CACHE_FILE}"
}

process_earthquakes() {
	local DATA
	DATA=$(curl -s "https://api.geonet.org.nz/quake?MMI=${MMI}")

	if ! echo "${DATA}" | jq empty >/dev/null 2>&1; then
		echo "Error: Invalid JSON response from GeoNet API" >&2
		exit 1
	fi

	echo "${DATA}" | jq -r '.features | sort_by(.properties.time) | .[] | select(.properties.quality != "deleted") | 
		[.properties.publicID, 
        (.properties.magnitude | . * 10 | round / 10),
        .properties.locality,
        (.properties.depth | round),
        .properties.time] | @tsv' |
		while IFS=$'\t' read -r PUBLIC_ID MAGNITUDE LOCALITY DEPTH TIME; do
			if ! grep -q "^${PUBLIC_ID}$" "${CACHE_FILE}"; then
				send_notification "${PUBLIC_ID}" "${MAGNITUDE}" "${LOCALITY}" "${DEPTH}" "${TIME}"
				sleep 1
			fi
		done
}

MMI=""
PRIORITY=""

while [[ $# -gt 0 ]]; do
	case "${1}" in
	-h | --help)
		usage
		exit 0
		;;
	-v | --version)
		echo "${VERSION}"
		exit 0
		;;
	-m | --mmi)
		MMI="${2}"
		shift 2
		;;
	-p | --priority)
		PRIORITY="${2}"
		shift 2
		;;
	*)
		echo "Error: Unknown argument '${1}'" >&2
		usage
		exit 1
		;;
	esac
done

if [[ -z "${MMI}" || -z "${PRIORITY}" ]]; then
	echo "Error: Missing required arguments" >&2
	usage
	exit 1
fi

check_dependencies
check_env_vars
validate_args
process_earthquakes
