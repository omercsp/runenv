#!/bin/bash
RE_GLOBAL_CONF_FILE="${HOME}/.config/runenv.conf"
RE_LOCAL_CONF_FILE=".runenv.conf"

_set_variable()
{
	local name=$1
	local default=$2
	local legal_values=$3
	local env_name=_$name

	if [[ -n ${!env_name+x} ]]; then
		eval ${name}=\"${!env_name}\"
	elif [[ -z ${!name+x} ]]; then
		eval ${name}=\"${default}\"
	fi

	[[ -z ${legal_values} ]] && return
	if [[ ! ${legal_values} =~  ${!name} ]]; then
		echo "Invalid arguemtn value '${!name}' for '${name}'"
		exit 1
	fi
}

_variable_str()
{
	local var=$1

	if [[ -z ${var} ]]; then
		echo "<None>"
	else
		echo ${var}
	fi
}

# Read configuration files
dir=$(pwd)

[[ -e ${RE_GLOBAL_CONF_FILE} ]] && source ${RE_GLOBAL_CONF_FILE}
while [[ ${dir} != "/" ]]; do
	conf_file=${dir}/${RE_LOCAL_CONF_FILE}
	if [[ -e ${conf_file} ]]; then
		source ${conf_file}
		break
	fi
	dir=$(realpath "${dir}/../")
done

_set_variable "RE_SHOW_SPLASH" "1" "0 1"
_set_variable "RE_TOOL" "podman" "podman docker"
_set_variable "RE_VERBOSE" "1" "0 1"
_set_variable "RE_NOTIFY_NATIVE" "0" "0 1"
_set_variable "RE_CONTAINER_ONLY" "0" "0 1"
_set_variable "RE_RUN_FLAGS"
_set_variable "RE_EXEC_FLAGS"
_set_variable "RE_VOL_MAPPING"
_set_variable "RE_VOL_PWD" "0" "0 1"
_set_variable "RE_COLORS" "1" "0 1"
_set_variable "RE_USE_CUR_CWD" "1" "0 1"
_set_variable "RE_CWD"
_set_variable "RE_CMD" "" ""
_set_variable "RE_REUSE_CONTAINER" "0" "0 1"

cmd=$*
[[ -z ${cmd} ]] && cmd=${RE_CMD}

if [[ -z ${RE_IMAGE} ]]; then
	if [[ ${RE_CONTAINER_ONLY} -eq 1 ]]; then
		echo "Missing image setting. Nothing to do"
		exit 1
	else
		if [[ ${RE_NOTIFY_NATIVE} -eq 1 ]]; then
			echo "No image found, running native command '${cmd}'"
			echo
		fi
		${cmd}
		exit $?
	fi
fi

# Set working direcotry, defult to current directory
if [[ -n ${RE_CWD} ]]; then
	RE_RUN_FLAGS+="-w=${RE_CWD}"
elif [[ ${RE_USE_CUR_CWD} -eq 1 ]]; then
	RE_RUN_FLAGS+="-w=$(pwd)"
fi

# Set volume mappings
old_ifs=${IFS}
IFS=";"
RE_VOL_MAPPING=(${RE_VOL_MAPPING})
IFS=${old_ifs}
if [[ ${RE_VOL_PWD} -eq 1 ]]; then
	RE_VOL_MAPPING+=(${PWD}:${PWD})
fi

# Check if to start a new container or try to exec an existing one
if [[ ${RE_REUSE_CONTAINER} -eq 1 ]]; then
	container_name=$(echo ${RE_IMAGE} ${RE_RUN_FLAGS} | md5sum | cut -d' ' -f1)
	container_id=$(${RE_TOOL} ps -a --filter=name=${container_name} --format="{{.Names}}")
	RE_RUN_FLAGS+=" -d -t" # Unless '-t' is set, we can't exec commands on it
	[[ ${RE_COLORS} -eq 1 ]] && RE_EXEC_FLAGS+=" -t"
else
	RE_RUN_FLAGS+="${RE_EXEC_FLAGS} --rm"
	[[ ${RE_COLORS} -eq 1 ]] && RE_RUN_FLAGS+=" -t"
fi

# Show some run environment info and maybe a minor splash screen
if [[ ${RE_VERBOSE} -gt 0 ]]; then
	if [[ ${RE_SHOW_SPLASH} -eq 1 ]]; then
		echo " __             ___"
		echo "|__) |  | |\ | |__  |\ | \  /"
		echo "|  \ \__/ | \| |___ | \|  \/"
		echo
	fi
	echo "Configuration file: $(_variable_str ${conf_file})"
	echo "Tool: ${RE_TOOL}"
	echo "Image: ${RE_IMAGE}"
	echo "Run flags: $(_variable_str ${RE_RUN_FLAGS})"
	case ${#RE_VOL_MAPPING[@]} in
	0)
		echo "Volumes: <None>"
		;;
	1)
		echo "Volume: ${RE_VOL_MAPPING[0]}"
		;;
	*)
		echo "Volumes:"
		index=1
		for volmap in ${RE_VOL_MAPPING[@]}; do
			echo -e "\t${index}. '${volmap}'"
			index=$(( index + 1 ))
		done
		;;
	esac
	if [[ ${RE_REUSE_CONTAINER} -eq 1 ]]; then
		if [[ -n ${container_id} ]]; then
			echo "Using existing container '${container_name}'"
			echo "Exec flags: $(_variable_str ${RE_EXEC_FLAGS})"
			echo "Container ID=${container_id}"
		else
			echo "Creating build container '${container_name}'"
		fi
	fi
	echo "Command: '$(_variable_str "${cmd}")'"
	echo ==============================================================================
fi

# Add volume mappings to the container run flags
for vol in ${RE_VOL_MAPPING[@]}; do
	RE_RUN_FLAGS+=" -v ${vol}"
done

if [[ ${RE_REUSE_CONTAINER} -eq 1 ]]; then
	if [[ -z ${container_id} ]]; then
		${RE_TOOL} run --name ${container_name} ${RE_RUN_FLAGS} ${RE_IMAGE} > /dev/null
		if [[ $? -ne 0 ]]; then
			echo "Error creating container"
			exit 1
		fi
	fi
	${RE_TOOL} exec ${RE_EXEC_FLAGS} ${container_name} bash -c "${cmd}"
else
	${RE_TOOL} run ${RE_RUN_FLAGS} ${RE_IMAGE} bash -c "${cmd}"
fi
ret=$?

if [[ ${RE_VERBOSE} -eq 1 ]]; then
	echo ==============================================================================
	echo Done!
fi
exit $ret

